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

-- Top players almost never skip: skipping loses the reward AND the shop that follows; only a
-- tag worth more than both (e.g. Investment) with a safe following blind is skipped.
function S.skip_decisions_follow_top_players(T)
    -- Ante 1 Small Blind with a deck that beats the Big Blind: top players skip for Investment,
    -- Coupon, Polychrome (docs/PRO_LESSONS.md); never for Voucher, Juggle, D6 alone
    local F, C = env()
    local O = BSCopilot.require('engine/outlook')
    local strong = { F.joker('j_joker'), F.joker('j_cavendish'), F.joker('j_duo'), F.joker('j_baron') }
    local function skip_for(tag, jokers, upcoming)
        local s = base_state(F, C, { jokers = jokers, upcoming = upcoming })
        s.run.ante = 1
        s.blind_tags = { Small = tag, Big = 'tag_uncommon' }
        return O.analyse(s, { samples = 24, rollouts = 16 }).skip
    end
    for _, tag in ipairs({ 'tag_investment', 'tag_coupon', 'tag_polychrome' }) do
        local sk = skip_for(tag, strong)
        T.ok(sk.recommended, tag .. ' is worth the skip (' .. string.format('%.1f vs %.1f', sk.tag_value, sk.lost) .. ')')
        T.ok(sk.p_following >= 0.9, 'the Big Blind stays safe')
    end
    for _, tag in ipairs({ 'tag_voucher', 'tag_juggle', 'tag_d_six', 'tag_double' }) do
        T.no(skip_for(tag, strong).recommended, tag .. ' is not worth a skip on its own')
    end
    -- not when the next blind cannot be beaten without the shop
    local hard = {
        { slot = 'Small', key = 'bl_small', chips = 300, state = 'Select', reward = 3 },
        { slot = 'Big', key = 'bl_big', chips = 20000, state = 'Upcoming', reward = 4 },
        { slot = 'Boss', key = 'bl_club', chips = 30000, boss = true, state = 'Upcoming', reward = 5 },
    }
    local sk = skip_for('tag_investment', strong, hard)
    T.no(sk.recommended, 'Investment, but the Big Blind is not safe')
    T.eq(sk.reason, 'not_safe')
end

return S
