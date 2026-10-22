-- "Mon choix" (1.0.12): the player's corrections. The copilot only READS what the player
-- highlighted, learns bounded preferences from it, and the box keeps every key from the game.
local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    return F, BSCopilot.require('learning/feedback'), BSCopilot.require('game/feedback_input'), BSCopilot.require('learning/learning')
end

local function shop_state(F, highlight)
    local s = F.state({ dollars = 20, ante = 3, stake = 4, jokers = { F.joker('j_joker') } })
    s.phase = 'shop'
    s.shop = { jokers = {
        { uid = 'duo', set = 'Joker', key = 'j_duo', name = 'The Duo', cost = 8, joker = F.joker('j_duo') },
        { uid = 'holo', set = 'Joker', key = 'j_hologram', name = 'Hologram', cost = 7, joker = F.joker('j_hologram'), highlighted = highlight or nil },
    }, vouchers = {}, boosters = { { uid = 'buf', set = 'Booster', key = 'p_buffoon_normal_1', name = 'Buffoon Pack', kind = 'Buffoon', cost = 4 } } }
    return s
end

local ADVICE_DUO = { action = 'buy', label = 'PRENDRE', text = 'Acheter The Duo (8 $)', targets = { 'duo' } }

-- with the runtime of the game: the profile whose corrections count
local function with_profile(prof, f)
    local was = BSCopilot.learning_runtime
    BSCopilot.learning_runtime = { profile = function() return prof end, player_feedback = function()
        return (prof.feedback and (prof.feedback.count or 0) > 0) and prof or nil end }
    local ok, err = pcall(f)
    BSCopilot.learning_runtime = was
    if not ok then error(err, 0) end
end

