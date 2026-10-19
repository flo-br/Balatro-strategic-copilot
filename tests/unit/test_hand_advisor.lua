local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    local HA = BSCopilot.require('engine/hand_advisor')
    return F, C, HA
end

local function deck_without(C, hand)
    local used = {}
    for _, c in ipairs(hand) do used[(c.rank or '') .. (c.suit or '')] = true end
    local d = {}
    for _, c in ipairs(C.standard_deck()) do
        if not used[c.rank .. c.suit] then d[#d + 1] = c end
    end
    return d
end

function S.made_flush_wins_now(T)
    local F, C, HA = env()
    local hand = C.parse_list('2h 7h 9h Jh Kh 3c 4d 5s')
    local s = F.state({ hand_cards = hand, deck = deck_without(C, hand), required = 250 })
    local r = HA.analyse(s, { rollouts = 16 })
    T.eq(r.best_play.hand, 'Flush')
    T.eq(r.best_play.mean, 292)
    T.eq(r.recommendation.type, 'play')
    T.eq(r.round.p_clear, 1); T.eq(r.round.method, 'exact')
    T.eq(#r.plays, 218)
end

function S.flush_draw_probability_is_exact(T)
    local F, C, HA = env()
    local P = BSCopilot.require('engine/probability')
    local hand = C.parse_list('2h 7h 9h Jh 3c 4d 5s Qs')
    local deck = deck_without(C, hand)
    local s = F.state({ hand_cards = hand, deck = deck })
    local targets = HA.discard_targets(s, hand, deck, { rules = {} })
    local flush
    for _, t in ipairs(targets) do if t.target.name == 'Flush' and t.target.suit == 'Hearts' then flush = t end end
    T.ok(flush, 'flush target found')
    T.eq(#flush.discard, 4)
    -- 9 hearts left among 44 cards, draw 4, need >= 1
    T.near(flush.p_complete, P.hypergeom_at_least(44, 9, 4, 1), 1e-12)
end

function S.impossible_blind_is_zero_and_easy_is_one(T)
    local F, C, HA = env()
    local hand = C.parse_list('2h 7d 9s Jc 3c 4d 5s Qs')
    local deck = deck_without(C, hand)
    local s = F.state({ hand_cards = hand, deck = deck, required = 10000000 })
    local r = HA.analyse(s, { rollouts = 24 })
    T.eq(r.round.p_clear, 0)
    s = F.state({ hand_cards = hand, deck = deck, required = 20 })
    r = HA.analyse(s, { rollouts = 24 })
    T.eq(r.round.p_clear, 1)
end

function S.more_hands_more_chance(T)
    local F, C, HA = env()
    local hand = C.parse_list('2h 7d 9s Jc 3c 4d 5s Qs')
    local deck = deck_without(C, hand)
    local p = {}
    for _, h in ipairs({ 1, 4 }) do
        local s = F.state({ hand_cards = hand, deck = deck, required = 300, hands_left = h, discards_left = 2 })
        p[h] = HA.analyse(s, { rollouts = 64 }).round.p_clear
    end
    T.ok(p[4] > p[1], string.format('4 hands %.2f should beat 1 hand %.2f', p[4], p[1]))
end

function S.forced_card_and_psychic_constraints(T)
    local F, C, HA = env()
    local hand = C.parse_list('Ah Ad 7c 2s 3h 9d Kc Qd')
    hand[3].forced = true -- Cerulean Bell
    local s = F.state({ hand_cards = hand, deck = deck_without(C, hand), required = 100000 })
    local r = HA.analyse(s, { rollouts = 4 })
    for _, p in ipairs(r.plays) do
        local has = false
        for _, c in ipairs(p.cards) do if c == hand[3] then has = true end end
        T.ok(has, 'every play contains the forced card')
    end
    hand[3].forced = nil
    s = F.state({ hand_cards = hand, deck = deck_without(C, hand), required = 100000,
        blind = { key = 'bl_psychic', boss = true, chips_required = 100000 } })
    r = HA.analyse(s, { rollouts = 4 })
    for _, p in ipairs(r.plays) do T.eq(#p.cards, 5) end
end

function S.cerulean_bell_forced_card_leaves_with_discards(T)
    local F, C, HA = env()
    local hand = C.parse_list('Ah Ad 7c 2s 3h 9d Kc Qd')
    hand[1].forced = true -- Cerulean Bell forces one ace of the pair
    local deck = deck_without(C, hand)
    local s = F.state({ hand_cards = hand, deck = deck, required = 100000,
        blind = { key = 'bl_final_bell', boss = true, chips_required = 100000 } })
    local targets = HA.discard_targets(s, hand, deck, { rules = {}, forced = hand[1] })
    T.ok(#targets > 0, 'discard options')
    local alone = false
    for _, t in ipairs(targets) do
        local has = false
        for _, c in ipairs(t.discard) do if c == hand[1] then has = true end end
        T.ok(has, 'the forced card goes with every discard')
        T.ok(#t.discard <= 5, 'at most 4 other cards')
        for _, c in ipairs(t.keep) do T.ok(c ~= hand[1], 'the forced card is never kept by a discard') end
        if #t.discard == 1 then alone = true end
    end
    T.ok(alone, 'discarding the forced card alone is an option')
    -- the full analysis: every discard candidate holds the forced card too
    local r = HA.analyse(s, { rollouts = 8 })
    for _, d in ipairs(r.discards) do
        local has = false
        for _, c in ipairs(d.discard) do if c == hand[1] then has = true end end
        T.ok(has, 'analysis discards hold the forced card')
    end
    hand[1].forced = nil
end

function S.cerulean_bell_rest_of_round_is_simulated(T)
    -- after each draw a new card is forced: the chances stay close to the same hand without the
    -- boss (before 1.0.8 the simulation found no legal play once the forced card was gone)
    local F, C, HA = env()
    local hand = C.parse_list('Ah Ad 7c 2s 3h 9d Kc Qd')
    local deck = deck_without(C, hand)
    local function p(bell)
        hand[3].forced = bell or nil
        local s = F.state({ hand_cards = hand, deck = deck, required = 200, hands_left = 4, discards_left = 3,
            blind = { key = bell and 'bl_final_bell' or 'bl_small', boss = bell, chips_required = 200, chips_scored = 0 } })
        return HA.analyse(s, { rollouts = 64, seed = 'bell' }).round.p_clear
    end
    local free, bell = p(false), p(true)
    hand[3].forced = nil
    T.ok(free > 0.5, string.format('reference chances %.2f', free))
    T.ok(bell > 0.75 * free, string.format('Cerulean Bell %.2f vs free %.2f', bell, free))
end

function S.bosses_that_change_between_hands(T)
    local F, C, HA = env()
    local Score = BSCopilot.require('engine/score')
    local R = BSCopilot.require('core/rng')
    local H = BSCopilot.require('model/hands')
    local rng = R.new('boss')
    local s = F.state({ levels = { Pair = 3 }, blind = { key = 'bl_eye', boss = true, chips_required = 1000 } })
    local P = Score.prepare(s)
    local Q = HA.boss_after_play(P, 'Pair', rng)
    T.ok(Q.blind.hands_used.Pair, 'The Eye: Pair used')
    T.ok(not (P.blind.hands_used or {}).Pair, 'state untouched')
    s.blind = { key = 'bl_mouth', boss = true, chips_required = 1000 }
    Q = HA.boss_after_play(Score.prepare(s), 'Flush', rng)
    T.eq(Q.blind.only_hand, 'Flush')
    s.blind = { key = 'bl_arm', boss = true, chips_required = 1000 }
    P = Score.prepare(s)
    Q = HA.boss_after_play(P, 'Pair', rng)
    T.eq(Q.hands.Pair.level, 2)
    T.eq(P.hands.Pair.level, 3)
    local c2, m2 = H.values_at('Pair', 2)
    T.eq(Q.hands.Pair.chips, c2); T.eq(Q.hands.Pair.mult, m2)
    local J = BSCopilot.require('model/jokers_db')
    s.blind = { key = 'bl_final_heart', boss = true, chips_required = 1000 }
    s.jokers = { { key = 'j_joker', name = 'Joker', ability = { mult = 4 } }, { key = 'j_greedy_joker', name = 'Greedy Joker', ability = {} } }
    P = Score.prepare(s)
    Q = HA.boss_after_play(P, 'Pair', rng)
    local n = 0
    for _, j in ipairs(Q.jokers) do if j.debuff then n = n + 1 end end
    T.eq(n, 1)
    T.ok(J ~= nil)
end

function S.face_down_cards_winning_visible_play(T)
    local F, C, HA = env()
    local hand = C.parse_list('Ah Ad 7c 2s')
    hand[4] = { uid = 'hidden', face_down = true, id = 0, nominal = 0, unknown = true }
    local s = F.state({ hand_cards = hand, deck = deck_without(C, hand), required = 50 })
    local r = HA.analyse(s, { rollouts = 4 })
    T.eq(r.notes[1], 'hidden_cards')
    local rec = r.recommendation
    T.eq(rec.type, 'play')
    local has = {}
    for _, c in ipairs(rec.cards) do has[c.uid] = true end
    T.ok(has[hand[1].uid] and has[hand[2].uid], 'the visible pair of aces wins: play it')
    T.ok(not has.hidden, 'no need to play the hidden card blind')
end

-- The House: every card face down. Hidden positions are interchangeable; the advice is a
-- number of hidden cards to play or discard, never based on the identity of a given card.
function S.all_cards_face_down_still_advised(T)
    local F, C, HA = env()
    local real = C.parse_list('Ah Ad 7c 9s 2h Kh 5d 3c')
    local hand = {}
    for i, c in ipairs(real) do hand[i] = { uid = 'h' .. i, face_down = true, id = 0, nominal = 0, unknown = true } end
    local deck = deck_without(C, real)
    local full = {}
    for _, c in ipairs(deck) do full[#full + 1] = c end
    for _, c in ipairs(real) do full[#full + 1] = c end
    local s = F.state({ hand_cards = hand, deck = deck, required = 300 })
    s.full_deck = full
    local r = HA.analyse(s, { rollouts = 24 })
    T.ok(not r.empty, 'not empty anymore')
    T.ok(r.recommendation and #r.recommendation.cards >= 1 and #r.recommendation.cards <= 5)
    for _, c in ipairs(r.recommendation.cards) do T.ok(c.face_down, 'only hidden positions') end
    T.eq(r.hidden.count, 8); T.eq(r.hidden.pool, 8, 'pool = full deck - draw pile')
    -- same advice whatever the real identity of each hidden card (only the pool counts)
    local shuffled = {}
    for i = 1, 8 do shuffled[i] = { uid = 'x' .. i, face_down = true, id = 0, nominal = 0, unknown = true } end
    local s2 = F.state({ hand_cards = shuffled, deck = deck, required = 300 })
    s2.full_deck = full
    local r2 = HA.analyse(s2, { rollouts = 24 })
    T.eq(r2.recommendation.type, r.recommendation.type)
    T.eq(#r2.recommendation.cards, #r.recommendation.cards)
end

function S.structural_candidates_cover_main_hands(T)
    local F, C, HA = env()
    local hand = C.parse_list('Ah Ad As Kc Kd 9h 8h 7h')
    local cands = HA.structural_candidates(hand, {})
    local PE = BSCopilot.require('engine/poker_eval')
    local names = {}
    for _, c in ipairs(cands) do names[PE.evaluate(c, {}).name] = true end
    T.ok(names['Full House']); T.ok(names['Three of a Kind']); T.ok(names['Pair']); T.ok(names['High Card'])
end

function S.straight_target_four_fingers(T)
    local F, C, HA = env()
    local hand = C.parse_list('5h 6d 2c 2s Kh Qd Jc 3h')
    local deck = deck_without(C, hand)
    local s = F.state({ hand_cards = hand, deck = deck })
    local targets = HA.discard_targets(s, hand, deck, { rules = { four_fingers = true } })
    local found
    for _, t in ipairs(targets) do if t.target.name == 'Straight' then found = t end end
    T.ok(found and found.p_complete > 0 and found.p_complete <= 1)
end

-- Card effects (model/effects_db.lua): a winning hand does not spend the cards that pay while
-- HELD (Gold card: $3 at the end of the round, Blue seal: a planet) as useless kickers.
function S.held_effects_stay_in_hand(T)
    local F, C, HA = env()
    for _, mod in ipairs({ { enh = 'm_gold' }, { seal = 'Blue' } }) do
        local hand = C.parse_list('Ah Ad 7c 9s 2h Qs 5d 3c')
        if mod.enh then C.set_enhancement(hand[6], mod.enh) end
        if mod.seal then hand[6].seal = mod.seal end
        local s = F.state({ hand_cards = hand, deck = deck_without(C, hand), required = 60 })
        local r = HA.analyse(s, { rollouts = 8 })
        T.eq(r.recommendation.type, 'play')
        for _, c in ipairs(r.recommendation.ref.cards) do T.ok(c ~= hand[6], 'Q held: ' .. tostring(mod.enh or mod.seal)) end
    end
end

function S.effects_change_card_worth(T)
    local _, C, HA = env()
    local plain, steel, gold, purple, lucky = C.parse('Ks'), C.parse('Ks'), C.parse('Ks'), C.parse('Ks'), C.parse('Ks')
    C.set_enhancement(steel, 'm_steel'); C.set_enhancement(gold, 'm_gold'); C.set_enhancement(lucky, 'm_lucky')
    purple.seal = 'Purple'
    T.ok(HA.card_value(steel) > HA.card_value(plain), 'steel kept before a plain card')
    T.ok(HA.card_value(gold) > HA.card_value(plain), 'gold kept before a plain card')
    T.ok(HA.card_value(purple) < HA.card_value(plain), 'purple seal discarded first (tarot)')
    T.ok(HA.card_value(lucky) < HA.card_value(plain) + 40, 'lucky: +20 Mult only 1 time in 5')
    -- discarding a Purple seal is worth a tarot; playing a Glass card risks breaking it
    T.ok(HA.side_value({ purple }, { purple, plain }, 'discard') > 0)
    local glass = C.parse('Ah'); C.set_enhancement(glass, 'm_glass')
    T.ok(HA.side_value({ glass }, { glass }, 'play', 0, 1) < 0)
end

return S
