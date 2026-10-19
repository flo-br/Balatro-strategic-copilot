local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local BD = BSCopilot.require('engine/builds')
    return F, BD
end

local function card(uid, id, suit, extra)
    local c = { uid = uid, id = id, suit = suit, nominal = math.min(10, id) }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

local function has(list, pattern)
    for _, e in ipairs(list) do if e.why:find(pattern, 1, true) then return e end end
end

function S.baron_and_mime(T)
    local F, BD = env()
    local s = F.state({ ante = 4, jokers = { F.joker('j_baron') } })
    local v, why = BD.joker_bonus('j_mime', s)
    T.near(v, 0.4 + 0.07, 1e-9, 'S pair + piece of the Baron build')
    T.ok(why:find('Baron', 1, true), why)
    local bare = F.state({ ante = 4 })
    T.eq((BD.joker_bonus('j_mime', bare)), 0, 'nothing to retrigger yet')
    -- early: synergies count less (do not force a build before the shop offers it)
    s.run.ante = 1
    T.near((BD.joker_bonus('j_mime', s)), 0.7 * 0.47, 1e-9)
end

function S.anti_synergies_and_deck(T)
    local F, BD = env()
    local s = F.state({ ante = 4, jokers = { F.joker('j_lucky_cat') } })
    local v, why = BD.joker_bonus('j_vampire', s)
    T.ok(v < 0, 'Vampire eats the Lucky cards')
    T.ok(why:find('anti', 1, true), why)
    s = F.state({ ante = 4, deck_stats = { size = 52, starting_size = 52, steel = 4, enhanced = 4, ranks = {}, suits = {} } })
    local _, _, list = BD.joker_bonus('j_steel_joker', s)
    T.ok(has(list, 'acier'), 'Steel Joker with 4 Steel cards')
end

function S.copy_jokers_want_a_target(T)
    local F, BD = env()
    local s = F.state({ ante = 4, jokers = { F.joker('j_cavendish') } })
    local _, _, list = BD.joker_bonus('j_blueprint', s)
    T.ok(has(list, '×3 copié'), 'Blueprint + Cavendish (named pair)')
    s = F.state({ ante = 4, jokers = { F.joker('j_duo') } })
    _, _, list = BD.joker_bonus('j_blueprint', s)
    T.ok(has(list, 'copie un multiplicateur'), 'Blueprint copies any xMult joker')
    s = F.state({ ante = 4, jokers = { F.joker('j_joker') } })
    T.eq((BD.joker_bonus('j_blueprint', s)), 0, 'nothing worth copying')
end

function S.active_builds_and_card_preferences(T)
    local F, BD = env()
    local s = F.state({ ante = 4, jokers = { F.joker('j_baron'), F.joker('j_mime') } })
    local b = BD.active(s)[1]
    T.eq(b.key, 'baron')
    T.ok(#b.missing > 0 and b.tip ~= nil)
    local bonus = BD.card_bonus(s)
    T.ok(bonus(card('k', 13, 'Spades')) > bonus(card('7', 7, 'Spades')) + 15, 'Baron wants Kings')
    s = F.state({ jokers = { F.joker('j_bloodstone'), F.joker('j_lusty_joker') } })
    T.eq(BD.payoff_suit(s), 'Hearts')
end

function S.tarot_targets_follow_the_build(T)
    local F, BD = env()
    local A = BSCopilot.require('engine/advice')
    local IT = BSCopilot.require('model/items_db')
    -- Strength with Baron: the Queen becomes a King (even though 8s are more common)
    local q, seven = card('q', 12, 'Spades'), card('7', 7, 'Hearts')
    local hand = { q, seven }
    local s = F.state({ hand_cards = hand, jokers = { F.joker('j_baron') } })
    s.full_deck = { q, seven }
    for i = 1, 6 do s.full_deck[#s.full_deck + 1] = card('e' .. i, 8, 'Clubs') end
    local t = A.targets(IT.consumable('c_strength'), s, hand, {})
    T.eq(t.cards[1].uid, 'q', 'Strength: Queen -> King for Baron')
    -- Hanged Man with Canio: figures are destroyed (each one +x1 Mult)
    local k, two, three = card('k', 13, 'Hearts'), card('2', 2, 'Clubs'), card('3', 3, 'Clubs')
    hand = { k, two, three }
    s = F.state({ hand_cards = hand, jokers = { F.joker('j_caino') } })
    s.full_deck = {}
    for i = 1, 30 do s.full_deck[i] = card('f' .. i, 9, 'Spades') end
    t = A.targets(IT.consumable('c_hanged_man'), s, hand, {})
    T.eq(t.cards[1].uid, 'k', 'Canio: the figure is destroyed')
    -- The Sun (Hearts) with Bloodstone: toward the payoff suit even if Spades dominate
    local a, b2 = card('a', 10, 'Spades'), card('b', 11, 'Clubs')
    hand = { a, b2 }
    s = F.state({ hand_cards = hand, jokers = { F.joker('j_bloodstone') } })
    s.full_deck = { a, b2 }
    for i = 1, 20 do s.full_deck[#s.full_deck + 1] = card('s' .. i, 4, 'Spades') end
    t = A.targets(IT.consumable('c_sun'), s, hand, { strict = true })
    T.ok(t and #t.cards >= 1, 'Sun converts toward Hearts for Bloodstone')
end

return S
