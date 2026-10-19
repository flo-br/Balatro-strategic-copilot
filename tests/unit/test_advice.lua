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
        -- o.rerolls: rerolls already paid in this shop (the price goes up by 1 $ each time)
        econ = { dollars = o.dollars or 10, bankrupt_at = 0, reroll_cost = 5 + (o.rerolls or 0), base_reroll_cost = 5,
            free_rerolls = o.free_rerolls or 0, interest_cap = 25 },
        run = { ante = o.ante or 1 },
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
    local cons = { { uid = 'c1', key = 'c_tower', set = 'Tarot', name = 'The Tower' }, { uid = 'c2', key = 'c_strength', set = 'Tarot', name = 'Strength' } }
    local st = A().shop_step(state({ dollars = 10, consumables = cons }), shop_result({ options = {
        { kind = 'tarot', uid = 'emp', name = 'The Empress', cost = 3, note = 66 } } }))
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'c1', 'weakest consumable sold to make room')
end

function S.shop_sells_a_useless_joker_only(T)
    local res = shop_result({ sells = { { uid = 'j1', name = 'Mystic Summit', sell = 3, note = 66, contribution = 0.01 } } })
    local st = A().shop_step(state(), res)
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'j1')
    res.sells[1].contribution = 0.12 -- brings 12 % of the score: keep it
    st = A().shop_step(state({ rerolls = 1 }), res)
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
    st = A().shop_step(state({ consumables = cons, vouchers = { v_observatory = true }, rerolls = 1 }), shop_result({}))
    T.eq(st.action, 'next_round', 'kept: Observatory gives x1.5 while held')
end

function S.money_tarots(T)
    -- The Hermit doubles the money up to +$20: used from $20 (top players)
    local st = A().shop_step(state({ dollars = 24, consumables = { { uid = 'h', key = 'c_hermit', set = 'Tarot', name = 'The Hermit' } } }), shop_result({}))
    T.eq(st.action, 'use'); T.ok(st.why:find('20', 1, true), st.why)
    st = A().shop_step(state({ dollars = 14, rerolls = 1, consumables = { { uid = 'h', key = 'c_hermit', set = 'Tarot', name = 'The Hermit' } } }), shop_result({}))
    T.eq(st.action, 'next_round', 'kept until $20')
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
    T.eq(A().shop_step(state({ jokers = jokers, rerolls = 1 }), shop_result({})).action, 'next_round')
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
    local r = { current = { name = 'Small Blind', chips = 300, slot = 'Small' }, p_current = { p = 0.97, lo = 0.9, hi = 1 },
        skip = { recommended = true, tag = 'tag_investment', tag_value = 15, lost = 5, p_following = 0.9 } }
    local st = A().blind_step(state({ phase = 'blind_select' }), r)
    T.eq(st.action, 'skip_blind'); T.eq(st.label, 'PASSER'); T.eq(st.button, 'skip_blind')
    T.ok(st.why:find('Investment Tag', 1, true), st.why)
    r.skip.recommended = false
    st = A().blind_step(state({ phase = 'blind_select' }), r)
    T.eq(st.action, 'select_blind'); T.eq(st.label, 'JOUER'); T.eq(st.button, 'select_blind'); T.eq(st.p, 0.97)
    r.current = { name = 'The Hook', chips = 1600, boss = true }; r.skip = nil
    T.eq(A().blind_step(state({ phase = 'blind_select' }), r).action, 'select_blind', 'a boss cannot be skipped')
end

function S.play_order_numbers(T)
    local a, k, q = card('a', 7, 'Spades'), card('k', 13, 'Hearts'), card('q', 12, 'Clubs')
    local s0 = state({ phase = 'hand', hand = { a, k, q } })
    local r = { remaining = 500, round = { p_clear = 0.8 }, recommendation = { type = 'play', ref = { cards = { a, k } },
        order = { play = { k, a }, held = { q }, gain = 0.3 } } }
    local st = A().hand_step(s0, r)
    T.eq(st.action, 'play')
    T.eq(st.target_labels.k, 'JOUER 1'); T.eq(st.target_labels.a, 'JOUER 2')
    T.eq(st.hold_labels.q, 'GARDER 1')
    T.ok(st.hint and st.hint:find('+30 %', 1, true), st.hint)
    r.recommendation.order = nil
    st = A().hand_step(s0, r)
    T.eq(st.target_labels, nil, 'no numbers when the order does not matter')
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

