local T = ...
local S = {}

function S.roundtrip(T)
    local J = BSCopilot.require('core/json')
    local v = { a = 1, b = { 1, 2, 3 }, c = 'héllo "quoted" \n', d = true, e = 1.5, f = -3, g = { x = { y = 'z' } } }
    local s = J.encode(v)
    T.deep_eq(J.decode(s), v)
    T.deep_eq(J.decode(J.encode(v, true)), v)
end

function S.deterministic_key_order(T)
    local J = BSCopilot.require('core/json')
    T.eq(J.encode({ b = 1, a = 2 }), '{"a":2,"b":1}')
end

function S.special_numbers_become_null(T)
    local J = BSCopilot.require('core/json')
    T.eq(J.encode({ 0 / 0, math.huge }), '[null,null]')
    T.eq(J.encode(1e15 + 0.5), '1e+15')
    T.eq(J.encode(123456789012), '123456789012')
end

function S.unicode_escapes(T)
    local J = BSCopilot.require('core/json')
    T.eq(J.decode('"\\u00e9"'), 'é')
    T.eq(J.decode('"\\ud83d\\ude00"'), '\240\159\152\128')
end

function S.rejects_garbage(T)
    local J = BSCopilot.require('core/json')
    T.raises(function() J.decode('{"a":1,}') end)
    T.raises(function() J.decode('{"a":1') end)
    T.raises(function() J.decode('[1,2] x') end)
    T.raises(function() J.decode('nul') end)
    local v, err = J.try_decode('{"a":')
    T.eq(v, nil); T.ok(err:find('json'))
end

function S.never_executes_code(T)
    local J = BSCopilot.require('core/json')
    _G.__bsc_pwned = nil
    T.raises(function() J.decode('return (function() _G.__bsc_pwned = true end)()') end)
    T.eq(_G.__bsc_pwned, nil)
end

function S.empty_object_marker(T)
    local J = BSCopilot.require('core/json')
    T.eq(J.encode({}), '[]')
    T.eq(J.encode(J.object()), '{}')
    T.eq(J.encode(J.decode('{}')), '{}')
end

return S
