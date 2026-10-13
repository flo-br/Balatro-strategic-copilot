local T = ...
local S = {}

function S.reproducible(T)
    local R = BSCopilot.require('core/rng')
    local a, b = R.new('seed'), R.new('seed')
    for _ = 1, 100 do T.eq(a:float(), b:float()) end
    local c = R.new('other')
    local same = 0
    for _ = 1, 50 do if a:float() == c:float() then same = same + 1 end end
    T.ok(same < 5)
end

function S.uniformity(T)
    local R = BSCopilot.require('core/rng')
    local r = R.new(42)
    local counts = { 0, 0, 0, 0, 0, 0 }
    local n = 60000
    for _ = 1, n do
        local v = r:int(1, 6)
        counts[v] = counts[v] + 1
    end
    for i = 1, 6 do T.near(counts[i] / n, 1 / 6, 0.01, 'face ' .. i) end
    for _ = 1, 1000 do
        local f = r:float()
        T.ok(f >= 0 and f < 1)
    end
end

function S.does_not_touch_math_random(T)
    local R = BSCopilot.require('core/rng')
    math.randomseed(1234)
    local expected = math.random()
    math.randomseed(1234)
    local r = R.new(1)
    for _ = 1, 1000 do r:float() end
    T.eq(math.random(), expected)
end

function S.sample_without_replacement(T)
    local R = BSCopilot.require('core/rng')
    local r = R.new(7)
    local t = { 1, 2, 3, 4, 5, 6, 7, 8 }
    for _ = 1, 100 do
        local s = r:sample(t, 5)
        T.eq(#s, 5)
        local seen = {}
        for _, v in ipairs(s) do T.no(seen[v]); seen[v] = true end
    end
    T.eq(#t, 8)
end

return S
