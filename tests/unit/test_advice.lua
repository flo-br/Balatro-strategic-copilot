-- engine/advice.lua: ONE step at a time, for every situation the player asked about (buy,
-- replace, sell, reroll, next blind, consumables, packs, skip or play a blind, joker order).
-- Results are built by hand: what is tested is the decision layer, not the analyses.
local T = ...
local S = {}

local function A() return BSCopilot.require('engine/advice') end

local function state(o)
    o = o or {}
    return {
        phase = o.phase or 'shop',
        econ = { dollars = o.dollars or 10, bankrupt_at = 0, reroll_cost = 5 },
        jokers = o.jokers or {}, joker_slots = 5,
        consumables = o.consumables or {}, consumable_slots = o.consumable_slots or 2,
        vouchers = o.vouchers or {}, hand_cards = o.hand or {}, blind = o.blind or {},
    }
end

local function shop_result(o)
    o = o or {}
    return { options = o.options or {}, sells = o.sells or {}, reroll = o.reroll,
        base = { p_next = 0.9, p_boss = 0.7 }, next_blind = { chips = 800 }, boss = { name = 'The Hook' } }
end

local function card(uid, id, suit, extra)
    local c = { uid = uid, id = id, suit = suit, nominal = math.min(10, id) }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

function S.shop_buys_the_best_affordable_item(T)
    local st = A().shop_step(state({ dollars = 10 }), shop_result({ options = {
        { kind = 'joker', uid = 'duo', name = 'The Duo', cost = 8, note = 78, affordable = true, reasons = { 'paires' } },
        { kind = 'joker', uid = 'cc', name = 'Credit Card', cost = 1, note = 40, affordable = true } } }))
    T.eq(st.action, 'buy'); T.eq(st.label, 'À PRENDRE'); T.eq(st.targets[1], 'duo'); T.eq(st.note, 78)
end

function S.shop_skips_unaffordable_then_takes_next(T)
    local st = A().shop_step(state({ dollars = 6 }), shop_result({ options = {
        { kind = 'joker', uid = 'duo', name = 'The Duo', cost = 8, note = 78 },
        { kind = 'planet', uid = 'pl', name = 'Mercury', cost = 3, note = 62 } } }))
    T.eq(st.action, 'buy'); T.eq(st.targets[1], 'pl')
end

function S.shop_replacement_sells_first(T)
    local jokers = { { uid = 'j1', name = 'Joker', sell_cost = 2 }, { uid = 'j2', name = 'Banner', sell_cost = 3 } }
    local st = A().shop_step(state({ dollars = 5, jokers = jokers }), shop_result({ options = {
        { kind = 'replace', uid = 'duo', name = 'The Duo', cost = 5, note = 74, replace_index = 2, replaces = 'Banner' } } }))
    T.eq(st.action, 'sell'); T.eq(st.label, 'À VENDRE'); T.eq(st.targets[1], 'j2')
    T.ok(st.text:find('Banner', 1, true) and st.text:find('The Duo', 1, true), st.text)
end

function S.shop_full_consumables_make_room(T)
    local cons = { { uid = 'c1', key = 'c_tower', set = 'Tarot', name = 'The Tower' }, { uid = 'c2', key = 'c_judgement', set = 'Tarot', name = 'Judgement' } }
    local st = A().shop_step(state({ dollars = 10, consumables = cons }), shop_result({ options = {
        { kind = 'tarot', uid = 'emp', name = 'The Empress', cost = 3, note = 66 } } }))
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'c1', 'weakest consumable sold to make room')
end

function S.shop_sells_a_useless_joker_only(T)
    local res = shop_result({ sells = { { uid = 'j1', name = 'Mystic Summit', sell = 3, note = 66, contribution = 0.01 } } })
    local st = A().shop_step(state(), res)
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'j1')
    res.sells[1].contribution = 0.12 -- brings 12 % of the score: keep it
    st = A().shop_step(state(), res)
    T.eq(st.action, 'next_round')
end

