-- Balatro Strategic Copilot - entry point (loaded by Steamodded, see BalatroStrategicCopilot.json)
-- The copilot only observes and advises: it never plays, selects, buys, sells or rerolls.

BSCopilot = BSCopilot or {}
local BSC = BSCopilot
BSC.VERSION = '1.0.0'
BSC.mod = SMODS and SMODS.current_mod or BSC.mod
BSC.modules = BSC.modules or {}

-- Module loader on top of SMODS.load_file (works after the initial load too, thanks to the id).
function BSC.require(name)
    local m = BSC.modules[name]
    if m ~= nil then return m end
    local path = 'src/' .. name .. '.lua'
    local chunk, err
    if SMODS and SMODS.load_file then
        chunk, err = SMODS.load_file(path, BSC.mod and BSC.mod.id or nil)
    elseif BSC.root then
        chunk, err = loadfile(BSC.root .. '/' .. path)
    end
    if not chunk then error('BSCopilot: cannot load ' .. path .. ': ' .. tostring(err)) end
    m = chunk()
    BSC.modules[name] = m
    return m
end

local ok, err = pcall(function()
    BSC.config = (BSC.mod and BSC.mod.config) or {}
    BSC.require('game/boot').start()
end)
if not ok then
    local msg = 'Balatro Strategic Copilot failed to start: ' .. tostring(err)
    if sendErrorMessage then sendErrorMessage(msg, 'BSCopilot') else print(msg) end
end
