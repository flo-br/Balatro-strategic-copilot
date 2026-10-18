-- Balatro Strategic Copilot - entry point (loaded by Steamodded, see BalatroStrategicCopilot.json)
-- The copilot only observes and advises: it never plays, selects, buys, sells or rerolls.

BSCopilot = BSCopilot or {}
local BSC = BSCopilot
BSC.VERSION = '1.0.7'
BSC.mod = SMODS and SMODS.current_mod or BSC.mod
BSC.modules = BSC.modules or {}

-- Module loader on top of SMODS.load_file (works after the initial load too, thanks to the id).
-- Autonomous mode (no Lovely/Steamodded, started by %AppData%/Balatro/main.lua): BSC.root_lfs is
-- the mod folder relative to the save directory, read through love.filesystem.
function BSC.require(name)
    local m = BSC.modules[name]
    if m ~= nil then return m end
    local path = 'src/' .. name .. '.lua'
    local chunk, err
    if BSC.mod and SMODS and SMODS.load_file then
        chunk, err = SMODS.load_file(path, BSC.mod.id)
    elseif BSC.root_lfs and love and love.filesystem then
        chunk, err = love.filesystem.load(BSC.root_lfs .. '/' .. path)
    elseif SMODS and SMODS.load_file then
        chunk, err = SMODS.load_file(path)
    elseif BSC.root then
        chunk, err = loadfile(BSC.root .. '/' .. path)
    end
    if not chunk then error('BSCopilot: cannot load ' .. path .. ': ' .. tostring(err)) end
    m = chunk()
    BSC.modules[name] = m
    return m
end

-- Startup status banner, installed FIRST and independent of every other module, so that the
-- player always sees whether the copilot started, and why not if it failed (instead of a
-- silent failure that only appears in the log).
BSC.status = { ok = nil, text = 'Balatro Strategic Copilot : démarrage…' }

function BSC.draw_status()
    local st = BSC.status
    if not st or not love or not love.graphics then return end
    local now = (love.timer and love.timer.getTime()) or os.clock()
    -- The countdown starts once the splash screen is over (fully visible until then, 60 s at
    -- most), so that the banner is still there when the main menu appears.
    st.first = st.first or now
    if not st.t0 then
        local G = rawget(_G, 'G')
        local splash = G and G.STATES and G.STATES.SPLASH ~= nil and G.STATE == G.STATES.SPLASH
        if not splash or now - st.first > 60 then st.t0 = now end
    end
    local age = st.t0 and (now - st.t0) or 0
    if st.ok and age > (st.ttl or 15) then return end
    local g = love.graphics
    local W, H = g.getDimensions()
    g.push('all')
    g.origin()
    local ok_font, font = pcall(function()
        BSC.status_font = BSC.status_font or g.newFont(math.max(14, math.floor(H / 50)))
        return BSC.status_font
    end)
    if ok_font and font then
        g.setFont(font)
        local lines = {}
        for l in (st.text .. '\n'):gmatch('(.-)\n') do lines[#lines + 1] = l end
        local w = 0
        for _, l in ipairs(lines) do w = math.max(w, font:getWidth(l)) end
        w = math.min(w + 24, W - 20)
        local h = #lines * font:getHeight() * 1.2 + 12
        local x = math.floor(W / 2 - w / 2)
        local alpha = st.ok and math.min(1, ((st.ttl or 15) - age) / 1.5) or 1
        if st.ok then g.setColor(0.10, 0.36, 0.22, 0.92 * alpha) else g.setColor(0.55, 0.10, 0.10, 0.95) end
        g.rectangle('fill', x, 8, w, h, 6, 6)
        g.setColor(1, 1, 1, alpha)
        for i, l in ipairs(lines) do g.print(l, x + 12, 14 + (i - 1) * font:getHeight() * 1.2) end
    end
    g.pop()
end

pcall(function()
    if type(Game) == 'table' and type(Game.draw) == 'function' and not BSC.status_hooked then
        BSC.status_hooked = true
        local draw_ref = Game.draw
        Game.draw = function(self, ...)
            draw_ref(self, ...)
            pcall(BSC.draw_status)
        end
    end
end)

local ok, err = pcall(function()
    BSC.config = (BSC.mod and BSC.mod.config) or {}
    if not BSC.mod and BSC.root_lfs and love and love.filesystem then
        -- autonomous mode: defaults from config.lua (Steamodded normally does this)
        local okc, cfg = pcall(function() return love.filesystem.load(BSC.root_lfs .. '/config.lua')() end)
        if okc and type(cfg) == 'table' then BSC.config = cfg end
    end
    BSC.require('game/boot').start()
end)
if ok then
    local keys = BSC.config and BSC.config.keys or {}
    local events = BSC.events_mode == 'native' and 'événements natifs' or 'détection par état (Steamodded ancien)'
    if BSC.standalone then events = 'mode autonome, sans Steamodded' end
    BSC.status = { ok = true, ttl = 15, text = 'Balatro Strategic Copilot ' .. BSC.VERSION .. ' actif — touche '
        .. string.upper(keys.panel or 'c') .. ' : panneau  (' .. events .. ')' }
else
    local msg = tostring(err)
    BSC.boot_error = msg
    local full = 'Balatro Strategic Copilot failed to start: ' .. msg
    if sendErrorMessage then sendErrorMessage(full, 'BSCopilot') else print(full) end
    local first = msg:gsub('\n.*', '')
    if #first > 140 then first = first:sub(1, 140) .. '…' end
    BSC.status = { ok = false, text = 'Balatro Strategic Copilot : erreur au démarrage\n' .. first
        .. (BSC.standalone and '\nDétails : %AppData%\\Balatro\\BSC\\amorce.log et BSC\\logs\\bsc.log'
            or '\nDétails : %AppData%\\Balatro\\Mods\\lovely\\log (rechercher BSCopilot)') }
end
