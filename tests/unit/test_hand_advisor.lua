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

return S