function S.shop_reroll_then_next_blind(T)
    local res = shop_result({ reroll = { cost = 5, worth = true, p_improve = 0.55 } })
    local st = A().shop_step(state({ dollars = 12 }), res)
    T.eq(st.action, 'reroll'); T.eq(st.label, 'RELANCER'); T.eq(st.button, 'reroll')
    st = A().shop_step(state({ dollars = 3 }), res)
    T.eq(st.action, 'next_round', 'cannot pay the reroll')
    T.eq(st.label, 'BLINDE SUIVANTE'); T.eq(st.button, 'next_round')
end

function S.shop_waits_for_the_complete_analysis(T)
    T.eq(A().shop_step(state(), shop_result({}), nil, true), nil)
end

function S.planets_are_used_unless_observatory(T)
    local cons = { { uid = 'p1', key = 'c_jupiter', set = 'Planet', name = 'Jupiter', hand_type = 'Flush' } }
    local st = A().shop_step(state({ consumables = cons }), shop_result({}))
    T.eq(st.action, 'use'); T.eq(st.label, 'UTILISER'); T.eq(st.targets[1], 'p1')
    st = A().shop_step(state({ consumables = cons, vouchers = { v_observatory = true } }), shop_result({}))
    T.eq(st.action, 'next_round', 'kept: Observatory gives x1.5 while held')
end

function S.money_tarots(T)
    local st = A().shop_step(state({ dollars = 14, consumables = { { uid = 'h', key = 'c_hermit', set = 'Tarot', name = 'The Hermit' } } }), shop_result({}))
    T.eq(st.action, 'use'); T.ok(st.why:find('14', 1, true), st.why)
    st = A().shop_step(state({ dollars = 2, consumables = { { uid = 'h', key = 'c_hermit', set = 'Tarot', name = 'The Hermit' } } }), shop_result({}))
    T.eq(st.action, 'next_round', 'not worth with 2 $')
end

function S.hand_play_and_discard_steps(T)
    local a, b, c = card('a', 14, 'Spades'), card('b', 14, 'Hearts'), card('c', 7, 'Clubs')
    local r = { remaining = 100, round = { p_clear = 0.8, lo = 0.7, hi = 0.9, method = 'monte_carlo' },
        recommendation = { type = 'play', ref = { cards = { a, b }, hand = 'Pair', mean = 64 } } }
    local st = A().hand_step(state({ phase = 'hand', hand = { a, b, c } }), r)
    T.eq(st.action, 'play'); T.eq(st.label, 'JOUER'); T.eq(#st.targets, 2); T.eq(st.p, 0.8)
    r.recommendation = { type = 'discard', cards = { c }, ref = { target = { name = 'Pair' } } }
    st = A().hand_step(state({ phase = 'hand', hand = { a, b, c } }), r)
    T.eq(st.action, 'discard'); T.eq(st.label, 'DÉFAUSSER'); T.eq(st.targets[1], 'c')
end

function S.tarot_used_on_the_cards_to_play(T)
    local a, b, c, d = card('a', 14, 'Spades'), card('b', 14, 'Hearts'), card('c', 3, 'Clubs'), card('d', 13, 'Spades')
    local r = { remaining = 100, round = { p_clear = 0.6 },
        recommendation = { type = 'play', ref = { cards = { a, b, d }, hand = 'Pair' } } }
    local st = A().hand_step(state({ phase = 'hand', hand = { a, b, c, d },
        consumables = { { uid = 'emp', key = 'c_empress', set = 'Tarot', name = 'The Empress' } } }), r)
    T.eq(st.action, 'use'); T.eq(st.targets[1], 'emp')
    T.eq(#st.use_on, 2, 'The Empress: 2 cards')
    local on = {}
    for _, u in ipairs(st.use_on) do on[u] = true end
    T.ok(on.a and on.b and not on.c, 'on the aces about to be played')
end

function S.luchador_against_a_dangerous_boss(T)
    local r = { remaining = 900, round = { p_clear = 0.45 }, recommendation = { type = 'play', ref = { cards = {} } } }
    local s = state({ phase = 'hand', jokers = { { uid = 'lu', key = 'j_luchador', name = 'Luchador' } },
        blind = { boss = true, key = 'bl_wall' } })
    local st = A().hand_step(s, r)
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'lu')
    r.round.p_clear = 0.95
    T.eq(A().hand_step(s, r).action, 'play', 'not needed when the boss is easy')
end

function S.invisible_joker_ready(T)
    local jokers = { { uid = 'inv', key = 'j_invisible', name = 'Invisible Joker', ability = { extra = 2, invis_rounds = 2 } },
        { uid = 'j', key = 'j_joker', name = 'Joker' } }
    local st = A().shop_step(state({ jokers = jokers }), shop_result({}))
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'inv')
    jokers[1].ability.invis_rounds = 1
    T.eq(A().shop_step(state({ jokers = jokers }), shop_result({})).action, 'next_round')
