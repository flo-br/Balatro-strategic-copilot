-- Balatro Strategic Copilot - core/util.lua
-- Pure helpers shared by every module. No access to game globals.

local U = {}

local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs

U.unpack = unpack or table.unpack

function U.clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

function U.round(x, digits)
    local m = 10 ^ (digits or 0)
    return floor(x * m + 0.5) / m
end

function U.is_finite(x)
    return type(x) == 'number' and x == x and x ~= math.huge and x ~= -math.huge
end

function U.num(x, default)
    if type(x) == 'number' and x == x then return x end
    local n = tonumber(x)
    if n and n == n then return n end
    return default
end

-- Deep copy of plain data. Functions/userdata are dropped, cycles and depth are bounded,
-- so a table coming from the game (which may reference engine objects) can be copied safely.
function U.deepcopy(v, max_depth, seen)
    max_depth = max_depth or 8
    local t = type(v)
    if t ~= 'table' then
        if t == 'function' or t == 'userdata' or t == 'thread' then return nil end
        return v
    end
    if max_depth <= 0 then return nil end
    seen = seen or {}
    if seen[v] then return nil end
    seen[v] = true
    local out = {}
    for k, val in pairs(v) do
        local kt = type(k)
        if kt == 'string' or kt == 'number' or kt == 'boolean' then
            local c = U.deepcopy(val, max_depth - 1, seen)
            if c ~= nil then out[k] = c end
        end
    end
    seen[v] = nil
    return out
end

function U.shallow_copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

function U.merge_defaults(t, defaults)
    t = t or {}
    for k, v in pairs(defaults) do
        if t[k] == nil then
            t[k] = type(v) == 'table' and U.deepcopy(v, 20) or v
        elseif type(v) == 'table' and type(t[k]) == 'table' then
            U.merge_defaults(t[k], v)
        end
    end
    return t
end

function U.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function U.sorted_keys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta == tb and (ta == 'number' or ta == 'string') then return a < b end
        return ta < tb
    end)
    return keys
end

function U.map(t, f)
    local out = {}
    for i = 1, #t do out[i] = f(t[i], i) end
    return out
end

function U.filter(t, f)
    local out = {}
    for i = 1, #t do if f(t[i], i) then out[#out + 1] = t[i] end end
    return out
end

function U.sum(t, f)
    local s = 0
    for i = 1, #t do s = s + (f and f(t[i]) or t[i]) end
    return s
end

function U.mean(t)
    if #t == 0 then return nil end
    return U.sum(t) / #t
end

function U.contains(t, v)
    for i = 1, #t do if t[i] == v then return true end end
    return false
end

function U.index_of(t, v)
    for i = 1, #t do if t[i] == v then return i end end
    return nil
end

-- Stable sort (table.sort is not stable): ties keep original order, so results are
-- deterministic across runs and platforms.
function U.stable_sort(t, less)
    local idx = {}
    for i = 1, #t do idx[i] = { v = t[i], i = i } end
    table.sort(idx, function(a, b)
        if less(a.v, b.v) then return true end
        if less(b.v, a.v) then return false end
        return a.i < b.i
    end)
    for i = 1, #idx do t[i] = idx[i].v end
    return t
end

-- All subsets of {1..n} with size between kmin and kmax, as index arrays.
function U.subsets(n, kmin, kmax)
    local out = {}
    local cur = {}
    local function rec(start, k)
        if #cur >= kmin then
            local s = {}
            for i = 1, #cur do s[i] = cur[i] end
            out[#out + 1] = s
        end
        if #cur == kmax then return end
        for i = start, n do
            cur[#cur + 1] = i
            rec(i + 1, k + 1)
            cur[#cur] = nil
        end
    end
    rec(1, 0)
    return out
end

-- Binomial coefficient as a float (exact for the ranges used here: n <= 100).
local binom_cache = {}
function U.choose(n, k)
    if k < 0 or k > n then return 0 end
    if k > n - k then k = n - k end
    local key = n * 1024 + k
    local c = binom_cache[key]
    if c then return c end
    local r = 1
    for i = 1, k do r = r * (n - k + i) / i end
    r = floor(r + 0.5)
    binom_cache[key] = r
    return r
end

function U.now()
    if love and love.timer and love.timer.getTime then return love.timer.getTime() end
    return os.clock()
end

-- Compact, deterministic string signature of plain data (used to detect state changes).
function U.signature(v, depth)
    depth = depth or 6
    local t = type(v)
    if t == 'table' then
        if depth <= 0 then return '{}' end
        local parts = {}
        for _, k in ipairs(U.sorted_keys(v)) do
            parts[#parts + 1] = tostring(k) .. '=' .. U.signature(v[k], depth - 1)
        end
        return '{' .. table.concat(parts, ',') .. '}'
    elseif t == 'number' then
        return string.format('%.6g', v)
    else
        return tostring(v)
    end
end

-- 32-bit FNV-1a hash of a string, computed with float arithmetic (Lua 5.1 has no bit ops).
function U.hash32(s)
    local h = 2166136261
    for i = 1, #s do
        local b = s:byte(i)
        -- h = h XOR b
        local hb = h % 256
        local x = 0
        local p = 1
        local a, c = hb, b
        for _ = 1, 8 do
            local ra, rc = a % 2, c % 2
            if ra ~= rc then x = x + p end
            a, c = (a - ra) / 2, (c - rc) / 2
            p = p * 2
        end
        h = h - hb + x
        -- h = h * 16777619 mod 2^32, split to stay exact in doubles
        local hi, lo = floor(h / 65536), h % 65536
        h = ((hi * 16777619 % 65536) * 65536 + lo * 16777619) % 4294967296
    end
    return h
end

function U.trim(s)
    return (tostring(s):gsub('^%s+', ''):gsub('%s+$', ''))
end

function U.fmt_int(n)
    if not U.is_finite(n) then return tostring(n) end
    local s = tostring(floor(n + 0.5))
    local neg = s:sub(1, 1) == '-'
    if neg then s = s:sub(2) end
    local out = s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
    return (neg and '-' or '') .. out
end

-- Compact number: 1234 -> "1 234", 1.5e6 -> "1,5 M", 2e9 -> "2 Md", huge -> "1.2e15".
function U.fmt_num(n)
    if not U.is_finite(n) then return tostring(n) end
    local a = abs(n)
    if a < 100000 then return U.fmt_int(n) end
    if a < 1e9 then return (string.format('%.1f M', n / 1e6):gsub('%.', ',')) end
    if a < 1e12 then return (string.format('%.1f Md', n / 1e9):gsub('%.', ',')) end
    return string.format('%.2e', n)
end

U.floor, U.ceil, U.max, U.min, U.abs = floor, ceil, max, min, abs

return U
