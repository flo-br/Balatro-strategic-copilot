-- Balatro Strategic Copilot - engine/shop.lua  (ShopAnalyzer)
-- Every option is evaluated as a VARIANT of the current state (buy X, sell Y, replace Y by X,
-- level up a hand...) and measured with the same sampled hands as the base build (common
-- random numbers), which gives:
--   ratio      : per-hand power ratio (simulated)
--   d_next     : change of P(clear next blind)   (bootstrap from samples)
--   d_boss     : change of P(clear the ante boss) (boss-specific samples, scaled)
--   d_win      : change of the run outlook        (model with limited confidence)
-- Effects that cannot be simulated get documented heuristic values (method 'heuristic').
-- The strategic note /100 combines these components (docs/MATHS.md §note); weights depend
-- continuously on the current danger and can only evolve through validated learning.

local BSC = BSCopilot
local U = BSC.require('core/util')
local R = BSC.require('core/rng')
local C = BSC.require('model/cards')
local H = BSC.require('model/hands')
local DB = BSC.require('model/jokers_db')
local IT = BSC.require('model/items_db')
local E = BSC.require('engine/economy')
local ST = BSC.require('engine/strategy')
local SY = BSC.require('engine/synergy')
local HA = BSC.require('engine/hand_advisor')

local SH = {}

local function noop() end
local function tanh(x) local e = math.exp(2 * x); return (e - 1) / (e + 1) end

SH.DEFAULT_WEIGHTS = { impact = 1.4, impact_danger = 1.6, power = 1.0, potential = 0.9, synergy = 0.5,
    econ = 0.8, cost = 0.7, cost_floor = 0.3, risk = 0.6 }

function SH.weights(danger, base)
    base = base or SH.DEFAULT_WEIGHTS
    local d = danger or 0
    return {
        impact = base.impact + base.impact_danger * d,
        power = base.power,
        potential = base.potential * (1 - d) + 0.1,
        synergy = base.synergy,
        econ = base.econ * (1 - d) + 0.1,
        cost = base.cost * (1 - d) + base.cost_floor,
        risk = base.risk,
    }
end

function SH.note(c, w)
    local z = w.impact * (c.impact or 0) + w.power * (c.power or 0) + w.potential * (c.potential or 0)
        + w.synergy * (c.synergy or 0) + w.econ * (c.econ or 0) - w.cost * (c.cost or 0) - w.risk * (c.risk or 0)
    local n = 50 + 50 * tanh(z)
    n = 50 + (n - 50) * (c.reliability or 1)
    return math.floor(U.clamp(n, 0, 100) + 0.5)
end

-- State variants ------------------------------------------------------------------------------
local function copy_state(state)
    local s = {}
    for k, v in pairs(state) do s[k] = v end
    return s
end

local function copy_list(t) local o = {} for i, v in ipairs(t or {}) do o[i] = v end return o end

local function copy_hands(hands)
    local o = {}
    for k, v in pairs(hands or {}) do
        local h = {}
        for kk, vv in pairs(v) do h[kk] = vv end
        o[k] = h
    end
    return o
end

