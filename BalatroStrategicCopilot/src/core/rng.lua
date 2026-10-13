-- Balatro Strategic Copilot - core/rng.lua
-- Deterministic PRNG for simulations. It is fully separate from the game's RNG
-- (pseudorandom / math.random / love.math): running an analysis never advances
-- or reads the game's random state, so the run itself is never affected.
-- Park-Miller "minimal standard" generator (multiplier 48271, modulus 2^31-1),
-- exact in double precision.

local R = {}
R.__index = R

local M = 2147483647
local A = 48271

local function hash_seed(seed)
    if type(seed) == 'number' then
        local s = math.floor(math.abs(seed)) % (M - 1)
        return s + 1
    end
    local s = tostring(seed or 'bsc')
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % (M - 1) end
    return h + 1
end

function R.new(seed)
    local self = setmetatable({}, R)
    self.state = hash_seed(seed)
    return self
end

function R:next_int()
    self.state = (self.state * A) % M
    return self.state
end

-- Uniform float in [0, 1).
function R:float()
    return (self:next_int() - 1) / (M - 1)
end

-- Uniform integer in [a, b].
function R:int(a, b)
    return a + math.floor(self:float() * (b - a + 1))
end

function R:chance(p)
    return self:float() < p
end

function R:shuffle(t)
    for i = #t, 2, -1 do
        local j = self:int(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- Draw k items without replacement from array t (t is not modified).
function R:sample(t, k)
    local n = #t
    k = math.min(k, n)
    local idx = {}
    for i = 1, n do idx[i] = i end
    local out = {}
    for i = 1, k do
        local j = self:int(i, n)
        idx[i], idx[j] = idx[j], idx[i]
        out[i] = t[idx[i]]
    end
    return out
end

-- Weighted pick: weights is an array of non-negative numbers; returns index.
function R:weighted(weights)
    local total = 0
    for i = 1, #weights do total = total + weights[i] end
    if total <= 0 then return nil end
    local x = self:float() * total
    for i = 1, #weights do
        x = x - weights[i]
        if x < 0 then return i end
    end
    return #weights
end

return R
