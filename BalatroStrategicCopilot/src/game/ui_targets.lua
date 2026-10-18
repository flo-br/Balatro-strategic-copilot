-- Balatro Strategic Copilot - game/ui_targets.lua
-- Finds the game's own buttons (reroll, next blind, select / skip blind, skip pack) to put the
-- step label above them. Read-only: the tree is only walked, never changed or clicked.
--
-- Verified in the sources: UI boxes expose their tree as box.UIRoot with .children, and a button
-- names the function it triggers in node.config.button (Steamodded sets e.config.button
-- = 'use_card'); the shop's next-round button has the id 'next_round_button'
-- (G.shop:get_UIE_by_ID('next_round_button') in vanilla code quoted by Steamodded).
-- NOT verified: the other function names below ('reroll_shop', 'select_blind', 'skip_blind',
-- 'skip_booster') and the G.blind_select / G.I.UIBOX holders. If a button is not found, the
-- step stays shown as text, and the buttons actually seen are written to the log once, so that
-- the names can be corrected from a real game.

local BSC = BSCopilot
local L = BSC.require('core/log')

local UT = { cache = {}, logged = {} }

UT.WANTED = {
    reroll = { ids = { 'reroll_shop_button' }, buttons = { 'reroll_shop' } },
    next_round = { ids = { 'next_round_button' }, buttons = { 'toggle_shop' } },
    select_blind = { ids = { 'select_blind_button' }, buttons = { 'select_blind' } },
    skip_blind = { ids = {}, buttons = { 'skip_blind' } },
    skip_pack = { ids = {}, buttons = { 'skip_booster' } },
}

local MAX_NODES = 6000

local function roots()
    local G = rawget(_G, 'G')
    local out, seen = {}, {}
    if type(G) ~= 'table' then return out end
    local function add(b)
        if type(b) == 'table' and type(b.UIRoot) == 'table' and not seen[b] then seen[b] = true; out[#out + 1] = b end
    end
    for _, k in ipairs({ 'shop', 'blind_select', 'buttons', 'booster_pack' }) do add(rawget(G, k)) end
    local reg = type(G.I) == 'table' and G.I.UIBOX
    if type(reg) == 'table' then for _, b in ipairs(reg) do add(b) end end
    return out
end

-- every node carrying a button function or an id, in tree order
function UT.scan()
    local found = {}
    local count = 0
    local function walk(node, depth)
        if count > MAX_NODES or depth > 40 or type(node) ~= 'table' then return end
        count = count + 1
        local cfg = node.config
        if type(cfg) == 'table' and (type(cfg.button) == 'string' or type(cfg.id) == 'string') then
            found[#found + 1] = { node = node, button = type(cfg.button) == 'string' and cfg.button or nil,
                id = type(cfg.id) == 'string' and cfg.id or nil }
        end
        local ch = node.children
        if type(ch) == 'table' then
            for _, c in ipairs(ch) do walk(c, depth + 1) end
            for k, c in pairs(ch) do if type(k) ~= 'number' then walk(c, depth + 1) end end
        end
    end
    for _, b in ipairs(roots()) do walk(b.UIRoot, 0) end
    return found
end

function UT.rect(node)
    local G = rawget(_G, 'G')
    local T = type(node) == 'table' and (node.VT or node.T)
    if not (T and T.x and T.w and G and G.ROOM and G.ROOM.T and G.TILESCALE and G.TILESIZE) then return nil end
    local s = G.TILESCALE * G.TILESIZE
    return (T.x + G.ROOM.T.x) * s, (T.y + G.ROOM.T.y) * s, T.w * s, T.h * s
end

local SLOT = { Small = 1, Big = 2, Boss = 3 }

local function pick(kind, list)
    if #list <= 1 then return list[1] end
    local G = rawget(_G, 'G')
    if kind == 'select_blind' or kind == 'skip_blind' then
        -- one column per blind, left to right: Small, Big, Boss
        table.sort(list, function(a, b)
            local xa, xb = (a.node.T and a.node.T.x) or 0, (b.node.T and b.node.T.x) or 0
            return xa < xb
        end)
        local deck = G and G.GAME and G.GAME.blind_on_deck
        local i = SLOT[deck or ''] or 1
        if kind == 'skip_blind' and UT.cache.select_blind_x then
            local best, d0
            for _, e in ipairs(list) do
                local d = math.abs(((e.node.T and e.node.T.x) or 0) - UT.cache.select_blind_x)
                if not d0 or d < d0 then best, d0 = e, d end
            end
            return best
        end
        return list[math.min(i, #list)]
    end
    return list[1]
end

-- node of a wanted button, or nil (then logged once with what was seen)
function UT.find(kind, phase)
    local w = UT.WANTED[kind]
    if not w then return nil end
    local all = UT.scan()
    local hits = {}
    for _, e in ipairs(all) do
        local ok = false
        for _, id in ipairs(w.ids) do if e.id == id then ok = true end end
        for _, bt in ipairs(w.buttons) do if e.button == bt then ok = true end end
        if ok then hits[#hits + 1] = e end
    end
    local e = pick(kind, hits)
    if e and kind == 'select_blind' then UT.cache.select_blind_x = e.node.T and e.node.T.x end
    if not e then
        local key = tostring(phase) .. ':' .. kind
        if not UT.logged[key] then
            UT.logged[key] = true
            local names, seen = {}, {}
            for _, x in ipairs(all) do
                local n = (x.button or '-') .. '/' .. (x.id or '-')
                if not seen[n] and #names < 40 then seen[n] = true; names[#names + 1] = n end
            end
            L.info('ui', 'button %s not found (phase %s); buttons seen (function/id): %s', kind, tostring(phase), table.concat(names, ', '))
        end
        return nil
    end
    return e.node
end

-- rectangle of a wanted button, cached briefly (the tree is walked at most 4 times a second)
function UT.button_rect(kind, phase, now)
    local c = UT.cache[kind]
    if not c or c.phase ~= phase or (now or 0) - (c.t or 0) > 0.25 then
        c = { phase = phase, t = now or 0, node = UT.find(kind, phase) }
        UT.cache[kind] = c
    end
    if not c.node then return nil end
    return UT.rect(c.node)
end

return UT
