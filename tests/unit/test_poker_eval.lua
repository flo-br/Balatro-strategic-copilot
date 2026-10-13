local T = ...
local S = {}

local function setup()
    local C = BSCopilot.require('model/cards')
    local P = BSCopilot.require('engine/poker_eval')
    return C, P
end

local function ev(str, rules, opts)
    local C, P = setup()
    local cards = C.parse_list(str)
    if opts then for i, o in pairs(opts) do for k, v in pairs(o) do cards[i][k] = v end end end
    return P.evaluate(cards, rules), cards
end

function S.basic_hands(T)
    T.eq(ev('Ah').name, 'High Card')
    T.eq(ev('Ah Kd 7c').name, 'High Card')
    T.eq(ev('Ah Ad 7c').name, 'Pair')
    T.eq(ev('Ah Ad 7c 7s 2h').name, 'Two Pair')
    T.eq(ev('Ah Ad As 7s 2h').name, 'Three of a Kind')
    T.eq(ev('9h Td Js Qs Kh').name, 'Straight')
    T.eq(ev('2h 7h 9h Jh Kh').name, 'Flush')
    T.eq(ev('Ah Ad As 7s 7h').name, 'Full House')
    T.eq(ev('Ah Ad As Ac 7h').name, 'Four of a Kind')
    T.eq(ev('9h Th Jh Qh Kh').name, 'Straight Flush')
end

function S.special_hands(T)
    local C, P = setup()
    -- Five of a kind needs duplicates (e.g. Cryptid copies)
    local five = { C.parse('Ah'), C.parse('Ah'), C.parse('Ad'), C.parse('As'), C.parse('Ac') }
    T.eq(P.evaluate(five).name, 'Five of a Kind')
    local fh = { C.parse('Ah'), C.parse('Ah'), C.parse('Ah'), C.parse('7h'), C.parse('7h') }
    T.eq(P.evaluate(fh).name, 'Flush House')
    local ff = { C.parse('Ah'), C.parse('Ah'), C.parse('Ah'), C.parse('Ah'), C.parse('Ah') }
    T.eq(P.evaluate(ff).name, 'Flush Five')
end

function S.ace_edges(T)
    T.eq(ev('Ah 2d 3s 4c 5h').name, 'Straight')       -- wheel
    T.eq(ev('Th Jd Qs Kc Ah').name, 'Straight')       -- broadway
    T.eq(ev('Qh Kd As 2c 3h').name, 'High Card')      -- no wrap-around
    T.eq(ev('Jh Qd Ks Ac 2h').name, 'High Card')
end

function S.scoring_cards(T)
    local e = ev('Ah Ad 7c 9s 2h')
    T.eq(#e.scoring, 2)
    e = ev('Kh 7d 4c')
    T.eq(#e.scoring, 1); T.eq(e.scoring[1].rank, 'King')
    e = ev('Ah Ad As 7s 7h')
    T.eq(#e.scoring, 5)
    e = ev('Ah Ad 7c 7s 2h')
    T.eq(#e.scoring, 4)
    -- highest card tie-break by suit nominal: Spades highest
    e = ev('Kh Ks')
    T.eq(e.name, 'Pair')
    e = ev('Kh Qs')
    T.eq(e.scoring[1].rank, 'King')
end

function S.contains_sub_hands(T)
    local e = ev('Ah Ad As 7s 7h')
    T.ok(e.contains['Pair']); T.ok(e.contains['Two Pair']); T.ok(e.contains['Three of a Kind'])
    T.ok(e.contains['Full House']); T.no(e.contains['Flush'])
    e = ev('Ah Ad As Ac 7h')
    T.ok(e.contains['Pair']); T.ok(e.contains['Three of a Kind']); T.no(e.contains['Two Pair'])
    e = ev('9h Th Jh Qh Kh')
    T.ok(e.contains['Straight']); T.ok(e.contains['Flush']); T.ok(e.contains['High Card'])
end

function S.four_fingers(T)
    local r = { four_fingers = true }
    T.eq(ev('2h 7h 9h Jh Ks', r).name, 'Flush')
    T.eq(#ev('2h 7h 9h Jh Ks', r).scoring, 4)
    T.eq(ev('5h 6d 7s 8c Kh', r).name, 'Straight')
    T.eq(ev('5h 6h 7h 8h Kd', r).name, 'Straight Flush')
    T.eq(ev('2h 7h 9h Jh Ks').name, 'High Card')
end

function S.shortcut(T)
    local r = { shortcut = true }
    T.eq(ev('2h 4d 6s 8c Th', r).name, 'Straight')
    T.eq(ev('2h 4d 6s 8c Qh', r).name, 'High Card')
    T.eq(ev('Ah 3d 5s 7c 9h', r).name, 'Straight') -- ace low with gaps
    T.eq(ev('2h 4d 6s 8c Th').name, 'High Card')
end

function S.smeared_and_wild(T)
    T.eq(ev('2h 7d 9h Jd Kh', { smeared = true }).name, 'Flush')
    T.eq(ev('2h 7d 9h Jd Kh').name, 'High Card')
    local e = ev('2h 7s 9h Jh Kh', nil, { [2] = { any_suit = true } })
    T.eq(e.name, 'Flush')
    -- debuffed wild card loses its wild property for flush purposes
    e = ev('2h 7s 9h Jh Kh', nil, { [2] = { any_suit = true, debuff = true } })
    T.eq(e.name, 'High Card')
    -- debuffed non-wild card still counts with its base suit
    e = ev('2h 7h 9h Jh Kh', nil, { [2] = { debuff = true } })
    T.eq(e.name, 'Flush')
end

function S.stone_cards(T)
    local C, P = setup()
    local cards = C.parse_list('Ah Ad 7c')
    local stone = C.parse('Ks', { enh = 'm_stone' })
    cards[#cards + 1] = stone
    local e = P.evaluate(cards)
    T.eq(e.name, 'Pair')
    T.eq(#e.scoring, 3) -- pair + stone
    T.ok(e.scoring[3] == stone)
    -- stones never pair with each other
    local s2 = { C.parse('Ks', { enh = 'm_stone' }), C.parse('Ks', { enh = 'm_stone' }) }
    T.eq(P.evaluate(s2).name, 'High Card')
end

function S.splash(T)
    local e = ev('Ah Ad 7c 9s 2h', { splash = true })
    T.eq(e.name, 'Pair')
    T.eq(#e.scoring, 5)
end

function S.scoring_keeps_play_order(T)
    local e, cards = ev('7c Ah 2h Ad')
    T.eq(e.scoring[1], cards[2]); T.eq(e.scoring[2], cards[4])
end

return S
