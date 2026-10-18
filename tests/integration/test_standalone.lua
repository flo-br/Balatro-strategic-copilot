-- Autonomous mode (no Lovely, no Steamodded): the bootstrap standalone/main.lua placed in the
-- save folder runs the game's original main.lua, then starts the copilot through love.filesystem.
-- The real LÖVE behaviour (save folder searched first for main.lua) is checked separately by
-- tests/standalone/run_love_standalone.sh on the real LÖVE runtime.
local T = ...
local S = {}

local MOD_DIR = 'Mods/BalatroStrategicCopilot'

-- love.filesystem as seen from the save folder: Mods/BalatroStrategicCopilot -> repository files
local function map_mod_files(FG)
    local fs = love.filesystem
    fs.load = function(p)
        local rel = p:match('^' .. MOD_DIR:gsub('%p', '%%%0') .. '/(.*)$')
        if not rel then return nil, 'not found: ' .. p end
        return loadfile(T.MOD_ROOT .. '/' .. rel)
    end
    local get = fs.getInfo
    fs.getInfo = function(p)
        local rel = p:match('^' .. MOD_DIR:gsub('%p', '%%%0') .. '/(.*)$')
        if rel then
            local f = io.open(T.MOD_ROOT .. '/' .. rel, 'rb')
            if f then f:close(); return { type = 'file' } end
            return nil
        end
        return get(p)
    end
end

local held = {}
local function fake_keyboard()
    love.keyboard = { isDown = function(...)
        for _, k in ipairs({ ... }) do
            if k == 'not_a_key' then error('Invalid key constant: ' .. k) end
            if held[k] then return true end
        end
        return false
    end }
end

local function boot_standalone(opts)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    opts = opts or {}
    opts.mod_root = T.MOD_ROOT
    opts.old_smods = true
    FG.install(opts)
    SMODS = nil
    map_mod_files(FG)
    fake_keyboard()
    held = {}
    BSCopilot = { root_lfs = MOD_DIR, standalone = true }
    assert(love.filesystem.load(MOD_DIR .. '/main.lua'))()
    return FG
end

function S.starts_without_steamodded(T)
    local FG = boot_standalone()
    T.ok(BSCopilot.status.ok, tostring(BSCopilot.status.text))
    T.ok(BSCopilot.status.text:find('mode autonome', 1, true), BSCopilot.status.text)
    T.eq(BSCopilot.events_mode, 'polling')
    T.eq(BSCopilot.config.keys.panel, 'c', 'config.lua read through love.filesystem')
    T.ok(BSCopilot.hooks.update and BSCopilot.hooks.draw, 'game hooks installed')
    T.ok(BSCopilot.hooks.keys, 'keys read from the keyboard')
    T.ok(not BSCopilot.hooks.calculate, 'no Steamodded event hook')
    FG.frames(5)
    Game.draw(G)
    local shown = false
    for _, c in ipairs(FG.calls.draw) do if c:find('mode autonome', 1, true) then shown = true end end
    T.ok(shown, 'banner drawn')
    FG.uninstall()
end

function S.keys_are_polled_safely(T)
    local FG = boot_standalone()
    local Ctl = BSCopilot.controller
    local p0 = Ctl.panel_open
    FG.frames(1) -- first frame: nothing held
    held.c = true; FG.frames(1)
    T.eq(Ctl.panel_open, not p0, 'C toggles the panel')
    FG.frames(3)
    T.eq(Ctl.panel_open, not p0, 'holding C does not repeat')
    held.c = false; FG.frames(1)
    G.CONTROLLER = { text_input_hook = {} }
    held.c = true; FG.frames(1)
    T.eq(Ctl.panel_open, not p0, 'ignored while a text field is focused')
    held.c = false; FG.frames(1)
    G.CONTROLLER = nil
    held.lctrl = true; held.c = true; FG.frames(1)
    T.eq(Ctl.panel_open, not p0, 'ignored with Ctrl held')
    held.lctrl = false; held.c = false; FG.frames(1)
    local d0 = Ctl.detail
    held.v = true; FG.frames(1)
    T.ok(Ctl.detail ~= d0, 'V toggles the details')
    FG.uninstall()
end