-- Targets of tarots / spectrals -------------------------------------------------------------
local function deck_of(list)
    local d = {}
    for i, c in ipairs(list) do d[i] = c end
    return d
end

function S.death_left_becomes_right(T)
    -- model: the King of the main suit with an enhancement; victim: a lone 2 of another suit
    local k = card('k', 13, 'Hearts', { enh = 'm_mult', mult = 4, pos_x = 1 })
    local two = card('two', 2, 'Clubs', { pos_x = 5 })
    local q = card('q', 12, 'Hearts', { pos_x = 3 })
    local hand = { k, q, two }
    local full = deck_of(hand)
    for i = 1, 8 do full[#full + 1] = card('h' .. i, 9, 'Hearts') end
    local s0 = state({ phase = 'hand', hand = hand, consumables = { { uid = 'death', key = 'c_death', set = 'Tarot', name = 'Death' } } })
    s0.full_deck = full
    local r = { remaining = 500, round = { p_clear = 0.6 }, recommendation = { type = 'play', ref = { cards = { k, q } } } }
    local st = A().hand_step(s0, r)
    T.eq(st.action, 'use'); T.eq(st.targets[1], 'death')
    T.eq(st.use_on[1], 'two', 'the weak 2 is converted'); T.eq(st.use_on[2], 'k', 'into the enhanced King')
    T.eq(st.use_labels.two, 'DEVIENT (gauche)'); T.eq(st.use_labels.k, 'MODÈLE (droite)')
    T.ok(st.hint and st.hint:find('gauche', 1, true), 'the 2 is right of the King: drag it left first')
    two.pos_x = 0
    T.eq(A().hand_step(s0, r).hint, nil, 'already in the right order')
end

function S.strength_hanged_man_and_seals(T)
    local A_ = A()
    local IT = BSCopilot.require('model/items_db')
    local hand = { card('a', 7, 'Spades'), card('b', 2, 'Clubs'), card('c', 13, 'Hearts', { enh = 'm_glass', x_mult = 2 }) }
    local s0 = state({ hand = hand })
    s0.full_deck = deck_of(hand)
    for i = 1, 30 do s0.full_deck[#s0.full_deck + 1] = card('e' .. i, 8, 'Hearts') end -- many 8s
    local t = A_.targets(IT.consumable('c_strength'), s0, hand, {})
    T.eq(t.cards[1].uid, 'a', 'Strength: the 7 becomes an 8 (most common rank)')
    t = A_.targets(IT.consumable('c_hanged_man'), s0, hand, {})
    T.eq(#t.cards, 2); T.ok(t.cards[1].uid ~= 'c' and t.cards[2].uid ~= 'c', 'never destroys the glass King')
    t = A_.targets(IT.consumable('c_deja_vu'), s0, hand, {})
    T.eq(t.cards[1].uid, 'c', 'red seal (retrigger) on the best scoring card')
    t = A_.targets(IT.consumable('c_medium'), s0, hand, {})
    T.eq(t.cards[1].uid, 'b', 'purple seal on a card to discard')
    local small = state({ hand = hand }); small.full_deck = deck_of(hand)
    T.eq(A_.targets(IT.consumable('c_hanged_man'), small, hand, {}), nil, 'no thinning below 20 cards')
end

function S.magician_and_chariot_targets(T)
    local A_ = A()
    local IT = BSCopilot.require('model/items_db')
    local a, b, c, d = card('a', 14, 'Spades'), card('b', 14, 'Hearts'), card('c', 13, 'Clubs'), card('d', 5, 'Spades')
    local s0 = state({ hand = { a, b, c, d } }); s0.full_deck = { a, b, c, d }
    local t = A_.targets(IT.consumable('c_magician'), s0, { a, b, c, d }, { play_cards = { a, b } })
    T.eq(#t.cards, 2); T.ok((t.cards[1] == a or t.cards[1] == b) and (t.cards[2] == a or t.cards[2] == b), 'lucky on the played aces')
    t = A_.targets(IT.consumable('c_chariot'), s0, { a, b, c, d }, { play_cards = { a, b } })
    T.eq(t.cards[1], c, 'steel on the King that stays in hand')
end

function S.free_consumables(T)
    local s0 = state({ consumables = { { uid = 'j', key = 'c_judgement', set = 'Tarot', name = 'Judgement' } }, rerolls = 1 })
    local st = A().shop_step(s0, shop_result({}))
    T.eq(st.action, 'use'); T.eq(st.targets[1], 'j')
    s0.jokers = { {}, {}, {}, {}, {} }
    T.eq(A().shop_step(s0, shop_result({})).action, 'next_round', 'no joker slot: keep it')
end

function S.pack_death_with_targets(T)
    local k = card('k', 13, 'Hearts', { enh = 'm_mult', mult = 4 })
    local two = card('two', 2, 'Clubs')
    local s0 = state({ phase = 'pack', hand = { two, k } }); s0.full_deck = { two, k }
    local res = { options = { { kind = 'tarot', key = 'c_death', uid = 'death', name = 'Death', note = 61 } } }
    local st = A().pack_step(s0, res)
    T.eq(st.action, 'take'); T.eq(st.label, 'À PRENDRE'); T.eq(st.targets[1], 'death')
    T.eq(st.use_on[1], 'two'); T.eq(st.use_on[2], 'k')
end

function S.blind_waits_for_final_decision(T)
    local r = { current = { name = 'Small Blind', chips = 300 }, p_current = { p = 0.97 } }
    T.eq(A().step('blind_select', state({ phase = 'blind_select' }), r, nil, true), nil, 'partial: nothing shown yet')
    T.ok(A().step('blind_select', state({ phase = 'blind_select' }), r, nil, false), 'final: shown')
end

-- Top players' money discipline (only while the next blinds are safe): interest first, boosters
-- bought very often, one reroll per shop before leaving.
function S.boosters_bought_from_a_lower_note(T)
    local opts = { { kind = 'booster', uid = 'arc', name = 'Arcana Pack', cost = 4, note = 54, interest_loss = 0 } }
    local st = A().shop_step(state({ dollars = 14 }), shop_result({ options = opts }))
    T.eq(st.action, 'buy'); T.eq(st.targets[1], 'arc')
    opts[1].kind = 'tarot'
    T.ok(A().shop_step(state({ dollars = 14 }), shop_result({ options = opts })).action ~= 'buy', 'same note, not a booster: not bought')
end

function S.interest_savings_from_ante_2(T)
    local opts = { { kind = 'joker', uid = 'j', name = 'Greedy Joker', cost = 5, note = 66, interest_loss = 1 } }
    -- ante 2, safe, 20 $: buying would leave 15 $ < 25 $ -> keep the money
    local three = { { uid = 'a' }, { uid = 'b' }, { uid = 'c' } } -- the first jokers are already there
    local st = A().shop_step(state({ dollars = 20, ante = 2, jokers = three }), shop_result({ options = opts }))
    T.eq(st.action, 'next_round'); T.ok(st.why:find('intérêts', 1, true) and st.why:find('Greedy Joker', 1, true), st.why)
    -- with no joker yet, the first one comes before the savings (top players: any joker beats none)
    T.eq(A().shop_step(state({ dollars = 20, ante = 2 }), shop_result({ options = opts })).action, 'buy')
    -- 32 $: the purchase only spends the excess above 25 $
    T.eq(A().shop_step(state({ dollars = 32, ante = 2, jokers = three }), shop_result({ options = opts })).action, 'buy')
    -- a strong item is bought anyway
    opts[1].note = 80
    T.eq(A().shop_step(state({ dollars = 20, ante = 2, jokers = three }), shop_result({ options = opts })).action, 'buy')
    -- danger: power first, the savings wait
    opts[1].note = 66
    local res = shop_result({ options = opts }); res.base.p_boss = 0.4
    T.eq(A().shop_step(state({ dollars = 20, ante = 2, jokers = three }), res).action, 'buy')
end

function S.interest_weighs_in_ante_1(T)
    -- ante 1: each $ of interest lost raises the bar (56 + 3 per $)
    local opts = { { kind = 'joker', uid = 'j', name = 'Joker', cost = 4, note = 60, interest_loss = 2 } }
    local three = { { uid = 'a' }, { uid = 'b' }, { uid = 'c' } }
    T.ok(A().shop_step(state({ dollars = 12, jokers = three }), shop_result({ options = opts })).action ~= 'buy', '60 < 56 + 2 x 3')
    opts[1].interest_loss = 1
    T.eq(A().shop_step(state({ dollars = 12, jokers = three }), shop_result({ options = opts })).action, 'buy')
end

function S.one_reroll_before_leaving(T)
    local res = shop_result({ reroll = { cost = 5, worth = false, p_improve = 0.4 } })
    local st = A().shop_step(state({ dollars = 12 }), res)
    T.eq(st.action, 'reroll'); T.ok(st.why:find('une relance', 1, true), st.why)
    T.eq(A().shop_step(state({ dollars = 12, rerolls = 1 }), res).action, 'next_round', 'already rerolled once')
    T.eq(A().shop_step(state({ dollars = 9, ante = 3 }), res).action, 'next_round', 'saving for interest')
    T.eq(A().shop_step(state({ dollars = 31, ante = 3 }), res).action, 'reroll', 'excess money above 25 $')
    st = A().shop_step(state({ dollars = 2, free_rerolls = 1, rerolls = 3 }), res)
    T.eq(st.action, 'reroll'); T.ok(st.why:find('gratuite', 1, true), st.why)
end

-- Joker stickers: an Eternal joker is never sold; an expired Perishable one is sold.
function S.stickers_eternal_and_perishable(T)
    local lu = { uid = 'lu', key = 'j_luchador', name = 'Luchador', eternal = true }
    local s0 = state({ phase = 'hand', jokers = { lu }, blind = { boss = true } })
    local r = { recommendation = { type = 'play', ref = { cards = {} } }, round = { p_clear = 0.3 } }
    T.ok(A().hand_step(s0, r).action ~= 'sell', 'eternal Luchador kept')
    local res = shop_result({ sells = { { uid = 'e', name = 'Mystic Summit', sell = 3, note = 70, contribution = 0 } } })
    local st = A().shop_step(state({ jokers = { { uid = 'e', name = 'Mystic Summit', eternal = true } }, rerolls = 1 }), res)
    T.eq(st.action, 'next_round', 'eternal: never advised for sale')
    local per = { uid = 'p', name = 'Gros Michel', perishable = true, perish_tally = 0, debuff = true, sell_cost = 2 }
    st = A().shop_step(state({ jokers = { per } }), shop_result({}))
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'p'); T.ok(st.why:find('périssable', 1, true), st.why)
end

-- Judgement with every joker slot taken: sell the weakest joker first, only when a random new
-- joker is likely better (measured by the shop analysis: r.slot_swaps).
function S.judgement_with_full_slots(T)
    local jokers = {}
    for i = 1, 5 do jokers[i] = { uid = 'j' .. i, key = 'j_joker', name = 'J' .. i } end
    local cons = { { uid = 'jg', key = 'c_judgement', set = 'Tarot', name = 'Judgement' } }
    local res = shop_result({}); res.slot_swaps = { any = { sell = jokers[3], k = 3, ratio = 1.2, p_better = 0.7, worth = true } }
    local st = A().shop_step(state({ jokers = jokers, consumables = cons }), res)
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'j3'); T.ok(st.text:find('Judgement', 1, true), st.text)
    -- once a slot is free: use it
    local four = { jokers[1], jokers[2], jokers[4], jokers[5] }
    st = A().shop_step(state({ jokers = four, consumables = cons }), shop_result({}))
    T.eq(st.action, 'use'); T.eq(st.targets[1], 'jg')
    -- not worth it: keep the jokers
    res.slot_swaps.any.worth = false
    T.ok(A().shop_step(state({ jokers = jokers, consumables = cons, rerolls = 1 }), res).action == 'next_round')
    -- taken from a pack with full slots: sell first
    local pr = { options = { { kind = 'tarot', key = 'c_judgement', uid = 'jp', name = 'Judgement', note = 62,
        swap = { sell = jokers[2], p_better = 0.6, worth = true } } } }
    st = A().pack_step(state({ jokers = jokers }), pr)
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'j2')
end

-- Lessons from top players (docs/PRO_LESSONS.md): falling behind -> scoring before interest;
-- last ante and The Ox -> no saving; Verdant Leaf -> sell the joker that scores least;
-- money above the cap -> rerolls while a multiplier is missing (one per shop in antes 1-3).
function S.pro_money_rules(T)
    local opts = { { kind = 'joker', uid = 'j', name = 'Joker', cost = 5, note = 66, interest_loss = 1 } }
    local res = shop_result({ options = opts })
    T.eq(A().shop_step(state({ dollars = 20, ante = 3 }), res).action, 'next_round', 'saving for interest')
    res.plan = { falling_behind = true, gaps = { power = true } }
    T.eq(A().shop_step(state({ dollars = 20, ante = 3 }), res).action, 'buy', 'falling behind: buy power')
    local s8 = state({ dollars = 20, ante = 8 }); s8.run.win_ante = 8
    T.eq(A().shop_step(s8, shop_result({ options = opts })).action, 'buy', 'last ante: money into score')
    local sox = state({ dollars = 20, ante = 6 }); sox.upcoming = { { slot = 'Boss', boss = true, key = 'bl_ox', state = 'Select' } }
    T.eq(A().shop_step(sox, shop_result({ options = opts })).action, 'buy', 'The Ox next: spend before')
end

function S.rich_rerolls_and_verdant_leaf(T)
    local res = shop_result({ reroll = { cost = 5, worth = false, p_improve = 0.4 } })
    res.plan = { gaps = { xmult = 1 } }
    local st = A().shop_step(state({ dollars = 50, ante = 5, rerolls = 2 }), res)
    T.eq(st.action, 'reroll'); T.ok(st.why:find('plafond', 1, true), st.why)
    T.eq(A().shop_step(state({ dollars = 50, ante = 2, rerolls = 1 }), res).action, 'next_round', 'antes 1-3: one reroll per shop')
    res.plan = { gaps = {} }
    T.eq(A().shop_step(state({ dollars = 40, ante = 5, rerolls = 2 }), res).action, 'next_round', 'no gap: keep the money')
    -- far above the cap, the money is idle: reroll for something better
    T.eq(A().shop_step(state({ dollars = 60, ante = 5, rerolls = 2 }), res).action, 'reroll')
    local jokers = { { uid = 'x', key = 'j_cavendish', name = 'Cavendish', sell_cost = 2 }, { uid = 'g', key = 'j_golden', name = 'Golden Joker', sell_cost = 3 },
        { uid = 'e', key = 'j_egg', name = 'Egg', eternal = true, sell_cost = 1 } }
    local hand = { card('h1', 13, 'Spades', { debuff = true }), card('h2', 5, 'Hearts', { debuff = true }) }
    local s0 = state({ phase = 'hand', jokers = jokers, hand = hand, blind = { boss = true, key = 'bl_final_leaf' } })
    local rr = { recommendation = { type = 'play', ref = { cards = {} } }, round = { p_clear = 0.2 } }
    st = A().hand_step(s0, rr)
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'g', 'the economy joker, not the multiplier, never the eternal one')
    -- once sold, the cards are no longer debuffed: no second sale
    for _, c in ipairs(hand) do c.debuff = false end
    T.ok(A().hand_step(s0, rr).action ~= 'sell', 'one joker only')
