-- The step as the player sees it: label above the right game object or button, joker order
-- numbers, The House (every card face down). UI trees are simulated like the game builds them
-- (box.UIRoot.children, node.config.button / node.config.id, node.T).
local T = ...
local S = {}

local function boot(opts)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    opts = opts or {}
    opts.mod_root = T.MOD_ROOT
    FG.install(opts)
    BSCopilot = nil
    dofile(T.MOD_ROOT .. '/main.lua')
    BSCopilot.config.ui.show_badges = true
    return FG, BSCopilot.controller
end

local function settle(FG, Ctl, phase, n)
    for _ = 1, n or 20000 do
        FG.frames(1, 0.05)
        if Ctl.results[phase] and not Ctl.partial[phase] then return true end
    end
    return false
end

local function node(t) return t end
local function button(fn, id, x, y) return node({ config = { button = fn, id = id }, T = { x = x, y = y, w = 2, h = 0.8 }, children = {} }) end

local function badge_with(m, text)
    for _, b in ipairs(m.badges or {}) do if b.text:find(text, 1, true) then return b end end
end

function S.next_blind_label_on_the_shop_button(T)
    local FG, Ctl = boot({ state = 5, dollars = 1, shop = {} })
    local nb = button('toggle_shop', 'next_round_button', 3, 9)
    G.shop = { UIRoot = node({ config = {}, children = { node({ config = {}, children = { nb, button('reroll_shop', nil, 6, 9) } }) } }) }
    T.ok(settle(FG, Ctl, 'shop'), 'shop analysis')
    local m = Ctl.ui_model()
    T.ok(m.lines[1][2].t:find('BLINDE SUIVANTE', 1, true), 'step line first')
    local b = badge_with(m, 'BLINDE SUIVANTE')
    T.ok(b, 'label on a button')
    local s = G.TILESCALE * G.TILESIZE
    T.eq(b.x, (3 + G.ROOM.T.x) * s, 'above next_round_button')
    FG.uninstall()
end

function S.missing_button_is_logged_and_text_kept(T)
    local FG, Ctl = boot({ state = 5, dollars = 1, shop = {} })
    G.shop = { UIRoot = node({ config = {}, children = { button('something_else', 'other_id', 1, 1) } }) }
    T.ok(settle(FG, Ctl, 'shop'), 'shop analysis')
    local m = Ctl.ui_model()
    T.ok(not badge_with(m, 'BLINDE SUIVANTE'), 'no badge without the button')
    T.ok(m.compact_lines[1][2].t:find('BLINDE SUIVANTE', 1, true), 'the step stays in the summary')
    local logged = false
    for _, l in ipairs(BSCopilot.modules['core/log'].buffer) do
        if l:find('button next_round not found', 1, true) and l:find('something_else/other_id', 1, true) then logged = true end
    end
    T.ok(logged, 'buttons seen written to the log')
    FG.uninstall()
end

function S.skip_label_on_the_current_blind_column(T)
    local FG, Ctl = boot({ state = 7 })
    G.GAME.blind_on_deck = 'Big'
    local cols = {}
    for i, x in ipairs({ 2, 8, 14 }) do
        local kids = { button('select_blind', nil, x, 6) }
        if i < 3 then kids[2] = button('skip_blind', nil, x + 0.3, 10) end
        cols[i] = node({ config = {}, T = { x = x, y = 4, w = 5, h = 8 }, children = kids })
    end
    G.blind_select = { UIRoot = node({ config = {}, children = cols }) }
    -- a finished blind analysis recommending to skip (the decision itself is tested in test_advice)
    Ctl.refresh(true)
    Ctl.sched:cancel('blind_select')
    Ctl.results.blind_select = { current = { name = 'Big Blind', chips = 450 }, p_current = { p = 0.98, lo = 0.9, hi = 1 },
        skip = { recommended = true, tag = 'tag_investment', tag_value = 15, lost = 6, p_following = 0.92 } }
    Ctl.partial.blind_select = nil
    Ctl.result_ver = (Ctl.result_ver or 0) + 1
    local m = Ctl.ui_model()
    local b = badge_with(m, 'PASSER')
    T.ok(b, 'label on the skip button')
    local s = G.TILESCALE * G.TILESIZE
    T.eq(b.x, (8.3 + G.ROOM.T.x) * s, 'skip button of the Big Blind column')
    Ctl.results.blind_select.skip.recommended = false
    Ctl.result_ver = Ctl.result_ver + 1
    b = badge_with(Ctl.ui_model(), 'JOUER')
    T.ok(b and b.x == (8 + G.ROOM.T.x) * s, 'select button of the Big Blind column')
    FG.uninstall()
