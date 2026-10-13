-- Minimal test library + mod bootstrap for running modules outside the game.

local T = { passed = 0, failed = 0, failures = {}, current = nil, timings = {} }

-- Fresh mod namespace that loads modules from disk (mirrors main.lua's loader).
function T.bootstrap(extra)
    BSCopilot = { modules = {}, VERSION = 'test', root = T.MOD_ROOT }
    local B = BSCopilot
    function B.require(name)
        local m = B.modules[name]
        if m ~= nil then return m end
        local path = T.MOD_ROOT .. '/src/' .. name .. '.lua'
        local chunk, err = loadfile(path)
        if not chunk then error('cannot load ' .. path .. ': ' .. tostring(err)) end
        m = chunk()
        B.modules[name] = m
        return m
    end
    if extra then for k, v in pairs(extra) do B[k] = v end end
    return B
end

local function fmt(v)
    if type(v) == 'string' then return string.format('%q', v) end
    if type(v) == 'table' then
        local ok, J = pcall(function() return BSCopilot.require('core/json') end)
        if ok and J then
            local ok2, s = pcall(J.encode, v)
            if ok2 then return s end
        end
    end
    return tostring(v)
end

local function fail(msg, level)
    error({ test_failure = true, msg = msg }, (level or 1) + 1)
end

function T.eq(a, b, msg)
    if a ~= b then fail((msg and (msg .. ': ') or '') .. 'expected ' .. fmt(b) .. ', got ' .. fmt(a), 2) end
end

function T.near(a, b, tol, msg)
    tol = tol or 1e-9
    if type(a) ~= 'number' or type(b) ~= 'number' or math.abs(a - b) > tol then
        fail((msg and (msg .. ': ') or '') .. 'expected ' .. fmt(b) .. ' ± ' .. tol .. ', got ' .. fmt(a), 2)
    end
end

function T.ok(v, msg)
    if not v then fail(msg or 'expected truthy value', 2) end
end

function T.no(v, msg)
    if v then fail(msg or ('expected falsy value, got ' .. fmt(v)), 2) end
end

function T.raises(f, msg)
    local ok = pcall(f)
    if ok then fail(msg or 'expected an error', 2) end
end

function T.deep_eq(a, b, msg, path)
    path = path or ''
    if type(a) ~= type(b) then fail((msg or '') .. ' type mismatch at ' .. path .. ': ' .. fmt(a) .. ' vs ' .. fmt(b), 2) end
    if type(a) ~= 'table' then
        if a ~= b then fail((msg or '') .. ' at ' .. path .. ': ' .. fmt(a) .. ' vs ' .. fmt(b), 2) end
        return
    end
    for k, v in pairs(a) do T.deep_eq(v, b[k], msg, path .. '.' .. tostring(k)) end
    for k, v in pairs(b) do if a[k] == nil then fail((msg or '') .. ' missing key ' .. path .. '.' .. tostring(k), 2) end end
end

function T.run_file(path, name)
    local chunk, err = loadfile(path)
    if not chunk then
        T.failed = T.failed + 1
        T.failures[#T.failures + 1] = name .. ': load error: ' .. tostring(err)
        return
    end
    local ok, suite = pcall(chunk, T)
    if not ok then
        T.failed = T.failed + 1
        T.failures[#T.failures + 1] = name .. ': suite error: ' .. tostring(suite)
        return
    end
    local names = {}
    for k in pairs(suite) do names[#names + 1] = k end
    table.sort(names)
    local file_start = os.clock()
    for _, tname in ipairs(names) do
        T.bootstrap()
        local t0 = os.clock()
        local ok2, e = pcall(suite[tname], T)
        local dt = os.clock() - t0
        if ok2 then
            T.passed = T.passed + 1
        else
            T.failed = T.failed + 1
            local msg = type(e) == 'table' and e.msg or tostring(e)
            T.failures[#T.failures + 1] = name .. ' :: ' .. tname .. ' -> ' .. msg
        end
        T.timings[#T.timings + 1] = { name = name .. ' :: ' .. tname, dt = dt }
    end
    io.write(string.format('  %-34s %3d tests  %.3fs\n', name, #names, os.clock() - file_start))
end

function T.report(total)
    io.write(string.format('\n%d passed, %d failed (%.2fs, %s)\n', T.passed, T.failed, total,
        (jit and jit.version) or _VERSION))
    for _, f in ipairs(T.failures) do io.write('  FAIL ' .. f .. '\n') end
    return T.failed == 0
end

return T
