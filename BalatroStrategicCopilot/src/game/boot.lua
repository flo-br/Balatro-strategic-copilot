-- Balatro Strategic Copilot - game/boot.lua
-- Wires the modules together at load time.

local BSC = BSCopilot
local U = BSC.require('core/util')
local L = BSC.require('core/log')
local I = BSC.require('core/i18n')

local Boot = {}

local DEFAULTS = {
    enabled = true, lang = 'fr',
    keys = { panel = 'c', detail = 'v', badges = 'b' },
    ui = { anchor = 'right', scale = 1.0, show_badges = true, show_compact = true, panel_open = false, detail = true, use_game_font = true },
    alerts = { enabled = true, danger_threshold = 0.5, great_buy_note = 80, joker_order_gain = 0.10, cooldown = 25, duration = 5 },
    thresholds = { prob_good = 0.80, prob_mid = 0.50, note_good = 70, note_mid = 45 },
    compute = { budget_ms = 4, rollouts = 64, max_branches = 48, samples = 160, poll_interval = 0.15, shop_samples = 120 },
    advice = { buy_note = 56, sell_note = 60, sell_max_contribution = 0.03, order_min_gain = 0.01, luchador_below = 0.80 },
    learning = { enabled = true, max_runs_kept = 300, min_samples_calibration = 30 },
    log = { level = 'info', file = true, max_file_kb = 512 },
}
Boot.DEFAULTS = DEFAULTS

function Boot.start()
    BSC.config = U.merge_defaults(BSC.config or {}, DEFAULTS)
    local cfg = BSC.config
    L.set_level(cfg.log.level)
    I.set_lang(cfg.lang)

    -- persistence & learning (optional: the mod still advises without them)
    local ok_p, err_p = pcall(function()
        local Persist = BSC.require('io/persistence')
        BSC.store = Persist.new(Persist.love_backend())
        BSC.store:init()
        if cfg.log.file then
            local max_bytes = (cfg.log.max_file_kb or 512) * 1024
            L.file_sink = function(line) BSC.store:append_log(line, max_bytes) end
        end
    end)
    if not ok_p then L.warn('boot', 'persistence unavailable: %s', tostring(err_p)) end

    BSC.events_mode = BSC.require('game/event_fallback').detect()
    if BSC.standalone then
        L.info('boot', 'autonomous mode (no Steamodded), LÖVE %s, events: %s',
            love and love.getVersion and table.concat({ love.getVersion() }, '.', 1, 3) or '?', BSC.events_mode)
    else
        L.info('boot', 'Steamodded %s, events: %s', tostring(rawget(_G, 'MODDED_VERSION') or '?'), BSC.events_mode)
    end

    local ok_cm, err_cm = pcall(function() BSC.compat = BSC.require('game/compat'); BSC.compat.scan() end)
    if not ok_cm then L.warn('boot', 'compatibility scan failed: %s', tostring(err_cm)) end

    local Ctl = BSC.require('game/controller')
    local UI = BSC.require('ui/ui_manager')
    Ctl.init()
    BSC.controller = Ctl

    -- optional modules registered on the controller (each one may fail independently)
    for _, name in ipairs({ 'game/register_strategy', 'learning/runtime' }) do
        local ok, err = pcall(function()
            local m = BSC.require(name)
            if m and m.attach then m.attach(Ctl) end
        end)
        if not ok then L.warn('boot', 'module %s unavailable: %s', name, tostring(err)) end
    end

    local Hooks = BSC.require('game/hooks')
    local installed = Hooks.install(Ctl, UI)
    BSC.hooks = installed

    if BSC.mod then -- the configuration tab lives in Steamodded's Mods menu
        local ok_c, err_c = pcall(function() BSC.require('game/config_ui').attach(BSC.mod) end)
        if not ok_c then L.warn('boot', 'config tab unavailable: %s', tostring(err_c)) end
    end

    L.info('boot', 'Balatro Strategic Copilot %s ready (update=%s draw=%s events=%s keys=%s)', BSC.VERSION,
        tostring(installed.update), tostring(installed.draw), tostring(installed.calculate), tostring(installed.keys))
    return true
end

return Boot
