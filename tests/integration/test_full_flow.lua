-- Drives the fake game through a whole (short) run and checks analyses, recording,
-- learning and persistence end to end.
local T = ...
local S = {}

local function boot(opts)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    opts = opts or {}
    opts.mod_root = T.MOD_ROOT
    FG.install(opts)
    BSCopilot = nil
    dofile(T.MOD_ROOT .. '/main.lua')
    return FG
end

local function settle(FG, pred, n)
    for _ = 1, n or 4000 do
        FG.frames(1, 0.05)
        if not pred or pred() then if not pred then end return true end
    end
    return false
end

function S.whole_run_learns_and_persists(T)
    local FG = boot({ required = 300 })
    local Ctl = BSCopilot.controller
    local mod = SMODS.current_mod
    T.ok(BSCopilot.learning_runtime, 'learning runtime attached')
    -- hand phase analysis
    T.ok(settle(FG, function() return Ctl.results.hand and not Ctl.partial.hand end))
    -- the player plays the pair of aces (observed through mod.calculate)
    local played = { G.hand.cards[1], G.hand.cards[2] }
    mod.calculate(mod, { before = true, full_hand = played, scoring_name = 'Pair' })
    G.STATE = G.STATES.HAND_PLAYED
    FG.frames(3)
    -- score lands, hand continues
    G.GAME.chips = 64
    G.GAME.current_round.hands_left = 3
    table.remove(G.hand.cards, 1); table.remove(G.hand.cards, 1)
    G.STATE = G.STATES.SELECTING_HAND
    FG.frames(5)
    local run = BSCopilot.learning_runtime.rec.run
    T.ok(run and #run.hands == 1, 'hand recorded')
    T.eq(run.hands[1].predicted, 64); T.eq(run.hands[1].actual, 64)
    -- blind lost: end of round with game over
    mod.calculate(mod, { end_of_round = true, game_over = true })
    G.STATE = G.STATES.GAME_OVER
    T.ok(settle(FG, function() return Ctl.results.game_over ~= nil end, 200), 'review produced')
    local rv = Ctl.results.game_over
    T.eq(rv.result, 'loss')
    -- files: profile and run log persisted, active run removed
    local has_profile, has_run = false, false
    for k in pairs(FG.mem) do
        if k:find('^BSC/profile%.[ab]%.json$') then has_profile = true end
        if k:find('^BSC/runs/run_.*%.[ab]%.json$') then has_run = true end
    end
    T.ok(has_profile, 'profile saved'); T.ok(has_run, 'run log saved')
    T.eq(BSCopilot.learning_runtime.profile().runs, 1)
    -- the review panel renders
    Ctl.panel_open = true
    Game.draw(G)
    -- restart: a fresh mod instance reloads the learned profile from disk
    local mem = FG.mem
    FG.install({ mod_root = T.MOD_ROOT })
    for k, v in pairs(mem) do love.filesystem.write(k:gsub('^dir:', ''), v) end
    for k in pairs(mem) do if k:find('^dir:') then love.filesystem.createDirectory(k:sub(5)) end end
    BSCopilot = nil
    dofile(T.MOD_ROOT .. '/main.lua')
    T.eq(BSCopilot.learning_runtime.profile().runs, 1, 'learning survived the restart')
    FG.uninstall()
end

function S.shop_phase_analysis(T)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    FG.install({ mod_root = T.MOD_ROOT, state = 5, dollars = 15,
        jokers = { FG.joker('j_joker', 'Joker', { mult = 4 }) },
        shop = { FG.joker('j_duo', 'The Duo', { x_mult = 2, type = 'Pair' }, { rarity = 3, cost = 8 }),
                 FG.joker('j_credit_card', 'Credit Card', { extra = 20 }, { rarity = 1, cost = 1 }) } })
    BSCopilot = nil
    dofile(T.MOD_ROOT .. '/main.lua')
    local Ctl = BSCopilot.controller
    local done = settle(FG, function() return Ctl.results.shop and not Ctl.partial.shop end, 20000)
    T.ok(done, 'shop analysis completes')
    local r = Ctl.results.shop
    T.eq(r.options[1].key, 'j_duo')
    T.ok(r.reroll ~= nil)
    -- badges are positioned over the shop cards
    Ctl.show_badges = true
    local m = Ctl.ui_model()
    T.ok(m.badges and #m.badges >= 2, 'badges on shop items')
    FG.uninstall()
end

return S