end

function S.pack_take_or_skip(T)
    local res = { options = { { kind = 'joker', uid = 'k', name = 'Blueprint', note = 82 }, { uid = 'x', note = 30 } } }
    local st = A().pack_step(state({ phase = 'pack' }), res)
    T.eq(st.action, 'take'); T.eq(st.label, 'À PRENDRE'); T.eq(st.targets[1], 'k')
    res.options[1].note = 41
    st = A().pack_step(state({ phase = 'pack' }), res)
    T.eq(st.action, 'skip_pack'); T.eq(st.label, 'PASSER'); T.eq(st.button, 'skip_pack')
end

function S.arcana_pack_tarot_with_targets(T)
    local hand = { card('a', 12, 'Hearts'), card('b', 12, 'Spades'), card('c', 2, 'Clubs') }
    local res = { options = { { kind = 'tarot', key = 'c_heirophant', uid = 'hier', name = 'The Hierophant', note = 64 } } }
    local st = A().pack_step(state({ phase = 'pack', hand = hand }), res)
    T.eq(st.action, 'take'); T.eq(#st.use_on, 2)
end

function S.blind_play_or_skip(T)
    local r = { current = { name = 'Small Blind', chips = 300 }, p_current = { p = 0.97, lo = 0.9, hi = 1 },
        skip = { recommended = true, tag = 'tag_investment', tag_value = 15, lost = 5, p_following = 0.9 } }
    local st = A().blind_step(state({ phase = 'blind_select' }), r)
    T.eq(st.action, 'skip_blind'); T.eq(st.label, 'PASSER'); T.eq(st.button, 'skip_blind')
    T.ok(st.why:find('investment', 1, true), st.why)
    r.skip.recommended = false
    st = A().blind_step(state({ phase = 'blind_select' }), r)
    T.eq(st.action, 'select_blind'); T.eq(st.label, 'JOUER'); T.eq(st.button, 'select_blind'); T.eq(st.p, 0.97)
    r.current = { name = 'The Hook', chips = 1600, boss = true }; r.skip = nil
    T.eq(A().blind_step(state({ phase = 'blind_select' }), r).action, 'select_blind', 'a boss cannot be skipped')
end

function S.order_marks_only_when_wrong(T)
    local s = state({ jokers = { { uid = 'duo', name = 'The Duo' }, { uid = 'jk', name = 'Joker' } } })
    local om = A().order_marks(s, { order = { 2, 1 }, gain = 0.25, names = { 'Joker', 'The Duo' } })
    T.ok(om, 'x2 before +4 Mult: reorder')
    T.eq(om.marks[1].uid, 'jk'); T.eq(om.marks[1].pos, 1)
    T.eq(om.marks[2].uid, 'duo'); T.eq(om.marks[2].pos, 2)
    T.eq(A().order_marks(s, { order = { 1, 2 }, gain = 0 }), nil, 'already right')
    T.eq(A().order_marks(s, { order = { 2, 1 }, gain = 0.002 }), nil, 'negligible gain')
    T.eq(A().order_marks(s, nil), nil)
end

return S
