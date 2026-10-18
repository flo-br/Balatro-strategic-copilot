-- Balatro Strategic Copilot - tools/smods_loader_check.lua
-- Runs the REAL mod loader of Steamodded on a Mods folder, with the game itself replaced by
-- tests/integration/fake_game.lua. It answers "does Steamodded find, enable and start the copilot
-- with this folder?" without the game. Both loader generations are supported:
--   * old   : src/loader.lua            (e.g. 1.0.0~BETA-0509c, May 2025: no zip, no blacklist)
--   * recent: src/preflight/loader.lua  (e.g. 26.x: zips, Mods/lovely/blacklist.txt = disabled mods)
-- Steamodded is not shipped with this project (GPL-3.0): pass the path of a source checkout.
--
-- usage (from the repository root, Linux/macOS shell):
--   luajit tools/smods_loader_check.lua <steamodded_source_dir> <Mods_dir>
-- The Mods folder is only read. Exit code 0 when the copilot was loaded and drew its banner.

local SMODS_SRC, MODS = arg[1], arg[2]
if not SMODS_SRC or not MODS then
    print('usage: luajit tools/smods_loader_check.lua <steamodded_source_dir> <Mods_dir>')
    os.exit(2)
end
local REPO = (arg[0]:match('^(.*)[/\\]tools[/\\][^/\\]+$') or '.')

local function readf(p)
    local f = io.open(p, 'rb'); if not f then return nil, 'not found: ' .. p end
    local s = f:read('*a'); f:close(); return s
end
local recent_src = readf(SMODS_SRC .. '/src/preflight/loader.lua')
local old_src = readf(SMODS_SRC .. '/src/loader.lua')
local recent = recent_src ~= nil and recent_src:find('function loadMods', 1, true) ~= nil
if not recent and not (old_src and old_src:find('function loadMods', 1, true)) then
    print('no Steamodded loader (src/preflight/loader.lua or src/loader.lua) in ' .. SMODS_SRC)
    os.exit(2)
end

local FG = dofile(REPO .. '/tests/integration/fake_game.lua')
-- recent Steamodded dispatches game events to mods; the old one does not
FG.install({ old_smods = not recent, mod_root = REPO .. '/BalatroStrategicCopilot' })
local keybind = SMODS.Keybind -- fake from fake_game.lua (the real one needs the whole game)

