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
local BD = BSC.require('engine/builds')
local HA = BSC.require('engine/hand_advisor')
local EF = BSC.require('model/effects_db')
local PL = BSC.require('engine/plan')
local FB = BSC.require('learning/feedback')
local I = BSC.require('core/i18n')

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
    if ch.jokers then s.jokers = ch.jokers end
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

local function risk_of(def, joker, state)
    local r, notes = 0, {}
    if def and def.risk and def.risk.destroy_odds then
        r = r + math.min(0.6, 3 / def.risk.destroy_odds); notes[#notes + 1] = 'peut être détruit'
    end
    if joker then
        if joker.perishable then
            local left = EF.perish_left(joker) or 5
            r = r + U.clamp(0.6 - 0.1 * left, 0.1, 0.6)
            notes[#notes + 1] = string.format('périssable : actif encore %d manche(s)', left)
        end
        -- the $3 per round is counted in the economy part of the note (econ_of)
        if joker.rental then r = r + 0.1; notes[#notes + 1] = 'location (3 $/manche)' end
        if joker.eternal then
            r = r + 0.1; notes[#notes + 1] = 'éternel (invendable)'
            -- high stakes: Eternal is fine on a joker kept all run (x Mult, growing), a trap on a
            -- temporary additive one that will still fill a slot at ante 7 (top players)
            local kind = PL.joker_kind(def)
            local ante = (state and state.run and state.run.ante) or 1
            if PL.high_stakes(state) and ante >= 3 and kind ~= 'xmult' and kind ~= 'scaling' then
                r = r + 0.3; notes[#notes + 1] = 'éternel et temporaire : occupera une place jusqu\'à la fin'
            end
            if joker.rental then r = r + 0.4; notes[#notes + 1] = 'éternel + location : 3 $ par manche pour toujours' end
        end
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

-- rounds a rental joker is expected to be kept (two antes): its rent counts as part of its price
SH.RENT_HORIZON = 6

local function has_tag(def, tag)
    for _, t in ipairs((def and def.tags) or {}) do if t == tag then return true end end
    return false
end

local function econ_of(def, joker, state)
    -- rental sticker: $3 per round for as long as it is kept
    local rent = (joker and joker.rental) and -3 or 0
    if not def or not def.econ then return rent, (rent ~= 0) and 'location : −3 $ par manche' or nil end
    local e = def.econ
    local v = rent
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
    if v == rent and has_tag and has_tag(def, 'econ') then v = v + 1.5 end
    if rent ~= 0 and not why then why = 'location : −3 $ par manche' end
    return v, why
end

-- A stand-in for the mult the board will gain later (future context of the notes).
SH.FUTURE_BLEND = 0
-- profile carrying the player's "Mon choix" corrections, or nil (none, disabled, simulator)
function SH.player_feedback()
    local lr = BSC.learning_runtime
    return lr and lr.player_feedback and lr.player_feedback() or nil
end

-- main hand focus of the planets (1.0.10, measured on the simulator); 0 disables
SH.MAIN_FOCUS = 0
SH.PACK_PENALTY = 0
-- jokers of a Buffoon Pack valued without their shop price (the pack price is paid instead)
SH.PACK_JOKERS_FREE = false
-- high stakes: extra weight of the board's power in the notes (0 = off)
SH.HS_POWER = 0
-- growth of the jokers drawn for a Buffoon Pack or a reroll counted as in the shop
SH.SAMPLE_GROWTH = false
-- growth of the joker bought to replace another one counted (1.0.11; false = as before)
SH.REPLACE_GROWTH = false

-- Prior calibration of the shop's blind probabilities (piecewise linear, monotone), from the
-- outcomes of 965 simulated bosses (docs/TRAINING.md); false disables it.
SH.PRIOR_CALIBRATION = false
SH.PRIOR_POINTS = { { 0, 0.26 }, { 0.15, 0.45 }, { 0.3, 0.85 }, { 0.5, 0.88 }, { 0.8, 0.92 }, { 1, 0.98 } }
function SH.prior_calibration(p)
    local pts = SH.PRIOR_POINTS
    if not p then return p end
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        if p <= b[1] then return a[2] + (b[2] - a[2]) * (p - a[1]) / (b[1] - a[1]) end
    end
    return pts[#pts][2]
end
function SH.phantom_mult(m)
    return { key = 'j_joker', name = 'future', ability = { mult = m, x_mult = 1 }, rarity = 1, blueprint_compat = true,
        sell_cost = 0, uid = 'phantom_future' }
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
    -- the estimate above plays typical hands WITHOUT discards: pessimistic. Measured on 965
    -- simulated bosses (1.0.10): announced 0.30-0.90, won 80-97 % of the time; below 0.30,
    -- 25-55 %. The advice thresholds (safe, danger, critical) read the calibrated value
    -- (SH.prior_calibration) unless the player's own calibration is active.
    -- (the internal components keep comparing raw estimates with each other)
    local p_next_cal, p_boss_cal = p_next, p_boss
    if not ctx.calibrate and SH.PRIOR_CALIBRATION then
        p_next_cal, p_boss_cal = SH.prior_calibration(p_next), SH.prior_calibration(p_boss)
    end
    local danger = ST.danger(p_next, p_boss)
    ctx.base = { ps = ps0, ps_boss = ps_boss, p_next = p_next, p_boss = p_boss, p_win = outlook.p_win }
    local w = SH.weights(danger, opts.weights)
    -- reasons the player gave with their corrections move some weights a little (bounded)
    local fbp0 = SH.player_feedback()
    if fbp0 then
        local nd = FB.nudges(fbp0)
        w.synergy = w.synergy * (nd.synergy or 1)
        w.potential = w.potential * (nd.potential or 1)
        w.risk = w.risk * (nd.risk or 1)
        w.impact = w.impact * (nd.impact or 1)
    end
    -- high stakes: the blinds outgrow what the next blind shows; the power of the board (median
    -- score: the best predictor of how far simulated runs go) weighs more (SH.HS_POWER)
    if (SH.HS_POWER or 0) > 0 and PL.high_stakes(state) then w.power = w.power * (1 + SH.HS_POWER) end
    local themes = SY.themes(state, ps0)
    -- the run's plan: multipliers due at this ante, main hand, gaps (engine/plan.lua)
    local plan = PL.analyse(state, { p_next = p_next, p_boss = p_boss, p_win = outlook.p_win, median = ps0.median })
    ctx.plan = plan
    local res = {
        base = { mean = ps0.mean, median = ps0.median, q25 = ps0.q25, q75 = ps0.q75, p_next = p_next_cal, p_boss = p_boss_cal,
            p_next_raw = p_next, p_boss_raw = p_boss,
            cal = (p_next_cal ~= p_next or p_boss_cal ~= p_boss) and SH.prior_calibration or nil,
            p_next_lo = (p_next_cal ~= p_next) and SH.prior_calibration(p_next_lo) or p_next_lo,
            p_next_hi = (p_next_cal ~= p_next) and SH.prior_calibration(p_next_hi) or p_next_hi,
            p_boss_lo = (p_boss_cal ~= p_boss) and SH.prior_calibration(p_boss_lo) or p_boss_lo,
            p_boss_hi = (p_boss_cal ~= p_boss) and SH.prior_calibration(p_boss_hi) or p_boss_hi,
            p_win = outlook.p_win, expected_blinds = outlook.expected_blinds, growth = outlook.growth,
            growth_source = outlook.growth_source, endless = outlook.endless, usage = ST.usage_fractions(ps0) },
        next_blind = next_b, boss = boss_b, danger = danger, weights = w, options = {}, sells = {},
        interest = { now = E.interest(dollars, econ), next_step = E.next_step(dollars, econ) },
        coverage = ps0.coverage,
    }
    res.plan = plan
    publish(res)

    -- Future context (1.0.10): the board an ante or two later (main hand +2 levels and +10 Mult
    -- the board does not have yet). An additive joker brings less there, a x Mult just as much:
    -- the note blends the gain now and the gain then (from ante 2, fully from ante 3). Seen in
    -- simulated runs at high stakes: the last joker slot went to a +Mult joker scored 94-100 on a
    -- weak board, the x Mult offered next to it could no longer be bought, and the run hit a wall
    -- at ante 5. SH.FUTURE_BLEND 0 disables it.
    local fblend = (SH.FUTURE_BLEND or 0) * U.clamp((((state.run and state.run.ante) or 1) - 1) / 2, 0, 1)
    local fut, fut_mean
    local function future_power(ch)
        if fblend <= 0 then return nil end
        if not fut then
            fut = state
            if plan.main_hand then fut = SH.variant(fut, { level = plan.main_hand, n = 2 }) end
            fut = SH.variant(fut, { add_joker = SH.phantom_mult(10) })
            fut_mean = ST.power_samples(fut, { n = ctx.n, seed = 'shop', task = task }).mean
        end
        local ps = ST.power_samples(SH.variant(fut, ch), { n = ctx.n, seed = 'shop', task = task })
        local ratio = (fut_mean and fut_mean > 0) and (ps.mean / fut_mean) or 1
        return U.clamp(math.log(math.max(1e-6, ratio)) / math.log(2), -1, 1)
    end
    local function blend_future(comp, ch)
        local fp = future_power(ch)
        if fp then comp.power = (1 - fblend) * (comp.power or 0) + fblend * fp; comp.future = fp end
        return comp
    end

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
        -- a consumable or voucher that feeds the jokers owned (model/synergies_db.lua)
        if (opt.item_synergy or 0) ~= 0 then comp.potential = (comp.potential or 0) + opt.item_synergy end
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
        if it.set ~= 'Joker' and not it.card then
            local ib, iwhy = BD.item_bonus(it, state)
            if ib ~= 0 then
                opt.item_synergy = ib
                local into = (ib > 0) and opt.reasons or opt.risks
                into[#into + 1] = iwhy
            end
        end
        if it.set == 'Joker' and it.joker then
            local j = it.joker
            local def = DB.get(j.key, j.name)
            opt.kind = 'joker'
            opt.joker_kind = PL.joker_kind(def)
            -- rental (gold stake): $1 now, then $3 at the end of EVERY round it is kept. Priced
            -- as what it costs over the rounds it is expected to be kept, not as $1: two cheap
            -- rentals in ante 1 eat all the money of the run (seen in the simulated gold stake)
            if j.rental then
                opt.rental = true
                cc = cost_component(cost + 3 * SH.RENT_HORIZON)
            end
            opt.name = j.name or opt.name
            local need_slot = (j.edition ~= 'e_negative')
            if not need_slot or slots_free > 0 then
                local st = SH.variant(state, { add_joker = j, dollars = -cost })
                local m = measure(ctx, st)
                local pot = 0
                local gj = grown(j, 3)
                -- Madness destroys a random other joker (not Eternal) every time a Small or Big Blind
                -- is selected: measured on the boards it leaves after its first destruction
                -- (average over the jokers it can destroy), and no growth counted (it eats the board)
                local destroyed = 0
                if j.key == 'j_madness' then
                    local acc = { ratio = 0, p_next = 0, p_boss = 0, p_win = 0 }
                    for k, o in ipairs(state.jokers or {}) do
                        if not o.eternal then
                            check()
                            local mk = measure(ctx, SH.variant(state, { replace_joker = k, with = j, dollars = -cost }))
                            destroyed = destroyed + 1
                            for f in pairs(acc) do acc[f] = acc[f] + (mk[f] or 0) end
                        end
                    end
                    if destroyed > 0 then
                        for f in pairs(acc) do m[f] = acc[f] / destroyed end
                        gj = nil
                        opt.risks[#opt.risks + 1] = 'détruit un joker au hasard à chaque blinde'
                    end
                end
                if gj then
                    local st2 = SH.variant(state, { add_joker = gj, dollars = -cost })
                    local m2 = measure(ctx, st2)
                    pot = U.clamp(math.log(math.max(1e-6, m2.ratio / math.max(1e-6, m.ratio))) / math.log(2), 0, 1)
                    if pot > 0.05 then opt.reasons[#opt.reasons + 1] = 'progresse avec le temps' end
                end
                local fit, why = SY.fit(def, themes)
                for _, r in ipairs(why) do opt.reasons[#opt.reasons + 1] = r end
                local risk, rnotes = risk_of(def, j, state)
                for _, r in ipairs(rnotes) do opt.risks[#opt.risks + 1] = r end
                local ev, ewhy = econ_of(def, j, state)
                if ewhy then opt.reasons[#opt.reasons + 1] = ewhy end
                -- the rent is already in the cost (cost_component above)
                if j.rental then ev = ev + 3 end
                if not def then opt.risks[#opt.risks + 1] = 'joker non reconnu : effet non simulé'; opt.method = 'partial' end
                local pb, pwhy = PL.joker_bonus(def, plan)
                if pwhy then opt.reasons[#opt.reasons + 1] = pwhy end
                -- synergies of top players' builds with the board and the deck (engine/builds.lua)
                local sb, swhy = BD.joker_bonus(j.key, state)
                if swhy then opt.reasons[#opt.reasons + 1] = swhy end
                opt.synergy_bonus = sb
                local comp = components(m, { potential = pot + pb + sb, synergy = fit, econ = U.clamp(ev * 3 / 20, -1, 1), cost = cc, risk = risk,
                    reliability = (def and m.complete) and 1 or 0.5 })
                if j.key ~= 'j_madness' then blend_future(comp, { add_joker = gj or j }) end
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
                    local risk, rnotes = risk_of(def, j, state)
                    for _, r in ipairs(rnotes) do opt.risks[#opt.risks + 1] = r end
                    local cc2 = cost_component(math.max(0, opt.cost) + (j.rental and 3 * SH.RENT_HORIZON or 0))
                    local ev = econ_of(def, j, state)
                    if j.rental then ev = ev + 3 end
                    -- replacing a joker: the plan counts what comes in AND what goes out
                    local pb, pwhy = PL.joker_bonus(def, plan)
                    local pout = PL.joker_bonus(DB.get(best.owned.key, best.owned.name), plan)
                    if pwhy then opt.reasons[#opt.reasons + 1] = pwhy end
                    local pen, penwhy = PL.replace_penalty(DB.get(best.owned.key, best.owned.name), def, plan)
                    pout = pout + pen
                    if penwhy then opt.risks[#opt.risks + 1] = penwhy end
                    -- synergies: those of the new joker with the rest, minus those lost with the old one
                    local sb, swhy = BD.joker_bonus(j.key, state, best.owned)
                    local sout = BD.joker_bonus(best.owned.key, state, best.owned)
                    if swhy then opt.reasons[#opt.reasons + 1] = swhy end
                    opt.synergy_bonus = sb - sout
                    -- a scaling joker replaced loses what it would have become
                    local gown = grown(best.owned, 3)
                    if gown then
                        local mg = measure(ctx, SH.variant(state, { replace_joker = best.k, with = gown }))
                        sout = sout + U.clamp(math.log(math.max(1e-6, mg.ratio)) / math.log(2), 0, 1)
                    end
                    -- ... and the new one gains what IT will become, as with a free slot (before
                    -- 1.0.11 only the joker sold was counted: Madness, Lucky Cat, Hologram,
                    -- Campfire... at x1 were noted 0 to 15 as replacements in simulated runs)
                    local pin = 0
                    local gin = SH.REPLACE_GROWTH and j.key ~= 'j_madness' and grown(j, 3)
                    if gin then
                        local mi = measure(ctx, SH.variant(state, { replace_joker = best.k, with = gin, dollars = -cost + (best.owned.sell_cost or 0) }))
                        pin = U.clamp(math.log(math.max(1e-6, mi.ratio / math.max(1e-6, best.m.ratio))) / math.log(2), 0, 1)
                        if pin > 0.05 then opt.reasons[#opt.reasons + 1] = 'progresse avec le temps' end
                    end
                    local comp = components(best.m, { potential = pb - pout + sb - sout + pin, synergy = fit, econ = U.clamp(ev * 3 / 20, -1, 1), cost = cc2, risk = risk,
                        reliability = def and 1 or 0.5 })
                    blend_future(comp, { replace_joker = best.k, with = j })
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
                -- the main hand of the plan grows with every level (more so after losses for
                -- lack of levels: engine/plan.lua)
                local focus = SH.MAIN_FOCUS or 0
                local main = (plan.main_hand == hand) and (0.2 + 0.3 * focus) * (plan.levels_weight or 1) or 0
                if main > 0 then opt.reasons[#opt.reasons + 1] = 'main principale du plan' end
                -- one main hand fed with the planets (top players; simulated high-stake runs: the
                -- level of the main hand at ante 4 is the best predictor of the ante reached):
                -- once it is clear, the planets of the other hands are worth less
                if focus > 0 and plan.main_hand and plan.main_hand ~= hand and (plan.main_share or 0) >= 0.4
                    and (plan.ante or 1) >= 3 and use < 0.3 then
                    main = -0.2 * focus
                    opt.risks[#opt.risks + 1] = 'pas la main principale (' .. tostring(plan.main_hand) .. ')'
                end
                finish(opt, m, components(m, { synergy = U.clamp(use * 1.5, 0, 1), potential = main, cost = cc,
                    reliability = m.complete and 1 or 0.5 }))
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
                -- cards that destroy jokers or shrink the hand: measured on the boards they leave
                if info.destroys or info.hand_size then
                    local dv = SH.destructive_value(state, ctx, it.key, info)
                    if dv then
                        v = dv.value
                        if dv.why then opt.reasons[#opt.reasons + 1] = dv.why end
                        if dv.risk then opt.risks[#opt.risks + 1] = dv.risk end
                    end
                end
                if info.money_to_zero then
                    -- Wraith: all the money is lost (and the interest it would bring)
                    v = v - math.min(dollars, 25) / 2.5
                    opt.risks[#opt.risks + 1] = 'met votre argent à 0'
                end
                if info.desc then opt.reasons[#opt.reasons + 1] = info.desc end
                if info.joker and slots_free <= 0 then
                    -- creates a joker but every slot is taken: only worth it if a random new
                    -- joker beats the weakest joker that can be sold
                    local sw = SH.slot_swap(state, ctx, res, w, task, info.joker)
                    if sw and sw.worth then
                        opt.reasons[#opt.reasons + 1] = string.format('jokers pleins : vendre %s pour l\'utiliser (%s de chances d\'avoir mieux)',
                            sw.sell.name or '?', I.pct(sw.p_better))
                        opt.swap = sw
                    else
                        v = math.min(v, 0)
                        opt.risks[#opt.risks + 1] = 'jokers pleins : aucun joker à sacrifier pour lui'
                    end
                end
                finish(opt, nil, { econ = U.clamp((v - cost) / 10, -1, 1), cost = cc * 0.5, reliability = 0.6 })
            end
        elseif it.set == 'Voucher' then
            opt.kind = 'voucher'
            local info = IT.VOUCHERS[it.key] or {}
            local sim = info.sim
            -- antes left in the run (a voucher is permanent)
            local run = state.run or {}
            local antes_left = math.max(1, (run.win_ante or 8) - (run.ante or 1) + 1)
            -- vouchers that add score now (hands, discards, hand size, joker slot, smaller blinds)
            opt.power_voucher = sim and ((sim.hands or 0) > 0 or (sim.discards or 0) > 0 or sim.hand_size or sim.slot or sim.ante) and true or nil
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
                -- Seed Money / Money Tree: only worth it with money to keep above the cap ($40+)
                if sim.interest_cap and econ.no_interest then
                    -- Green Deck: no interest at all, a higher cap is worth nothing
                    extra.econ = -0.5; opt.risks[#opt.risks + 1] = 'aucun intérêt avec ce deck'
                elseif sim.interest_cap then extra.econ = U.clamp((dollars >= 40) and 0.5 or ((dollars >= 25) and 0.2 or 0), 0, 1); opt.reasons[#opt.reasons + 1] = 'plafond d\'intérêts relevé' end
                if sim.hands and sim.hands > 0 then opt.reasons[#opt.reasons + 1] = '+1 main par manche' end
                if sim.discards and sim.discards > 0 then opt.reasons[#opt.reasons + 1] = '+1 défausse par manche' end
                if sim.hand_size then opt.reasons[#opt.reasons + 1] = '+1 taille de main' end
                -- a permanent hand, discard or card in hand helps every blind left, not only the
                -- next ones measured here
                if (sim.hands or 0) > 0 or (sim.discards or 0) > 0 or sim.hand_size then
                    extra.potential = (extra.potential or 0) + 0.3 * math.min(1, antes_left / 4)
                end
                extra.cost = cc
                extra.reliability = 0.9
                opt.method = 'simulation'
                finish(opt, m, components(m, extra))
            else
                opt.method = 'heuristic'
                local v = info.v or 4
                if info.per_ante then
                    v = info.per_ante * antes_left
                    -- Telescope feeds the main hand (taken "almost every time" by top players)
                    if it.key == 'v_telescope' then v = v * (1 + 0.6 * (SH.MAIN_FOCUS or 0)) end
                    opt.reasons[#opt.reasons + 1] = string.format('permanent : ~%d $ sur les %d antes restantes (estimation)', math.floor(v + 0.5), antes_left)
                end
                finish(opt, nil, { econ = U.clamp((v - cost) / 12, -1, 1), potential = 0.2, cost = cc * 0.6, reliability = 0.6 })
            end
        elseif it.set == 'Booster' then
            opt.kind = 'booster'
            opt.pack_kind = it.kind
            local value, method, why = SH.booster_value(state, it, ctx, res, w, task)
            finish(opt, nil, { reliability = 1 })
            local rel = (method == 'simulation') and 0.9 or 0.7
            opt.note = math.floor(U.clamp(50 + (value - 10 * cc - 50) * rel, 0, 100) + 0.5)
            -- (measured on the simulator: SH.PACK_PENALTY points off Arcana / Standard / Spectral packs)
            if (SH.PACK_PENALTY or 0) ~= 0 and (it.kind == 'Arcana' or it.kind == 'Standard' or it.kind == 'Spectral') then
                opt.note = math.max(0, opt.note - SH.PACK_PENALTY)
            end
            -- the pack feeds the jokers owned (Celestial with Constellation, Standard with Hologram...)
            if (opt.item_synergy or 0) ~= 0 then
                opt.note = math.floor(U.clamp(opt.note + 45 * w.potential * opt.item_synergy, 0, 100) + 0.5)
            end
            opt.method = method
            opt.reasons[#opt.reasons + 1] = why
            if IT.BOOSTERS[it.kind or ''] and IT.BOOSTERS[it.kind].jokers and slots_free <= 0 then
                opt.risks[#opt.risks + 1] = 'aucun emplacement de joker libre'
            end
        elseif it.card then
            -- playing card (shop or Standard pack): worth what its enhancement, edition and seal
            -- bring (model/effects_db.lua); a plain card only dilutes the deck
            opt.kind = 'card'
            opt.method = 'heuristic'
            local c = it.card
            local extra = EF.card_value(c) - (c.nominal or 0) - (c.debuff and -50 or 0)
            local desc = I.T('mod_desc')
            for _, k in ipairs(EF.modifiers(c)) do
                opt.reasons[#opt.reasons + 1] = (type(desc) == 'table' and desc[k]) or k
            end
            local money = ((c.h_dollars or 0) > 0 or c.seal == 'Gold') and 0.2 or 0
            finish(opt, nil, { power = U.clamp((extra - 6) / 60, -0.2, 1), econ = money, cost = cc, reliability = 0.6 })
        end
    end
    -- a joker-creating card already held while every slot is taken (Judgement, Wraith, The Soul)
    if slots_free <= 0 and not opts.pack_items then
        for _, c in ipairs(state.consumables or {}) do
            local info = IT.consumable(c.key)
            if info and info.joker then SH.slot_swap(state, ctx, res, w, task, info.joker) end
        end
    end
    -- the player's corrections ("Mon choix", learning/feedback.lua): an item they chose instead of
    -- the advice is noted higher, the one advised instead lower (bounded, shown in the reasons)
    local fbp = SH.player_feedback()
    if fbp then
        for _, o in ipairs(res.options) do
            local dv, fwhy = FB.item_adjust(fbp, o)
            if dv ~= 0 and o.note then
                o.note = math.floor(U.clamp(o.note + dv, 0, 100) + 0.5)
                o.player_adjust = dv
                o.reasons = o.reasons or {}
                o.reasons[#o.reasons + 1] = fwhy
            end
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
            -- a piece of a build keeps what it will bring with the others (engine/builds.lua)
            local sout = BD.joker_bonus(j.key, state, j)
            -- a scaling joker is bought for what it becomes: its sale counts that too (before
            -- 1.0.9 Runner, Hologram, Glass Joker... were bought "for their growth", then sold
            -- in the same shop as "bringing 0 %")
            local contribution, pot = 1 - m.ratio, 0
            local gj = grown(j, 3)
            if gj then
                local mg = measure(ctx, SH.variant(state, { replace_joker = k, with = gj }))
                if mg.ratio > 0 then
                    contribution = math.max(contribution, 1 - m.ratio / mg.ratio)
                    pot = U.clamp(math.log(math.max(1e-6, mg.ratio)) / math.log(2), 0, 1)
                end
            end
            local comp = components(m, { econ = U.clamp(((j.sell_cost or 0) - ev * 2) / 15, -1, 1), potential = -sout - pot,
                reliability = def and 1 or 0.5 })
            local note = SH.note(comp, w)
            res.sells[#res.sells + 1] = { index = k, name = j.name, uid = j.uid, sell = j.sell_cost or 0, note = note, ratio = m.ratio,
                synergy = sout, growth = (pot > 0) and pot or nil,
                d_next = (m.p_next and p_next) and (m.p_next - p_next) or nil, d_boss = (m.p_boss and p_boss) and (m.p_boss - p_boss) or nil,
                contribution = contribution }
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

-- Hex (Polychrome on one random joker without edition, the others destroyed), Ankh (copy of
-- one random joker, the others destroyed; needs a free slot), Ectoplasm (Negative on a random
-- joker, -1 hand size), Ouija (-1 hand size): what the board is worth afterwards, averaged over
-- the random outcomes, in "dollars" for the note (positive only when the board improves).
-- Eternal jokers are never destroyed.
function SH.destructive_value(state, ctx, key, info)
    local jokers = state.jokers or {}
    local function measure_list(list, extra)
        local st = SH.variant(state, { jokers = list })
        if extra and extra.hand_size then st = SH.variant(st, { hand_size = extra.hand_size }) end
        return measure(ctx, st).ratio
    end
    local outcomes = {}
    if key == 'c_hex' or key == 'c_ankh' then
        if key == 'c_ankh' and #jokers >= (state.joker_slots or 5) then
            return { value = -10, risk = 'emplacements pleins : Ankh ne peut pas être utilisé' }
        end
        for k, j in ipairs(jokers) do
            if key == 'c_ankh' or not j.edition then
                local list = {}
                for i, o in ipairs(jokers) do
                    if i == k then
                        local kept = {}
                        for f, v in pairs(o) do kept[f] = v end
                        if key == 'c_hex' then kept.edition = 'e_polychrome' end
                        list[#list + 1] = kept
                        if key == 'c_ankh' then
                            local dup = {}
                            for f, v in pairs(o) do dup[f] = v end
                            if dup.edition == 'e_negative' then dup.edition = nil end
                            list[#list + 1] = dup
                        end
                    elseif o.eternal then
                        list[#list + 1] = o
                    end
                end
                outcomes[#outcomes + 1] = measure_list(list)
            end
        end
        if #outcomes == 0 then return { value = 0, risk = 'aucun joker éligible' } end
    elseif key == 'c_ectoplasm' or key == 'c_ouija' then
        outcomes[1] = measure_list(jokers, { hand_size = -1 })
    else
        return nil
    end
    local sum = 0
    for _, r in ipairs(outcomes) do sum = sum + r end
    local ratio = sum / #outcomes
    -- dollars-equivalent: +/- 10 $ per 10 % of power, plus the slot of Ectoplasm
    local value = 100 * (ratio - 1) + ((key == 'c_ectoplasm') and 4 or 0)
    local out = { value = value, ratio = ratio }
    if ratio < 0.95 then
        out.risk = string.format('détruit ou affaiblit le jeu : puissance ×%.2f en moyenne', ratio)
    else
        out.why = string.format('puissance ×%.2f en moyenne après effet', ratio)
    end
    return out
end

-- The sellable joker whose removal costs the least power (cached per analysis).
function SH.weakest_joker(state, ctx, task)
    if ctx.weakest ~= nil then return ctx.weakest or nil end
    local check = (task and task.check) or noop
    local weakest
    for k, j in ipairs(state.jokers or {}) do
        check()
        if EF.can_sell(j) then
            local m = measure(ctx, SH.variant(state, { remove_joker = k, dollars = j.sell_cost or 0 }))
            if not weakest or m.ratio > weakest.ratio then weakest = { k = k, j = j, ratio = m.ratio } end
        end
    end
    ctx.weakest = weakest or false
    return weakest
end

-- Full joker slots and a card that creates a joker (Judgement: shop rarities, Wraith: rare,
-- The Soul: legendary): is a random new joker worth more than the weakest joker that can be
-- sold? Measured like a replacement (sell the weakest, add each sampled joker), cached per
-- rarity. Returns { sell = joker, k, ratio, p_better, worth } or nil (nothing can be sold).
function SH.slot_swap(state, ctx, res, w, task, rarity)
    ctx.slot_swap = ctx.slot_swap or {}
    if ctx.slot_swap[rarity] ~= nil then return ctx.slot_swap[rarity] or nil end
    local check = (task and task.check) or noop
    local weakest = SH.weakest_joker(state, ctx, task)
    if not weakest then ctx.slot_swap[rarity] = false; return nil end
    local keys = {}
    if rarity == 'legendary' then
        for _, k in ipairs(DB.all_keys()) do if DB.get(k).rarity == 4 then keys[#keys + 1] = k end end
    else
        local pool = SH.joker_pool(state)
        local rng = R.new('swap:' .. tostring(rarity))
        for _ = 1, 8 do
            local r = (rarity == 'rare') and 3 or rng:weighted(SH.RARITY_WEIGHTS)
            local list = (#pool[r] > 0) and pool[r] or pool[1]
            if #list > 0 then keys[#keys + 1] = list[rng:int(1, #list)] end
        end
    end
    local sum, better, n = 0, 0, 0
    for _, key in ipairs(keys) do
        check()
        if DB.get(key) then
            local st = SH.variant(state, { replace_joker = weakest.k, with = joker_entry_from_def(key), dollars = weakest.j.sell_cost or 0 })
            local m = measure(ctx, st)
            sum = sum + m.ratio; n = n + 1
            if m.ratio > 1.02 then better = better + 1 end
        end
    end
    if n == 0 then ctx.slot_swap[rarity] = false; return nil end
    local out = { sell = weakest.j, k = weakest.k, ratio = sum / n, p_better = better / n }
    out.worth = out.ratio > 1.05 and out.p_better >= 0.5
    ctx.slot_swap[rarity] = out
    res.slot_swaps = res.slot_swaps or {}
    res.slot_swaps[rarity] = out
    return out
end

-- Jokers that never get a sticker (game data, eternal_compat / perishable_compat; lists of the
-- Balatro Wiki, pages Eternal and Perishable): growing jokers are never Perishable, jokers that
-- destroy or sell themselves never Eternal.
SH.NEVER_ETERNAL = { j_gros_michel = true, j_ice_cream = true, j_cavendish = true, j_luchador = true, j_turtle_bean = true,
    j_diet_cola = true, j_popcorn = true, j_ramen = true, j_selzer = true, j_mr_bones = true, j_invisible = true }
SH.NEVER_PERISHABLE = { j_ceremonial = true, j_ride_the_bus = true, j_runner = true, j_constellation = true, j_green_joker = true,
    j_red_card = true, j_madness = true, j_square = true, j_vampire = true, j_hologram = true, j_rocket = true, j_obelisk = true,
    j_lucky_cat = true, j_flash = true, j_trousers = true, j_castle = true, j_glass = true, j_wee = true }
function SH.sticker_compat(key)
    return not SH.NEVER_ETERNAL[key], not SH.NEVER_PERISHABLE[key]
end

-- Notes of jokers drawn from the real pool (rarity 70/25/5 %), measured by simulation; shared
-- by the reroll value and Buffoon packs (computed once per analysis).
function SH.joker_samples(state, ctx, res, w, task)
    if ctx.joker_samples then return ctx.joker_samples end
    local check = (task and task.check) or noop
    local econ = state.econ or {}
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
            local note, note_free
            local weakest = (slots_free <= 0) and SH.weakest_joker(state, ctx, task) or nil
            -- stickers of the higher stakes, as the game rolls them for shop and pack jokers:
            -- Eternal 30 % (Black Stake), else Perishable 30 % (Orange), and Rental 30 % (Gold).
            -- Before 1.0.9 a Buffoon Pack was bought at gold stake for an expected 97/100, then
            -- every joker in it was a rental or weak and the pack was skipped.
            local stake = (state.run and state.run.stake) or 1
            local r1, r2 = 0, 0
            if stake >= 4 then r1, r2 = rng:float(), rng:float() end
            local eternal_ok, perishable_ok = SH.sticker_compat(key)
            local eternal = stake >= 4 and r1 > 0.7 and eternal_ok
            local perishable = not eternal and stake >= 7 and r1 > 0.4 and r1 <= 0.7 and perishable_ok
            local rental = stake >= 8 and r2 > 0.7
            if rental then j.cost = 1; j.rental = true end
            if slots_free > 0 or weakest then
                -- full slots: the new joker would replace the weakest sellable one
                local st = weakest and SH.variant(state, { replace_joker = weakest.k, with = j, dollars = -(j.cost or 5) + (weakest.j.sell_cost or 0) })
                    or SH.variant(state, { add_joker = j, dollars = -(j.cost or 5) })
                local m = measure({ n = math.max(24, math.floor(ctx.n / 2)), base = ctx.base, X_next = ctx.X_next, X_boss = ctx.X_boss,
                    profile = ctx.profile, calibrate = ctx.calibrate, task = task }, st)
                local fit = SY.fit(DB.get(key), SY.themes(state, ctx.base.ps))
                -- a growing joker is worth what it will become, as in the shop (SH.SAMPLE_GROWTH)
                local pot = 0
                local gj = SH.SAMPLE_GROWTH and grown(j, 3)
                if gj then
                    local st2 = weakest and SH.variant(state, { replace_joker = weakest.k, with = gj, dollars = -(j.cost or 5) + (weakest.j.sell_cost or 0) })
                        or SH.variant(state, { add_joker = gj, dollars = -(j.cost or 5) })
                    local m2 = measure({ n = math.max(24, math.floor(ctx.n / 2)), base = ctx.base, X_next = ctx.X_next, X_boss = ctx.X_boss,
                        profile = ctx.profile, calibrate = ctx.calibrate, task = task }, st2)
                    pot = U.clamp(math.log(math.max(1e-6, m2.ratio / math.max(1e-6, m.ratio))) / math.log(2), 0, 1)
                end
                local bn, bb = res.base.p_next_raw or res.base.p_next, res.base.p_boss_raw or res.base.p_boss
                local dn = (m.p_next and bn) and (m.p_next - bn) or 0
                local db = (m.p_boss and bb) and (m.p_boss - bb) or 0
                local comp = { impact = U.clamp((0.5 * dn + 0.5 * db) * 5, -1.5, 1.5),
                    power = U.clamp(math.log(math.max(1e-6, m.ratio)) / math.log(2), -1, 1), synergy = fit,
                    potential = pot + (PL.joker_bonus(DB.get(key), ctx.plan)) + (BD.joker_bonus(key, state, weakest and weakest.j)),
                    cost = U.clamp(((j.cost or 5) + (rental and 3 * SH.RENT_HORIZON or 0)) / math.max(10, (econ.dollars or 0) + 10), 0, 1.5),
                    risk = (perishable and 0.3 or 0) + (eternal and 0.1 or 0), reliability = 1 }
                note = SH.note(comp, w)
                -- the same joker drawn from a Buffoon Pack is free (the pack price is counted
                -- once, by the pack note): only the rent remains
                comp.cost = U.clamp((rental and 3 * SH.RENT_HORIZON or 0) / math.max(10, (econ.dollars or 0) + 10), 0, 1.5)
                note_free = SH.note(comp, w)
            else
                note = 40
            end
            values[#values + 1] = { key = key, name = DB.get(key).name, note = note, note_free = note_free or note }
        end
    end
    ctx.joker_samples = values
    return values
end

-- Expected best (and second best) of k draws without replacement among notes (bootstrap).
function SH.expected_best(notes, k, seed)
    if #notes == 0 then return 50, 50 end
    k = math.max(1, math.min(k or 1, #notes))
    local rng = R.new(seed or 'best')
    local B = 400
    local s1, s2 = 0, 0
    for _ = 1, B do
        local idx = {}
        for i = 1, #notes do idx[i] = i end
        local best, second = -1, -1
        for d = 1, k do
            local j = rng:int(d, #idx)
            idx[d], idx[j] = idx[j], idx[d]
            local v = notes[idx[d]]
            if v > best then second = best; best = v elseif v > second then second = v end
        end
        s1 = s1 + best
        s2 = s2 + math.max(second, 0)
    end
    return s1 / B, s2 / B
end

-- Booster packs valued by their CONTENT (top players buy them very often): expected best card
-- among the cards shown, minus the cost (interest included). Buffoon: jokers measured by
-- simulation; Celestial: planets of the hands you actually play; Arcana / Spectral / Standard:
-- documented heuristic values.
SH.BASE_HANDS = { 'High Card', 'Pair', 'Two Pair', 'Three of a Kind', 'Straight', 'Flush', 'Full House',
    'Four of a Kind', 'Straight Flush' }
function SH.booster_value(state, it, ctx, res, w, task)
    local kind = it.kind or ''
    local k = it.pack_size or ((kind == 'Buffoon') and 2 or 3)
    local choose = it.choose or 1
    local notes, method, why = {}, 'heuristic', nil
    if kind == 'Buffoon' then
        for _, v in ipairs(SH.joker_samples(state, ctx, res, w, task)) do
            notes[#notes + 1] = SH.PACK_JOKERS_FREE and v.note_free or v.note
        end
        method = 'simulation'
    elseif kind == 'Celestial' then
        local usage = res.base.usage or {}
        local telescope = state.vouchers and state.vouchers.v_telescope
        local top, top_u = nil, -1
        local focus = SH.MAIN_FOCUS or 0
        local main = ctx.plan and ctx.plan.main_hand
        for _, h in ipairs(SH.BASE_HANDS) do
            local u = usage[h] or 0
            local n = 50 + 30 * math.min(1, 1.5 * u)
            -- the planet of the main hand: worth more (main hand focus)
            if focus > 0 and h == main then n = math.min(100, 50 + 30 * math.min(1, 1.5 * math.max(u, 0.4)) + 12 * focus) end
            notes[#notes + 1] = n
            if u > top_u then top, top_u = h, u end
        end
        if telescope and top then
            -- Telescope: the most played hand's planet is always in the pack
            local t = (focus > 0 and main) or top
            local u = usage[t] or 0
            notes = { math.min(100, 50 + 30 * math.min(1, 1.5 * math.max(u, (focus > 0 and t == main) and 0.4 or 0)) + ((focus > 0 and t == main) and 12 * focus or 0)) }
            k = 1
        end
    elseif kind == 'Arcana' or kind == 'Spectral' then
        -- each card scored like the same card in the shop (heuristic econ value), but free:
        -- the pack price is subtracted once, by the caller
        local dollars = (state.econ and state.econ.dollars) or 0
        local sell_values = 0
        for _, j in ipairs(state.jokers or {}) do sell_values = sell_values + (j.sell_cost or 0) end
        local list = (kind == 'Arcana') and IT.TAROTS or IT.SPECTRALS
        for key, info in pairs(list) do
            -- The Soul and Black Hole are too rare in packs to weigh like the others
            if key ~= 'c_soul' and key ~= 'c_black_hole' then
                local v = info.v or 3
                if info.money == 'double' then v = math.min(dollars, 20) end
                if info.money == 'sell_values' then v = math.min(sell_values, 50) end
                if info.target or info.sim then v = v + 1 end
                notes[#notes + 1] = SH.note({ econ = U.clamp(v / 10, -1, 1), reliability = 0.6 }, w)
            end
        end
        table.sort(notes)
    else
        notes = { 46 }
    end
    local best, second = SH.expected_best(notes, k, 'booster:' .. kind)
    local value = best
    if choose >= 2 then value = math.min(100, value + 0.5 * math.max(0, second - 50)) end
    why = string.format('meilleure carte attendue ~%d/100 (%d au choix)', math.floor(value + 0.5), k)
    return value, method, why
end

function SH.reroll_value(state, ctx, res, w, task)
    local econ = state.econ or {}
    local rates = econ.rates or { joker = 20, tarot = 4, planet = 4, spectral = 0 }
    local total_rate = (rates.joker or 0) + (rates.tarot or 0) + (rates.planet or 0) + (rates.spectral or 0) + (rates.playing_card or 0)
    local p_joker = total_rate > 0 and (rates.joker or 0) / total_rate or 0
    local values = SH.joker_samples(state, ctx, res, w, task)
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
