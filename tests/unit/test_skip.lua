local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local SK = BSCopilot.require('engine/skip')
    return F, SK
end

local SMALL = { slot = 'Small', reward = 3, chips = 300 }

local function eval(SK, s, ctx)
    ctx = ctx or {}
    ctx.current = ctx.current or SMALL
    ctx.p_following = ctx.p_following or 0.97
    ctx.p_boss = ctx.p_boss or 0.95
    ctx.median = ctx.median or 200
    ctx.plan = ctx.plan or { gaps = {} }
    return SK.evaluate(s, ctx)
end

function S.cost_counts_reward_hands_interest_shop(T)
    local F, SK = env()
    local s = F.state({ dollars = 20 })
    s.blind_tags = { Small = 'tag_voucher', Big = 'tag_rare' }
    local r = eval(SK, s)
    T.eq(r.parts.reward, 3)
    T.eq(r.parts.interest, 4)
    T.eq(r.parts.hands, 3, 'a one-hand blind leaves 3 hands ($1 each)')
    T.ok(r.parts.shop > 0, 'the shop that follows the blind')
    -- Red Stake: the Small Blind pays nothing, skipping it costs less
    local red = eval(SK, s, { current = { slot = 'Small', reward = 0, chips = 300 } })
    T.near(r.lost - red.lost, 3, 1e-9)
    -- a rental joker costs $3 per round: a skip saves it
    s.jokers = { F.joker('j_joker') }
    local before = eval(SK, s).lost
    s.jokers[1].rental = true
    T.near(before - eval(SK, s).lost, 3, 1e-9)
end

function S.money_tags_by_the_amount_they_give(T)
    local F, SK = env()
    local s = F.state({ dollars = 30 })
    T.eq((SK.tag_value('tag_economy', s)), 30)
    s.econ.dollars = 70
    T.ok((SK.tag_value('tag_economy', s)) <= 40, 'Economy: $40 at most')
    s.econ.dollars = 10
    s.run.skips = 3
    T.eq((SK.tag_value('tag_skip', s)), 20, 'Speed: $5 per skip, this one included')
    s.run.hands_played = 17
    T.eq((SK.tag_value('tag_handy', s)), 17)
    T.eq((SK.tag_value('tag_investment', s)), 25)
end

function S.orbital_only_on_the_main_hand(T)
    local F, SK = env()
    local s = F.state({ ante = 3 })
    local main = SK.tag_value('tag_orbital', s, { orbital_hand = 'Pair', plan = { main_hand = 'Pair', gaps = {} } })
    local other = SK.tag_value('tag_orbital', s, { orbital_hand = 'Straight Flush', plan = { main_hand = 'Pair', gaps = {} }, usage = {} })
    T.ok(main >= 9, 'main hand: about 3 planets')
    T.eq(other, 0, 'a hand never played: worthless')
end

function S.big_blind_skip_needs_a_safe_boss(T)
    local F, SK = env()
    local s = F.state({ dollars = 4 })
    s.blind_tags = { Small = 'tag_voucher', Big = 'tag_investment' }
    local big = { slot = 'Big', reward = 4, chips = 450 }
    local r = eval(SK, s, { current = big, p_boss = 0.8 })
    T.no(r.recommended, 'boss only 80 % with no shop before it')
    T.eq(r.reason, 'not_safe'); T.ok(r.following_is_boss)
    r = eval(SK, s, { current = big, p_boss = 0.97 })
    T.ok(r.recommended, 'Investment with a safe boss')
end

function S.double_tag_copies_a_strong_next_tag(T)
    local F, SK = env()
    local s = F.state({ dollars = 4 })
    s.blind_tags = { Small = 'tag_double', Big = 'tag_investment' }
    local r = eval(SK, s)
    T.ok(r.tag_value >= 12, 'Double before an Investment Tag')
    s.blind_tags = { Small = 'tag_double', Big = 'tag_voucher' }
    T.ok(eval(SK, s).tag_value <= 1, 'Double before a weak tag: worthless')
end

function S.boss_tag_only_against_a_counter(T)
    local F, SK = env()
    local s = F.state()
    T.ok((SK.tag_value('tag_boss', s, { p_boss = 0.95, p_boss_generic = 0.96 })) < 1, 'about the same boss')
    T.ok((SK.tag_value('tag_boss', s, { p_boss = 0.4, p_boss_generic = 0.9 })) >= 25, 'a boss that counters the build')
end

return S
