-- Reference scores computed by hand from the vanilla/Steamodded rules.
-- Each case documents the arithmetic so it can be re-checked against the game.
local T = ...
local S = {}

local function env()
    package.loaded['fixtures.states'] = nil
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    local Score = BSCopilot.require('engine/score')
    return F, C, Score
end

local function play(o, played, held)
    local F, C, Score = env()
    local s = F.state(o)
    local p = type(played) == 'string' and C.parse_list(played) or played
    local h = type(held) == 'string' and C.parse_list(held) or (held or {})
    return Score.evaluate(s, p, h)
end

function S.pair_of_aces_no_joker(T)
    -- Pair lvl1: 10 x 2 ; chips +11 +11 = 32 ; 32*2 = 64
    local r = play({}, 'Ah Ad 7c')
    T.eq(r.hand, 'Pair'); T.eq(r.mean, 64); T.ok(r.exact); T.eq(r.method, 'exact')
end

function S.joker_plus_four(T)
    local F = env()
    -- 32 x (2+4) = 192
    T.eq(play({ jokers = { F.joker('j_joker') } }, 'Ah Ad').mean, 192)
end

function S.flush(T)
    -- Flush lvl1 35x4 ; 2+7+9+10+10 = 38 ; 73*4 = 292
    T.eq(play({}, '2h 7h 9h Jh Kh').mean, 292)
end

function S.glass_then_holo_order(T)
    local F, C = env()
    -- High card 5x1 ; A = 11 -> 16 chips ; glass x2 -> mult 2 ; holo +10 AFTER -> 12 ; 16*12 = 192
    local a = C.parse('As', { enh = 'm_glass', edition = 'e_holo' })
    T.eq(play({}, { a }).mean, 192)
end

function S.steel_baron_mime(T)
    local F, C = env()
    local k = C.parse('Ks', { enh = 'm_steel' })
    -- Pair 2s: 10 + 2 + 2 = 14 chips, mult 2 ; steel x1.5, Baron x1.5 -> 4.5 ; 14*4.5 = 63
    T.eq(play({ jokers = { F.joker('j_baron') } }, '2s 2h', { k }).mean, 63)
    -- Mime retriggers the held King once more: 2*1.5^4 = 10.125 ; floor(14*10.125) = 141
    T.eq(play({ jokers = { F.joker('j_baron'), F.joker('j_mime') } }, '2s 2h', { k }).mean, 141)
end

function S.red_seal_and_hack(T)
    local F, C = env()
    local three = C.parse('3s', { seal = 'Red' })
    -- 3s scored 3 times (base + red seal + Hack), 3h twice (base + Hack): 10 + 9 + 6 = 25 ; x2 = 50
    T.eq(play({ jokers = { F.joker('j_hack') } }, { three, C.parse('3h') }).mean, 50)
end

function S.blueprint_position(T)
    local F = env()
    -- Blueprint left of Joker copies it: mult 2+4+4 = 10 ; 32*10 = 320
    T.eq(play({ jokers = { F.joker('j_blueprint'), F.joker('j_joker') } }, 'Ah Ad').mean, 320)
    -- Blueprint rightmost copies nothing: 32*6 = 192
    T.eq(play({ jokers = { F.joker('j_joker'), F.joker('j_blueprint') } }, 'Ah Ad').mean, 192)
    -- Brainstorm copies the leftmost joker
    T.eq(play({ jokers = { F.joker('j_joker'), F.joker('j_brainstorm') } }, 'Ah Ad').mean, 320)
    -- Blueprint cannot copy a non-compatible joker (Four Fingers)
    T.eq(play({ jokers = { F.joker('j_blueprint'), F.joker('j_four_fingers') } }, 'Ah Ad').mean, 64)
end

function S.the_flint(T)
    -- Pair 10x2 halved -> 5x1 ; 5 + 22 = 27 ; 27*1 = 27
    local r = play({ blind = { key = 'bl_flint', boss = true, chips_required = 600 } }, 'Ah Ad')
    T.eq(r.mean, 27)
end

function S.plasma_deck(T)
    local F = env()
    -- 32 chips, 6 mult -> balanced 19 x 19 = 361
    T.eq(play({ jokers = { F.joker('j_joker') }, flags = { plasma = true } }, 'Ah Ad').mean, 361)
