-- Balatro Strategic Copilot - game/compat.lua  (CompatibilityManager)
-- * lists the other loaded mods (Steamodded registry);
-- * cross-checks our poker-hand identification against the game's own
--   G.FUNCS.get_poker_hand_info on the cards the PLAYER highlighted (the game calls it itself
--   on every highlight, so calling it again on the same cards adds no new effect);
-- * counts runtime mismatches between "exact" predictions and real scores: after repeated
--   mismatches, exact labels are downgraded for the session (honest degradation);
-- * converts big numbers of the Talisman mod (tables) through its own to_number().

local BSC = BSCopilot
local L = BSC.require('core/log')
local PE = BSC.require('engine/poker_eval')

local CM = { level = 'complete', mods = {}, hand_mismatches = 0, score_mismatches = 0, notes = {} }

local META = { Steamodded = true, Lovely = true, Balatro = true, BalatroStrategicCopilot = true }

function CM.scan()
    CM.mods = {}
    local SMODS = rawget(_G, 'SMODS')
    if type(SMODS) == 'table' and type(SMODS.Mods) == 'table' then
        for id, m in pairs(SMODS.Mods) do
            if type(m) == 'table' and not META[id] and m.can_load ~= false and not m.disabled and not m.meta_mod then
                CM.mods[#CM.mods + 1] = m.name or id
            end
        end
    end
    table.sort(CM.mods)
    CM.talisman = type(SMODS) == 'table' and type(SMODS.Mods) == 'table' and SMODS.Mods.Talisman ~= nil
    CM.update_level()
    if #CM.mods > 0 then L.info('compat', 'other mods: %s', table.concat(CM.mods, ', ')) end
    return CM.mods
end

function CM.update_level()
    if CM.score_mismatches >= 2 or CM.hand_mismatches >= 2 then CM.level = 'degraded'
    elseif #CM.mods > 0 then CM.level = 'partial'
    else CM.level = 'complete' end
end

-- Number conversion tolerant to Talisman big numbers.
function CM.num(x, default)
    if type(x) == 'number' then return x end
    if type(x) == 'table' then
        local f = rawget(_G, 'to_number')
        if type(f) == 'function' then
            local ok, v = pcall(f, x)
            if ok and type(v) == 'number' then return v end
        end
        local ok, v = pcall(function() return tonumber(tostring(x)) end)
        if ok and v then return v end
    end
    local n = tonumber(x)
    if n then return n end
    return default
end

-- Compare our hand name with the native one for the highlighted cards.
-- cards_game: game Card objects (highlighted), cards_norm: our normalized copies (same order)
function CM.cross_check_hand(cards_game, cards_norm, rules)
    local G = rawget(_G, 'G')
    if not (G and G.FUNCS and type(G.FUNCS.get_poker_hand_info) == 'function') then return nil end
    if #cards_game == 0 or #cards_game ~= #cards_norm then return nil end
    local ok, native = pcall(G.FUNCS.get_poker_hand_info, cards_game)
    if not ok or type(native) ~= 'string' then return nil end
    local ours = PE.evaluate(cards_norm, rules).name
    if native ~= ours and native ~= 'NULL' then
        CM.hand_mismatches = CM.hand_mismatches + 1
        CM.notes[#CM.notes + 1] = 'main : ' .. tostring(ours) .. ' ≠ jeu : ' .. tostring(native)
        L.warn('compat', 'hand mismatch: ours=%s game=%s', tostring(ours), tostring(native))
        CM.update_level()
        return false, native, ours
    end
    return true, native, ours
end

function CM.record_score(predicted, actual, exact)
    if exact and predicted and actual and math.abs(predicted - actual) > 0.5 then
        CM.score_mismatches = CM.score_mismatches + 1
        CM.notes[#CM.notes + 1] = string.format('score exact prévu %s, obtenu %s', tostring(predicted), tostring(actual))
        L.warn('compat', 'exact score mismatch: predicted %s actual %s', tostring(predicted), tostring(actual))
        CM.update_level()
    end
end

-- Exact labels allowed? (false after repeated mismatches in this session)
function CM.trust_exact()
    return CM.level ~= 'degraded'
end

return CM
