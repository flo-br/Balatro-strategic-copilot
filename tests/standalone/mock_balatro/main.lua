-- SIMULATED Balatro main.lua (not the real game), packed into a fused executable like
-- Balatro.exe. It has the shape that matters for the autonomous mode: it defines love.load,
-- love.update and love.draw, and the Game class / G state (from tests/integration/fake_game.lua).
-- Test logic (key presses, screenshots, results) is driven by BSC_SCENARIO.
MOCK = MOCK or { main_runs = 0 }
MOCK.main_runs = MOCK.main_runs + 1
MOCK.frames = 0
local REPO = os.getenv('BSC_REPO')
local SCEN = os.getenv('BSC_SCENARIO') or 'autonome'
local FG = dofile(REPO .. '/tests/integration/fake_game.lua')
local result = {}
local function res(k, v) result[#result + 1] = k .. '=' .. tostring(v) end

function love.load()
    local real_love = love
    FG.install({ mod_root = REPO .. '/BalatroStrategicCopilot', real_love = true, required = 300, dollars = 14 })
    love = real_love
    for i, c in ipairs(G.hand.cards) do c.T = { x = 3 + i * 1.6, y = 7, w = 1.4, h = 1.9 }; c.VT = c.T end
    G.TILESIZE = 20; G.TILESCALE = 2.0; G.ROOM = { T = { x = 1, y = 0.5, w = 30, h = 17 } }
    G.LANG.font.file = nil
    G.STATE = G.STATES.SPLASH
    if SCEN == 'smods' then
        -- Steamodded has already loaded the copilot (Lovely installed): the bootstrap must stay out
        SMODS.Mods.BalatroStrategicCopilot = SMODS.current_mod
        BSCopilot = nil
        dofile(REPO .. '/BalatroStrategicCopilot/main.lua')
    else
        SMODS = nil -- no Lovely, no Steamodded
    end
end

-- keyboard: simulated presses on top of the real love.keyboard
local real_isDown = love.keyboard.isDown
local held = {}
love.keyboard.isDown = function(...)
    for _, k in ipairs({ ... }) do if held[k] then return true end end
    return real_isDown(...)
end

function love.update(dt)
    MOCK.frames = MOCK.frames + 1
    local f = MOCK.frames
    if f == 25 then G.STATE = G.STATES.SELECTING_HAND end
    Game.update(G, dt)
    local B = rawget(_G, 'BSCopilot')
    local Ctl = B and B.controller
    if f == 30 then love.graphics.captureScreenshot('shot_banner.png') end
    if Ctl then
        if f == 40 then res('panel_before', Ctl.panel_open); held.c = true end
        if f == 43 then held.c = false end
        if f == 50 then res('panel_after_key_c', Ctl.panel_open); G.CONTROLLER = { text_input_hook = {} }; held.c = true end
        if f == 53 then held.c = false end
        if f == 60 then res('panel_after_c_while_typing', Ctl.panel_open); G.CONTROLLER = nil end
        if not MOCK.done and Ctl.results.hand and not Ctl.partial.hand then MOCK.done = f; res('analysis_done_frame', f) end
    end
    if (MOCK.done and f == MOCK.done + 20) or f >= 900 then
        love.graphics.captureScreenshot('shot_final.png')
    end
    if (MOCK.done and f == MOCK.done + 25) or f >= 905 then
        res('frames', f); res('main_runs', MOCK.main_runs)
        res('bscopilot', B ~= nil); res('standalone', B and B.standalone)
        res('status', B and B.status and B.status.text)
        res('hooks', B and B.hooks and (tostring(B.hooks.update) .. '/' .. tostring(B.hooks.draw) .. '/' .. tostring(B.hooks.keys)))
        love.filesystem.write('mock_result.txt', table.concat(result, '\n') .. '\n')
        love.event.quit()
    end
end

function love.draw()
    love.graphics.clear(0.13, 0.33, 0.25)
    love.graphics.setColor(0.95, 0.95, 0.9)
    for _, c in ipairs(G.hand.cards) do
        love.graphics.rectangle('fill', (c.T.x + 1) * 40, (c.T.y + 0.5) * 40, 56, 76, 4, 4)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Balatro (simulation) - frame ' .. MOCK.frames, 10, 690)
    Game.draw(G)
end
