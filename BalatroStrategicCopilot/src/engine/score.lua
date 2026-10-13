-- Balatro Strategic Copilot - engine/score.lua  (ScoreEvaluator)
-- Pure re-implementation of the Steamodded scoring pipeline for vanilla content
-- (see docs/AUDIT.md §4-5 for the verified order):
--   boss debuff_hand / The Arm / The Ox / The Tooth / The Hook
--   -> context.before (jokers, left to right)        [may level up / mutate]
--   -> base chips & mult of the (possibly re-levelled) hand, The Flint
--   -> played cards in play order: card (chips, mult, x_mult, $), edition, jokers 'individual',
--      then retriggers (red seal, Hack, Sock and Buskin, Hanging Chad, Dusk, Seltzer, copies)
--   -> held cards: card (h_mult, Steel x_mult), jokers (Baron, Shoot the Moon, Raised Fist),
--      retriggers (red seal, Mime) only if the card did something
--   -> jokers: edition (foil/holo), joker_main, other_joker (Baseball), polychrome;
--      then consumables (Observatory planets)
--   -> deck final step (Plasma balance) -> floor(chips * mult)
-- Random events are choice points: enumerated exactly up to a branch budget, otherwise
-- sampled by Monte-Carlo (reproducible). Nothing here touches the game.

local BSC = BSCopilot
local U = BSC.require('core/util')
local R = BSC.require('core/rng')
local C = BSC.require('model/cards')
local H = BSC.require('model/hands')
local DB = BSC.require('model/jokers_db')
local PE = BSC.require('engine/poker_eval')

local Score = {}

local floor = math.floor

-- Choosers ----------------------------------------------------------------------------------

