local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    local ST = BSCopilot.require('engine/strategy')
    return F, C, ST
end

local function base_state(F, C, o)
    o = o or {}
    o.deck = o.deck or C.standard_deck()
    local s = F.state(o)
    s.full_deck = o.full_deck or C.standard_deck()
    s.round.round_hands = 4; s.round.round_discards = 3; s.round.hand_size = 8
    s.upcoming = o.upcoming or {
        { slot = 'Small', key = 'bl_small', chips = 300, state = 'Select' },
        { slot = 'Big', key = 'bl_big', chips = 450, state = 'Upcoming' },
        { slot = 'Boss', key = 'bl_club', chips = 600, boss = true, state = 'Upcoming' },
    }
    return s
end

function S.power_samples_reproducible_and_monotone(T)
    local F, C, ST = env()
    local s = base_state(F, C)
    local a = ST.power_samples(s, { n = 30, seed = 'x' })
    local b = ST.power_samples(s, { n = 30, seed = 'x' })
    T.eq(a.mean, b.mean)
    local s2 = base_state(F, C, { jokers = { F.joker('j_joker'), F.joker('j_cavendish') } })
    local c = ST.power_samples(s2, { n = 30, seed = 'x' })
    T.ok(c.mean > a.mean * 2.5, string.format('jokers raise power: %.0f vs %.0f', c.mean, a.mean))
    T.ok(next(a.usage) ~= nil)
end

function S.bootstrap_monotone(T)
    local F, C, ST = env()
    local s = base_state(F, C)
    local ps = ST.power_samples(s, { n = 40, seed = 'y' })
    local p_small = ST.p_clear_bootstrap(ps, 150)
    local p_big = ST.p_clear_bootstrap(ps, 1500)
    T.ok(p_small >= p_big)
    T.eq(ST.p_clear_bootstrap(ps, 0), 1)
    local p_scaled = ST.p_clear_bootstrap(ps, 1500, { scale = 3 })
    T.ok(p_scaled >= p_big)
end

function S.rollouts_reasonable(T)
    local F, C, ST = env()
    local s = base_state(F, C)
    local easy = ST.p_clear_rollouts(s, 100, { n = 16 })
    local hard = ST.p_clear_rollouts(s, 50000, { n = 16 })
    T.eq(easy, 1); T.eq(hard, 0)
end

function S.boss_effects_applied(T)
    local F, C, ST = env()
    local s = base_state(F, C)
    local deck, h, d, hs = ST.apply_boss(s, 'bl_club', s.full_deck)
    local deb = 0
    for _, c in ipairs(deck) do if c.debuff then deb = deb + 1 end end
    T.eq(deb, 13)
    local _, h2 = ST.apply_boss(s, 'bl_needle', s.full_deck)
    T.eq(h2, 1)
    local _, _, d3 = ST.apply_boss(s, 'bl_water', s.full_deck)
    T.eq(d3, 0)
    local _, _, _, hs4 = ST.apply_boss(s, 'bl_manacle', s.full_deck)
    T.eq(hs4, 7)
    -- original deck untouched
    for _, c in ipairs(s.full_deck) do T.no(c.debuff) end
end

function S.remaining_blinds_and_outlook(T)
    local F, C, ST = env()
    local s = base_state(F, C)
    local bl = ST.remaining_blinds(s)
    T.eq(#bl, 3 + 7 * 3)
    T.eq(bl[4].chips, 800); T.eq(bl[5].chips, 1200); T.eq(bl[6].chips, 1600)
    local weak = ST.run_outlook(s, ST.power_samples(s, { n = 30 }))
    local s2 = base_state(F, C, { jokers = { F.joker('j_joker'), F.joker('j_cavendish'), F.joker('j_duo'), F.joker('j_baron') } })
    local strong = ST.run_outlook(s2, ST.power_samples(s2, { n = 30 }))
    T.ok(strong.p_win >= weak.p_win)
    T.ok(strong.expected_blinds > weak.expected_blinds)
    T.ok(weak.p_win >= 0 and weak.p_win <= 1)
end

function S.growth_shrinks_to_prior(T)
    local _, _, ST = env()
    local g0 = ST.growth(nil)
    T.eq(g0, ST.PRIOR_GROWTH)
    -- one observed run with a huge growth must not move the estimate much
    local g1 = ST.growth({ growth = { n = 1, sum_log = math.log(10) } })
    T.ok(g1 < 3, 'one run cannot dominate the prior: ' .. g1)
    local g2 = ST.growth({ growth = { n = 100, sum_log = 100 * math.log(3) } })
    T.ok(math.abs(g2 - 3) < 0.2, 'many runs dominate: ' .. g2)
end

function S.danger_is_continuous(T)
    local _, _, ST = env()
    local prev = -1
    for i = 0, 10 do
        local d = ST.danger(1 - i / 10, 1 - i / 10)
        T.ok(d >= prev); prev = d
    end
    T.near(ST.danger(1, 1), 0, 1e-12)
end

return S
