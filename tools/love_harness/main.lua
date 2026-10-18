-- Balatro Strategic Copilot - LÖVE harness.
-- Runs the real mod code inside the real LÖVE runtime (love.graphics, love.filesystem,
-- love.timer) on a SIMULATED Balatro state, renders the overlay and saves screenshots.
-- Usage: xvfb-run -s "-screen 0 1600x900x24" love tools/love_harness <repo_root> [scenario]
-- This is not the real game: it validates rendering and persistence APIs only.

local repo = arg[2] or '.'
local scenario = arg[3] or 'hand'
local MOD = repo .. '/BalatroStrategicCopilot'
local FG = dofile(repo .. '/tests/integration/fake_game.lua')
local report = {}
local function log(...) local s = string.format(...) report[#report + 1] = s print(s) end

local frame, shots, done_at = 0, 0, nil

function love.load()
    local opts = { mod_root = MOD, real_love = true, required = 300, dollars = 14 }
    if scenario == 'blind' then
        opts.state = 7
        opts.jokers = { FG.joker('j_joker', 'Joker', { mult = 4 }), FG.joker('j_cavendish', 'Cavendish', { extra = { odds = 1000, Xmult = 3 } }) }
    end
    if scenario == 'hand' then
        -- x3 placed BEFORE +4 Mult: the copilot must ask for the right order
        opts.jokers = { FG.joker('j_cavendish', 'Cavendish', { extra = { odds = 1000, Xmult = 3 } }), FG.joker('j_joker', 'Joker', { mult = 4 }) }
    end
    if scenario == 'house' then
        opts.required = 600
        local inhand = { Ah = 1, Ad = 1, ['7c'] = 1, ['9s'] = 1, ['2h'] = 1, Kh = 1, ['5d'] = 1, ['3c'] = 1 }
        opts.deck = {}
        for _, r in ipairs({ '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A' }) do
            for _, su in ipairs({ 's', 'h', 'd', 'c' }) do if not inhand[r .. su] then opts.deck[#opts.deck + 1] = r .. su end end
        end
    end
    if scenario == 'shop' then
        opts.state = 5
        opts.jokers = { FG.joker('j_joker', 'Joker', { mult = 4 }), FG.joker('j_cavendish', 'Cavendish', { extra = { odds = 1000, Xmult = 3 } }) }
        opts.shop = { FG.joker('j_duo', 'The Duo', { x_mult = 2, type = 'Pair' }, { rarity = 3, cost = 8 }),
                      FG.joker('j_credit_card', 'Credit Card', { extra = 20 }, { rarity = 1, cost = 1 }) }
    end
    if scenario == 'death' then
        -- Death in the consumable area (top right, where the game puts it): the copilot must name
        -- the two cards and which one goes on the left; the panel must not cover the area
        opts.hand = { 'Ah', '9s', '7c', '2h', 'Kh', '5d', '3c', 'Qd' }
        opts.jokers = { FG.joker('j_joker', 'Joker', { mult = 4 }) }
    end
    if scenario == 'effects' then
        -- cards with modifiers and jokers with stickers: what the copilot shows about them
        opts.hand = { 'Ks', 'Kh', 'Qs', 'Ah', '9d', '7c', '4h', '2s' }
        opts.jokers = { FG.joker('j_joker', 'Joker', { mult = 4, eternal = true }),
            FG.joker('j_gros_michel', 'Gros Michel', { extra = { odds = 6, mult = 15 }, perishable = true, perish_tally = 2 }) }
        opts.required = 600
    end
    -- keep the real love.* but install the simulated G / SMODS / Game
    local real_love = love
    FG.install(opts)
    love = real_love
    -- position the simulated cards on screen (game units)
    for i, c in ipairs(G.hand.cards) do c.T = { x = 3 + i * 1.6, y = 7, w = 1.4, h = 1.9 }; c.VT = c.T end
    if G.shop_jokers then for i, c in ipairs(G.shop_jokers.cards) do c.T = { x = 8 + i * 2.2, y = 4, w = 1.4, h = 1.9 }; c.VT = c.T end end
    for i, c in ipairs(G.jokers.cards) do c.T = { x = 6 + i * 1.8, y = 0.6, w = 1.4, h = 1.9 }; c.VT = c.T end
    G.TILESIZE = 20; G.TILESCALE = 2.3; G.ROOM = { T = { x = 1, y = 0.5, w = 30, h = 17 } }
    if scenario == 'effects' then
        local function enh(c, key, ab) c.config.center = { key = key, set = 'Enhanced' }; c.ability.set = 'Enhanced'; for k, v in pairs(ab) do c.ability[k] = v end end
        enh(G.hand.cards[1], 'm_steel', { h_x_mult = 1.5 })
        enh(G.hand.cards[3], 'm_gold', { h_dollars = 3 })
        G.hand.cards[4].edition = { holo = true, type = 'holo' }
        G.hand.cards[5].seal = 'Blue'
        G.hand.cards[6].seal = 'Purple'
    end
    if scenario == 'death' then
        local death = { sort_id = 9001, ability = { set = 'Tarot', name = 'Death' }, config = { center = { key = 'c_death', set = 'Tarot' } },
            sell_cost = 1, cost = 3, facing = 'front', T = { x = 24.6, y = 0.6, w = 1.4, h = 1.9 } }
        death.VT = death.T
        G.consumeables.cards = { death }
        G.consumeables.T = { x = 23.8, y = 0.4, w = 5.2, h = 2.4 }
    end
    -- simulated game buttons, as UI trees (box.UIRoot.children, config.button / config.id)
    local function btn(fn, id, x, y, label) return { config = { button = fn, id = id }, T = { x = x, y = y, w = 3, h = 0.9 }, label = label, children = {} } end
    HARNESS_BUTTONS = {}
    if scenario == 'shop' then
        local nb, rr = btn('toggle_shop', 'next_round_button', 1, 3.2, 'Blinde suivante'), btn('reroll_shop', nil, 1, 4.5, 'Relancer 5 $')
        G.shop = { UIRoot = { config = {}, children = { nb, rr } } }
        HARNESS_BUTTONS = { nb, rr }
    end
    if scenario == 'blind' then
        G.GAME.blind_on_deck = 'Small'
        local cols = {}
        for i, x in ipairs({ 6, 12, 18 }) do
            local kids = { btn('select_blind', nil, x, 9, 'Sélectionner') }
            if i < 3 then kids[2] = btn('skip_blind', nil, x, 12, 'Passer') end
            cols[i] = { config = {}, children = kids }
            for _, k in ipairs(kids) do HARNESS_BUTTONS[#HARNESS_BUTTONS + 1] = k end
        end
        G.blind_select = { UIRoot = { config = {}, children = cols } }
        G.GAME.round_resets.blind_tags = { Small = 'tag_investment', Big = 'tag_double' }
    end
    G.LANG.font.file = nil
    if scenario == 'house' then
        G.GAME.blind = { name = 'The House', chips = 600, boss = true, config = { blind = { key = 'bl_house' } } }
        for _, c in ipairs(G.hand.cards) do c.facing = 'back' end
    end
    BSCopilot = nil
    dofile(MOD .. '/main.lua')
    BSCopilot.controller.panel_open = true
    log('save directory: %s', love.filesystem.getSaveDirectory())
    log('hooks: update=%s draw=%s calc=%s keys=%s', tostring(BSCopilot.hooks.update), tostring(BSCopilot.hooks.draw),
        tostring(BSCopilot.hooks.calculate), tostring(BSCopilot.hooks.keys))
end

function love.update(dt)
    frame = frame + 1
    if frame == 20 then love.graphics.captureScreenshot('banner_' .. scenario .. '.png') end -- banner_shot
    Game.update(G, dt)
    local Ctl = BSCopilot.controller
    local ph = (scenario == 'shop' and 'shop') or (scenario == 'blind' and 'blind_select') or 'hand'
    if done_at and frame == done_at + 1 then
        local st = Ctl.step(ph)
        log('step: %s %s (%s)', tostring(st and st.label), tostring(st and st.text), tostring(st and st.why))
        local om = Ctl.order_marks()
        if om then local t = {} for _, m in ipairs(om.marks) do t[#t + 1] = m.pos .. '=' .. tostring(m.name) end log('order: %s', table.concat(t, ' ')) end
    end
    if not done_at and Ctl.results[ph] and not Ctl.partial[ph] then
        done_at = frame
        log('analysis %s complete after %d frames', ph, frame)
    end
    if scenario == 'hand' and done_at and frame == done_at + 2 then
        -- simulate a selection by the player (the mod never selects cards itself)
        G.hand.highlighted = { G.hand.cards[1], G.hand.cards[2] }
    end
    if done_at and frame == done_at + 30 then
        love.graphics.captureScreenshot('overlay_' .. scenario .. '.png')
        shots = shots + 1
    end
    if done_at and frame == done_at + 40 then
        -- persistence check with the real love.filesystem
        local st = BSCopilot.store
        if st then
            local ok = st:save('harness_check', 1, { frame = frame, text = 'é' })
            local data = st:load('harness_check', 1, function() return nil end)
            log('persistence save=%s reload=%s', tostring(ok), tostring(data and data.text == 'é'))
        end
        local L = BSCopilot.require('core/log')
        for k, v in pairs(L.timings) do log('timing %s: %.1f ms (max %.1f)', k, v.total / v.n * 1000, v.max * 1000) end
        log('errors logged: %d', L.counters.error)
        for _, l in ipairs(L.recent(10)) do if l:find('ERROR') then log('%s', l) end end
        love.filesystem.write('harness_report_' .. scenario .. '.txt', table.concat(report, '\n'))
        love.event.quit(0)
    end
    if frame > 6000 then log('timeout'); love.event.quit(1) end
end

function love.draw()
    -- a dark green table and card placeholders, then the game draw (with the overlay hook)
    love.graphics.clear(0.13, 0.33, 0.25, 1)
    local s = G.TILESCALE * G.TILESIZE
    local function cardbox(c, label)
        local x, y = (c.T.x + G.ROOM.T.x) * s, (c.T.y + G.ROOM.T.y) * s
        love.graphics.setColor(0.95, 0.95, 0.9, 1)
        love.graphics.rectangle('fill', x, y, c.T.w * s, c.T.h * s, 6, 6)
        love.graphics.setColor(0.1, 0.1, 0.1, 1)
        love.graphics.print(label, x + 6, y + 6)
    end
    for _, c in ipairs(G.hand.cards) do cardbox(c, c.facing == 'back' and '(cachée)' or (tostring(c.base.value) .. ' ' .. tostring(c.base.suit))) end
    for _, b in ipairs(HARNESS_BUTTONS or {}) do
        local x, y = (b.T.x + G.ROOM.T.x) * s, (b.T.y + G.ROOM.T.y) * s
        love.graphics.setColor(0.85, 0.35, 0.15, 1)
        love.graphics.rectangle('fill', x, y, b.T.w * s, b.T.h * s, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(b.label, x + 8, y + 8)
    end
    if G.shop_jokers then for _, c in ipairs(G.shop_jokers.cards) do cardbox(c, tostring(c.ability.name)) end end
    if G.consumeables.T then
        local a = G.consumeables.T
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.rectangle('fill', (a.x + G.ROOM.T.x) * s, (a.y + G.ROOM.T.y) * s, a.w * s, a.h * s, 8, 8)
    end
    for _, c in ipairs(G.consumeables.cards) do cardbox(c, tostring(c.ability.name)) end
    for _, c in ipairs(G.jokers.cards) do cardbox(c, tostring(c.ability.name)) end
    Game.draw(G)
end
