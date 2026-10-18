local T = ...
local S = {}

local function fake_clock()
    local t = 0
    return function() return t end, function(dt) t = t + dt end
end

function S.yields_on_budget_and_completes(T)
    local Sched = BSCopilot.require('core/scheduler')
    local clock, advance = fake_clock()
    local s = Sched.new(clock)
    local result
    s:submit('job', function(task)
        local acc = 0
        for i = 1, 10 do
            acc = acc + i
            advance(0.002) -- each unit of work costs 2 ms
            task.check()
        end
        return acc
    end, function(res) result = res end)
    local frames = 0
    while s:busy() and frames < 100 do
        s:step(0.004)
        frames = frames + 1
    end
    T.eq(result, 55)
    T.ok(frames >= 4, 'work must be split across several frames, got ' .. frames)
end

function S.cancel_discards_result(T)
    local Sched = BSCopilot.require('core/scheduler')
    local clock, advance = fake_clock()
    local s = Sched.new(clock)
    local called = false
    s:submit('job', function(task)
        for _ = 1, 100 do advance(0.01); task.check() end
        return 1
    end, function() called = true end)
    s:step(0.004)
    s:cancel('job')
    s:run_all(10)
    T.no(called)
    T.no(s:busy())
end

function S.resubmit_replaces(T)
    local Sched = BSCopilot.require('core/scheduler')
    local s = Sched.new()
    local got = {}
    s:submit('a', function() return 1 end, function(r) got[#got + 1] = r end)
    s:submit('a', function() return 2 end, function(r) got[#got + 1] = r end)
    s:run_all()
    T.eq(#got, 1); T.eq(got[1], 2)
end

function S.errors_reported(T)
    local Sched = BSCopilot.require('core/scheduler')
    local s = Sched.new()
    local err
    s:submit('bad', function() error('boom') end, function(_, e) err = e end)
    s:run_all()
    T.ok(tostring(err):find('boom'))
end

-- protection that still lets the task yield (Lua 5.1 cannot yield across pcall)
function S.protected_yields_catches_and_propagates_cancel(T)
    local Sch = BSCopilot.require('core/scheduler')
    local sched = Sch.new()
    local steps, got = 0, nil
    sched:submit('p', function(task)
        local ok, v = Sch.protected(function()
            for _ = 1, 5 do steps = steps + 1; coroutine.yield() end
            return 42
        end)
        local ok2, err = Sch.protected(function() error('boom') end)
        return { ok = ok, v = v, ok2 = ok2, err = tostring(err) }
    end, function(res) got = res end)
    for _ = 1, 50 do sched:step(0.001) end
    T.ok(got, 'task finished')
    T.eq(got.ok, true); T.eq(got.v, 42); T.eq(steps, 5)
    T.eq(got.ok2, false); T.ok(got.err:find('boom', 1, true))
    -- a cancellation is not turned into an ordinary error
    local okc, errc = pcall(Sch.protected, function() error({ cancelled = true }) end)
    T.eq(okc, false)
    T.ok(type(errc) == 'table' and errc.cancelled, 'cancellation propagated')
end

return S
