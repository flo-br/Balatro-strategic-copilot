-- Steamodded 1.0.0~BETA-0509c (May 2025) does not dispatch contexts to mods (verified in its
-- sources): the copilot must still work and rebuild events from state changes.
local T = ...
local S = {}

local function boot(opts)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    opts = opts or {}
    opts.mod_root = T.MOD_ROOT
    opts.old_smods = true
    FG.install(opts)
    BSCopilot = nil
    dofile(T.MOD_ROOT .. '/main.lua')
    return FG
end

local function settle(FG, pred, n)
    for _ = 1, n or 4000 do
        FG.frames(1, 0.05)
        if pred() then return true end
    end
    return false
end

function S.status_banner_and_mode(T)
    local FG = boot()
    T.eq(BSCopilot.events_mode, 'polling')
    T.ok(BSCopilot.status.ok)
    T.ok(BSCopilot.status.text:find('actif'), BSCopilot.status.text)
    T.ok(BSCopilot.status.text:find('Steamodded ancien'))
    Game.draw(G)
    local shown = false
    for _, c in ipairs(FG.calls.draw) do if c:find('actif') then shown = true end end
    T.ok(shown, 'startup banner drawn')
    FG.uninstall()
end

-- The banner must still be visible when the main menu appears after the splash screen.
function S.banner_countdown_starts_after_splash(T)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    FG.install({ mod_root = T.MOD_ROOT, state = 13 })
    local clock = 100
    love.timer.getTime = function() return clock end
    BSCopilot = nil
    dofile(T.MOD_ROOT .. '/main.lua')
    local function shown()
        FG.calls.draw = {}
        Game.draw(G)
        for _, c in ipairs(FG.calls.draw) do if c:find('actif') then return true end end
        return false
    end
    T.eq(G.STATE, G.STATES.SPLASH)
    T.ok(shown(), 'visible during the splash')
    clock = clock + 40
    T.ok(shown(), 'still visible after a long splash')
    G.STATE = G.STATES.MENU
    T.ok(shown(), 'visible when the main menu appears')
    clock = clock + 14
    T.ok(shown(), 'visible during the countdown')
    clock = clock + 2
    T.ok(not shown(), 'hidden after the countdown')
    FG.uninstall()
end

function S.startup_error_is_visible(T)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    FG.install({ mod_root = T.MOD_ROOT })
    local real = SMODS.load_file
    SMODS.load_file = function(path, id)
        if path:find('boot') then return nil, 'simulated broken file' end
        return real(path, id)
    end
    BSCopilot = nil
    dofile(T.MOD_ROOT .. '/main.lua')
    T.eq(BSCopilot.status.ok, false)
    T.ok(BSCopilot.status.text:find('erreur au démarrage'))
    T.ok(BSCopilot.status.text:find('simulated broken file'))
    Game.draw(G)
    local shown = false
    for _, c in ipairs(FG.calls.draw) do if c:find('erreur') then shown = true end end
    T.ok(shown, 'error banner drawn')
    local logged = false
    for _, l in ipairs(FG.calls.logs) do if l:find('failed to start') then logged = true end end
    T.ok(logged, 'error also sent to the log')
    FG.uninstall()
end

function S.hand_and_discard_detected_without_events(T)
    local FG = boot({ required = 300 })
    local Ctl = BSCopilot.controller
    T.ok(settle(FG, function() return Ctl.results.hand and not Ctl.partial.hand end))
    -- the player plays the pair of aces: cards go to G.play during HAND_PLAYED
    local played = { G.hand.cards[1], G.hand.cards[2] }
    G.play = { cards = played }
    G.STATE = G.STATES.HAND_PLAYED
    FG.frames(4)
    table.remove(G.hand.cards, 1); table.remove(G.hand.cards, 1)
    G.play.cards = {}
    G.GAME.chips = 64
    G.GAME.current_round.hands_left = 3
    G.STATE = G.STATES.SELECTING_HAND
    FG.frames(5)
    local run = BSCopilot.learning_runtime.rec.run
    T.ok(run and #run.hands == 1, 'hand recorded without Steamodded events')
    T.eq(run.hands[1].predicted, 64); T.eq(run.hands[1].actual, 64)
    -- discard two cards (no hand used)
    T.ok(settle(FG, function() return Ctl.results.hand and not Ctl.partial.hand end))
    table.remove(G.hand.cards, 1); table.remove(G.hand.cards, 1)
    G.GAME.current_round.discards_left = 2
    FG.frames(5)
    local last = run.decisions[#run.decisions]
    T.eq(last.kind, 'pre_discard')
    T.eq(#run.hands, 1, 'a discard is not a hand')
    FG.uninstall()
end

function S.shop_actions_detected_without_events(T)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    local duo = FG.joker('j_duo', 'The Duo', { x_mult = 2, type = 'Pair' }, { rarity = 3, cost = 8 })
    local cc = FG.joker('j_credit_card', 'Credit Card', { extra = 20 }, { rarity = 1, cost = 1 })
    local owned = FG.joker('j_joker', 'Joker', { mult = 4 }, { sell_cost = 1 })
    FG.install({ mod_root = T.MOD_ROOT, old_smods = true, state = 5, dollars = 20, jokers = { owned }, shop = { duo, cc } })
    BSCopilot = nil
    dofile(T.MOD_ROOT .. '/main.lua')
    local Ctl = BSCopilot.controller
    -- a run must exist for the recorder: start from the shop state
    T.ok(settle(FG, function() return Ctl.results.shop and not Ctl.partial.shop end, 20000))
    local run = BSCopilot.learning_runtime.rec.run
    T.ok(run, 'run started')
    -- buy The Duo: it moves from the shop to the jokers, money spent
    table.remove(G.shop_jokers.cards, 1)
    table.insert(G.jokers.cards, duo)
    G.GAME.dollars = 12
    FG.frames(5)
    local d = run.decisions[#run.decisions]
    T.eq(d.kind, 'buying_card'); T.eq(d.key, 'j_duo'); T.ok(d.followed, 'best option was bought')
    -- sell the Joker: money gained
    T.ok(settle(FG, function() return Ctl.results.shop and not Ctl.partial.shop end, 20000))
    table.remove(G.jokers.cards, 1)
    G.GAME.dollars = 13
    FG.frames(5)
    d = run.decisions[#run.decisions]
    T.eq(d.kind, 'selling_card'); T.eq(d.key, 'j_joker')
    -- reroll: the remaining shop card is replaced, money spent
    T.ok(settle(FG, function() return Ctl.results.shop and not Ctl.partial.shop end, 20000))
    G.shop_jokers.cards = { FG.joker('j_jolly', 'Jolly Joker', { t_mult = 8, type = 'Pair' }, { cost = 3 }) }
    G.GAME.dollars = 8
    FG.frames(5)
    d = run.decisions[#run.decisions]
    T.eq(d.kind, 'reroll_shop')
    FG.uninstall()
end

function S.native_events_take_over_when_present(T)
    local FG = boot()
    T.eq(BSCopilot.events_mode, 'polling')
    local mod = SMODS.current_mod
    mod.calculate(mod, { setting_blind = true })
    T.eq(BSCopilot.events_mode, 'native', 'real events win, no double counting')
    FG.uninstall()
end

return S