-- Enumeration chooser: replays a prefix of choices; at each new choice point it takes the
-- first option and records the alternatives to explore later.
local function new_enum_chooser(prefix, pending)
    local ch = { prefix = prefix, pos = 0, prob = 1, path = {}, points = 0 }
    local function choose(probs)
        ch.pos = ch.pos + 1
        ch.points = ch.points + 1
        local k = ch.prefix[ch.pos]
        if k == nil then
            local first
            for i = 1, #probs do
                if probs[i] > 0 then
                    if not first then first = i
                    else
                        local np = {}
                        for t = 1, ch.pos - 1 do np[t] = ch.path[t] end
                        np[ch.pos] = i
                        pending[#pending + 1] = np
                    end
                end
            end
            k = first or 1
        end
        ch.path[ch.pos] = k
        ch.prob = ch.prob * (probs[k] or 0)
        return k
    end
    function ch:chance(p)
        if p >= 1 then return true end
        if p <= 0 then return false end
        return choose({ p, 1 - p }) == 1
    end
    function ch:int(a, b)
        if b <= a then return a end
        local n = b - a + 1
        local probs = {}
        for i = 1, n do probs[i] = 1 / n end
        return a + choose(probs) - 1
    end
    function ch:pick(n)
        if n <= 1 then return 1 end
        local probs = {}
        for i = 1, n do probs[i] = 1 / n end
        return choose(probs)
    end
    return ch
end

local function new_sample_chooser(rng)
    local ch = { prob = 1, points = 0 }
    function ch:chance(p)
        if p >= 1 then return true end
        if p <= 0 then return false end
        ch.points = ch.points + 1
        return rng:float() < p
    end
    function ch:int(a, b)
        if b <= a then return a end
        ch.points = ch.points + 1
        return rng:int(a, b)
    end
    function ch:pick(n)
        if n <= 1 then return 1 end
        ch.points = ch.points + 1
        return rng:int(1, n)
    end
    return ch
end

-- Preparation (once per game state) ----------------------------------------------------------

local function joker_enabled(j) return not j.debuff end

-- Build the static evaluation context from a snapshot.
function Score.prepare(state, opts)
    opts = opts or {}
    local P = { state = state, opts = opts }
    P.hands = state.hands or H.default_table()
    P.prob_normal = state.probabilities_normal or 1
    P.dollars = (state.econ and state.econ.dollars) or 0
    P.round = state.round or {}
    P.blind = state.blind or {}
    P.targets = state.targets or {}
    P.deck_stats = state.full_deck_stats or {}
    P.deck_count = state.deck_count or (state.deck and #state.deck) or 0
    P.joker_slots = state.joker_slots or 5
    P.plasma = state.flags and state.flags.plasma
    P.observatory = state.vouchers and state.vouchers.v_observatory
    P.observatory_x = (state.flags and state.flags.observatory_x) or 1.5
    P.hands_played_total = (state.run and state.run.hands_played) or 0
    P.skips = (state.run and state.run.skips) or 0
    P.tarots_used = (state.run and state.run.tarots_used) or 0

    local coverage = { unsupported = {}, notes = {}, hidden = false }
    local rules = {}
    P.jokers = {}
    for i, j in ipairs(state.jokers or {}) do
        local def = DB.get(j.key, j.name)
        local entry = {
            key = j.key, name = j.name, def = def, ability = j.ability or {},
            debuff = j.debuff, edition = j.edition, rarity = j.rarity or (def and def.rarity),
            bp = (j.blueprint_compat ~= nil) and j.blueprint_compat or (def and def.bp),
            sell_cost = j.sell_cost or 0, face_down = j.face_down, idx = i,
        }
        P.jokers[i] = entry
        if not def then
            if not j.debuff then
                coverage.unsupported[#coverage.unsupported + 1] = j.name or j.key or '?'
                local lm = state.learned_multipliers and j.key and state.learned_multipliers[j.key]
                if lm then
                    P.learned_mult = (P.learned_mult or 1) * lm
                    coverage.learned = coverage.learned or {}
                    coverage.learned[#coverage.learned + 1] = j.name or j.key
                end
            end
        elseif def.rule and not j.debuff then
            rules[def.rule] = true
        end
        if j.edition and not C.EDITIONS[j.edition] then
            coverage.unsupported[#coverage.unsupported + 1] = 'edition:' .. tostring(j.edition)
        end
        if j.face_down then coverage.hidden = true end
    end
    P.consumables = state.consumables or {}
    P.rules = rules
    P.coverage = coverage
    -- boss effects that matter during scoring (ignored when the blind is disabled)
    P.boss = (P.blind.boss and not P.blind.disabled) and P.blind.key or nil
    return P
end

-- Card value getters (vanilla/SMODS semantics) ----------------------------------------------

local function ms(base, perma)
    base = (base ~= 0 and base) or 1
    local ret = base * ((perma or 0) + 1)
    if ret == 1 then return 0 end
    if ret > 0 then return ret end
    return 0
end

local function chip_bonus(c)
    if c.no_rank and c.enh == 'm_stone' then return (c.bonus or 0) + (c.perma_bonus or 0) end
    return (c.nominal or 0) + (c.bonus or 0) + (c.perma_bonus or 0)
end

-- One deterministic pass of the pipeline, random events drawn from chooser `ch`.
local function run_once(P, played_src, held_src, ch, trace)
    local played, held = {}, {}
    for i, c in ipairs(played_src) do played[i] = C.copy(c) end
    for i, c in ipairs(held_src) do held[i] = C.copy(c) end
    local jokers = {}
    for i, j in ipairs(P.jokers) do
        jokers[i] = {
            key = j.key, name = j.name, def = j.def, ability = U.deepcopy(j.ability, 6) or {},
            debuff = j.debuff, edition = j.edition, rarity = j.rarity, bp = j.bp, sell_cost = j.sell_cost, idx = i,
        }
    end

    local chips, mult = 0, 0
    local earned = 0
    local dollars_base = P.dollars
    local log = trace and {} or nil
    local function note(fmt, ...)
        if log then log[#log + 1] = string.format(fmt, ...) end
    end

    local ev = PE.evaluate(played, P.rules)
    local hand = ev.name
    local res = { hand = hand, scoring_uids = {}, chips = 0, mult = 0, score = 0, dollars = 0 }
    if not hand then return res end
    for _, c in ipairs(ev.scoring) do res.scoring_uids[#res.scoring_uids + 1] = c.uid end

    -- local copy of the levels of this hand (Space Joker / The Arm may change it)
    local hp = P.hands[hand] or {}
    local level = hp.level or 1
    local base_chips, base_mult = hp.chips, hp.mult
    if base_chips == nil then base_chips, base_mult = H.values_at(hand, level) end
    local function level_up(n)
        level = math.max(0, level + n)
        local b = { chips = hp.chips, mult = hp.mult, l_chips = hp.l_chips or (H.BASE[hand] and H.BASE[hand].l_chips) or 0,
            l_mult = hp.l_mult or (H.BASE[hand] and H.BASE[hand].l_mult) or 0,
            s_chips = hp.s_chips or (H.BASE[hand] and H.BASE[hand].chips) or hp.chips,
            s_mult = hp.s_mult or (H.BASE[hand] and H.BASE[hand].mult) or hp.mult }
        base_chips, base_mult = H.values_at(hand, level, b)
        note('niveau de main -> %d', level)
    end

    -- context object handed to joker functions
    local x = {
        rules = P.rules, hand = hand, contains = ev.contains, scoring = ev.scoring, full = played,
        held = held, rand = ch, prob_normal = P.prob_normal, targets = P.targets, hands_table = P.hands,
        hands_left_eval = math.max(0, (P.round.hands_left or 1) - 1),
        discards_left = P.round.discards_left or 0, deck_count = P.deck_count,
        hands_played = P.hands_played_total, copying = false,
    }
    function x.is_face(c) return C.is_face(c, P.rules) end
    function x.is_suit(c, suit, bypass) return C.is_suit(c, suit, P.rules, bypass, false) end
    function x.is_suit_flush(c, suit) return C.is_suit(c, suit, P.rules, nil, true) end
    function x.level_up(n) level_up(n) end
    function x.earn(d) earned = earned + d end
    function x.dollars() return dollars_base + earned end
    function x.deck_stat(k)
        local v = P.deck_stats[k]
        if v == nil and k == 'size' then v = P.deck_stats.size end
        return v or 0
    end
    function x.joker_count() return #jokers end
    function x.hand_played_count() return (hp.played or 0) + 1 end
    function x.hand_played_this_round() return (hp.played_this_round or 0) + 1 end
    function x.tarots_used() return P.tarots_used end
    function x.skips() return P.skips end
    function x.stencil_xmult()
        local xm = P.joker_slots - #jokers
        for _, j in ipairs(jokers) do if j.key == 'j_stencil' then xm = xm + 1 end end
        return xm
    end
    function x.other_jokers_sell_value(self_j)
        local s = 0
        for _, j in ipairs(jokers) do
            if j.idx ~= self_j.idx then s = s + (j.sell_cost or 0) end
        end
        return s
    end

    -- copy resolution (Blueprint: right neighbour, Brainstorm: leftmost)
    local function resolve(i, depth)
        local j = jokers[i]
        if not j or j.debuff then return nil end
        local d = j.def
        if not d then return nil end
        if not d.copy then return j end
        if depth > #jokers + 1 then return nil end
        local ti = (d.copy == 'right') and (i + 1) or 1
        if ti == i then return nil end
        local t = jokers[ti]
        if not t or t.debuff or not t.bp then return nil end
        return resolve(ti, depth + 1)
    end

    local function call(phase, i, a, b)
        local j = jokers[i]
        if j.debuff or not j.def then return nil end
        local target, copying = j, false
        if j.def.copy then
            target = resolve(i, 0)
            if not target or target == j then return nil end
            copying = true
        end
        local f = target.def[phase]
        if not f then return nil end
        x.copying = copying
        local r = f(x, target, a, b)
        x.copying = false
        return r
    end

    local function apply(eff, who)
        if not eff then return false end
        local did = false
        if eff.chips and eff.chips ~= 0 then chips = chips + eff.chips; did = true end
        if eff.mult and eff.mult ~= 0 then mult = mult + eff.mult; did = true end
        if eff.x_chips and eff.x_chips ~= 1 and eff.x_chips > 0 then chips = chips * eff.x_chips; did = true end
        if eff.x_mult and eff.x_mult ~= 1 and eff.x_mult > 0 then mult = mult * eff.x_mult; did = true end
        if eff.dollars and eff.dollars ~= 0 then earned = earned + eff.dollars; did = true end
        if did and log then
            note('%s: +%s jetons +%s mult x%s -> %s x %s', who or '?', tostring(eff.chips or 0), tostring(eff.mult or 0),
                tostring(eff.x_mult or 1), U.round(chips, 2), U.round(mult, 2))
        end
        return did
    end

    -- boss effects before scoring ------------------------------------------------------------
    local boss = P.boss
    if boss == 'bl_psychic' and #played < 5 then res.debuffed_hand = true end
    if boss == 'bl_eye' and P.blind.hands_used and P.blind.hands_used[hand] then res.debuffed_hand = true end
    if boss == 'bl_mouth' and P.blind.only_hand and P.blind.only_hand ~= hand then res.debuffed_hand = true end
    if res.debuffed_hand then
        note('main annulée par la blinde %s', boss)
        res.trace = log
        return res
    end
    if boss == 'bl_arm' and level > 1 then level_up(-1) end
    if boss == 'bl_ox' and P.targets.most_played_hand == hand then dollars_base = 0 end
    if boss == 'bl_tooth' then dollars_base = dollars_base - #played end
    if boss == 'bl_hook' and #held > 0 then
        for _ = 1, math.min(2, #held) do
            local k = ch:pick(#held)
            table.remove(held, k)
        end
    end

    -- context.before -------------------------------------------------------------------------
    for i = 1, #jokers do call('before', i) end

    chips, mult = base_chips or 0, base_mult or 1
    note('%s niv.%d : %s x %s', hand, level, chips, mult)
    if boss == 'bl_flint' then
        mult = math.max(floor(mult * 0.5 + 0.5), 1)
        chips = math.max(floor(chips * 0.5 + 0.5), 0)
        note('The Flint : %s x %s', chips, mult)
    end

    -- played cards ---------------------------------------------------------------------------
    local in_scoring = {}
    for _, c in ipairs(ev.scoring) do in_scoring[c] = true end
    for _, c in ipairs(played) do
        if in_scoring[c] and not c.debuff then
            local reps, k = 1, 1
            while k <= reps do
                local label = C.label(c)
                -- playing_card table
                local eff = { chips = chip_bonus(c) }
                local m = (c.perma_mult or 0)
                if c.lucky then
                    if ch:chance(P.prob_normal / 5) then c.lucky_trigger = true; m = m + (c.mult or 0) end
                else
                    m = m + (c.mult or 0)
                end
                eff.mult = m
                local xm = ms(c.x_mult or 1, c.perma_x_mult)
                if xm > 0 then eff.x_mult = xm end
                local xc = ms(c.x_chips or 1, c.perma_x_chips)
                if xc > 0 then eff.x_chips = xc end
                local pd = (c.perma_p_dollars or 0)
                if c.seal == 'Gold' then pd = pd + 3 end
                if (c.p_dollars or 0) > 0 then
                    if c.lucky then
                        if ch:chance(P.prob_normal / 15) then c.lucky_trigger = true; pd = pd + c.p_dollars end
                    else
                        pd = pd + c.p_dollars
                    end
                end
                eff.dollars = pd
                apply(eff, label)
                -- edition
                local ed = c.edition and C.EDITIONS[c.edition]
                if ed then apply(ed, label .. ' (édition)') end
                -- jokers individual
                for i = 1, #jokers do
                    apply(call('indiv', i, c), jokers[i].name)
                end
                c.lucky_trigger = nil
                if k == 1 then
                    if c.seal == 'Red' then reps = reps + 1 end
                    reps = reps + (c.perma_repetitions or 0)
                    for i = 1, #jokers do
                        local n = call('rep', i, c, 'play')
                        if n and n > 0 then reps = reps + n end
                    end
                end
                k = k + 1
            end
        end
    end

    -- held cards -----------------------------------------------------------------------------
    for _, c in ipairs(held) do
        if not c.debuff and not c.face_down then
            local reps, k = 1, 1
            while k <= reps do
                local label = C.label(c) .. ' (en main)'
                local did = false
                local eff = {}
                local hm = (c.h_mult or 0) + (c.perma_h_mult or 0)
                if hm ~= 0 then eff.mult = hm end
                local hxm = ms(c.h_x_mult or 1, c.perma_h_x_mult)
                if hxm > 0 then eff.x_mult = hxm end
                local hc = (c.h_chips or 0) + (c.perma_h_chips or 0)
                if hc ~= 0 then eff.chips = hc end
                did = apply(eff, label) or did
                for i = 1, #jokers do
                    did = apply(call('held', i, c), jokers[i].name) or did
                end
                if k == 1 and did then
                    if c.seal == 'Red' then reps = reps + 1 end
                    for i = 1, #jokers do
                        local n = call('rep', i, c, 'hand')
                        if n and n > 0 then reps = reps + n end
                    end
                end
                k = k + 1
            end
        end
    end

    -- jokers ---------------------------------------------------------------------------------
    for i, j in ipairs(jokers) do
        if not j.debuff then
            if j.edition == 'e_foil' then apply({ chips = 50 }, j.name .. ' (Foil)')
            elseif j.edition == 'e_holo' then apply({ mult = 10 }, j.name .. ' (Holo)') end
            apply(call('main', i), j.name)
        end
        for k = 1, #jokers do
            apply(call('other', k, j), jokers[k].name)
        end
        if not j.debuff and j.edition == 'e_polychrome' then apply({ x_mult = 1.5 }, j.name .. ' (Polychrome)') end
    end
    -- consumables: Observatory
    if P.observatory then
        for _, c in ipairs(P.consumables) do
            if c.set == 'Planet' and c.hand_type == hand and not c.debuff then
                apply({ x_mult = P.observatory_x }, 'Observatory')
            end
        end
    end

    -- deck final step ------------------------------------------------------------------------
    if P.plasma then
        local tot = chips + mult
        chips = floor(tot / 2)
        mult = floor(tot / 2)
        note('Plasma : %s x %s', chips, mult)
    end

    res.chips, res.mult = chips, mult
    res.score = floor(chips * mult * (P.learned_mult or 1))
    res.dollars = earned
    res.level = level
    res.trace = log
    res.jokers_after = jokers
    return res
end

-- Derive a prepared context for a later point of the same round (used by simulations):
-- overrides = { hands_left, discards_left, deck_count, dollars, jokers_after, hands_played_delta }
function Score.derive(P, o)
    local Q = {}
    for k, v in pairs(P) do Q[k] = v end
    Q.round = { hands_left = o.hands_left or P.round.hands_left, discards_left = o.discards_left or P.round.discards_left }
    if o.deck_count then Q.deck_count = o.deck_count end
    if o.dollars then Q.dollars = o.dollars end
    if o.hands_played then Q.hands_played_total = o.hands_played end
    if o.jokers_after then
        local js = {}
        for i, j in ipairs(P.jokers) do
            local nj = {}
            for k, v in pairs(j) do nj[k] = v end
            local after = o.jokers_after[i]
            if after then nj.ability = after.ability end
            js[i] = nj
        end
        Q.jokers = js
    end
    if o.hands then Q.hands = o.hands end
    if o.blind then Q.blind = o.blind end
    return Q
end

-- Public API ---------------------------------------------------------------------------------

-- Evaluate a play. Returns
--  { hand, method = 'exact'|'enumeration'|'monte_carlo', exact = bool, mean, min, max,
--    dist = {{score, p}...}, p_at_least = fn, dollars (expected), coverage, debuffed_hand, trace }
function Score.evaluate_prepared(P, played, held, opts)
    opts = opts or {}
    local max_runs = opts.max_branches or 256
    local results = {}
    local pending = { {} }
    local runs = 0
    local aborted = false
    local first
    while #pending > 0 do
        local prefix = table.remove(pending)
        local ch = new_enum_chooser(prefix, pending)
        local r = run_once(P, played, held, ch, opts.trace and runs == 0)
        runs = runs + 1
        first = first or r
        results[#results + 1] = { score = r.score, p = ch.prob, dollars = r.dollars, r = r }
        if runs >= max_runs and #pending > 0 then aborted = true; break end
    end

    local method
    if aborted then
        -- Monte-Carlo fallback, reproducible
        results = {}
        local rng = R.new(opts.seed or 'score')
        local n = opts.samples or 600
        for _ = 1, n do
            local ch = new_sample_chooser(rng)
            local r = run_once(P, played, held, ch, false)
            results[#results + 1] = { score = r.score, p = 1 / n, dollars = r.dollars }
        end
        method = 'monte_carlo'
    elseif runs == 1 then
        method = 'exact'
    else
        method = 'enumeration'
    end

    -- aggregate distribution
    local agg = {}
    local mean, dmean = 0, 0
    local mn, mx = math.huge, -math.huge
    for _, e in ipairs(results) do
        agg[e.score] = (agg[e.score] or 0) + e.p
        mean = mean + e.score * e.p
        dmean = dmean + (e.dollars or 0) * e.p
        if e.score < mn then mn = e.score end
        if e.score > mx then mx = e.score end
    end
    local dist = {}
    for s, p in pairs(agg) do dist[#dist + 1] = { s, p } end
    table.sort(dist, function(a, b) return a[1] < b[1] end)

    local cov = P.coverage
    local fully_known = (#cov.unsupported == 0) and not cov.hidden
    for _, c in ipairs(played) do
        if c.face_down or c.unknown_enh then fully_known = false end
    end
    for _, c in ipairs(held) do
        if c.face_down or c.unknown_enh then fully_known = false end
    end

    local out = {
        hand = first.hand, level = first.level, scoring_uids = first.scoring_uids,
        debuffed_hand = first.debuffed_hand, method = method,
        exact = (method == 'exact') and fully_known,
        deterministic = (method == 'exact'),
        complete = fully_known,
        mean = mean, min = mn, max = mx, dist = dist, dollars = dmean,
        chips = first.chips, mult = first.mult, trace = first.trace,
        coverage = cov, runs = runs,
    }
    function out.p_at_least(target)
        local p = 0
        for _, e in ipairs(dist) do if e[1] >= target then p = p + e[2] end end
        if p > 1 then p = 1 end
        return p
    end
    return out
end

function Score.evaluate(state, played, held, opts)
    local P = Score.prepare(state, opts)
    return Score.evaluate_prepared(P, played, held, opts)
end

-- Deterministic expected-value proxy used in hot loops (no enumeration): random events
-- resolved by expectation is not possible in general, so we sample a fixed small number
-- of paths with a fixed seed. Returns mean score and hand name.
function Score.quick(P, played, held, rng, samples)
    samples = samples or 1
    local tot = 0
    local hand, last
    for _ = 1, samples do
        local ch = new_sample_chooser(rng)
        local r = run_once(P, played, held, ch, false)
        tot = tot + r.score
        hand = r.hand
        last = r
        if ch.points == 0 then return r.score, hand, true, r end
    end
    return tot / samples, hand, false, last
end

Score._run_once = run_once
Score._enum_chooser = new_enum_chooser

return Score
