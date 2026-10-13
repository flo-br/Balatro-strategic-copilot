-- Balatro Strategic Copilot - engine/probability.lua  (ProbabilityEngine)
-- Exact combinatorics on the KNOWN remaining deck composition (order is unknown and is
-- never used), plus Monte-Carlo helpers with confidence intervals.

local BSC = BSCopilot
local U = BSC.require('core/util')

local P = {}

local choose = U.choose

-- P(X = k) for X ~ Hypergeometric(N population, K successes, n draws)
function P.hypergeom(N, K, n, k)
    if k < 0 or k > K or k > n or n - k > N - K then return 0 end
    return choose(K, k) * choose(N - K, n - k) / choose(N, n)
end

function P.hypergeom_at_least(N, K, n, k)
    if k <= 0 then return 1 end
    if n > N then n = N end
    local p = 0
    for i = k, math.min(K, n) do p = p + P.hypergeom(N, K, n, i) end
    if p > 1 then p = 1 end
    return p
end

-- Probability that n cards drawn from N contain at least one card of EACH group.
-- groups: array of group sizes (disjoint). Exact, by inclusion-exclusion.
function P.all_groups_hit(N, groups, n)
    if n > N then n = N end
    local m = #groups
    if m == 0 then return 1 end
    for i = 1, m do if groups[i] <= 0 then return 0 end end
    local total = choose(N, n)
    if total == 0 then return 0 end
    local p = 0
    -- iterate over subsets of groups (m is small: <= 5 missing ranks)
    for mask = 0, 2 ^ m - 1 do
        local size, bits, mm = 0, 0, mask
        for i = 1, m do
            if mm % 2 == 1 then size = size + groups[i]; bits = bits + 1 end
            mm = math.floor(mm / 2)
        end
        local term = choose(N - size, n) / total
        if bits % 2 == 1 then p = p - term else p = p + term end
    end
    if p < 0 then p = 0 end
    if p > 1 then p = 1 end
    return p
end

-- Probability that at least r of the (disjoint) groups are hit by n draws from N.
-- Exact: sum over hit-sets T (|T| >= r) of P(all of T hit, none of the others hit),
-- each term by inclusion-exclusion. Groups are few (<= 5), so this is cheap.
function P.groups_hit_at_least(N, groups, n, r)
    local m = #groups
    if r <= 0 then return 1 end
    if r > m then return 0 end
    if n > N then n = N end
    local total = choose(N, n)
    if total == 0 then return 0 end
    local function size_of(mask)
        local s, mm = 0, mask
        for i = 1, m do
            if mm % 2 == 1 then s = s + groups[i] end
            mm = math.floor(mm / 2)
        end
        return s
    end
    local function popcount(mask)
        local c, mm = 0, mask
        while mm > 0 do c = c + mm % 2; mm = math.floor(mm / 2) end
        return c
    end
    local full = 2 ^ m - 1
    local p = 0
    for T = 0, full do
        local t = popcount(T)
        if t >= r then
            local comp = full - T
            local comp_size = size_of(comp)
            -- iterate subsets U of T
            local pt = 0
            local U_ = T
            while true do
                local term = choose(N - comp_size - size_of(U_), n) / total
                if popcount(U_) % 2 == 1 then pt = pt - term else pt = pt + term end
                if U_ == 0 then break end
                -- next subset of T (descending): (U - 1) & T, computed without bit ops
                local nxt = U_ - 1
                local res, bit, a, b = 0, 1, nxt, T
                for _ = 1, m do
                    if a % 2 == 1 and b % 2 == 1 then res = res + bit end
                    a = math.floor(a / 2); b = math.floor(b / 2); bit = bit * 2
                end
                U_ = res
            end
            p = p + pt
        end
    end
    if p < 0 then p = 0 end
    if p > 1 then p = 1 end
    return p
end

-- Probability that n draws contain at least `need` cards from a set of size K,
-- OR (alternatives) - helper for "at least one of several ranks" etc.
function P.any_hit(N, K, n)
    return 1 - P.hypergeom(N, K, n, 0)
end

-- Wilson score interval for a binomial proportion (95% by default).
function P.wilson(successes, n, z)
    z = z or 1.96
    if n <= 0 then return 0, 0, 1 end
    local p = successes / n
    local z2 = z * z
    local denom = 1 + z2 / n
    local centre = (p + z2 / (2 * n)) / denom
    local half = (z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n))) / denom
    return p, math.max(0, centre - half), math.min(1, centre + half)
end

-- Confidence label from an interval half-width and method.
function P.confidence_label(method, half_width)
    if method == 'exact' then return 'high' end
    if method == 'enumeration' then return 'high' end
    if not half_width then return 'low' end
    if half_width <= 0.04 then return 'high' end
    if half_width <= 0.10 then return 'medium' end
    return 'low'
end

return P
