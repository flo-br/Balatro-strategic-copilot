-- Balatro Strategic Copilot - core/log.lua  (DebugManager)
-- Levelled logging with an in-memory ring buffer, an optional bounded file sink and
-- relay to the Steamodded console. Logging must never raise: every sink is protected.

local L = {}

L.LEVELS = { off = 0, error = 1, warn = 2, info = 3, debug = 4, trace = 5 }
local NAMES = { 'ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE' }

L.level = L.LEVELS.info
L.buffer_size = 300
L.buffer = {}
L.counters = { error = 0, warn = 0 }
L.file_sink = nil          -- function(line) set by persistence once available
L.console = true
L.timings = {}             -- name -> {n, total, max}

function L.set_level(name)
    local lv = L.LEVELS[name]
    if lv then L.level = lv end
end

local function console_relay(lv, msg)
    if not L.console then return end
    local f
    if lv == 1 then f = rawget(_G, 'sendErrorMessage')
    elseif lv == 2 then f = rawget(_G, 'sendWarnMessage')
    elseif lv == 3 then f = rawget(_G, 'sendInfoMessage')
    else f = rawget(_G, 'sendDebugMessage') end
    if type(f) == 'function' then pcall(f, msg, 'BSCopilot') end
end

function L.log(lv, category, fmt, ...)
    if lv > L.level or lv <= 0 then return end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    local line = string.format('[%s] %s %s: %s', os.date('%H:%M:%S'), NAMES[lv], category or '-', msg)
    local b = L.buffer
    b[#b + 1] = line
    if #b > L.buffer_size then table.remove(b, 1) end
    if lv == 1 then L.counters.error = L.counters.error + 1 end
    if lv == 2 then L.counters.warn = L.counters.warn + 1 end
    console_relay(lv, category and (category .. ': ' .. msg) or msg)
    if L.file_sink then pcall(L.file_sink, line) end
end

function L.error(cat, fmt, ...) L.log(1, cat, fmt, ...) end
function L.warn(cat, fmt, ...) L.log(2, cat, fmt, ...) end
function L.info(cat, fmt, ...) L.log(3, cat, fmt, ...) end
function L.debug(cat, fmt, ...) L.log(4, cat, fmt, ...) end
function L.trace(cat, fmt, ...) L.log(5, cat, fmt, ...) end

-- Record a duration (seconds) for performance diagnostics.
function L.timing(name, seconds)
    local t = L.timings[name]
    if not t then t = { n = 0, total = 0, max = 0 }; L.timings[name] = t end
    t.n = t.n + 1
    t.total = t.total + seconds
    if seconds > t.max then t.max = seconds end
    t.last = seconds
end

-- Run f(...) protected; logs and returns nil on error. Never lets an error escape to the game.
function L.guard(category, f, ...)
    local ok, a, b, c, d = pcall(f, ...)
    if not ok then
        L.error(category, '%s', tostring(a))
        return nil, a
    end
    return a, b, c, d
end

function L.recent(n)
    local out = {}
    local b = L.buffer
    for i = math.max(1, #b - (n or 20) + 1), #b do out[#out + 1] = b[i] end
    return out
end

return L
