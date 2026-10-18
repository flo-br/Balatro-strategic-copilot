-- Balatro Strategic Copilot - game/hooks.lua
-- Installs the (few) attachment points, all verified in Steamodded sources:
--   * Game.update / Game.draw wrapped (same technique Steamodded uses, src/ui.lua);
--     the original function always runs first and our code is protected by pcall.
--   * mod.calculate(self, context): observation of game events; ALWAYS returns nil
--     (verified: SMODS.eval_individual ignores non-table results).
--   * SMODS.Keybind for the panel keys; without Steamodded (autonomous mode), the same keys are
--     read with love.keyboard.isDown on each frame (edge detection), never while the game has a
--     text field focused (G.CONTROLLER.text_input_hook, vanilla).
-- No Lovely patch, no change to the game's files or objects.

local BSC = BSCopilot
local L = BSC.require('core/log')

local Hooks = { installed = {}, polled = nil }

-- Autonomous mode: panel keys polled once per frame (a press is the up -> down transition).
function Hooks.poll_keys()
    local P = Hooks.polled
    if not P then return end
    local kb = love and love.keyboard
    if not (kb and kb.isDown) then return end
    local G = rawget(_G, 'G')
    local typing = G and G.CONTROLLER and G.CONTROLLER.text_input_hook
    local modifier = kb.isDown('lctrl', 'rctrl', 'lalt', 'ralt', 'lgui', 'rgui')
    for _, b in ipairs(P) do
        local down = kb.isDown(b.key)
        if down and not b.down and not typing and not modifier then
            local ok, err = pcall(b.action)
            if not ok then L.error('keybind', '%s', tostring(err)) end
        end
        b.down = down
    end
end

function Hooks.install(Ctl, UI)
    local Game = rawget(_G, 'Game')
    if type(Game) == 'table' and type(Game.update) == 'function' and not Hooks.installed.update then
        local update_ref = Game.update
        Game.update = function(self, dt)
            update_ref(self, dt)
            local ok, err = pcall(Ctl.update, dt)
            if not ok then L.error('update', '%s', tostring(err)) end
            if Hooks.polled then pcall(Hooks.poll_keys) end
        end
        Hooks.installed.update = true
    else
        L.warn('hooks', 'Game.update not found: analyses will not run')
    end

    if type(Game) == 'table' and type(Game.draw) == 'function' and not Hooks.installed.draw then
        local draw_ref = Game.draw
        Game.draw = function(self, ...)
            draw_ref(self, ...)
            local ok, err = pcall(function() UI.draw(Ctl.ui_model()) end)
            if not ok then
                Hooks.draw_errors = (Hooks.draw_errors or 0) + 1
                if Hooks.draw_errors <= 5 then L.error('draw', '%s', tostring(err)) end
            end
        end
        Hooks.installed.draw = true
    else
        L.warn('hooks', 'Game.draw not found: overlay disabled')
    end

    local mod = BSC.mod
    if type(mod) == 'table' then
        mod.calculate = function(self, context)
            local ok, err = pcall(Ctl.observe, context)
            if not ok then L.debug('observe', '%s', tostring(err)) end
            return nil
        end
        Hooks.installed.calculate = true
    end

    local SMODS = rawget(_G, 'SMODS')
    if type(SMODS) == 'table' and type(SMODS.Keybind) == 'table' then
        local keys = (BSC.config and BSC.config.keys) or {}
        local function bind(key, action)
            if type(key) ~= 'string' or key == '' then return end
            local ok, err = pcall(SMODS.Keybind, { key_pressed = key, event = 'pressed', action = function()
                local ok2, e2 = pcall(action)
                if not ok2 then L.error('keybind', '%s', tostring(e2)) end
            end })
            if not ok then L.warn('hooks', 'keybind %s failed: %s', key, tostring(err)) end
        end
        bind(keys.panel or 'c', Ctl.toggle_panel)
        bind(keys.detail or 'v', Ctl.toggle_detail)
        bind(keys.badges or 'b', Ctl.toggle_badges)
        Hooks.installed.keys = true
    elseif love and love.keyboard and love.keyboard.isDown then
        local keys = (BSC.config and BSC.config.keys) or {}
        local P = {}
        local function bind(key, action)
            if type(key) ~= 'string' or key == '' then return end
            local okk = pcall(love.keyboard.isDown, key)
            if okk then P[#P + 1] = { key = key, action = action, down = true } end -- down: ignore a key held at start
        end
        bind(keys.panel or 'c', Ctl.toggle_panel)
        bind(keys.detail or 'v', Ctl.toggle_detail)
        bind(keys.badges or 'b', Ctl.toggle_badges)
        Hooks.polled = P
        Hooks.installed.keys = #P > 0
        L.info('hooks', 'no SMODS.Keybind: %d keys read directly from the keyboard', #P)
    else
        L.warn('hooks', 'SMODS.Keybind unavailable: keys disabled')
    end
    return Hooks.installed
end

return Hooks