function S.key_held_at_start_is_ignored(T)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    FG.install({ mod_root = T.MOD_ROOT, old_smods = true })
    SMODS = nil
    map_mod_files(FG)
    fake_keyboard()
    held = { c = true }
    BSCopilot = { root_lfs = MOD_DIR, standalone = true }
    assert(love.filesystem.load(MOD_DIR .. '/main.lua'))()
    local p0 = BSCopilot.controller.panel_open
    FG.frames(2)
    T.eq(BSCopilot.controller.panel_open, p0, 'no toggle for a key already down at start')
    held.c = false; FG.frames(1); held.c = true; FG.frames(1)
    T.eq(BSCopilot.controller.panel_open, not p0, 'next press works')
    FG.uninstall()
end

-- The bootstrap itself, with a fake love.filesystem reproducing LÖVE's search order.
local ORIGINAL_MAIN = [[
ORIGINAL_RUNS = (ORIGINAL_RUNS or 0) + 1
function love.update(dt) UPDATES = (UPDATES or 0) + 1; Game.update(G, dt) end
function love.draw() Game.draw(G) end
]]

local function run_bootstrap(opts)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    FG.install({ mod_root = T.MOD_ROOT, old_smods = true })
    if not opts.smods then SMODS = nil end
    map_mod_files(FG)
    fake_keyboard()
    ORIGINAL_RUNS, UPDATES, BSCopilot = nil, nil, nil
    local fs = love.filesystem
    local appended = false
    local order = {}
    fs.getIdentity = function() return 'Balatro' end
    fs.setIdentity = function(id, append) appended = append and true or false; order[#order + 1] = tostring(append) end
    fs.getSaveDirectory = function() return 'memory' end
    local bootstrap_src = io.open(T.REPO_ROOT .. '/standalone/main.lua', 'rb'):read('*a')
    local read = fs.read
    fs.read = function(p)
        if p == 'main.lua' then
            if appended and not opts.no_original then return ORIGINAL_MAIN end
            return bootstrap_src -- save folder searched first: our own file
        end
        return read(p)
    end
    love.getVersion = function() return 11, 5, 0, 'Mysterious Mysteries' end
    if opts.no_mod then
        local gi = fs.getInfo
        fs.getInfo = function(p) if p:find(MOD_DIR, 1, true) then return nil end return gi(p) end
    end
    if opts.smods then
        SMODS.Mods.BalatroStrategicCopilot = SMODS.current_mod
        dofile(T.MOD_ROOT .. '/main.lua')
    end
    local ok, err = pcall(assert(loadstring(bootstrap_src, '@main.lua')))
    return FG, ok, err, order
end

local function amorce(FG) return FG.mem['BSC/amorce.log'] or '' end

function S.bootstrap_runs_original_then_copilot(T)
    local FG, ok, err, order = run_bootstrap({})
    T.ok(ok, tostring(err))
    T.eq(ORIGINAL_RUNS, 1, 'original main.lua run exactly once')
    T.eq(table.concat(order, ','), 'true,false', 'save folder put last, then back first')
    T.ok(not BSCopilot, 'copilot not started before the first frame')
    love.update(0.05)
    T.eq(UPDATES, 1, 'the game update still runs')
    T.ok(BSCopilot and BSCopilot.standalone and BSCopilot.status.ok, 'copilot started at the first frame')
    love.update(0.05); love.draw()
    T.eq(UPDATES, 2)
    local log = amorce(FG)
    T.ok(log:find('amorce lue', 1, true) and log:find("main.lua d'origine exécuté", 1, true) and log:find('copilote 1.0', 1, true), log)
    FG.uninstall()
end

function S.bootstrap_leaves_steamodded_alone(T)
    local FG, ok, err = run_bootstrap({ smods = true })
    T.ok(ok, tostring(err))
    local before = BSCopilot
    love.update(0.05)
    T.ok(BSCopilot == before and not BSCopilot.standalone, 'copilot loaded by Steamodded kept, not loaded twice')
    T.ok(amorce(FG):find('Steamodded gère déjà', 1, true), amorce(FG))
    FG.uninstall()
end

function S.bootstrap_missing_mod_keeps_game_running(T)
    local FG, ok, err = run_bootstrap({ no_mod = true })
    T.ok(ok, tostring(err))
    love.update(0.05); love.update(0.05)
    T.eq(UPDATES, 2, 'game continues')
    T.ok(not BSCopilot, 'copilot not started')
    T.ok(amorce(FG):find('dossier introuvable', 1, true), amorce(FG))
    FG.uninstall()
end

function S.bootstrap_without_original_fails_clearly(T)
    local FG, ok, err = run_bootstrap({ no_original = true })
    T.ok(not ok, 'stops instead of looping on itself')
    T.ok(tostring(err):find('Supprimez', 1, true), tostring(err))
    FG.uninstall()
end

return S