local function sh(cmd) local p = io.popen(cmd); local o = p:read('*a'); p:close(); return o end
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
-- read-only stand-in for nativefs, the file API Steamodded uses
local nfs = {
    getDirectoryItems = function(d)
        local out = {}
        for l in sh('ls -A ' .. q(d) .. ' 2>/dev/null'):gmatch('[^\n]+') do out[#out + 1] = l end
        return out
    end,
    getInfo = function(p)
        local t = sh('if [ -d ' .. q(p) .. ' ]; then echo directory; elif [ -f ' .. q(p) .. ' ]; then echo file; fi'):gsub('%s', '')
        if t == '' then return nil end
        return { type = t }
    end,
    read = readf,
    lines = function(p) return io.lines(p) end,
    getNormalizedPath = function(p) return (p:gsub('//+', '/')) end,
    mount = function() return false end, -- zip mounting needs LÖVE: zips are reported as not loadable
    -- the Mods folder stays untouched: writes (e.g. a recent Steamodded disabling a duplicate
    -- copy through Mods/lovely/blacklist.txt) are only reported
    write = function(p, d) print(('Steamodded would write %s: %s'):format(p, tostring(d):gsub('\n', ' '))); return true end,
    append = function(p, d) print(('Steamodded would append to %s: %s'):format(p, tostring(d):gsub('\n', ' '))); return true end,
}
NFS = nfs

JSON = dofile(SMODS_SRC .. '/libs/json/json.lua')
inspect = function(t)
    local o = {}
    for k, v in pairs(t or {}) do o[#o + 1] = tostring(k) .. '=' .. tostring(v) end
    return '{' .. table.concat(o, ',') .. '}'
end
HEX = function(hex)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, 1 }
end
package.preload.lovely = function() return { version = '0.0.0-check', mod_dir = MODS } end
package.preload['SMODS.preflight.sharedUtil'] = function() return dofile(SMODS_SRC .. '/src/preflight/sharedUtil.lua') end
G.VERSION = G.VERSION or '1.0.1o-FULL'
function boot_print_stage() end
if not recent then
    -- V (version objects) lives in utils.lua in the old layout
    local u = assert(readf(SMODS_SRC .. '/src/utils.lua'))
    local a = assert(u:find('V_MT = {', 1, true), 'V_MT not found in utils.lua')
    local b = u:find('\nend', assert(u:find('function V.is_valid', a, true), 'V.is_valid not found'), true)
    assert(load(u:sub(a, b + 4), '=smods_utils_V'))()
end

-- Steamodded's own folder in Mods (skipped by the loader), whatever its name
local smods_dir = 'smods-main'
for _, name in ipairs(nfs.getDirectoryItems(MODS)) do
    local d = MODS .. '/' .. name
    if nfs.getInfo(d .. '/version.lua') and nfs.getInfo(d .. '/src/core.lua') and nfs.getInfo(d .. '/lovely') then smods_dir = name end
end
local version = (readf(SMODS_SRC .. '/version.lua') or ''):match('"(.-)"') or '?'
SMODS = { id = 'Steamodded', version = version, can_load = true, meta_mod = true, path = MODS .. '/' .. smods_dir .. '/',
    MODS_DIR = MODS, NFS = nfs, compat_0_9_8 = {}, Keybind = keybind, get_optional_features = function() end }
if recent then SMODS.get_mods_scoring_targets = function() return {} end end

local load_mods
if recent then
    assert(load(recent_src, '=smods_preflight_loader'))()
    -- the loading step is a local function of the loader: same source, with its upvalue
    local a = recent_src:find('local function load_mods()', 1, true)
    local b = recent_src:find('function SMODS.injectItems()', a, true)
    load_mods = assert(load('local NFS = SMODS.NFS\n' .. recent_src:sub(a, b - 1) .. '\nreturn load_mods', '=smods_load_mods'))()
else
    assert(load(old_src, '=smods_loader'))()
end
function boot_print_stage() end
do
    local ui = assert(readf(SMODS_SRC .. '/src/ui.lua'))
    local a = assert(ui:find('function SMODS.load_mod_config', 1, true), 'load_mod_config not found in ui.lua')
    local b = ui:find('\nend\n', assert(ui:find('function SMODS.save_mod_config', a, true)), true)
    assert(load('local NFS = SMODS.NFS\n' .. ui:sub(a, b + 4), '=smods_ui_config'))()
end
SMODS.get_optional_features = function() end
print(('Steamodded %s (%s), Mods = %s'):format(version, recent and 'src/preflight/loader.lua' or 'src/loader.lua', MODS))

local ok, err = pcall(loadMods, MODS)
if ok and load_mods then ok, err = pcall(load_mods) end
local mod = SMODS.Mods and SMODS.Mods.BalatroStrategicCopilot
local drew = nil
if ok and rawget(_G, 'BSCopilot') then
    pcall(Game.draw, G)
    for _, d in ipairs(FG.calls.draw) do
        if d:find('Balatro Strategic Copilot', 1, true) then drew = d:gsub('^print:', '') end
    end
end
print('loading             : ' .. (ok and 'ok' or ('ERROR ' .. tostring(err))))
print('copilot found       : ' .. tostring(mod ~= nil) .. (mod and mod.path and ('  (' .. mod.path .. ')') or ''))
print('copilot can_load    : ' .. tostring(mod and mod.can_load) .. ((mod and mod.disabled) and '  (DISABLED)' or ''))
print('startup banner      : ' .. tostring(drew or 'none'))
for _, l in ipairs(FG.calls.logs) do
    if l:find('JSON') or l:find('Copilot') or l:find('BSCopilot') or l:find('Duplicate') or l:find('unable') then
        print('log: ' .. l:sub(1, 240))
    end
end
os.exit((mod and drew) and 0 or 1)