end

-- Money above the interest cap earns nothing: a real improvement is bought from it.
function S.excess_money_buys_improvements(T)
    local three = { { uid = 'a' }, { uid = 'b' }, { uid = 'c' } }
    local opts = { { kind = 'joker', uid = 'j', name = 'Joker', cost = 5, note = 55, interest_loss = 0 } }
    T.eq(A().shop_step(state({ dollars = 20, ante = 4, jokers = three, rerolls = 1 }), shop_result({ options = opts })).action, 'next_round')
    T.eq(A().shop_step(state({ dollars = 40, ante = 4, jokers = three }), shop_result({ options = opts })).action, 'buy', '40 - 5 > 25 + 5')
end

-- No churn: a replacement needs a clear gain; rerolls in danger have a budget.
function S.no_churn_and_reroll_budget(T)
    local jokers = { { uid = 'j1', name = 'Joker', sell_cost = 2 }, { uid = 'j2', name = 'Banner', sell_cost = 3 } }
    local opts = { { kind = 'replace', uid = 'duo', name = 'The Duo', cost = 5, note = 57, replace_index = 2, replaces = 'Banner' } }
    T.ok(A().shop_step(state({ dollars = 40, jokers = jokers, rerolls = 1 }), shop_result({ options = opts })).action ~= 'sell', '57: not worth a replacement')
    opts[1].note = 64
    T.eq(A().shop_step(state({ dollars = 40, jokers = jokers }), shop_result({ options = opts })).action, 'sell')
    local res = shop_result({ reroll = { cost = 5, worth = false, p_improve = 0.4 } })
    res.base.p_boss = 0.6; res.plan = { gaps = { power = true } }
    T.eq(A().shop_step(state({ dollars = 20, ante = 5, rerolls = 1 }), res).action, 'reroll', 'danger: reroll')
    T.eq(A().shop_step(state({ dollars = 20, ante = 5, rerolls = 2 }), res).action, 'next_round', 'budget of 2 rerolls')
    -- critical (boss more likely lost than won), missing a x Mult: the savings go into rerolls
    res.base.p_boss = 0.3; res.plan = { gaps = { xmult = true } }
    local st = A().shop_step(state({ dollars = 20, ante = 5, rerolls = 4 }), res)
    T.eq(st.action, 'reroll', 'critical: no budget')
    T.ok(st.why:find('perdue'), st.why)
    T.eq(A().shop_step(state({ dollars = 8, ante = 5, rerolls = 4 }), res).action, 'next_round', 'a little money kept')
