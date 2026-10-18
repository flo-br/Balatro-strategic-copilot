-- Balatro Strategic Copilot - ui/ui_manager.lua  (UIManager)
-- Draws the copilot overlay with plain love.graphics calls after the game has drawn its
-- frame (screen space). It never changes the game's UI objects. All drawing is protected:
-- the graphics state is saved/restored with push('all')/pop().

local BSC = BSCopilot
local U = BSC.require('core/util')
local L = BSC.require('core/log')
local I = BSC.require('core/i18n')
local Fmt = BSC.require('ui/format')

local UI = {}

UI.palette = {
    text = { 0.95, 0.96, 0.98, 1 }, dim = { 0.70, 0.74, 0.82, 1 }, title = { 1.00, 0.84, 0.40, 1 },
    good = { 0.36, 0.86, 0.46, 1 }, mid = { 1.00, 0.66, 0.22, 1 }, bad = { 1.00, 0.38, 0.38, 1 },
    chips = { 0.42, 0.72, 1.00, 1 }, mult = { 1.00, 0.42, 0.42, 1 }, money = { 1.00, 0.86, 0.30, 1 },
    accent = { 0.78, 0.62, 1.00, 1 },
    Spades = { 0.70, 0.74, 1.00, 1 }, Hearts = { 1.00, 0.48, 0.48, 1 }, Clubs = { 0.56, 0.92, 0.62, 1 }, Diamonds = { 1.00, 0.72, 0.36, 1 },
    bg = { 0.07, 0.09, 0.13, 0.88 }, border = { 1, 1, 1, 0.18 }, badge_bg = { 0.05, 0.06, 0.09, 0.92 },
}

UI.fonts = {}
UI.font_file = nil
UI.glyphs_checked = false
UI.sanitize = {}

local function lg() return love and love.graphics end

function UI.font(size)
    size = math.max(8, math.floor(size + 0.5))
    local f = UI.fonts[size]
    if f then return f end
    local g = lg()
    local ok, font
    if UI.font_file then ok, font = pcall(g.newFont, UI.font_file, size) end
    if not ok or not font then ok, font = pcall(g.newFont, size) end
    if not ok then return nil end
    UI.fonts[size] = font
    if not UI.glyphs_checked then
        UI.glyphs_checked = true
        UI.check_glyphs(font)
    end
    return font
end

-- Replace characters the font cannot draw (pixel fonts often lack ≈ … — œ, suit glyphs).
function UI.check_glyphs(font)
    local has = function(s)
        if not font.hasGlyphs then return false end
        local ok, v = pcall(font.hasGlyphs, font, s)
        return ok and v
    end
    local map = { ['≈'] = '~', ['…'] = '...', ['—'] = '-', ['±'] = '+/-', ['œ'] = 'oe', ['é'] = 'e', ['è'] = 'e',
        ['ê'] = 'e', ['à'] = 'a', ['â'] = 'a', ['ç'] = 'c', ['î'] = 'i', ['ô'] = 'o', ['û'] = 'u', ['ù'] = 'u',
        ['É'] = 'E', ['È'] = 'E', ['À'] = 'A' }
    UI.sanitize = {}
    for ch, rep in pairs(map) do
        if not has(ch) then UI.sanitize[ch] = rep end
    end
    if has('♠♥♣♦') then
        Fmt.symbols.suits = { Spades = '♠', Hearts = '♥', Clubs = '♣', Diamonds = '♦' }
    end
    if has('▲▼●') then
        Fmt.symbols.good, Fmt.symbols.mid, Fmt.symbols.bad = '▲', '●', '▼'
    end
end

local function clean(s)
    s = tostring(s)
    for ch, rep in pairs(UI.sanitize) do
        if s:find(ch, 1, true) then s = s:gsub(ch, rep) end
    end
    return s
end
UI.clean = clean

local function colour(name, alpha)
    local c = UI.palette[name] or UI.palette.text
    return c[1], c[2], c[3], (c[4] or 1) * (alpha or 1)
end