end

function S.lucky_card_distribution(T)
    local F, C = env()
    -- 16 chips; mult 1 (p=.8) or 21 (p=.2): scores 16 / 336 ; mean 80 ; $ 20/15
    local r = play({}, { C.parse('As', { enh = 'm_lucky' }) })
    T.eq(r.method, 'enumeration'); T.no(r.exact)
    T.near(r.mean, 80, 1e-9)
    T.eq(r.min, 16); T.eq(r.max, 336)
    T.near(r.p_at_least(300), 0.2, 1e-12)
    T.near(r.dollars, 20 / 15, 1e-9)
    -- Oops! All 6s doubles the probabilities (normal = 2): mult hit 2/5
    local r2 = play({ prob = 2 }, { C.parse('As', { enh = 'm_lucky' }) })
    T.near(r2.p_at_least(300), 0.4, 1e-12)
end

function S.space_joker_level_up(T)
    local F = env()
    -- 1/4: Pair lvl2 = 25 x 3 -> (25+22)*3 = 141 ; 3/4: 64 ; mean = 0.25*141 + 0.75*64 = 83.25
    local r = play({ jokers = { F.joker('j_space') } }, 'Ah Ad')
    T.near(r.mean, 83.25, 1e-9)
end

function S.ride_the_bus(T)
    local F = env()
    -- no face: mult 3 -> 4 in context.before ; 32 x (2+4) = 192
    T.eq(play({ jokers = { F.joker('j_ride_the_bus', { mult = 3 }) } }, 'Ah Ad').mean, 192)
    -- face scored: reset to 0 ; Kings: 10+10+10 = 30 x 2 = 60
    T.eq(play({ jokers = { F.joker('j_ride_the_bus', { mult = 3 }) } }, 'Kh Kd').mean, 60)
end

function S.vampire_strips_glass(T)
    local F, C = env()
    -- glass removed before scoring, Vampire 1 -> 1.1 : 16 chips x (1 x 1.1) = 17.6 -> 17
    local r = play({ jokers = { F.joker('j_vampire') } }, { C.parse('As', { enh = 'm_glass' }) })
    T.eq(r.mean, 17)
end

function S.midas_mask_removes_bonus(T)
    local F, C = env()
    -- King with Bonus (+30) becomes Gold before scoring: 5 + 10 = 15 x 1
    local r = play({ jokers = { F.joker('j_midas_mask') } }, { C.parse('Ks', { enh = 'm_bonus' }) })
    T.eq(r.mean, 15)
end

function S.debuffed_card_does_not_score(T)
    local F, C = env()
    local cards = C.parse_list('Ah Ad')
    cards[2].debuff = true
    -- still a Pair, but only Ah scores: 10 + 11 = 21 x 2 = 42
    local r = play({}, cards)
    T.eq(r.hand, 'Pair'); T.eq(r.mean, 42)
end

function S.baseball_card(T)
    local F = env()
    -- Hack is Uncommon: Baseball x1.5 ; 32 x 3 = 96
    T.eq(play({ jokers = { F.joker('j_hack'), F.joker('j_baseball') } }, 'Ah Ad').mean, 96)
end

function S.photograph_hanging_chad(T)
    local F = env()
    -- Ks is first face and first scored card: 3 scorings, each x2 -> x8 ; chips 10+30+10 = 50 ; mult 2*8 = 16 ; 800
    T.eq(play({ jokers = { F.joker('j_photograph'), F.joker('j_hanging_chad') } }, 'Ks Kh').mean, 800)
end

function S.psychic_requires_five(T)
    local r = play({ blind = { key = 'bl_psychic', boss = true, chips_required = 600 } }, 'Ah Ad')
    T.eq(r.mean, 0); T.ok(r.debuffed_hand)
    -- disabled boss (Chicot/Luchador): normal score
    local r2 = play({ blind = { key = 'bl_psychic', boss = true, disabled = true, chips_required = 600 } }, 'Ah Ad')
    T.eq(r2.mean, 64)
end

