-- Balatro Strategic Copilot - engine/poker_eval.lua  (RulesEngine: poker hands)
-- Faithful port of the poker-hand evaluation used by Steamodded/vanilla:
--   get_X_same, get_flush (SMODS patch: >= four_fingers cards), get_straight (SMODS
--   implementation with Shortcut skip and Ace as straight edge), get_highest, and the
--   SMODS PokerHand evaluate functions (Flush Five ... High Card).
-- rules = { four_fingers=bool, shortcut=bool, smeared=bool, splash=bool, pareidolia=bool }

local BSC = BSCopilot
local C = BSC.require('model/cards')
local H = BSC.require('model/hands')

local P = {}

-- Rank chain used by get_straight. Ace is a straight edge: it can only start (A-2-3-4-5)
-- or end (10-J-Q-K-A) a straight, never wrap around.
local NEXT = { [2] = { 3 }, [3] = { 4 }, [4] = { 5 }, [5] = { 6 }, [6] = { 7 }, [7] = { 8 }, [8] = { 9 },
    [9] = { 10 }, [10] = { 11 }, [11] = { 12 }, [12] = { 13 }, [13] = { 14 }, [14] = { 2 } }
local EDGE = { [14] = true }
local RANK_IDS = { 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 }

-- get_X_same(num, hand, or_more): groups of equal rank, highest rank first.
function P.x_same(num, cards, or_more)
    local by_id = {}
    for _, c in ipairs(cards) do
        if C.has_rank(c) then
            local g = by_id[c.id]
            if not g then g = {}; by_id[c.id] = g end
            g[#g + 1] = c
        end
    end
    local ret = {}
    for id = 14, 2, -1 do
        local g = by_id[id]
        if g and ((or_more and #g >= num) or #g == num) then ret[#ret + 1] = g end
    end
    return ret
end

function P.flush(cards, rules)
    local need = (rules and rules.four_fingers) and 4 or 5
    if #cards < need then return {} end
    for _, suit in ipairs(C.SUITS) do
        local t = {}
        for _, c in ipairs(cards) do
            if C.is_suit(c, suit, rules, nil, true) then t[#t + 1] = c end
        end
        if #t >= need then return { t } end
    end
    return {}
end

local function next_ranks(id, start, skip)
    local ret = {}
    if not start and EDGE[id] then return ret end
    for _, v in ipairs(NEXT[id]) do
        ret[#ret + 1] = v
        if skip and not EDGE[v] then
            for _, w in ipairs(NEXT[v]) do ret[#ret + 1] = w end
        end
    end
    return ret
end

function P.straight(cards, rules)
    local min_length = (rules and rules.four_fingers) and 4 or 5
    local skip = rules and rules.shortcut
    if #cards < min_length then return {} end
    local ranks = {}
    for _, c in ipairs(cards) do
        if C.has_rank(c) then
            ranks[c.id] = ranks[c.id] or {}
            table.insert(ranks[c.id], c)
        end
    end
    local tuples = {}
    for _, id in ipairs(RANK_IDS) do
        if ranks[id] then tuples[#tuples + 1] = { id } end
    end
    local ret = {}
    for i = 2, #cards + 1 do
        local new_tuples = {}
        for _, tuple in ipairs(tuples) do
            local any_tuple = false
            if i ~= #cards + 1 then
                for _, l in ipairs(next_ranks(tuple[i - 1], i == 2, skip)) do
                    if ranks[l] then
                        local nt = {}
                        for k = 1, #tuple do nt[k] = tuple[k] end
                        nt[#nt + 1] = l
                        new_tuples[#new_tuples + 1] = nt
                        any_tuple = true
                    end
                end
            end
            if i > min_length and not any_tuple then
                local s = {}
                for _, v in ipairs(tuple) do
                    for _, c in ipairs(ranks[v]) do s[#s + 1] = c end
                end
                ret[#ret + 1] = s
            end
        end
        tuples = new_tuples
    end
    table.sort(ret, function(a, b) return #a > #b end)
    return ret
end

function P.highest(cards)
    local best
    for _, c in ipairs(cards) do
        if not best or C.nominal_key(c) > C.nominal_key(best) then best = c end
    end
    if best then return { { best } } end
    return {}
end

local function merge(...)
    local seen, out = {}, {}
    for _, list in ipairs({ ... }) do
        for _, group in ipairs(list) do
            for _, c in ipairs(group) do
                if not seen[c] then seen[c] = true; out[#out + 1] = c end
            end
        end
    end
    return out
end

-- Full evaluation: returns
--  { name = top hand, scoring = {cards in play order}, contains = {[hand]=true}, parts = {...} }
function P.evaluate(cards, rules)
    rules = rules or {}
    local parts = {
        _highest = P.highest(cards),
        _straight = P.straight(cards, rules),
        _flush = P.flush(cards, rules),
        _2 = P.x_same(2, cards, true),
        _3 = P.x_same(3, cards, true),
        _4 = P.x_same(4, cards, true),
        _5 = P.x_same(5, cards, true),
    }
    local all_pairs = {}
    if next(parts._2) then all_pairs = { merge(parts._2) } end
    parts._all_pairs = all_pairs

    local res = {}
    res['Flush Five'] = (next(parts._5) and next(parts._flush)) and { merge(parts._5, parts._flush) } or {}
    res['Flush House'] = (#parts._3 >= 1 and #parts._2 >= 2 and next(parts._flush)) and { merge(all_pairs, parts._flush) } or {}
    res['Five of a Kind'] = parts._5
    res['Straight Flush'] = (next(parts._straight) and next(parts._flush)) and { merge(parts._straight, parts._flush) } or {}
    res['Four of a Kind'] = parts._4
    res['Full House'] = (#parts._3 >= 1 and #parts._2 >= 2) and all_pairs or {}
    res['Flush'] = parts._flush
    res['Straight'] = parts._straight
    res['Three of a Kind'] = parts._3
    res['Two Pair'] = (#parts._2 >= 2) and all_pairs or {}
    res['Pair'] = parts._2
    res['High Card'] = parts._highest

    local name, scoring_set
    local contains = {}
    for _, hname in ipairs(H.ORDER) do
        if next(res[hname]) then
            contains[hname] = true
            if not name then name = hname; scoring_set = res[hname][1] end
        end
    end
    if not name then return { name = nil, scoring = {}, contains = contains, parts = parts, all = res } end

    -- scoring cards: Splash makes every played card score; Stone cards always score.
    local in_scoring = {}
    for _, c in ipairs(scoring_set) do in_scoring[c] = true end
    local scoring = {}
    for _, c in ipairs(cards) do
        if rules.splash or in_scoring[c] or c.always_scores then scoring[#scoring + 1] = c end
    end
    return { name = name, scoring = scoring, contains = contains, parts = parts, all = res }
end

-- Royal flush display name (cosmetic).
function P.display_name(ev)
    if ev.name == 'Straight Flush' then
        local royal = true
        for _, c in ipairs(ev.scoring) do
            if not (c.id == 14 or c.id == 10 or (c.id >= 11 and c.id <= 13)) then royal = false end
        end
        if royal then return 'Royal Flush' end
    end
    return ev.name
end

return P