function S.capture_reads_what_the_player_highlighted(T)
    local F, FB = env()
    local ctx = FB.capture(shop_state(F, true), 'shop', ADVICE_DUO)
    T.ok(ctx, 'context')
    T.eq(ctx.advice.item.key, 'j_duo', 'the advice: The Duo')
    T.eq(#ctx.selected, 1); T.eq(ctx.selected[1].key, 'j_hologram')
    T.eq(ctx.choices[1].kind, 'buy'); T.ok(ctx.choices[1].label:find('Hologram', 1, true), ctx.choices[1].label)
    local kinds = {}
    for _, c in ipairs(ctx.choices) do kinds[c.kind] = true end
    T.ok(kinds.leave and kinds.reroll, 'leaving and rerolling are always choices in the shop')
    -- in hand: nothing highlighted, nothing to confirm
    local s = F.state({ hand_cards = { F.card and F.card('Ah') or BSCopilot.require('model/cards').parse('Ah') } })
    local none, why = FB.capture(s, 'hand', nil)
    T.eq(none, nil); T.eq(why, 'nothing_selected')
    -- cards highlighted: play them or discard them
    local C = BSCopilot.require('model/cards')
    local cards = C.parse_list('Ah Ad 7c')
    cards[1].highlighted = true; cards[2].highlighted = true
    local hc = FB.capture(F.state({ hand_cards = cards }), 'hand', { action = 'play', label = 'JOUER', text = 'Jouer', cards = { cards[3] } })
    T.eq(hc.choices[1].kind, 'play'); T.eq(hc.choices[2].kind, 'discard')
    T.ok(hc.choices[1].label:find('A', 1, true), hc.choices[1].label)
end

function S.corrections_learn_bounded_preferences(T)
    local F, FB, _, LE = env()
    local prof = LE.new_profile(0)
    local ctx = FB.capture(shop_state(F, true), 'shop', ADVICE_DUO)
    local changes = FB.record(prof, { ctx = ctx, choice = ctx.choices[1], reason = 'synergy', text = 'Riff-raff me donne des jokers' }, 100)
    local d = prof.feedback
    T.eq(d.items.j_hologram, 4, 'chosen +4'); T.eq(d.items.j_duo, -4, 'advised instead -4')
    T.eq(d.reasons.synergy, 1)
    T.ok(#changes >= 2, table.concat(changes, ', '))
    -- bounded, whatever the number of corrections
    for _ = 1, 10 do FB.record(prof, { ctx = ctx, choice = ctx.choices[1], reason = 'synergy' }, 101) end
    T.eq(d.items.j_hologram, FB.ITEM_CAP); T.eq(d.items.j_duo, -FB.ITEM_CAP)
    local nd = FB.nudges(prof)
    T.ok(nd.synergy > 1 and nd.synergy <= 1.5, 'synergies weigh more, bounded: ' .. tostring(nd.synergy))
    -- the text is kept, cut to 200 characters, control characters removed
    FB.record(prof, { ctx = ctx, choice = ctx.choices[1], reason = 'other', text = ('a'):rep(300) .. '\n' }, 102)
    T.eq(#d.entries[#d.entries].text, FB.MAX_TEXT)
    -- money: "keep it" and "spend it" cancel out
    local p2 = LE.new_profile(0)
    FB.record(p2, { ctx = ctx, choice = ctx.choices[1], reason = 'economy' }, 1)
    FB.record(p2, { ctx = ctx, choice = ctx.choices[1], reason = 'spend' }, 2)
    T.eq(FB.nudges(p2).interest, nil)
    -- reset
    FB.reset(prof)
    T.eq(prof.feedback.count, 0); T.eq(next(prof.feedback.items), nil)
    T.eq(next(FB.nudges(prof)), nil, 'no correction, no effect')
end

function S.the_shop_notes_follow_the_corrections(T)
    local F, FB, _, LE = env()
    local C = BSCopilot.require('model/cards')
    local SH = BSCopilot.require('engine/shop')
    local function note_of(prof)
        local s = shop_state(F, false)
        s.full_deck = C.standard_deck()
        s.round.round_hands, s.round.round_discards, s.round.hand_size = 4, 3, 8
        local holo, reasons
        with_profile(prof, function()
            local r = SH.analyse(s, { n = 16 })
            for _, o in ipairs(r.options) do if o.key == 'j_hologram' then holo, reasons = o.note, o.reasons end end
        end)
        return holo, reasons
    end
    local prof = LE.new_profile(0)
    local before = note_of(prof)
    local ctx = FB.capture(shop_state(F, true), 'shop', ADVICE_DUO)
    FB.record(prof, { ctx = ctx, choice = ctx.choices[1], reason = 'other' }, 1)
    local after, reasons = note_of(prof)
    T.ok(after > before, string.format('Hologram %d -> %d', before, after))
    local shown = false
    for _, r in ipairs(reasons or {}) do if tostring(r):find('vos choix', 1, true) then shown = true end end
    T.ok(shown, 'the reason says it')
end

function S.the_box_keeps_every_key_from_the_game(T)
    local F, FB, FI, LE = env()
    local prof = LE.new_profile(0)
    local got = {}
    local old_love = love
    love = { keypressed = function(k) got[#got + 1] = 'key:' .. k end, keyreleased = function(k) got[#got + 1] = 'up:' .. k end,
        textinput = function(t) got[#got + 1] = 'text:' .. t end }
    local ok, err = pcall(function()
        local saved
        FI.on_saved = function(ch) saved = ch end
        with_profile(prof, function()
            T.ok(FI.open(shop_state(F, true), 'shop', ADVICE_DUO))
            -- every key goes to the box, none to the game (typing "r" never restarts the run)
            love.keypressed('1')          -- choice 1: buy Hologram
            T.eq(FI.active.stage, 'reason')
            love.keypressed('1')          -- reason 1: synergy
            T.eq(FI.active.stage, 'text')
            love.keypressed('r'); love.textinput('r'); love.textinput('é'); love.keyreleased('r')
            T.eq(FI.active.text, 'ré')
            love.keypressed('backspace')
            T.eq(FI.active.text, 'r', 'a UTF-8 character removed whole')
            love.textinput('iff')
            love.keypressed('return')
        end)
        T.eq(#got, 0, 'the game received nothing: ' .. table.concat(got, ' '))
        T.eq(FI.active, nil, 'closed')
        T.ok(saved, 'saved')
        T.eq(prof.feedback.entries[1].text, 'riff')
        T.eq(prof.feedback.entries[1].reason, 'synergy')
        -- closed: the keys go to the game again
        love.keypressed('c')
        T.eq(got[1], 'key:c')
        -- Escape closes without saving
        with_profile(prof, function()
            FI.open(shop_state(F, true), 'shop', ADVICE_DUO)
            love.keypressed('escape')
        end)
        T.eq(FI.active, nil); T.eq(#prof.feedback.entries, 1)
    end)
    love = old_love
    FI.active = nil; FI.hooks = nil; FI.on_saved = nil
    if not ok then error(err, 0) end
end

function S.text_file_line_and_review(T)
    local F, FB, _, LE = env()
    local prof = LE.new_profile(0)
    local ctx = FB.capture(shop_state(F, true), 'shop', ADVICE_DUO)
    local _, kept = FB.record(prof, { ctx = ctx, choice = ctx.choices[1], reason = 'xmult', text = 'il grandit vite' }, 1000)
    local line = FB.export_line(kept)
    T.ok(line:find('mon choix : Acheter Hologram', 1, true), line)
    T.ok(line:find('il grandit vite', 1, true), line)
    T.ok(line:find('The Duo', 1, true), line)
    -- the review lists the corrections of the run
    local RV = BSCopilot.require('learning/review')
    local lines = RV.panel(nil, { result = 'loss', ante = 4, causes = {}, mistakes = {}, tips = {}, successes = {},
        feedback = FB.run_entries(prof, 0), feedback_summary = FB.summary(prof) }, false)
    local all = {}
    for _, l in ipairs(lines) do for _, sg in ipairs(l) do all[#all + 1] = sg.t end end
    local txt = table.concat(all, ' ')
    T.ok(txt:find('Hologram', 1, true) and txt:find('il grandit vite', 1, true), txt)
    -- the shop's x Mult urgency follows "il me faut du ×Mult"
    local PL = BSCopilot.require('engine/plan')
    with_profile(prof, function() T.ok(PL.lesson('xmult') > 1, 'x Mult more urgent') end)
end

return S
