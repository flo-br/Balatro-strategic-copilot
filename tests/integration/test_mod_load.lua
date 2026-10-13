local T = ...
local S = {}

local function load_fake(opts)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    opts = opts or {}
    opts.mod_root = T.MOD_ROOT
    FG.install(opts)
    BSCopilot = nil
    dofile(T.MOD_ROOT .. '/main.lua')
    return FG
end

local function run_until(FG, pred, max_frames)
    for _ = 1, max_frames or 3000 do
        FG.frames(1, 0.05)
        if pred() then return true end
    end
    return false
end

function S.main_loads_and_installs_hooks(T)
    local FG = load_fake()
    T.ok(BSCopilot and BSCopilot.controller, 'controller created')
    T.ok(BSCopilot.hooks.update and BSCopilot.hooks.draw and BSCopilot.hooks.calculate and BSCopilot.hooks.keys)
    T.eq(#FG.calls.keybinds, 3)
    T.eq(FG.calls.keybinds[1].key_pressed, 'c')
    T.ok(type(SMODS.current_mod.config_tab) == 'function', 'config tab registered')
    local tab = SMODS.current_mod.config_tab()
    T.ok(tab.n == G.UIT.ROOT)
    FG.uninstall()
end

function S.first_real_recommendation(T)
    local FG = load_fake({ required = 300 })
    local Ctl = BSCopilot.controller
    T.ok(run_until(FG, function() return Ctl.results.hand ~= nil end), 'hand analysis completes')
    local r = Ctl.results.hand
    T.ok(r.best_play, 'has a best play')
    T.eq(r.best_play.hand, 'Pair') -- Ah Ad is the only pair
    T.eq(r.best_play.mean, 64)
    T.ok(r.recommendation and r.round and r.round.p_clear >= 0 and r.round.p_clear <= 1)
    -- the original game functions still run
    T.ok(FG.calls.game_update > 0)
    FG.uninstall()
end

function S.overlay_draws_without_touching_game(T)
    local FG = load_fake()
    local Ctl = BSCopilot.controller
    run_until(FG, function() return Ctl.results.hand ~= nil end)
    Ctl.toggle_panel()
    Game.draw(G)
    T.eq(FG.calls.game_draw, 1, 'original draw called once')
    local printed = 0
    for _, c in ipairs(FG.calls.draw) do if c:find('^print:') then printed = printed + 1 end end
    T.ok(printed >= 5, 'panel printed text lines: ' .. printed)
    T.eq(FG.calls.draw[1], 'push')
    T.eq(FG.calls.draw[#FG.calls.draw], 'pop')
    FG.uninstall()
end

function S.selection_is_scored_exactly(T)
    local FG = load_fake()
    local Ctl = BSCopilot.controller
    run_until(FG, function() return Ctl.state ~= nil end)
    G.hand.highlighted = { G.hand.cards[1], G.hand.cards[2] }
    FG.frames(5, 0.05)
    T.ok(Ctl.selection, 'selection evaluated')
    T.eq(Ctl.selection.hand, 'Pair'); T.eq(Ctl.selection.mean, 64); T.ok(Ctl.selection.exact)
    FG.uninstall()
end

function S.calculate_hook_returns_nothing(T)
    local FG = load_fake()
    local mod = SMODS.current_mod
    local contexts = {
        { before = true, full_hand = { G.hand.cards[1], G.hand.cards[2] }, scoring_name = 'Pair' },
        { individual = true, cardarea = G.hand, other_card = G.hand.cards[1] },
        { buying_card = true, card = FG.joker('j_joker', 'Joker', { mult = 4 }) },
        { end_of_round = true, game_over = true },
        { mod_probability = true, numerator = 1, denominator = 4 },
        'not a table',
    }
    for _, ctx in ipairs(contexts) do
        local r1, r2 = mod.calculate(mod, ctx)
        T.eq(r1, nil); T.eq(r2, nil)
    end
    T.ok(#BSCopilot.controller.events >= 3)
    FG.uninstall()
end

function S.survives_broken_game_state(T)
    local FG = load_fake()
    G.hand = nil
    G.GAME.hands = 'garbage'
    local ok, err = pcall(FG.frames, 30, 0.05)
    T.ok(ok, 'update never raises: ' .. tostring(err))
    local ok2 = pcall(Game.draw, G)
    T.ok(ok2, 'draw never raises')
    FG.uninstall()
end

function S.no_game_action_is_ever_called(T)
    -- the mod must not call any G.FUNCS action: replace them all with tripwires
    local FG = load_fake()
    local tripped = {}
    for _, name in ipairs({ 'play_cards_from_highlighted', 'discard_cards_from_highlighted', 'buy_from_shop', 'sell_card',
        'reroll_shop', 'use_card', 'select_blind', 'skip_blind', 'cash_out', 'toggle_shop', 'end_consumeable' }) do
        G.FUNCS[name] = function() tripped[#tripped + 1] = name end
    end
    local hand_fn = {}
    G.hand.add_to_highlighted = function() hand_fn[#hand_fn + 1] = 'highlight' end
    local Ctl = BSCopilot.controller
    run_until(FG, function() return Ctl.results.hand ~= nil end)
    Ctl.toggle_panel(); Game.draw(G)
    T.eq(#tripped, 0, 'no action function called')
    T.eq(#hand_fn, 0, 'no card selected by the mod')
    FG.uninstall()
end

return S
