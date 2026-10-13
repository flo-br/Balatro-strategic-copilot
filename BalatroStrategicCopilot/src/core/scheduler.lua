-- Balatro Strategic Copilot - core/scheduler.lua
-- Cooperative scheduler: long analyses run inside coroutines and yield when their
-- per-frame time budget is spent, so the game keeps a smooth frame rate.
-- A task can be cancelled (e.g. the game state changed and its result became stale).

local S = {}
S.__index = S

local U -- set lazily (util) to keep this file standalone-loadable

function S.new(clock)
    local self = setmetatable({}, S)
    self.tasks = {}          -- ordered list
    self.by_name = {}
    self.clock = clock or function() return (U and U.now()) or os.clock() end
    self.deadline = nil
    self.current = nil
    return self
end

function S.set_util(u) U = u end

-- Submit (or replace) a named task. fn(task) runs in a coroutine; it should call
-- task:check() regularly. on_done(result, err) is called on completion.
function S:submit(name, fn, on_done)
    self:cancel(name)
    local task = { name = name, on_done = on_done, sched = self, cancelled = false, steps = 0 }
    function task.check()
        if task.cancelled then error({ cancelled = true }) end
        if self.deadline and self.clock() >= self.deadline then
            coroutine.yield()
            if task.cancelled then error({ cancelled = true }) end
        end
    end
    task.co = coroutine.create(function() return fn(task) end)
    self.tasks[#self.tasks + 1] = task
    self.by_name[name] = task
    return task
end

function S:cancel(name)
    local t = self.by_name[name]
    if t then
        t.cancelled = true
        self.by_name[name] = nil
        for i = #self.tasks, 1, -1 do
            if self.tasks[i] == t then table.remove(self.tasks, i) end
        end
    end
end

function S:cancel_all()
    for _, t in ipairs(self.tasks) do t.cancelled = true end
    self.tasks = {}
    self.by_name = {}
end

function S:busy()
    return #self.tasks > 0
end

function S:is_running(name)
    return self.by_name[name] ~= nil
end

-- Run tasks for at most budget seconds. Returns number of tasks still pending.
function S:step(budget)
    if #self.tasks == 0 then return 0 end
    local start = self.clock()
    self.deadline = start + (budget or 0.004)
    local i = 1
    while i <= #self.tasks do
        local task = self.tasks[i]
        if self.clock() >= self.deadline then break end
        self.current = task
        local ok, res = coroutine.resume(task.co, task)
        self.current = nil
        task.steps = task.steps + 1
        if coroutine.status(task.co) == 'dead' then
            table.remove(self.tasks, i)
            if self.by_name[task.name] == task then self.by_name[task.name] = nil end
            if task.on_done and not task.cancelled then
                if ok then
                    task.on_done(res, nil)
                elseif not (type(res) == 'table' and res.cancelled) then
                    task.on_done(nil, res)
                end
            end
        else
            i = i + 1
        end
    end
    self.deadline = nil
    return #self.tasks
end

-- Run everything to completion (tests, or when the caller accepts blocking).
function S:run_all(max_iterations)
    local n = 0
    while #self.tasks > 0 do
        self:step(1e9)
        n = n + 1
        if max_iterations and n > max_iterations then break end
    end
end

return S