-- Lay out segments word by word (wrapping inside long segments), returns placed pieces.
local function layout(lines, w, font, line_h)
    local pieces = {}
    local cy = 0
    local indent = font:getWidth('  ')
    for _, l in ipairs(lines) do
        local cx = 0
        for _, s in ipairs(l) do
            local text = clean(s.t)
            -- split into words keeping the spaces attached
            for word in text:gmatch('%S*%s*') do
                if word ~= '' then
                    local ww = font:getWidth(word)
                    if cx + ww > w and cx > indent then
                        cx = indent
                        cy = cy + line_h
                        word = word:gsub('^%s+', '')
                        ww = font:getWidth(word)
                    end
                    pieces[#pieces + 1] = { x = cx, y = cy, t = word, c = s.c }
                    cx = cx + ww
                end
            end
        end
        cy = cy + line_h
    end
    return pieces, cy
end

local function draw_lines(lines, x, y, w, font, line_h, alpha)
    local g = lg()
    g.setFont(font)
    local pieces, h = layout(lines, w, font, line_h)
    for _, p in ipairs(pieces) do
        g.setColor(colour(p.c, alpha))
        g.print(p.t, math.floor(x + p.x), math.floor(y + p.y))
    end
    return h
end

local function measure_lines(lines, w, font, line_h)
    local _, h = layout(lines, w, font, line_h)
    return h
end

-- model = { panel_open, detail, title, lines, compact_lines, badges = {{x,y,w,h,text,class}},
--           alerts = {{text, class}}, anchor = 'right'|'left', scale }
function UI.draw(model)
    local g = lg()
    if not g or not model then return end
    -- the game font may not be ready when the mod loads: resolve it lazily, once
    if not UI.font_resolved then
        UI.font_resolved = true
        local G = rawget(_G, 'G')
        local use_game = not (BSC.config and BSC.config.ui and BSC.config.ui.use_game_font == false)
        if use_game and not UI.font_file and G and G.LANG and G.LANG.font and G.LANG.font.file then
            UI.font_file = G.LANG.font.file
        end
        if not use_game then UI.font_file = nil end
    end
    local W, H = g.getDimensions()
    local base = math.max(11, math.floor(H / 54 * (model.scale or 1)))
    local font = UI.font(base)
    local small = UI.font(base * 0.85)
    if not font or not small then return end
    local line_h = font:getHeight() * 1.15
    g.push('all')
    g.origin()

    -- panel or compact box
    local lines = model.panel_open and model.lines or model.compact_lines
    if lines and #lines > 0 then
        local pw = model.panel_open and math.max(300, math.floor(W * 0.27)) or math.max(240, math.floor(W * 0.2))
        local pad = math.floor(base * 0.6)
        local title_h = line_h
        local body_h = measure_lines(lines, pw - 2 * pad, model.panel_open and font or small, line_h)
        local ph = math.min(H - 20, title_h + body_h + 2 * pad + (model.footer and line_h or 0))
        local px = (model.anchor == 'left') and 10 or (W - pw - 10)
        local py = model.panel_open and math.floor(H * 0.12) or math.floor(H * 0.02)
        -- never over the game's consumable area (its cards and their "Use" buttons)
        local av = model.avoid
        if av and px < av.x + av.w and px + pw > av.x and py < av.y + av.h + 8 then
            py = math.floor(av.y + av.h + 8)
            ph = math.min(ph, H - 10 - py)
        elseif py + ph > H - 10 then
            py = math.max(10, H - 10 - ph)
        end
        g.setColor(colour('bg'))
        g.rectangle('fill', px, py, pw, ph, 8, 8)
        g.setColor(colour('border'))
        g.setLineWidth(1)
        g.rectangle('line', px, py, pw, ph, 8, 8)
        g.setScissor(px, py, pw, ph)
        g.setFont(font)
        g.setColor(colour('title'))
        g.print(clean(model.title or I.T('title')), px + pad, py + pad)
        draw_lines(lines, px + pad, py + pad + title_h, pw - 2 * pad, model.panel_open and font or small, line_h)
        if model.footer and model.panel_open then
            g.setFont(small)
            g.setColor(colour('dim'))
            g.print(clean(model.footer), px + pad, py + ph - pad - small:getHeight())
        end
        g.setScissor()
    end

    -- badges over cards (drawn after the panel: never hidden by it)
    if model.badges then
        for _, b in ipairs(model.badges) do
            -- strong = the step to do now (bigger, thicker frame); pos = 'below' for order numbers
            local f = b.strong and font or small
            g.setFont(f)
            local text = clean(b.text)
            local tw = f:getWidth(text) + (b.strong and 14 or 10)
            local th = f:getHeight() + (b.strong and 6 or 4)
            local bx = math.floor(b.x + b.w / 2 - tw / 2)
            local by
            if b.pos == 'below' then
                by = math.floor(b.y + b.h + 2)
                if by + th > H then by = math.floor(b.y + b.h - th - 2) end
            else
                by = math.floor(b.y - th - 2)
                if by < 0 then by = math.floor(b.y + 2) end
            end
            bx = math.max(2, math.min(bx, W - tw - 2))
            g.setColor(colour('badge_bg'))
            g.rectangle('fill', bx, by, tw, th, 4, 4)
            g.setColor(colour(b.class or 'text'))
            g.setLineWidth(b.strong and 3 or 2)
            g.rectangle('line', bx, by, tw, th, 4, 4)
            g.print(text, bx + (b.strong and 7 or 5), by + (b.strong and 3 or 2))
        end
    end

    -- alerts (toasts), top centre
    if model.alerts and #model.alerts > 0 then
        g.setFont(font)
        local ay = math.floor(H * 0.005) + 4
        for _, a in ipairs(model.alerts) do
            local text = clean(a.text)
            local tw = font:getWidth(text) + 24
            local ax = math.floor(W / 2 - tw / 2)
            g.setColor(colour('bg', a.alpha))
            g.rectangle('fill', ax, ay, tw, line_h + 6, 6, 6)
            g.setColor(colour(a.class or 'mid', a.alpha))
            g.setLineWidth(2)
            g.rectangle('line', ax, ay, tw, line_h + 6, 6, 6)
            g.print(text, ax + 12, ay + 3)
            ay = ay + line_h + 10
        end
    end
    g.pop()
end

return UI
