-- Balatro Strategic Copilot - engine/strategy.lua  (StrategyEngine core)
-- Build power and run outlook:
--   * power samples: best play (fast policy) on random fresh hands drawn from the full deck
--     composition, with common random numbers so that variants (buy X, sell Y, level up Z)
--     are compared on the same hands;
--   * P(clear a blind of size X): bootstrap over power samples (cheap, used for comparisons)
--     or full round rollouts with the explicit policy (used for the next blind);
--   * P(win the run): product over remaining blinds with a power-growth model whose
--     parameter is learned from the player's past runs (shrunk toward a prior);
--   * risk posture: continuous "danger" derived from the next blinds, never a fixed threshold.

local BSC = BSCopilot
local U = BSC.require('core/util')
local R = BSC.require('core/rng')
local C = BSC.require('model/cards')
local H = BSC.require('model/hands')
local BL = BSC.require('model/blinds_db')
local Score = BSC.require('engine/score')
local HA = BSC.require('engine/hand_advisor')
local PR = BSC.require('engine/probability')

local ST = {}

ST.PRIOR_GROWTH = 2.0      -- prior power growth per ante (documented in docs/MATHS.md)
ST.PRIOR_GROWTH_WEIGHT = 5 -- equivalent number of observed runs for the prior

local function noop() end

local function round_params(state)
    local r = state.round or {}
    return r.round_hands or 4, r.round_discards or 3, r.hand_size or 8
end

-- Apply a boss blind to a copy of the deck (debuffs) and round parameters.
function ST.apply_boss(state, boss_key, deck)
    local b = BL.get(boss_key)
    local h, d, hs = round_params(state)
    local out = {}
    local effect = b and b.effect
    -- vanilla Blind:debuff_card: card:is_suit(suit, true) (Wild cards, and both red or both
    -- black suits with Smeared Joker, are debuffed too), card:is_face(true) (every card with
    -- Pareidolia), cards played this ante for The Pillar
    local rules = (effect == 'debuff_suit' or effect == 'debuff_face') and Score.prepare(state).rules or nil
    for i, c in ipairs(deck) do
        local cc = c
        local deb = false
        if effect == 'debuff_suit' and C.is_suit(c, b.suit, rules, true) then deb = true end
        if effect == 'debuff_face' and C.is_face(c, rules, true) then deb = true end
        if effect == 'debuff_played_ante' and c.played_this_ante then deb = true end
        if deb then cc = C.copy(c); cc.debuff = true end
        out[i] = cc
    end
    if effect == 'hands_1' then h = 1 end
    if effect == 'no_discards' then d = 0 end
    if effect == 'hand_size_minus' then hs = hs - 1 end
    return out, h, d, hs
end