function S.observatory(T)
    -- Mercury held with Observatory: x1.5 on Pair: 32 x 3 = 96
    local r = play({ vouchers = { v_observatory = true }, consumables = { { key = 'c_mercury', set = 'Planet', hand_type = 'Pair' } } }, 'Ah Ad')
    T.eq(r.mean, 96)
end

function S.misprint_enumerated(T)
    local F = env()
    -- mult 2 + U{0..23} ; mean mult 13.5 -> 32 * 13.5 = 432
    local r = play({ jokers = { F.joker('j_misprint') } }, 'Ah Ad')
    T.eq(r.method, 'enumeration'); T.near(r.mean, 432, 1e-9); T.eq(r.min, 64); T.eq(r.max, 32 * 25)
end

function S.many_random_events_fall_back_to_monte_carlo(T)
    local F, C = env()
    local cards = {}
    for _, code in ipairs({ 'As', 'Ad', 'Ah', 'Ac', 'Ks' }) do cards[#cards + 1] = C.parse(code, { enh = 'm_lucky', seal = 'Red' }) end
    local r = play({ jokers = { F.joker('j_misprint'), F.joker('j_bloodstone') } }, cards)
    T.eq(r.method, 'monte_carlo'); T.no(r.exact)
    T.ok(r.mean > 0)
end

function S.unsupported_joker_is_not_exact(T)
    local r = play({ jokers = { { key = 'j_mymod_weird', name = 'Weird Modded Joker', ability = {} } } }, 'Ah Ad')
    T.eq(r.mean, 64); T.no(r.exact); T.eq(r.coverage.unsupported[1], 'Weird Modded Joker')
    -- a debuffed unknown joker cannot act: still exact
    local r2 = play({ jokers = { { key = 'j_mymod_weird', name = 'Weird', ability = {}, debuff = true } } }, 'Ah Ad')
    T.ok(r2.exact)
end

function S.bull_counts_money_earned_while_scoring(T)
    local F, C = env()
    -- $10 + Gold seal $3 earned before joker_main: Bull 2*13 = 26 ; (32+26) x 2 = 116
    local cards = C.parse_list('Ah Ad')
    cards[1].seal = 'Gold'
    local r = play({ dollars = 10, jokers = { F.joker('j_bull') } }, cards)
    T.eq(r.mean, 116); T.eq(r.dollars, 3)
end

function S.raised_fist(T)
    local F = env()
    -- lowest held is 5 -> +10 mult : 32 x 12 = 384
    T.eq(play({ jokers = { F.joker('j_raised_fist') } }, 'Ah Ad', '9d 5s Kc').mean, 384)
end

function S.splash(T)
    local F = env()
    -- every played card scores: 10 + 11 + 11 + 7 = 39 x 2 = 78
    T.eq(play({ jokers = { F.joker('j_splash') } }, 'Ah Ad 7c').mean, 78)
end

function S.the_arm_levels_down(T)
    -- Pair lvl2 (25x3) -> lvl1 (10x2) before scoring: 32 x 2 = 64
    local r = play({ levels = { Pair = 2 }, blind = { key = 'bl_arm', boss = true, chips_required = 600 } }, 'Ah Ad')
    T.eq(r.mean, 64); T.eq(r.level, 1)
end

function S.hiker_with_red_seal(T)
    local F, C = env()
    -- first scoring: 11 then Hiker +5 ; retrigger: 16 ; chips 5 + 11 + 16 = 32 x 1
    T.eq(play({ jokers = { F.joker('j_hiker') } }, { C.parse('As', { seal = 'Red' }) }).mean, 32)
end

function S.wee_joker_gains_during_hand(T)
    local F = env()
    -- 10 + 2 + 2 + (8+8) = 30 x 2 = 60
    T.eq(play({ jokers = { F.joker('j_wee') } }, '2s 2h').mean, 60)
end

function S.card_sharp_and_supernova(T)
    local F = env()
    -- Pair played once this round already: x3 ; 32 x 6 = 192
    T.eq(play({ jokers = { F.joker('j_card_sharp') }, hands_patch = { Pair = { played_this_round = 1 } } }, 'Ah Ad').mean, 192)
    T.eq(play({ jokers = { F.joker('j_card_sharp') } }, 'Ah Ad').mean, 64)
    -- Supernova: Pair played 4 times before -> +5 mult : 32 x 7 = 224
    T.eq(play({ jokers = { F.joker('j_supernova') }, hands_patch = { Pair = { played = 4 } } }, 'Ah Ad').mean, 224)
end

function S.obelisk_resets_on_most_played(T)
    local F = env()
    -- Pair is the most played hand (5 vs 2): reset to x1 -> 64
    T.eq(play({ jokers = { F.joker('j_obelisk', { x_mult = 2 }) }, hands_patch = { Pair = { played = 5 }, Flush = { played = 2 } } }, 'Ah Ad').mean, 64)
    -- Flush played more often: Obelisk grows 2 -> 2.2 : 32 x 4.4 = 140.8 -> 140
    T.eq(play({ jokers = { F.joker('j_obelisk', { x_mult = 2 }) }, hands_patch = { Pair = { played = 1 }, Flush = { played = 6 } } }, 'Ah Ad').mean, 140)
end

function S.dusk_and_acrobat_last_hand(T)
    local F = env()
    -- last hand: Dusk retriggers both Aces: 10 + 22 + 22 = 54 x 2 = 108 ; Acrobat x3
    T.eq(play({ hands_left = 1, jokers = { F.joker('j_dusk') } }, 'Ah Ad').mean, 108)
    T.eq(play({ hands_left = 2, jokers = { F.joker('j_dusk') } }, 'Ah Ad').mean, 64)
    T.eq(play({ hands_left = 1, jokers = { F.joker('j_acrobat') } }, 'Ah Ad').mean, 192)
end

function S.joker_editions_order(T)
    local F = env()
    -- Holo Joker: +10 (edition) then +4 : 32 x 16 = 512 ; Polychrome Joker: (2+4) x1.5 = 9 -> 288
    T.eq(play({ jokers = { F.joker('j_joker', nil, { edition = 'e_holo' }) } }, 'Ah Ad').mean, 512)
    T.eq(play({ jokers = { F.joker('j_joker', nil, { edition = 'e_polychrome' }) } }, 'Ah Ad').mean, 288)
    -- Polychrome is applied after that joker's effect but before the next joker:
    -- [Poly Joker, Joker] -> (2+4)*1.5 + 4 = 13 -> 416
    T.eq(play({ jokers = { F.joker('j_joker', nil, { edition = 'e_polychrome' }), F.joker('j_joker') } }, 'Ah Ad').mean, 416)
end

function S.debuffed_joker_inactive(T)
    local F = env()
    T.eq(play({ jokers = { F.joker('j_joker', nil, { debuff = true }) } }, 'Ah Ad').mean, 64)
end

function S.stencil_counts_empty_slots(T)
    local F = env()
    -- 5 slots, 2 jokers (Stencil + Joker): x(3 empty + 1 stencil) = x4 ; (2+4)*4 = 24 -> 32*24 = 768
    T.eq(play({ jokers = { F.joker('j_joker'), F.joker('j_stencil') } }, 'Ah Ad').mean, 768)
end

function S.flower_pot_and_seeing_double(T)
    local F = env()
    -- Flush house is impossible here; use a 4-suit two pair + kicker: Ah Ad Kc Ks 2h -> Two Pair (scoring 4 cards)
    -- Flower pot needs all 4 suits among scoring cards: H, D, C, S -> x3 ; chips 20+11+11+10+10 = 62 ; 62 x 6 = 372
    T.eq(play({ jokers = { F.joker('j_flower_pot') } }, 'Ah Ad Kc Ks 2h').mean, 372)
    -- Seeing double: club + other suit -> x2 : 62 x 4 = 248
    T.eq(play({ jokers = { F.joker('j_seeing_double') } }, 'Ah Ad Kc Ks 2h').mean, 248)
end

function S.trace_explains_steps(T)
    local F, C, Score = env()
    local s = F.state({ jokers = { F.joker('j_joker') } })
    local r = Score.evaluate(s, C.parse_list('Ah Ad'), {}, { trace = true })
    T.ok(type(r.trace) == 'table' and #r.trace >= 3)
end

return S
