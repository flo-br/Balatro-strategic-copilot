-- Balatro Strategic Copilot - core/json.lua
-- Safe JSON codec in pure Lua 5.1. Data files are never executed (no loadstring),
-- so a corrupted or malicious data file cannot run code.

local J = {}

local escapes = {
    ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
    ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function escape_str(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        return escapes[c] or string.format('\\u%04x', c:byte())
    end) .. '"'
end

local function is_array(t)
    local n = #t
    local count = 0
    for k in pairs(t) do
        if type(k) ~= 'number' or k < 1 or k > n or k % 1 ~= 0 then return false end
        count = count + 1
    end
    return count == n
end

local function encode_value(v, out, depth, pretty, indent)
    if depth > 64 then error('json: nesting too deep') end
    local t = type(v)
    if v == nil then
        out[#out + 1] = 'null'
    elseif t == 'boolean' then
        out[#out + 1] = v and 'true' or 'false'
    elseif t == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then
            out[#out + 1] = 'null'
        elseif v % 1 == 0 and v > -1e15 and v < 1e15 then
            out[#out + 1] = string.format('%.0f', v)
        else
            out[#out + 1] = string.format('%.14g', v)
        end
    elseif t == 'string' then
        out[#out + 1] = escape_str(v)
    elseif t == 'table' then
        local nl = pretty and ('\n' .. string.rep('  ', indent + 1)) or ''
        local close = pretty and ('\n' .. string.rep('  ', indent)) or ''
        if next(v) == nil then
            out[#out + 1] = (getmetatable(v) and getmetatable(v).__jsontype == 'object') and '{}' or '[]'
        elseif is_array(v) then
            out[#out + 1] = '['
            for i = 1, #v do
                if i > 1 then out[#out + 1] = ',' end
                out[#out + 1] = nl
                encode_value(v[i], out, depth + 1, pretty, indent + 1)
            end
            out[#out + 1] = close .. ']'
        else
            local keys = {}
            for k in pairs(v) do
                local kt = type(k)
                if kt == 'string' or kt == 'number' then keys[#keys + 1] = k end
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            out[#out + 1] = '{'
            local first = true
            for _, k in ipairs(keys) do
                local val = v[k]
                local vt = type(val)
                if vt ~= 'function' and vt ~= 'userdata' and vt ~= 'thread' then
                    if not first then out[#out + 1] = ',' end
                    first = false
                    out[#out + 1] = nl .. escape_str(tostring(k)) .. (pretty and ': ' or ':')
                    encode_value(val, out, depth + 1, pretty, indent + 1)
                end
            end
            out[#out + 1] = close .. '}'
        end
    else
        out[#out + 1] = 'null'
    end
end

function J.encode(v, pretty)
    local out = {}
    encode_value(v, out, 0, pretty, 0)
    return table.concat(out)
end

-- Marks an empty table so it encodes as {} instead of [].
function J.object(t)
    return setmetatable(t or {}, { __jsontype = 'object' })
end

-- Decoder ---------------------------------------------------------------------------------

local function decode_error(str, pos, msg)
    local line, col = 1, 1
    for i = 1, pos - 1 do
        if str:sub(i, i) == '\n' then line, col = line + 1, 1 else col = col + 1 end
    end
    error(string.format('json: %s at line %d col %d', msg, line, col), 0)
end

local function skip_ws(str, pos)
    local _, e = str:find('^[ \n\r\t]*', pos)
    return e + 1
end

local decode_value

local function utf8_char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then
        return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
    end
    if cp < 0x10000 then
        return string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
    end
    return string.char(0xF0 + math.floor(cp / 0x40000), 0x80 + math.floor(cp / 0x1000) % 0x40,
        0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

local function decode_string(str, pos)
    local buf = {}
    local i = pos + 1
    while true do
        local c = str:sub(i, i)
        if c == '' then decode_error(str, i, 'unterminated string') end
        if c == '"' then return table.concat(buf), i + 1 end
        if c == '\\' then
            local n = str:sub(i + 1, i + 1)
            local map = { b = '\b', f = '\f', n = '\n', r = '\r', t = '\t', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
            if map[n] then
                buf[#buf + 1] = map[n]
                i = i + 2
            elseif n == 'u' then
                local hex = str:sub(i + 2, i + 5)
                if not hex:match('^%x%x%x%x$') then decode_error(str, i, 'bad unicode escape') end
                local cp = tonumber(hex, 16)
                i = i + 6
                if cp >= 0xD800 and cp <= 0xDBFF and str:sub(i, i + 1) == '\\u' then
                    local lo = tonumber(str:sub(i + 2, i + 5), 16)
                    if lo and lo >= 0xDC00 and lo <= 0xDFFF then
                        cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
                        i = i + 6
                    end
                end
                buf[#buf + 1] = utf8_char(cp)
            else
                decode_error(str, i, 'bad escape')
            end
        else
            if c:byte() < 32 then decode_error(str, i, 'control character in string') end
            local j = str:find('[%c"\\]', i)
            if not j then decode_error(str, i, 'unterminated string') end
            buf[#buf + 1] = str:sub(i, j - 1)
            i = j
        end
    end
end

local function decode_number(str, pos)
    local s, e = str:find('^-?%d+%.?%d*[eE]?[-+]?%d*', pos)
    if not s then decode_error(str, pos, 'bad number') end
    local n = tonumber(str:sub(s, e))
    if not n then decode_error(str, pos, 'bad number') end
    return n, e + 1
end

function decode_value(str, pos, depth)
    if depth > 128 then decode_error(str, pos, 'nesting too deep') end
    pos = skip_ws(str, pos)
    local c = str:sub(pos, pos)
    if c == '{' then
        local obj = {}
        pos = skip_ws(str, pos + 1)
        if str:sub(pos, pos) == '}' then return J.object(obj), pos + 1 end
        while true do
            pos = skip_ws(str, pos)
            if str:sub(pos, pos) ~= '"' then decode_error(str, pos, 'expected key') end
            local key
            key, pos = decode_string(str, pos)
            pos = skip_ws(str, pos)
            if str:sub(pos, pos) ~= ':' then decode_error(str, pos, 'expected ":"') end
            local val
            val, pos = decode_value(str, pos + 1, depth + 1)
            obj[key] = val
            pos = skip_ws(str, pos)
            local d = str:sub(pos, pos)
            if d == '}' then return obj, pos + 1 end
            if d ~= ',' then decode_error(str, pos, 'expected "," or "}"') end
            pos = pos + 1
        end
    elseif c == '[' then
        local arr = {}
        pos = skip_ws(str, pos + 1)
        if str:sub(pos, pos) == ']' then return arr, pos + 1 end
        local n = 0
        while true do
            local val
            val, pos = decode_value(str, pos, depth + 1)
            n = n + 1
            arr[n] = val
            pos = skip_ws(str, pos)
            local d = str:sub(pos, pos)
            if d == ']' then return arr, pos + 1 end
            if d ~= ',' then decode_error(str, pos, 'expected "," or "]"') end
            pos = pos + 1
        end
    elseif c == '"' then
        return decode_string(str, pos)
    elseif c == '-' or c:match('%d') then
        return decode_number(str, pos)
    elseif str:sub(pos, pos + 3) == 'true' then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == 'false' then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == 'null' then
        return nil, pos + 4
    end
    decode_error(str, pos, 'unexpected character "' .. c .. '"')
end

-- Returns value or raises; use J.try_decode for a non-raising variant.
function J.decode(str)
    if type(str) ~= 'string' then error('json: expected string', 0) end
    local v, pos = decode_value(str, 1, 0)
    pos = skip_ws(str, pos)
    if pos <= #str then decode_error(str, pos, 'trailing data') end
    return v
end

function J.try_decode(str)
    local ok, v = pcall(J.decode, str)
    if ok then return v end
    return nil, v
end

return J