local function pick_targets(deck, n, pred, better)
    local cands = {}
    for i, c in ipairs(deck) do if pred(c) then cands[#cands + 1] = i end end
    table.sort(cands, function(a, b) return better(deck[a], deck[b]) end)
    local out = {}
    for i = 1, math.min(n, #cands) do out[i] = cands[i] end
    return out
end

function SH.variant(state, ch)
    local s = copy_state(state)
    if ch.add_joker then
        s.jokers = copy_list(state.jokers)
        s.jokers[#s.jokers + 1] = ch.add_joker
        if ch.add_joker.edition == 'e_negative' then s.joker_slots = (state.joker_slots or 5) + 1 end
    end
    if ch.remove_joker then
        s.jokers = {}
        for i, j in ipairs(state.jokers or {}) do if i ~= ch.remove_joker then s.jokers[#s.jokers + 1] = j end end
    end
    if ch.replace_joker then
        s.jokers = copy_list(state.jokers)
        s.jokers[ch.replace_joker] = ch.with
    end
    if ch.level then
        s.hands = copy_hands(state.hands)
        local h = s.hands[ch.level]
        if h then
            h.level = (h.level or 1) + (ch.n or 1)
            h.chips = (h.chips or 0) + (h.l_chips or 0) * (ch.n or 1)
            h.mult = (h.mult or 1) + (h.l_mult or 0) * (ch.n or 1)
        end
    end
    if ch.level_all then
        s.hands = copy_hands(state.hands)
        for _, h in pairs(s.hands) do
            h.level = (h.level or 1) + ch.level_all
            h.chips = (h.chips or 0) + (h.l_chips or 0) * ch.level_all
            h.mult = (h.mult or 1) + (h.l_mult or 0) * ch.level_all
        end
    end
    if ch.enhance or ch.suit then
        local deck = {}
        for i, c in ipairs(state.full_deck or {}) do deck[i] = c end
        local idx
        if ch.enhance then
            idx = pick_targets(deck, ch.n or 1, function(c) return not c.enh end,
                function(a, b) return HA.card_value(a) > HA.card_value(b) end)
            for _, i in ipairs(idx) do local c = C.copy(deck[i]); C.set_enhancement(c, ch.enhance); deck[i] = c end
        else
            idx = pick_targets(deck, ch.n or 3, function(c) return c.suit ~= ch.suit and not c.no_suit end,
                function(a, b) return HA.card_value(a) < HA.card_value(b) end)
            for _, i in ipairs(idx) do local c = C.copy(deck[i]); c.suit = ch.suit; c.suit_nominal = C.SUIT_NOMINAL[ch.suit]; deck[i] = c end
        end
        s.full_deck = deck
        local SR = BSC.require('game/state_reader')
        s.full_deck_stats = SR.deck_stats(deck, state.full_deck_stats and state.full_deck_stats.starting_size or 52)
    end
    if ch.hands or ch.discards or ch.hand_size then
        local r = {}
        for k, v in pairs(state.round or {}) do r[k] = v end
        r.round_hands = math.max(1, (r.round_hands or 4) + (ch.hands or 0))
        r.round_discards = math.max(0, (r.round_discards or 3) + (ch.discards or 0))
        r.hand_size = math.max(1, (r.hand_size or 8) + (ch.hand_size or 0))
        s.round = r
    end
    if ch.dollars then
        local e = {}
        for k, v in pairs(state.econ or {}) do e[k] = v end
        e.dollars = (e.dollars or 0) + ch.dollars
        if ch.interest_cap then e.interest_cap = (e.interest_cap or 25) + ch.interest_cap end
        s.econ = e
    end
    if ch.slots then s.joker_slots = (state.joker_slots or 5) + ch.slots end
    return s
end

-- Measurement ----------------------------------------------------------------------------------
local function measure(ctx, st, label)
    local ps = ST.power_samples(st, { n = ctx.n, seed = 'shop', task = ctx.task })
    local ratio = (ctx.base.ps.mean > 0) and (ps.mean / ctx.base.ps.mean) or 1
    local p_next = ctx.X_next and ST.p_clear_bootstrap(ps, ctx.X_next, { seed = 'next', B = 300 }) or nil
    local p_boss = ctx.X_boss and ctx.base.ps_boss and ST.p_clear_bootstrap(ctx.base.ps_boss, ctx.X_boss, { seed = 'boss', B = 300, scale = ratio }) or nil
    local out = ST.run_outlook(st, ps, { profile = ctx.profile, calibrate = ctx.calibrate, B = 200 })
    return { ps = ps, ratio = ratio, p_next = p_next, p_boss = p_boss, p_win = out.p_win, expected_blinds = out.expected_blinds,
        complete = #(ps.coverage and ps.coverage.unsupported or {}) == 0 }
end

-- generic growth of scaling jokers for the "potential" component (heuristic, documented)
local GROWTH = {
    j_green_joker = { field = 'mult', per_round = 3 }, j_ride_the_bus = { field = 'mult', per_round = 2 },
    j_runner = { field = 'extra.chips', per_round = 15 }, j_square = { field = 'extra.chips', per_round = 4 },
    j_constellation = { field = 'x_mult', per_round = 0.1 }, j_hologram = { field = 'x_mult', per_round = 0.1 },
    j_vampire = { field = 'x_mult', per_round = 0.2 }, j_lucky_cat = { field = 'x_mult', per_round = 0.25 },
    j_madness = { field = 'x_mult', per_round = 0.33 }, j_campfire = { field = 'x_mult', per_round = 0.15 },
    j_red_card = { field = 'mult', per_round = 2 }, j_flash = { field = 'mult', per_round = 2 },
    j_glass = { field = 'x_mult', per_round = 0.2 }, j_hit_the_road = { field = 'x_mult', per_round = 0.3 },
    j_obelisk = { field = 'x_mult', per_round = 0.3 }, j_trousers = { field = 'mult', per_round = 2 },
    j_wee = { field = 'extra.chips', per_round = 8 }, j_ceremonial = { field = 'mult', per_round = 4 },
    j_castle = { field = 'extra.chips', per_round = 9 }, j_yorick = { field = 'x_mult', per_round = 0.15 },
    j_caino = { field = 'caino_xmult', per_round = 0.3 }, j_throwback = { field = 'x_mult', per_round = 0.1 },
}

local function grown(joker, rounds)
    local g = GROWTH[joker.key]
    if not g then return nil end
    local j = {}
    for k, v in pairs(joker) do j[k] = v end
    j.ability = U.deepcopy(joker.ability or {}, 6) or {}
    local inc = g.per_round * rounds
    if g.field == 'extra.chips' then
        if type(j.ability.extra) ~= 'table' then j.ability.extra = {} end
        j.ability.extra.chips = (j.ability.extra.chips or 0) + inc
    else
        local base = j.ability[g.field]
        if g.field == 'x_mult' or g.field == 'caino_xmult' then base = base or 1 else base = base or 0 end
        j.ability[g.field] = base + inc
    end
    return j
end
SH.grown = grown

local function risk_of(def, joker)
    local r, notes = 0, {}
    if def and def.risk and def.risk.destroy_odds then
        r = r + math.min(0.6, 3 / def.risk.destroy_odds); notes[#notes + 1] = 'peut être détruit'
    end
    if joker then
        if joker.perishable then r = r + 0.3; notes[#notes + 1] = 'périssable' end
        if joker.rental then r = r + 0.3; notes[#notes + 1] = 'location (3 $/manche)' end
        if joker.eternal then r = r + 0.1; notes[#notes + 1] = 'éternel (invendable)' end
    end
    if def then
        for _, t in ipairs(def.tags) do
            if t == 'destroys_jokers' then r = r + 0.25; notes[#notes + 1] = 'détruit d\'autres jokers' end
            if t == 'decaying' then r = r + 0.1; notes[#notes + 1] = 's\'affaiblit avec le temps' end
            if t == 'hand_size_minus' then r = r + 0.15; notes[#notes + 1] = '-2 taille de main' end
        end
    end
    return U.clamp(r, 0, 1), notes
end

local function econ_of(def, joker, state)
    if not def or not def.econ then return 0, nil end
    local e = def.econ
    local v = 0
    local why
    if e.per_round then v = v + e.per_round end
    if e.per_nine_per_round then v = v + e.per_nine_per_round * ((state.full_deck_stats or {}).nines or 4) end
    if e.interest_bonus then v = v + math.min(5, math.floor(((state.econ or {}).dollars or 0) / 5)) end
    if e.sell_value_per_round then v = v + e.sell_value_per_round end
    if e.sell_value_all_per_round then v = v + e.sell_value_all_per_round * math.max(1, #(state.jokers or {})) end
    if e.avg_per_round then v = v + e.avg_per_round end
    if e.per_face_scored then v = v + 1.5 end
    if e.per_unused_discard_if_none_used then v = v + 2 end
    if e.free_rerolls then v = v + 2 end
    if e.per_round_field then v = v + 2 end
    if e.per_matching_discard then v = v + 3 end
    if e.first_discard_single then v = v + 2 end
    if e.conditional_discard then v = v + 2 end
    if e.debt then v = v + 1; why = 'permet de s\'endetter jusqu\'à ' .. e.debt .. ' $' end
    if v > 0 and not why then why = string.format('rapporte ~%d $/manche (estimation)', math.floor(v + 0.5)) end
    return v, why
end

-- Value (dollars-equivalent) of a joker type for the reroll/booster estimates.
local function joker_entry_from_def(key)
    local def = DB.get(key)
    local ab = U.deepcopy(def.config or {}, 6) or {}
    if ab.Xmult then ab.x_mult = ab.Xmult end
    ab.x_mult = ab.x_mult or 1
    ab.mult = ab.mult or 0
    return { key = key, name = def.name, ability = ab, rarity = def.rarity, blueprint_compat = def.bp,
        sell_cost = math.floor((def.cost or 4) / 2), cost = def.cost }
end
SH.joker_entry_from_def = joker_entry_from_def

-- Analysis ---------------------------------------------------------------------------------------
-- ctx inputs: { n, profile, calibrate, weights, task, publish }
function SH.analyse(state, opts, task)
    opts = opts or {}
    local check = (task and task.check) or noop
    local publish = opts.publish or noop
    local ctx = { n = opts.n or 48, profile = opts.profile, calibrate = opts.calibrate, task = task }
    local econ = state.econ or {}
    local dollars = econ.dollars or 0
    local floor_money = econ.bankrupt_at or 0

    -- base build
    local blinds = ST.remaining_blinds(state)
    local next_b, boss_b
    for _, b in ipairs(blinds) do
        if not next_b then next_b = b end
        if b.boss and not boss_b then boss_b = b end
    end
    ctx.X_next = next_b and next_b.chips
    ctx.X_boss = boss_b and boss_b.chips
    local ps0 = ST.power_samples(state, { n = ctx.n, seed = 'shop', task = task, keep_plays = true })
    local boss_key = boss_b and boss_b.key
    local ps_boss = ST.power_samples(state, { n = ctx.n, seed = 'shop', task = task, boss = boss_key })
    local outlook = ST.run_outlook(state, ps0, { profile = ctx.profile, calibrate = ctx.calibrate, B = 300 })
    local p_next, p_next_lo, p_next_hi, p_boss, p_boss_lo, p_boss_hi
    if ctx.X_next then p_next, p_next_lo, p_next_hi = ST.p_clear_bootstrap(ps0, ctx.X_next, { seed = 'next', B = 300 }) end
    if ctx.X_boss then p_boss, p_boss_lo, p_boss_hi = ST.p_clear_bootstrap(ps_boss, ctx.X_boss, { seed = 'boss', B = 300 }) end
    if ctx.calibrate then
        if p_next then p_next = ctx.calibrate(p_next) end
        if p_boss then p_boss = ctx.calibrate(p_boss) end
    end
    local danger = ST.danger(p_next, p_boss)
    ctx.base = { ps = ps0, ps_boss = ps_boss, p_next = p_next, p_boss = p_boss, p_win = outlook.p_win }
    local w = SH.weights(danger, opts.weights)
    local themes = SY.themes(state, ps0)
    local res = {
        base = { mean = ps0.mean, median = ps0.median, q25 = ps0.q25, q75 = ps0.q75, p_next = p_next, p_boss = p_boss,
            p_next_lo = p_next_lo, p_next_hi = p_next_hi, p_boss_lo = p_boss_lo, p_boss_hi = p_boss_hi,
            p_win = outlook.p_win, expected_blinds = outlook.expected_blinds, growth = outlook.growth,
            growth_source = outlook.growth_source, endless = outlook.endless, usage = ST.usage_fractions(ps0) },
        next_blind = next_b, boss = boss_b, danger = danger, weights = w, options = {}, sells = {},
        interest = { now = E.interest(dollars, econ), next_step = E.next_step(dollars, econ) },
        coverage = ps0.coverage,
    }
    publish(res)

    local function components(m, extra)
        local c = {}
        local dn = (m.p_next and p_next) and (m.p_next - p_next) or 0
        local db = (m.p_boss and p_boss) and (m.p_boss - p_boss) or 0
        local dw = (m.p_win and outlook.p_win) and (m.p_win - outlook.p_win) or 0
        c.impact = U.clamp((0.35 * dn + 0.35 * db + 0.3 * dw) * 5, -1.5, 1.5)
        c.power = U.clamp(math.log(math.max(1e-6, m.ratio)) / math.log(2), -1, 1)
        for k, v in pairs(extra or {}) do c[k] = v end
        return c
    end

    local function finish(opt, m, comp)
        opt.note = SH.note(comp, w)
        opt.components = comp
        if m then
            opt.ratio = m.ratio
            opt.p_next, opt.p_boss, opt.p_win = m.p_next, m.p_boss, m.p_win
            opt.d_next = (m.p_next and p_next) and (m.p_next - p_next) or nil
            opt.d_boss = (m.p_boss and p_boss) and (m.p_boss - p_boss) or nil
            opt.d_win = (m.p_win and outlook.p_win) and (m.p_win - outlook.p_win) or nil
        end
        res.options[#res.options + 1] = opt
    end

    local function cost_component(cost)
        local loss = E.interest_loss(dollars, cost, econ)
        return U.clamp((cost + 3 * loss) / math.max(10, dollars + 10), 0, 1.5), loss
    end

    local slots_free = (state.joker_slots or 5) - #(state.jokers or {})
    local shop = state.shop or {}
    local items = {}
    for _, it in ipairs(shop.jokers or {}) do items[#items + 1] = it end
    for _, it in ipairs(shop.vouchers or {}) do items[#items + 1] = it end
    for _, it in ipairs(shop.boosters or {}) do items[#items + 1] = it end
    if opts.pack_items then items = opts.pack_items end

    for _, it in ipairs(items) do
        check()
        local cost = opts.pack_items and 0 or (it.cost or 0)
        local affordable = (dollars - cost) >= floor_money
        local opt = { kind = 'item', set = it.set, key = it.key, uid = it.uid, name = it.name or it.key, cost = cost,
            affordable = affordable, reasons = {}, risks = {}, method = 'simulation' }
        local cc, loss = cost_component(cost)
        opt.interest_loss = loss
        if it.set == 'Joker' and it.joker then
            local j = it.joker
            local def = DB.get(j.key, j.name)
            opt.kind = 'joker'
            opt.name = j.name or opt.name
            local need_slot = (j.edition ~= 'e_negative')
            if not need_slot or slots_free > 0 then
                local st = SH.variant(state, { add_joker = j, dollars = -cost })
                local m = measure(ctx, st)
                local pot = 0
                local gj = grown(j, 3)
                if gj then
                    local st2 = SH.variant(state, { add_joker = gj, dollars = -cost })
                    local m2 = measure(ctx, st2)
                    pot = U.clamp(math.log(math.max(1e-6, m2.ratio / math.max(1e-6, m.ratio))) / math.log(2), 0, 1)
                    if pot > 0.05 then opt.reasons[#opt.reasons + 1] = 'progresse avec le temps' end
                end
                local fit, why = SY.fit(def, themes)
                for _, r in ipairs(why) do opt.reasons[#opt.reasons + 1] = r end
                local risk, rnotes = risk_of(def, j)
                for _, r in ipairs(rnotes) do opt.risks[#opt.risks + 1] = r end
                local ev, ewhy = econ_of(def, j, state)
                if ewhy then opt.reasons[#opt.reasons + 1] = ewhy end
                if not def then opt.risks[#opt.risks + 1] = 'joker non reconnu : effet non simulé'; opt.method = 'partial' end
                local comp = components(m, { potential = pot, synergy = fit, econ = U.clamp(ev * 3 / 20, -1, 1), cost = cc, risk = risk,
                    reliability = (def and m.complete) and 1 or 0.5 })
                finish(opt, m, comp)
            else
                -- no free slot: best replacement
                local best
                for k, owned in ipairs(state.jokers or {}) do
                    check()
                    if not owned.eternal then
                        local st = SH.variant(state, { replace_joker = k, with = j, dollars = -cost + (owned.sell_cost or 0) })
                        local m = measure(ctx, st)
                        if not best or m.ratio > best.m.ratio then best = { k = k, m = m, owned = owned } end
                    end
                end
                if best then
                    opt.kind = 'replace'
                    opt.replaces = best.owned.name
                    opt.replace_index = best.k
                    opt.cost = cost - (best.owned.sell_cost or 0)
                    local fit, why = SY.fit(def, themes)
                    for _, r in ipairs(why) do opt.reasons[#opt.reasons + 1] = r end
                    local risk, rnotes = risk_of(def, j)
                    for _, r in ipairs(rnotes) do opt.risks[#opt.risks + 1] = r end
                    local cc2 = cost_component(math.max(0, opt.cost))
                    local comp = components(best.m, { synergy = fit, cost = cc2, risk = risk, reliability = def and 1 or 0.5 })
                    finish(opt, best.m, comp)
                else
                    opt.note = 0; opt.blocked = 'no_slot'; res.options[#res.options + 1] = opt
                end
            end
        elseif it.set == 'Planet' then
            opt.kind = 'planet'
            local hand = it.hand_type or H.PLANETS[it.key]
            if hand then
                local st = SH.variant(state, { level = hand, n = 1, dollars = -cost })
                local m = measure(ctx, st)
                local use = res.base.usage[hand] or 0
                if use > 0.2 then opt.reasons[#opt.reasons + 1] = string.format('main jouée %d %% du temps', math.floor(use * 100)) end
                finish(opt, m, components(m, { synergy = U.clamp(use * 1.5, 0, 1), cost = cc, reliability = m.complete and 1 or 0.5 }))
            else
                opt.method = 'heuristic'
                finish(opt, nil, { econ = 0.1, cost = cc, reliability = 0.6 })
            end
        elseif it.set == 'Tarot' or it.set == 'Spectral' then
            opt.kind = it.set == 'Tarot' and 'tarot' or 'spectral'
            local info = IT.consumable(it.key) or {}
            local sim = info.sim
            if sim and (sim.enhance or sim.suit or sim.level_all) then
                local ch = { dollars = -cost }
                if sim.enhance then ch.enhance = sim.enhance; ch.n = sim.n end
                if sim.suit then ch.suit = sim.suit; ch.n = sim.n end
                if sim.level_all then ch.level_all = sim.level_all end
                local st = SH.variant(state, ch)
                local m = measure(ctx, st)
                opt.method = 'simulation_approx'
                opt.reasons[#opt.reasons + 1] = 'effet simulé sur des cartes cibles probables'
                finish(opt, m, components(m, { cost = cc, econ = 0, reliability = 0.8 }))
            else
                opt.method = 'heuristic'
                local v = info.v or 3
                if info.money == 'double' then v = math.min(dollars, 20) end
                if info.money == 'sell_values' then
                    local sv = 0
                    for _, j in ipairs(state.jokers or {}) do sv = sv + (j.sell_cost or 0) end
                    v = math.min(sv, 50)
                end
                if info.desc then opt.reasons[#opt.reasons + 1] = info.desc end
                finish(opt, nil, { econ = U.clamp((v - cost) / 10, -1, 1), cost = cc * 0.5, reliability = 0.6 })
            end
        elseif it.set == 'Voucher' then
            opt.kind = 'voucher'
            local info = IT.VOUCHERS[it.key] or {}
            local sim = info.sim
            if sim and (sim.hands or sim.discards or sim.hand_size or sim.slot or sim.interest_cap or sim.ante) then
                local ch = { dollars = -cost, hands = sim.hands, discards = sim.discards, hand_size = sim.hand_size, slots = sim.slot,
                    interest_cap = sim.interest_cap }
                local st = SH.variant(state, ch)
                if sim.ante then
                    local run = {}
                    for k, v in pairs(st.run or {}) do run[k] = v end
                    run.ante = math.max(1, (run.ante or 1) + sim.ante)
                    st.run = run
                end
                local m = measure(ctx, st)
                -- slot value is not visible in current power: value the option of a future joker
                local extra = {}
                if sim.slot then extra.potential = 0.4; opt.reasons[#opt.reasons + 1] = 'emplacement de joker supplémentaire' end
                if sim.interest_cap then extra.econ = U.clamp((dollars >= 25) and 0.5 or 0.15, 0, 1); opt.reasons[#opt.reasons + 1] = 'plafond d\'intérêts relevé' end
                if sim.hands then opt.reasons[#opt.reasons + 1] = '+1 main par manche' end
                if sim.discards then opt.reasons[#opt.reasons + 1] = '+1 défausse par manche' end
                if sim.hand_size then opt.reasons[#opt.reasons + 1] = '+1 taille de main' end
                extra.cost = cc
                extra.reliability = 0.9
                opt.method = 'simulation'
                finish(opt, m, components(m, extra))
            else
                opt.method = 'heuristic'
                local v = info.v or 4
                finish(opt, nil, { econ = U.clamp((v - cost) / 12, -1, 1), potential = 0.2, cost = cc * 0.6, reliability = 0.6 })
            end
        elseif it.set == 'Booster' then
            opt.kind = 'booster'
            opt.method = 'heuristic'
            local info = IT.BOOSTERS[it.kind or ''] or { v = 3 }
            local v = info.v
            if info.jokers and slots_free <= 0 then v = v * 0.4; opt.risks[#opt.risks + 1] = 'aucun emplacement de joker libre' end
            if it.choose and it.pack_size then v = v * (0.7 + 0.15 * it.choose + 0.05 * it.pack_size) end
            finish(opt, nil, { econ = U.clamp((v - cost) / 8, -1, 1), cost = cc * 0.6, reliability = 0.6 })
        elseif it.card then
            opt.kind = 'card'
            opt.method = 'heuristic'
            finish(opt, nil, { econ = -0.1, cost = cc, reliability = 0.5 })
        end
    end
    table.sort(res.options, function(a, b) return (a.note or 0) > (b.note or 0) end)
    publish(res)

    -- sells (only meaningful ones)
    for k, j in ipairs(state.jokers or {}) do
        check()
        if not j.eternal and not opts.pack_items then
            local st = SH.variant(state, { remove_joker = k, dollars = j.sell_cost or 0 })
            local m = measure(ctx, st)
            local def = DB.get(j.key, j.name)
            local ev = econ_of(def, j, state)
            local comp = components(m, { econ = U.clamp(((j.sell_cost or 0) - ev * 2) / 15, -1, 1), reliability = def and 1 or 0.5 })
            local note = SH.note(comp, w)
            res.sells[#res.sells + 1] = { index = k, name = j.name, uid = j.uid, sell = j.sell_cost or 0, note = note, ratio = m.ratio,
                d_next = (m.p_next and p_next) and (m.p_next - p_next) or nil, d_boss = (m.p_boss and p_boss) and (m.p_boss - p_boss) or nil,
                contribution = 1 - m.ratio }
        end
    end
    table.sort(res.sells, function(a, b) return a.note > b.note end)

    -- joker order
    res.order = SY.best_order(state, ps0, task)

    -- reroll: expected best new item value vs cost (pool distribution from game data)
    if state.phase == 'shop' and not opts.pack_items then
        res.reroll = SH.reroll_value(state, ctx, res, w, task)
    end
    res.active_synergies = SY.active(state, ps0)
    publish(res)
    return res
end

-- Reroll ------------------------------------------------------------------------------------------
-- Uses: shop rates (read from the game), vanilla rarity weights 70/25/5 %, the joker pool
-- (unlocked / gated jokers read from the game when available), owned jokers excluded.
SH.RARITY_WEIGHTS = { 0.70, 0.25, 0.05 }

function SH.joker_pool(state)
    local owned = {}
    for _, j in ipairs(state.jokers or {}) do owned[j.key] = true end
    local showman = owned.j_ring_master
    local pool = { {}, {}, {} }
    if state.joker_pool then
        for _, p in ipairs(state.joker_pool) do
            if p.available and (showman or not owned[p.key]) and p.rarity and pool[p.rarity] then
                table.insert(pool[p.rarity], p.key)
            end
        end
    else
        for _, k in ipairs(DB.all_keys()) do
            local d = DB.get(k)
            if d.rarity <= 3 and (showman or not owned[k]) and k ~= 'j_cavendish' then table.insert(pool[d.rarity], k) end
        end
    end
    return pool
end

function SH.reroll_value(state, ctx, res, w, task)
    local check = (task and task.check) or noop
    local econ = state.econ or {}
    local rates = econ.rates or { joker = 20, tarot = 4, planet = 4, spectral = 0 }
    local total_rate = (rates.joker or 0) + (rates.tarot or 0) + (rates.planet or 0) + (rates.spectral or 0) + (rates.playing_card or 0)
    local p_joker = total_rate > 0 and (rates.joker or 0) / total_rate or 0
    local pool = SH.joker_pool(state)
    local rng = R.new('reroll')
    local M = 10
    local values = {}
    local slots_free = (state.joker_slots or 5) - #(state.jokers or {})
    for i = 1, M do
        check()
        local r = rng:weighted(SH.RARITY_WEIGHTS)
        if #pool[r] == 0 then r = 1 end
        local list = pool[r]
        local key = (#list > 0) and list[rng:int(1, #list)] or nil
        if key and not DB.get(key) then
            -- modded joker in the pool: its value cannot be simulated (neutral, flagged)
            values[#values + 1] = { key = key, name = key, note = 50, unknown = true }
        elseif key then
            local j = joker_entry_from_def(key)
            local note
            if slots_free > 0 then
                local st = SH.variant(state, { add_joker = j, dollars = -(j.cost or 5) })
                local m = measure({ n = math.max(24, math.floor(ctx.n / 2)), base = ctx.base, X_next = ctx.X_next, X_boss = ctx.X_boss,
                    profile = ctx.profile, calibrate = ctx.calibrate, task = task }, st)
                local fit = SY.fit(DB.get(key), SY.themes(state, ctx.base.ps))
                local dn = (m.p_next and res.base.p_next) and (m.p_next - res.base.p_next) or 0
                local db = (m.p_boss and res.base.p_boss) and (m.p_boss - res.base.p_boss) or 0
                local comp = { impact = U.clamp((0.5 * dn + 0.5 * db) * 5, -1.5, 1.5),
                    power = U.clamp(math.log(math.max(1e-6, m.ratio)) / math.log(2), -1, 1), synergy = fit,
                    cost = U.clamp((j.cost or 5) / math.max(10, (econ.dollars or 0) + 10), 0, 1.5), reliability = 1 }
                note = SH.note(comp, w)
            else
                note = 40
            end
            values[#values + 1] = { key = key, name = DB.get(key).name, note = note }
        end
    end
    -- expected best note among 2 new slots (bootstrap), non-joker slots counted as average (50)
    local B = 400
    local brng = R.new('reroll_boot')
    local sum_best = 0
    local best_now = 50
    for _, o in ipairs(res.options) do if o.affordable and (o.note or 0) > best_now then best_now = o.note end end
    local improve = 0
    for _ = 1, B do
        local best = 0
        for _ = 1, 2 do
            local v
            if brng:float() < p_joker and #values > 0 then v = values[brng:int(1, #values)].note else v = 50 end
            if v > best then best = v end
        end
        sum_best = sum_best + best
        if best > best_now then improve = improve + 1 end
    end
    local exp_best = sum_best / B
    local cost = econ.reroll_cost or 5
    local loss = E.interest_loss(econ.dollars or 0, cost, econ)
    local p_improve = improve / B
    local worth = (exp_best - best_now) > 4 and p_improve > 0.3 and (econ.dollars or 0) - cost >= (econ.bankrupt_at or 0)
    return { cost = cost, expected_best_note = exp_best, current_best_note = best_now, p_improve = p_improve,
        interest_loss = loss, worth = worth, samples = values, p_joker = p_joker, method = 'monte_carlo', n = #values }
end

return SH
