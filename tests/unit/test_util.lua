local T = ...
local S = {}

function S.choose_values(T)
    local U = BSCopilot.require('core/util')
    T.eq(U.choose(5, 2), 10)
    T.eq(U.choose(52, 5), 2598960)
    T.eq(U.choose(10, 0), 1)
    T.eq(U.choose(3, 4), 0)
end

function S.subsets_count(T)
    local U = BSCopilot.require('core/util')
    -- sum_{k=1..5} C(8,k) = 8+28+56+70+56 = 218
    T.eq(#U.subsets(8, 1, 5), 218)
    T.eq(#U.subsets(4, 0, 4), 16)
end

function S.deepcopy_drops_functions_and_cycles(T)
    local U = BSCopilot.require('core/util')
    local a = { x = 1, f = function() end, t = { y = 2 } }
    a.self = a
    local c = U.deepcopy(a)
    T.eq(c.x, 1); T.eq(c.t.y, 2); T.eq(c.f, nil); T.eq(c.self, nil)
end

function S.stable_sort_keeps_ties(T)
    local U = BSCopilot.require('core/util')
    local t = { { k = 1, n = 'a' }, { k = 0, n = 'b' }, { k = 1, n = 'c' }, { k = 0, n = 'd' } }
    U.stable_sort(t, function(x, y) return x.k < y.k end)
    T.eq(t[1].n, 'b'); T.eq(t[2].n, 'd'); T.eq(t[3].n, 'a'); T.eq(t[4].n, 'c')
end

function S.hash_is_fnv1a(T)
    local U = BSCopilot.require('core/util')
    -- reference FNV-1a 32-bit values
    T.eq(U.hash32(''), 2166136261)
    T.eq(U.hash32('a'), 0xe40c292c)
    T.eq(U.hash32('foobar'), 0xbf9cf968)
end

function S.formatting(T)
    local U = BSCopilot.require('core/util')
    T.eq(U.fmt_int(1234567), '1 234 567')
    T.eq(U.fmt_int(-950), '-950')
    T.eq(U.fmt_num(2500000), '2,5 M')
end

function S.merge_defaults_nested(T)
    local U = BSCopilot.require('core/util')
    local t = U.merge_defaults({ a = 1, sub = { x = 5 } }, { a = 2, b = 3, sub = { x = 1, y = 2 } })
    T.eq(t.a, 1); T.eq(t.b, 3); T.eq(t.sub.x, 5); T.eq(t.sub.y, 2)
end

return S
