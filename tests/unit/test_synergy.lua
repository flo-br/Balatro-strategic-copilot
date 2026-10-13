local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    local ST = BSCopilot.require('engine/strategy')
    local SY = BSCopilot.require('engine/synergy')
    return F, C, ST, SY
end

local function state(F, C, jokers, deck)
    local s = F.state({ jokers = jokers })
    s.full_deck = deck or C.standard_deck()
    s.round.round_hands, s.round.round_discards, s.round.hand_size = 4, 3, 8
    return s
end

function S.order_matters_for_xmult(T)
    local F, C, ST, SY = env()
    -- Cavendish (x3) before Joker (+4) is worse than Joker then Cavendish
    local s = state(F, C, { F.joker('j_cavendish'), F.joker('j_joker') })
    local ps = ST.power_samples(s, { n = 20, keep_plays = true, seed = 'o' })
    local best = SY.best_order(s, ps)
    T.ok(best, 'an improvement is found')
    T.eq(best.names[1], 'Joker'); T.eq(best.names[2], 'Cavendish')
    T.ok(best.gain > 0.1)
    -- already optimal: no suggestion
    local s2 = state(F, C, { F.joker('j_joker'), F.joker('j_cavendish') })
    local ps2 = ST.power_samples(s2, { n = 20, keep_plays = true, seed = 'o' })
    T.eq(SY.best_order(s2, ps2), nil)
    -- purely additive jokers: order cannot matter, no computation
    local s3 = state(F, C, { F.joker('j_joker'), F.joker('j_jolly') })
    T.no(SY.order_sensitive(s3))
end

function S.contributions_measured(T)
    local F, C, ST, SY = env()
    local s = state(F, C, { F.joker('j_joker'), F.joker('j_credit_card') })
    local ps = ST.power_samples(s, { n = 20, keep_plays = true, seed = 'c' })
    local contrib = SY.contributions(s, ps)
    T.ok(contrib[1].share > 0.2, 'Joker contributes')
    T.near(contrib[2].share, 0, 1e-9, 'Credit Card adds no score')
end

function S.fit_reflects_build(T)
    local F, C, ST, SY = env()
    local DB = BSCopilot.require('model/jokers_db')
    -- deck of hearts only: flushes everywhere
    local deck = {}
    for _, r in ipairs(C.RANK_ORDER) do for _ = 1, 3 do deck[#deck + 1] = C.new(r, 'Hearts') end end
    local s = state(F, C, {}, deck)
    s.full_deck_stats = BSCopilot.require('game/state_reader').deck_stats(deck, 52)
    local ps = ST.power_samples(s, { n = 20, seed = 'f' })
    local th = SY.themes(s, ps)
    local fit_flush = SY.fit(DB.get('j_droll'), th)
    local fit_straight = SY.fit(DB.get('j_crazy'), th)
    local fit_hearts = SY.fit(DB.get('j_lusty_joker'), th)
    T.ok(fit_flush > fit_straight, 'flush joker fits a flush deck')
    T.ok(fit_hearts > 0.2, 'hearts joker fits a hearts deck')
    -- no artificial bonus for an unexploitable synergy
    T.eq(SY.fit(DB.get('j_steel_joker'), th), 0)
end

return S
