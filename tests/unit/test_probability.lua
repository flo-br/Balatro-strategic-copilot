local T = ...
local S = {}

local function brute(deck_labels, n, predicate)
    -- enumerate every n-subset of the deck (exact reference)
    local U = BSCopilot.require('core/util')
    local subs = U.subsets(#deck_labels, n, n)
    local hit = 0
    for _, idx in ipairs(subs) do
        local drawn = {}
        for i, k in ipairs(idx) do drawn[i] = deck_labels[k] end
        if predicate(drawn) then hit = hit + 1 end
    end
    return hit / #subs
end

function S.hypergeometric_known_values(T)
    local P = BSCopilot.require('engine/probability')
    local U = BSCopilot.require('core/util')
    -- at least one ace in 5 cards from 52
    T.near(P.hypergeom_at_least(52, 4, 5, 1), 1 - U.choose(48, 5) / U.choose(52, 5), 1e-12)
    local s = 0
    for k = 0, 5 do s = s + P.hypergeom(52, 13, 5, k) end
    T.near(s, 1, 1e-12)
    T.eq(P.hypergeom_at_least(10, 3, 2, 3), 0)
    T.eq(P.hypergeom_at_least(10, 3, 2, 0), 1)
end

function S.flush_completion_matches_bruteforce(T)
    local P = BSCopilot.require('engine/probability')
    -- deck of 14 cards: 4 hearts, 10 others ; draw 3, need >= 1 heart
    local deck = {}
    for i = 1, 4 do deck[#deck + 1] = 'H' end
    for i = 1, 10 do deck[#deck + 1] = 'X' end
    local ref = brute(deck, 3, function(d) for _, v in ipairs(d) do if v == 'H' then return true end end end)
    T.near(P.hypergeom_at_least(14, 4, 3, 1), ref, 1e-12)
    local ref2 = brute(deck, 4, function(d) local c = 0 for _, v in ipairs(d) do if v == 'H' then c = c + 1 end end return c >= 2 end)
    T.near(P.hypergeom_at_least(14, 4, 4, 2), ref2, 1e-12)
end

function S.straight_groups_match_bruteforce(T)
    local P = BSCopilot.require('engine/probability')
    -- groups: rank A x3, rank B x2, rank C x1 ; 6 other cards ; total 12 ; draw 4
    local deck = { 'A', 'A', 'A', 'B', 'B', 'C', 'X', 'X', 'X', 'X', 'X', 'X' }
    local function has(d, v) for _, x in ipairs(d) do if x == v then return true end end return false end
    local ref_all = brute(deck, 4, function(d) return has(d, 'A') and has(d, 'B') and has(d, 'C') end)
    T.near(P.all_groups_hit(12, { 3, 2, 1 }, 4), ref_all, 1e-12)
    local ref2 = brute(deck, 4, function(d)
        local c = 0
        for _, v in ipairs({ 'A', 'B', 'C' }) do if has(d, v) then c = c + 1 end end
        return c >= 2
    end)
    T.near(P.groups_hit_at_least(12, { 3, 2, 1 }, 4, 2), ref2, 1e-12)
    T.near(P.groups_hit_at_least(12, { 3, 2, 1 }, 4, 3), ref_all, 1e-12)
    T.near(P.groups_hit_at_least(12, { 3, 2, 1 }, 4, 1), brute(deck, 4, function(d) return has(d, 'A') or has(d, 'B') or has(d, 'C') end), 1e-12)
    T.eq(P.all_groups_hit(12, { 3, 0 }, 4), 0)
end

function S.wilson_interval(T)
    local P = BSCopilot.require('engine/probability')
    local p, lo, hi = P.wilson(50, 100)
    T.near(p, 0.5, 1e-12); T.near(lo, 0.4038, 1e-3); T.near(hi, 0.5962, 1e-3)
    local _, lo0, hi0 = P.wilson(0, 20)
    T.eq(lo0, 0); T.ok(hi0 > 0.1 and hi0 < 0.2)
end

return S