end

function S.joker_order_numbers_when_wrong(T)
    -- The Duo (x2 on a pair) BEFORE Joker (+4 Mult): the x2 would apply before the +4
    local FG2 = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    FG2.install({ mod_root = T.MOD_ROOT, required = 5000,
        jokers = { FG2.joker('j_duo', 'The Duo', { x_mult = 2, type = 'Pair' }), FG2.joker('j_joker', 'Joker', { mult = 4 }) } })
    BSCopilot = nil
    dofile(T.MOD_ROOT .. '/main.lua')
    BSCopilot.config.ui.show_badges = true
    local C2 = BSCopilot.controller
    T.ok(settle(FG2, C2, 'hand'), 'hand analysis')
    local om = C2.order_marks()
    T.ok(om, 'order to change')
    T.eq(om.marks[1].name, 'Joker'); T.eq(om.marks[2].name, 'The Duo')
    local m = C2.ui_model()
    local below = 0
    for _, b in ipairs(m.badges or {}) do if b.pos == 'below' then below = below + 1 end end
    T.eq(below, 2, 'a number under each joker')
    local found = false
    for _, l in ipairs(m.lines) do for _, sg in ipairs(l) do if sg.t:find('Ordre des jokers', 1, true) then found = true end end end
    T.ok(found, 'order line in the panel')
    -- once the player has put them in the right order, the numbers disappear
    G.jokers.cards[1], G.jokers.cards[2] = G.jokers.cards[2], G.jokers.cards[1]
    local first = tostring(G.jokers.cards[1].sort_id)
    T.eq(C2.order_marks() and #C2.order_marks().marks, 2, 'before the re-analysis, the numbers follow the analysed arrangement')
    local ok = false
    for _ = 1, 20000 do
        FG2.frames(1, 0.05)
        if C2.state and C2.state.jokers[1] and tostring(C2.state.jokers[1].uid) == first and C2.results.hand and not C2.partial.hand then ok = true; break end
    end
    T.ok(ok, 'reanalysed')
    T.eq(C2.order_marks(), nil, 'right order: no numbers')
    FG2.uninstall()
end

function S.the_house_all_face_down(T)
    local FG, Ctl = boot({ required = 300, deck = { '2s', '3s', '4s', '5s', '6s', '7s', '8s', '9h', 'Th', 'Jh', 'Qh', 'Kd', 'Ac', 'Ks', 'Qc',
        '4d', '6h', '8c', 'Jd', 'Tc' } })
    G.GAME.blind = { name = 'The House', chips = 300, boss = true, config = { blind = { key = 'bl_house' } } }
    for _, c in ipairs(G.hand.cards) do c.facing = 'back' end
    T.ok(settle(FG, Ctl, 'hand'), 'analysis completes')
    local r = Ctl.results.hand
    T.ok(not r.empty, 'no more "Aucune analyse disponible"')
    local m = Ctl.ui_model()
    local txt = ''
    for _, sg in ipairs(m.lines[1]) do txt = txt .. sg.t end
    T.ok(txt:find('cartes cachées', 1, true) or txt:find('carte cachée', 1, true), txt)
    local n = 0
    for _, b in ipairs(m.badges or {}) do if b.text == 'JOUER' or b.text == 'DÉFAUSSER' then n = n + 1 end end
    T.ok(n >= 1 and n <= 5, 'labels on hidden cards: ' .. n)
    FG.uninstall()
end

return S
