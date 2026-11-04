-- "Je joue, tu apprends" (1.0.14): the player plays, the copilot compares each action with the
-- step it would have advised for that state and learns from the differences (bounded).
local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    return F, BSCopilot.require('learning/feedback'), BSCopilot.require('learning/observe'), BSCopilot.require('learning/learning')
end

local function shop_state(F, dollars)
    local s = F.state({ dollars = dollars or 30, ante = 3, stake = 7, jokers = { F.joker('j_joker') } })
    s.phase = 'shop'
    s.shop = { jokers = {
        { uid = 'duo', set = 'Joker', key = 'j_duo', name = 'The Duo', cost = 8, joker = F.joker('j_duo') },
        { uid = 'holo', set = 'Joker', key = 'j_hologram', name = 'Hologram', cost = 7, joker = F.joker('j_hologram') },
    }, vouchers = {}, boosters = { { uid = 'buf', set = 'Booster', key = 'p_buffoon_normal_1', name = 'Buffoon Pack', kind = 'Buffoon', cost = 4 } } }
    return s
end

local BUY_DUO = { action = 'buy', label = 'À PRENDRE', text = 'Acheter The Duo (8 $)', targets = { 'duo' } }

function S.a_choice_unlike_the_advice_is_learned(T)
    local F, FB, OB, LE = env()
    local prof = LE.new_profile(0)
    local s = shop_state(F)
    OB.last.shop = { step = BUY_DUO, state = s }
    -- the player buys Hologram where the copilot advised The Duo
    local o = OB.on_event({ kind = 'buying_card', uid = 'holo', key = 'j_hologram' }, s)
    T.ok(o and o.action == 'buy' and o.item.key == 'j_hologram', 'observation')
    local changes, kept, agreed = FB.observe(prof, o, 10)
    T.ok(kept and not agreed, 'learned')
    T.eq(prof.feedback.items.j_hologram, FB.OBS_ITEM_STEP); T.eq(prof.feedback.items.j_duo, -FB.OBS_ITEM_STEP)
    T.ok(table.concat(changes, ' '):find('Hologram', 1, true), table.concat(changes, ' '))
    T.eq(kept.reason, 'observed')
    T.ok(FB.export_line(kept):find('observé', 1, true), FB.export_line(kept))
    -- half the weight of a correction with the X key, same bounds
    for _ = 1, 20 do FB.observe(prof, OB.on_event({ kind = 'buying_card', uid = 'holo' }, s), 11) end
    T.eq(prof.feedback.items.j_hologram, FB.ITEM_CAP)
    -- the same purchase as the advice: counted, nothing learned
    local before = prof.feedback.items.j_duo
    local _, k2, ag2 = FB.observe(prof, OB.on_event({ kind = 'buying_card', uid = 'duo' }, s), 12)
    T.ok(ag2 and not k2); T.eq(prof.feedback.items.j_duo, before)
    T.ok(prof.feedback.observed.agree >= 1 and prof.feedback.observed.seen >= 22)
    -- an advice computed for another state is never used
    T.eq(OB.on_event({ kind = 'buying_card', uid = 'holo' }, shop_state(F)), nil)
end

function S.money_habits_leave_and_reroll(T)
    local F, FB, OB, LE = env()
    local prof = LE.new_profile(0)
    local s = shop_state(F, 12)
    -- the copilot advised The Duo, the player left with the money
    OB.last.shop = { step = BUY_DUO, state = s }
    local o = OB.on_state(s, { phase = 'blind_select' })
    T.eq(o.action, 'leave')
    FB.observe(prof, o, 1)
    T.eq(prof.feedback.items.j_duo, -FB.OBS_ITEM_STEP)
    T.eq(prof.feedback.reasons.economy, FB.OBS_MONEY)
    -- the copilot advised to keep the money, the player rerolled
    OB.last.shop = { step = { action = 'next_round', label = 'BLINDE SUIVANTE', text = '' }, state = s }
    FB.observe(prof, OB.on_event({ kind = 'reroll_shop' }, s), 2)
    T.eq(prof.feedback.reasons.spend, FB.OBS_MONEY)
    -- keep and spend cancel out in the interest nudge
    T.eq(FB.nudges(prof).interest, nil)
    -- leaving when the advice was to leave: agreement
    local _, kept, agreed = FB.observe(prof, OB.on_state(s, { phase = 'blind_select' }), 3)
    T.ok(agreed and not kept)
end

function S.plays_are_counted_not_learned(T)
    local F, FB, OB, LE = env()
    local prof = LE.new_profile(0)
    local s = F.state({ hand_cards = BSCopilot.require('model/cards').parse_list('Ah Ad 7c 2s') })
    s.phase = 'hand'
    OB.last.hand = { step = { action = 'play', label = 'JOUER', targets = { s.hand_cards[1].uid, s.hand_cards[2].uid } }, state = s }
    local _, _, agreed = FB.observe(prof, OB.on_event({ kind = 'before', uids = { s.hand_cards[2].uid, s.hand_cards[1].uid } }, s), 1)
    T.ok(agreed, 'same cards in another order: the same play')
    local _, kept = FB.observe(prof, OB.on_event({ kind = 'pre_discard', uids = { s.hand_cards[3].uid } }, s), 2)
    T.eq(kept, nil, 'a discard instead of the play: counted only')
    local ob = prof.feedback.observed
    T.eq(ob.by.hand.seen, 2); T.eq(ob.by.hand.agree, 1); T.eq(next(prof.feedback.items), nil)
end

function S.the_runtime_learns_only_in_the_mode(T)
    local F, FB, OB = env()
    local RT = BSCopilot.require('learning/runtime')
    local was_store, was_lr = BSCopilot.store, BSCopilot.learning_runtime
    BSCopilot.store = nil
    local listener, learned
    local Ctl = { on = function(f) listener = f end, register = function() end, results = {}, state = nil,
        on_observed = function(ch) learned = ch end }
    local ok, err = pcall(function()
        RT.attach(Ctl)
        T.eq(RT.observe_on(), false, 'off by default')
        local s = shop_state(F, 30)
        local r = { options = { { kind = 'joker', uid = 'duo', name = 'The Duo', key = 'j_duo', cost = 8, note = 80 } }, sells = {},
            base = { p_next = 0.99, p_boss = 0.95 }, next_blind = { chips = 300 }, boss = { name = 'The Hook' } }
        -- off: nothing learned
        Ctl.state = s
        listener('analysis', { phase = 'shop', result = r, state = s })
        listener('event', { kind = 'buying_card', uid = 'holo' })
        T.eq(next((RT.profile().feedback or {}).items or {}), nil, 'mode off: nothing learned')
        -- on: the advice of that state (buy The Duo) against the purchase of Hologram
        T.eq(RT.set_observe(true), true)
        listener('analysis', { phase = 'shop', result = r, state = s })
        listener('event', { kind = 'buying_card', uid = 'holo' })
        T.eq(RT.profile().feedback.items.j_hologram, FB.OBS_ITEM_STEP)
        T.ok(learned and table.concat(learned, ' '):find('Hologram', 1, true), 'told to the player')
        T.eq(RT.observed_stats().learned, 1)
        RT.set_observe(false)
        T.eq(RT.observe_on(), false)
    end)
    BSCopilot.store, BSCopilot.learning_runtime = was_store, was_lr
    OB.last = {}
    if not ok then error(err, 0) end
end

return S