-- Per-hand power samples. opts: { n, seed, boss, hands, discards, hand_size, task }
function ST.power_samples(state, opts)
    opts = opts or {}
    local check = (opts.task and opts.task.check) or noop
    local n = opts.n or 80
    local deck = state.full_deck or state.deck or {}
    local h, d, hs = round_params(state)
    if opts.boss then deck, h, d, hs = ST.apply_boss(state, opts.boss, deck) end
    h = opts.hands or h
    hs = opts.hand_size or hs
    local blind = opts.boss and { key = opts.boss, boss = true } or { key = 'bl_small', boss = false }
    local st2 = {}
    for k, v in pairs(state) do st2[k] = v end
    st2.blind = blind
    st2.round = { hands_left = math.max(2, h), discards_left = d, hand_size = hs }
    local P = Score.prepare(st2)
    local P_last = Score.derive(P, { hands_left = 1 })
    local scores, usage = {}, {}
    local plays
    local min_cards = (opts.boss == 'bl_psychic') and 5 or nil
    -- the player puts the cards in the best order (Hanging Chad, Photograph, Glass...)
    local order = HA.order_sensitive(P, deck)
    for i = 1, n do
        check()
        local rng = R.new((opts.seed or 'power') .. ':' .. i)
        local hand = rng:sample(deck, math.min(hs, #deck))
        local PP = (h > 0 and i % math.max(1, h) == 0) and P_last or P
        local forced = (opts.boss == 'bl_final_bell' and #hand > 0) and hand[rng:int(1, #hand)] or nil
        local best, s, hname = HA.best_play_fast(PP, hand, rng, { min_cards = min_cards, forced = forced, order = order })
        scores[i] = s or 0
        if hname then usage[hname] = (usage[hname] or 0) + 1 end
        if opts.keep_plays and best then
            plays = plays or {}
            plays[i] = { played = best, held = HA.minus(hand, best), last = (PP == P_last) }
        end
    end
    local sorted = {}
    for i, v in ipairs(scores) do sorted[i] = v end
    table.sort(sorted)
    local mean = U.mean(scores) or 0
    return { scores = scores, sorted = sorted, mean = mean, median = sorted[math.max(1, math.floor(#sorted / 2))] or 0,
        q25 = sorted[math.max(1, math.floor(#sorted * 0.25))] or 0, q75 = sorted[math.max(1, math.floor(#sorted * 0.75))] or 0,
        usage = usage, n = n, hands = h, discards = d, hand_size = hs, coverage = P.coverage, plays = plays, prepared = P }
end

-- Most played hand types in the samples (fractions).
function ST.usage_fractions(ps)
    local out = {}
    local total = 0
    for _, v in pairs(ps.usage) do total = total + v end
    for k, v in pairs(ps.usage) do out[k] = v / math.max(1, total) end
    return out
end

-- P(total over the round >= X) from per-hand samples (bootstrap). Discards are modelled as
-- extra draws: each hand takes the max of k samples, k = 1 + discards/hands (stochastic).
-- scale: multiplies every sample (power growth). Returns p, lo, hi.
function ST.p_clear_bootstrap(ps, X, opts)
    opts = opts or {}
    local B = opts.B or 400
    local h = opts.hands or ps.hands or 4
    local d = opts.discards or ps.discards or 3
    local scale = opts.scale or 1
    local samples = ps.scores
    local n = #samples
    if n == 0 or h <= 0 then return 0, 0, 0 end
    if X <= 0 then return 1, 1, 1 end
    local rng = R.new(opts.seed or 'boot')
    local extra = d / h
    local wins = 0
    for _ = 1, B do
        local total = 0
        for _ = 1, h do
            local k = 1 + math.floor(extra)
            if rng:float() < extra - math.floor(extra) then k = k + 1 end
            local best = 0
            for _ = 1, k do
                local v = samples[rng:int(1, n)]
                if v > best then best = v end
            end
            total = total + best * scale
            if total >= X then break end
        end
        if total >= X then wins = wins + 1 end
    end
    return PR.wilson(wins, B)
end

-- Faithful estimate for the next blind: full rollouts of a fresh round with the policy.
function ST.p_clear_rollouts(state, X, opts)
    opts = opts or {}
    local check = (opts.task and opts.task.check) or noop
    local n = opts.n or 64
    local deck0 = state.full_deck or {}
    local h, d, hs = round_params(state)
    if opts.boss then deck0, h, d, hs = ST.apply_boss(state, opts.boss, deck0) end
    local st2 = {}
    for k, v in pairs(state) do st2[k] = v end
    st2.blind = { key = opts.boss or 'bl_small', boss = opts.boss ~= nil, chips_required = X, chips_scored = 0 }
    st2.round = { hands_left = h, discards_left = d, hand_size = hs }
    local P = Score.prepare(st2)
    local ctx = { state = st2, hand_size = hs, serpent = opts.boss == 'bl_serpent',
        forced_rule = opts.boss == 'bl_final_bell',
        play_opts = { min_cards = (opts.boss == 'bl_psychic') and 5 or nil } }
    local wins = 0
    for i = 1, n do
        check()
        local rng = R.new((opts.seed or 'fresh') .. ':' .. i)
        local deck = {}
        for k, c in ipairs(deck0) do deck[k] = c end
        rng:shuffle(deck)
        local hand = {}
        for k = 1, math.min(hs, #deck) do hand[k] = deck[k] end
        local rest = {}
        for k = hs + 1, #deck do rest[#rest + 1] = deck[k] end
        -- Cerulean Bell: a random card of the first hand is forced
        ctx.forced = (ctx.forced_rule and #hand > 0) and hand[rng:int(1, #hand)] or nil
        local Pstep = Score.derive(P, { hands_left = h, discards_left = d, deck_count = #rest })
        local action = HA.policy(Pstep, hand, h, d, X, rest, rng, ctx, ctx.forced)
        local ok = HA.rollout(P, action, hand, rest, h, d, X, rng, ctx)
        if ok then wins = wins + 1 end
    end
    return PR.wilson(wins, n)
end

-- Blind sizes from now to the winning ante (or a horizon in endless mode).
function ST.remaining_blinds(state, horizon)
    local run = state.run or {}
    local ante = run.ante or 1
    local win = run.win_ante or 8
    local scaling, ante_scaling = run.scaling or 1, run.ante_scaling or 1
    local out = {}
    -- current ante: use the upcoming list (respects defeated/skipped blinds)
    for _, b in ipairs(state.upcoming or {}) do
        if b.state ~= 'Defeated' and b.state ~= 'Skipped' then
            out[#out + 1] = { ante = ante, slot = b.slot, key = b.key, chips = b.chips, boss = b.boss, name = b.name }
        end
    end
    local last = (run.won or ante > win) and (ante + (horizon or 3)) or win
    for a = ante + 1, last do
        local base = BL.base_amount(a, scaling) * ante_scaling
        out[#out + 1] = { ante = a, slot = 'Small', chips = math.floor(base * 1), boss = false }
        out[#out + 1] = { ante = a, slot = 'Big', chips = math.floor(base * 1.5), boss = false }
        out[#out + 1] = { ante = a, slot = 'Boss', chips = math.floor(base * 2), boss = true, unknown_boss = true }
    end
    return out
end

-- Learned growth per ante (geometric), from the learning profile if available.
function ST.growth(profile)
    local g = profile and profile.growth
    local prior = math.log(ST.PRIOR_GROWTH)
    if not g or (g.n or 0) == 0 then return ST.PRIOR_GROWTH, 'prior' end
    local w = ST.PRIOR_GROWTH_WEIGHT
    local mean = (prior * w + g.sum_log * 1) / (w + g.n)
    return math.exp(mean), 'learned'
end

-- P(win the run) and expected progress. Unknown future bosses: an average difficulty factor.
function ST.run_outlook(state, ps, opts)
    opts = opts or {}
    local blinds = ST.remaining_blinds(state, opts.horizon)
    local growth, gsrc = ST.growth(opts.profile)
    local ante_now = (state.run and state.run.ante) or 1
    local calib = opts.calibrate or function(p) return p end
    local p_all = 1
    local expected_blinds = 0
    local details = {}
    local boss_factor = opts.boss_factor or 0.85 -- unknown boss: ~15% harder on average (prior)
    for i, b in ipairs(blinds) do
        local scale = growth ^ (b.ante - ante_now)
        local X = b.chips
        if b.unknown_boss then X = X / boss_factor end
        local p = ST.p_clear_bootstrap(ps, X, { scale = scale, seed = 'outlook' .. i, B = opts.B or 300 })
        p = calib(p)
        p_all = p_all * p
        expected_blinds = expected_blinds + p_all
        details[#details + 1] = { ante = b.ante, slot = b.slot, chips = b.chips, p = p, cumulative = p_all, name = b.name }
        if p_all < 1e-4 then break end
    end
    return { p_win = p_all, expected_blinds = expected_blinds, details = details, growth = growth, growth_source = gsrc,
        endless = state.run and state.run.won }
end

-- Continuous danger in [0,1] from the probability of clearing the next blinds.
function ST.danger(p_next, p_boss)
    p_next = p_next or 1
    p_boss = p_boss or p_next
    return U.clamp(1 - (0.6 * p_next + 0.4 * p_boss), 0, 1)
end

return ST
