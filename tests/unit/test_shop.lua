local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    local SH = BSCopilot.require('engine/shop')
    return F, C, SH
end

local function shop_state(F, C, o)
    o = o or {}
    local s = F.state({ jokers = o.jokers or {}, dollars = o.dollars or 10, joker_slots = o.slots or 5, levels = o.levels })
    s.phase = 'shop'
    s.full_deck = C.standard_deck()
    s.round.round_hands, s.round.round_discards, s.round.hand_size = 4, 3, 8
    s.run.ante = 2
    s.upcoming = {
        { slot = 'Small', key = 'bl_small', chips = 800, state = 'Select' },
        { slot = 'Big', key = 'bl_big', chips = 1200, state = 'Upcoming' },
        { slot = 'Boss', key = 'bl_hook', chips = 1600, boss = true, state = 'Upcoming' },
    }
    local items = {}
    for i, it in ipairs(o.items or {}) do it.uid = it.uid or ('item' .. i); items[i] = it end
    s.shop = { jokers = items, vouchers = o.vouchers or {}, boosters = o.boosters or {} }
    return s
end

local function joker_item(F, key, cost, ability)
    local j = F.joker(key, ability)
    return { set = 'Joker', key = key, name = j.name, cost = cost or 5, joker = j }
end

function S.strong_joker_beats_weak(T)
    local F, C, SH = env()
    local s = shop_state(F, C, { items = { joker_item(F, 'j_credit_card', 1), joker_item(F, 'j_duo', 8) }, dollars = 12 })
    local r = SH.analyse(s, { n = 24 })
    T.eq(r.options[1].key, 'j_duo', 'The Duo ranked first')
    T.ok(r.options[1].note > r.options[2].note)
    T.ok(r.options[1].ratio > 1.3, 'Duo raises power')
    T.ok(r.options[1].note >= 0 and r.options[1].note <= 100)
    T.ok(r.base.p_next ~= nil and r.base.p_boss ~= nil)
end

function S.unaffordable_is_flagged(T)
    local F, C, SH = env()
    local s = shop_state(F, C, { items = { joker_item(F, 'j_duo', 8) }, dollars = 3 })
    local r = SH.analyse(s, { n = 16 })
    T.eq(r.options[1].affordable, false)
end

function S.full_slots_offer_replacement(T)
    local F, C, SH = env()
    local jokers = {}
    for _ = 1, 5 do jokers[#jokers + 1] = F.joker('j_credit_card') end
    local s = shop_state(F, C, { jokers = jokers, items = { joker_item(F, 'j_duo', 8) }, dollars = 20 })
    local r = SH.analyse(s, { n = 16 })
    T.eq(r.options[1].kind, 'replace')
    T.eq(r.options[1].replaces, 'Credit Card')
end

function S.planet_for_played_hand(T)
    local F, C, SH = env()
    local s = shop_state(F, C, { items = {
        { set = 'Planet', key = 'c_mercury', name = 'Mercury', cost = 3, hand_type = 'Pair' },
        { set = 'Planet', key = 'c_eris', name = 'Eris', cost = 3, hand_type = 'Flush Five' },
    } })
    local r = SH.analyse(s, { n = 24 })
    local notes = {}
    for _, o in ipairs(r.options) do notes[o.key] = o end
    T.ok(notes.c_mercury.ratio > 1.0, 'Mercury helps (pairs are common)')
    T.near(notes.c_eris.ratio, 1, 1e-9, 'Flush Five never played: no gain')
    T.ok(notes.c_mercury.note > notes.c_eris.note)
end

function S.variant_level_up(T)
    local F, C, SH = env()
    local s = shop_state(F, C)
    local v = SH.variant(s, { level = 'Pair', n = 1 })
    T.eq(v.hands.Pair.level, 2); T.eq(v.hands.Pair.chips, 25); T.eq(v.hands.Pair.mult, 3)
    T.eq(s.hands.Pair.level, 1, 'original state untouched')
    local v2 = SH.variant(s, { enhance = 'm_mult', n = 2 })
    local n = 0
    for _, c in ipairs(v2.full_deck) do if c.enh == 'm_mult' then n = n + 1 end end
    T.eq(n, 2)
    for _, c in ipairs(s.full_deck) do T.no(c.enh) end
end

function S.reroll_estimate(T)
    local F, C, SH = env()
    local s = shop_state(F, C, { items = { joker_item(F, 'j_duo', 8) }, dollars = 30 })
    local r = SH.analyse(s, { n = 16 })
    T.ok(r.reroll and r.reroll.n > 0)
    T.ok(r.reroll.p_improve >= 0 and r.reroll.p_improve <= 1)
    T.eq(r.reroll.method, 'monte_carlo')
end

function S.note_weights_follow_danger(T)
    local _, _, SH = env()
    local calm, crit = SH.weights(0), SH.weights(1)
    T.ok(crit.impact > calm.impact, 'danger raises the weight of immediate impact')
    T.ok(crit.econ < calm.econ, 'danger lowers the weight of economy')
    T.eq(SH.note({}, calm), 50)
end

return S
