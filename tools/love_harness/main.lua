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
    if scenario == 'shop' then
        opts.state = 5
        opts.jokers = { FG.joker('j_joker', 'Joker', { mult = 4 }), FG.joker('j_cavendish', 'Cavendish', { extra = { odds = 1000, Xmult = 3 } }) }
        opts.shop = { FG.joker('j_duo', 'The Duo', { x_mult = 2, type = 'Pair' }, { rarity = 3, cost = 8 }),
                      FG.joker('j_credit_card', 'Credit Card', { extra = 20 }, { rarity = 1, cost = 1 }) }
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
    G.LANG.font.file = nil
    BSCopilot = nil
    dofile(MOD .. '/main.lua')
    BSCopilot.controller.panel_open = true
    log('save directory: %s', love.filesystem.getSaveDirectory())
    log('hooks: update=%s draw=%s calc=%s keys=%s', tostring(BSCopilot.hooks.update), tostring(BSCopilot.hooks.draw),
        tostring(BSCopilot.hooks.calculate), tostring(BSCopilot.hooks.keys))
end

function love.update(dt)
    frame = frame + 1
    Game.update(G, dt)
    local Ctl = BSCopilot.controller
    local ph = (scenario == 'shop' and 'shop') or (scenario == 'blind' and 'blind_select') or 'hand'
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
    for _, c in ipairs(G.hand.cards) do cardbox(c, tostring(c.base.value) .. ' ' .. tostring(c.base.suit)) end
    if G.shop_jokers then for _, c in ipairs(G.shop_jokers.cards) do cardbox(c, tostring(c.ability.name)) end end
    for _, c in ipairs(G.jokers.cards) do cardbox(c, tostring(c.ability.name)) end
    Game.draw(G)
end
