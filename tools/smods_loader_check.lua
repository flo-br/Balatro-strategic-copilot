-- Balatro Strategic Copilot - tools/smods_loader_check.lua
-- Runs the REAL mod loader of an old Steamodded (src/loader.lua layout, e.g. 1.0.0~BETA-0509c)
-- on a Mods folder, with the game itself replaced by tests/integration/fake_game.lua. It answers
-- "does Steamodded find and start the copilot with this folder layout?" without the game.
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
local loader_src = readf(SMODS_SRC .. '/src/loader.lua')
if not loader_src or not loader_src:find('function loadMods', 1, true) then
    print('src/loader.lua with loadMods() not found in ' .. SMODS_SRC .. ' (only the old loader layout is supported)')
    os.exit(2)
end

local FG = dofile(REPO .. '/tests/integration/fake_game.lua')
FG.install({ old_smods = true, mod_root = REPO .. '/BalatroStrategicCopilot' })

local function sh(cmd) local p = io.popen(cmd); local o = p:read('*a'); p:close(); return o end
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
-- read-only stand-in for nativefs, the file API Steamodded uses
NFS = {
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
}

-- pieces of Steamodded the loader needs, taken from its own sources
local keybind = SMODS.Keybind -- fake from fake_game.lua (the real one needs the whole game)
do
    local u = assert(readf(SMODS_SRC .. '/src/utils.lua'))
    local a = assert(u:find('V_MT = {', 1, true), 'V_MT not found in utils.lua')
    local b = u:find('\nend', assert(u:find('function V.is_valid', a, true), 'V.is_valid not found'), true)
    assert(load(u:sub(a, b + 4), '=smods_utils_V'))()
end
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
G.VERSION = G.VERSION or '1.0.1o-FULL'
local version = (readf(SMODS_SRC .. '/version.lua') or ''):match('"(.-)"') or '?'
SMODS = { id = 'Steamodded', version = version, can_load = true, meta_mod = true, path = MODS .. '/smods-main/',
    MODS_DIR = MODS, compat_0_9_8 = {}, Keybind = keybind }
assert(load(loader_src, '=smods_loader'))()
do
    local ui = assert(readf(SMODS_SRC .. '/src/ui.lua'))
    local a = assert(ui:find('function SMODS.load_mod_config', 1, true), 'load_mod_config not found in ui.lua')
    local b = ui:find('\nend\n', assert(ui:find('function SMODS.save_mod_config', a, true)), true)
    assert(load(ui:sub(a, b + 4), '=smods_ui_config'))()
end
function boot_print_stage() end
SMODS.get_optional_features = function() end
print('Steamodded ' .. version .. ' (src/loader.lua), Mods = ' .. MODS)

local ok, err = pcall(loadMods, MODS)
local mod = SMODS.Mods and SMODS.Mods.BalatroStrategicCopilot
local drew = nil
if ok and rawget(_G, 'BSCopilot') then
    pcall(Game.draw, G)
    for _, d in ipairs(FG.calls.draw) do
        if d:find('Balatro Strategic Copilot', 1, true) then drew = d:gsub('^print:', '') end
    end
end
print('loadMods            : ' .. (ok and 'ok' or ('ERROR ' .. tostring(err))))
print('copilot found       : ' .. tostring(mod ~= nil) .. (mod and mod.path and ('  (' .. mod.path .. ')') or ''))
print('copilot can_load    : ' .. tostring(mod and mod.can_load))
print('startup banner      : ' .. tostring(drew or 'none'))
for _, l in ipairs(FG.calls.logs) do
    if l:find('JSON') or l:find('Copilot') or l:find('BSCopilot') or l:find('Duplicate') or l:find('unable') then
        print('log: ' .. l:sub(1, 240))
    end
end
os.exit((mod and drew) and 0 or 1)