end

function S.rentals_bought_only_when_strong_and_sold_when_not_needed(T)
    -- a rental ($3 every round) is not an "empty slot" joker: only strong or needed to survive
    local opts = { { kind = 'joker', uid = 'r', name = 'Lusty Joker', cost = 1, note = 64, affordable = true, rental = true } }
    T.ok(A().shop_step(state({ dollars = 6, rerolls = 1 }), shop_result({ options = opts })).action ~= 'buy', 'safe: not bought')
    local danger = shop_result({ options = opts })
    danger.base = { p_next = 0.5, p_boss = 0.3 }
    T.eq(A().shop_step(state({ dollars = 6, rerolls = 1 }), danger).action, 'buy', 'in danger: bought')
    -- owned rental, next blinds still safe without it: sold (stops the rent)
    local jokers = { { uid = 'r', key = 'j_lusty_joker', name = 'Lusty Joker', rental = true, sell_cost = 0 } }
    local res = shop_result({ sells = { { index = 1, uid = 'r', name = 'Lusty Joker', sell = 0, note = 50, d_next = -0.02, d_boss = 0, contribution = 0.1 } } })
    local st = A().shop_step(state({ dollars = 2, jokers = jokers }), res)
    T.eq(st.action, 'sell'); T.eq(st.targets[1], 'r')
    T.ok(st.why:find('location'), st.why)
    -- carries the score (strong rental bought on purpose): kept while there is money to spend
    res.sells[1].contribution = 0.4
    T.ok(A().shop_step(state({ dollars = 14, jokers = jokers, rerolls = 1 }), res).action ~= 'sell', 'strong rental: kept')
    -- ... but with little money the rent blocks everything: sold once the next blinds are safe
    T.eq(A().shop_step(state({ dollars = 2, jokers = jokers }), res).action, 'sell', 'tight money: sold')
    res.sells[1].contribution = 0.1
    -- needed: kept
    res.sells[1].d_boss = -0.4
    T.ok(A().shop_step(state({ dollars = 2, jokers = jokers }), res).action ~= 'sell', 'needed for the boss: kept')
end

return S
