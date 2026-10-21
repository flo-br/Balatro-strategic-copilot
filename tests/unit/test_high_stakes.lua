-- High stakes (1.0.10): rules of the best players (docs/PRO_HIGH_STAKES_SOURCES.md) and the
-- signals measured on the simulator (docs/TRAINING.md).
local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    return F, BSCopilot.require('engine/plan'), BSCopilot.require('engine/skip'), BSCopilot.require('engine/advice'),
        BSCopilot.require('engine/shop')
end

function S.almost_no_skip_at_high_stakes(T)
    local F, PL, SK = env()
    local function ev(stake, tag, ante)
        local s = F.state({ dollars = 4, stake = stake, ante = ante or 1 })
        s.blind_tags = { Small = tag, Big = 'tag_rare' }
        return SK.evaluate(s, { current = { slot = 'Small', reward = 0, chips = 300 }, p_following = 0.99, p_boss = 0.99,
            median = 200, plan = { gaps = {} } })
    end
    -- the same Polychrome skip: worth it at the White Stake, not from the Green Stake
    local white = ev(1, 'tag_polychrome')
    T.ok(white.recommended, 'white stake: skipped (margin ' .. tostring(white.margin) .. ')')
    local black = ev(4, 'tag_polychrome')
    T.no(black.recommended); T.eq(black.reason, 'high_stake')
    -- the standard exception: the Investment Tag in the first antes
    T.ok(ev(4, 'tag_investment', 1).recommended, 'Investment at ante 1')
    T.no(ev(4, 'tag_investment', 4).recommended, 'not at ante 4')
    -- the blind step says why
    local A = BSCopilot.require('engine/advice')
    local st = A.blind_step(F.state({ stake = 4 }), { current = { slot = 'Small', name = 'Small Blind' }, skip = black, p_current = { p = 1 } })
    T.eq(st.action, 'select_blind')
    T.ok(st.why:find('mise élevée', 1, true), st.why)
    -- switch off: as before
    PL.HIGH_STAKE_RULES = false
    T.ok(ev(4, 'tag_polychrome').recommended)
    PL.HIGH_STAKE_RULES = true
end

function S.no_multiplier_at_ante_4_stops_the_savings(T)
    local F, PL = env()
    local p = PL.analyse(F.state({ ante = 4, stake = 4, jokers = { F.joker('j_joker'), F.joker('j_greedy_joker') } }), { median = 100000 })
    T.ok(p.off_track and p.no_xmult_late, 'no x Mult entering ante 5')
    p = PL.analyse(F.state({ ante = 4, stake = 1, jokers = { F.joker('j_joker') } }), { median = 100000 })
    T.no(p.no_xmult_late, 'white stake: not this rule')
    p = PL.analyse(F.state({ ante = 4, stake = 4, jokers = { F.joker('j_duo') } }), { median = 100000 })
    T.no(p.off_track, 'one x Mult and a strong hand: on track')
end

function S.track_of_the_winning_runs(T)
    local F, PL = env()
    -- off by default (no measured gain); the mechanism stays available
    T.eq(PL.TRACK_SCALE, 0)
    PL.TRACK_SCALE = 1
    -- ante 3, White Stake: base 2000; the winners' track is 1.2 x base = 2400
    local p = PL.analyse(F.state({ ante = 3, jokers = { F.joker('j_duo') } }), { median = 2000 })
    T.ok(p.off_track, 'below the track'); T.no(p.falling_behind, 'but not falling behind (0.5 x base)')
    p = PL.analyse(F.state({ ante = 3, jokers = { F.joker('j_duo') } }), { median = 3000 })
    T.no(p.off_track)
    -- off track: the savings are not kept (the next ante grows x2.5)
    local A = BSCopilot.require('engine/advice')
    local function state(o)
        return { phase = 'shop', econ = { dollars = o.dollars, bankrupt_at = 0, reroll_cost = 6, base_reroll_cost = 5, interest_cap = 25 },
            run = { ante = 3, stake = 1 }, jokers = {}, joker_slots = 5, consumables = {}, consumable_slots = 2, vouchers = {} }
    end
    local opts = { { kind = 'joker', uid = 'j', name = 'Joker', cost = 6, note = 62, affordable = true } }
    local res = { options = opts, sells = {}, base = { p_next = 0.95, p_boss = 0.9 }, plan = { gaps = {} } }
    T.ok(A.shop_step(state({ dollars = 26 }), res).action ~= 'buy', 'on track: the savings are kept')
    res.plan = { gaps = { power = true }, off_track = true }
    T.eq(A.shop_step(state({ dollars = 26 }), res).action, 'buy', 'off track: power first')
    PL.TRACK_SCALE = 0
end

function S.rentals_and_eternals_at_high_stakes(T)
    local F, PL, SK, A = env()
    local function state(o)
        return { phase = 'shop', econ = { dollars = o.dollars or 30, bankrupt_at = 0, reroll_cost = 6, base_reroll_cost = 5, interest_cap = 25 },
            run = { ante = o.ante or 3, stake = 8 }, jokers = o.jokers or {}, joker_slots = 5, consumables = {}, consumable_slots = 2, vouchers = {} }
    end
    local function res(opt) return { options = { opt }, sells = {}, base = { p_next = 0.95, p_boss = 0.9 }, plan = { gaps = {} } } end
    -- safe: an additive rental waits for a copy without rent, an x Mult one is taken if strong
    local add = { kind = 'joker', uid = 'a', name = 'Jolly', cost = 1, note = 90, affordable = true, rental = true, joker_kind = 'additive' }
    T.ok(A.shop_step(state({}), res(add)).action ~= 'buy', 'additive rental: no')
    local xm = { kind = 'joker', uid = 'x', name = 'The Duo', cost = 1, note = 90, affordable = true, rental = true, joker_kind = 'xmult' }
    T.eq(A.shop_step(state({}), res(xm)).action, 'buy', 'x Mult rental: yes')
    -- one rental at most before ante 6
    local owned = { { uid = 'r', key = 'j_duo', name = 'The Duo', rental = true, sell_cost = 0 } }
    T.ok(A.shop_step(state({ jokers = owned }), res(xm)).action ~= 'buy', 'a second rental before ante 6: no')
    -- the rent comes before the interest: $28 to keep with one rental
    local pol_res = res({ kind = 'joker', uid = 'j', name = 'Joker', cost = 3, note = 62, affordable = true })
    T.ok(A.shop_step(state({ dollars = 30, jokers = owned }), pol_res).action ~= 'buy', '$30 - $3 < $28: kept')
    -- Eternal on a temporary additive joker after ante 2: a risk in the note
    local SH = BSCopilot.require('engine/shop')
    local C = BSCopilot.require('model/cards')
    local function note(eternal)
        local s = F.state({ dollars = 12, stake = 4, ante = 3, jokers = { F.joker('j_duo') } })
        s.phase = 'shop'; s.full_deck = C.standard_deck()
        s.round.round_hands, s.round.round_discards, s.round.hand_size = 4, 3, 8
        local j = F.joker('j_jolly'); j.eternal = eternal
        s.shop = { jokers = { { set = 'Joker', key = 'j_jolly', name = 'Jolly Joker', cost = 3, joker = j, uid = 'e' } }, vouchers = {}, boosters = {} }
        return SH.analyse(s, { n = 16 }).options[1]
    end
    local plain, eternal = note(false), note(true)
    T.ok(eternal.note < plain.note, string.format('eternal %d < %d', eternal.note, plain.note))
end

function S.vouchers_wait_for_a_safe_board(T)
    local F, PL, SK, A = env()
    local function state() return { phase = 'shop', econ = { dollars = 40, bankrupt_at = 0, reroll_cost = 6, base_reroll_cost = 5, interest_cap = 25 },
        run = { ante = 2, stake = 1 }, jokers = {}, joker_slots = 5, consumables = {}, consumable_slots = 2, vouchers = {} } end
    local over = { kind = 'voucher', uid = 'o', name = 'v_overstock_norm', cost = 10, note = 65, affordable = true }
    local danger = { options = { over }, sells = {}, base = { p_next = 0.5, p_boss = 0.04 }, plan = { gaps = {} } }
    T.ok(A.shop_step(state(), danger).action ~= 'buy', 'boss at 4 %: Overstock waits')
    local grab = { kind = 'voucher', uid = 'g', name = 'v_grabber', cost = 10, note = 65, affordable = true, power_voucher = true }
    danger.options = { grab }
    T.eq(A.shop_step(state(), danger).action, 'buy', '+1 hand helps now: bought')
    -- Seed Money is worth nothing without interest (Green Deck)
    local SH = BSCopilot.require('engine/shop')
    local C = BSCopilot.require('model/cards')
    local function seed(no_interest)
        local s = F.state({ dollars = 45 })
        s.phase = 'shop'; s.full_deck = C.standard_deck(); s.econ.no_interest = no_interest
        s.round.round_hands, s.round.round_discards, s.round.hand_size = 4, 3, 8
        s.shop = { jokers = {}, vouchers = { { set = 'Voucher', key = 'v_seed_money', name = 'Seed Money', cost = 10, uid = 'v' } }, boosters = {} }
        return SH.analyse(s, { n = 16 }).options[1]
    end
    T.ok(seed(true).note < seed(false).note, 'no interest: worth less')
end

function S.prior_calibration_of_the_shop_chances(T)
    local SH = select(5, env())
    -- monotone, and close to the outcomes measured on the simulator
    local last = -1
    for p = 0, 1.0001, 0.05 do
        local c = SH.prior_calibration(math.min(1, p))
        T.ok(c >= last - 1e-9, 'monotone at ' .. p)
        last = c
    end
    T.near(SH.prior_calibration(0.4), 0.865, 0.01)
    T.ok(SH.prior_calibration(0.05) < 0.4, 'a real danger stays a danger')
end

function S.main_hand_focus_of_the_planets(T)
    local F, PL, SK, A, SH = env()
    local C = BSCopilot.require('model/cards')
    local function planet_note(focus, key, hand)
        SH.MAIN_FOCUS = focus
        local s = F.state({ dollars = 12, ante = 4 })
        s.phase = 'shop'; s.full_deck = C.standard_deck()
        s.round.round_hands, s.round.round_discards, s.round.hand_size = 4, 3, 8
        s.hands.Flush.played = 12; s.hands.Pair.played = 3
        s.shop = { jokers = { { set = 'Planet', key = key, name = key, cost = 3, uid = 'p', hand_type = hand } }, vouchers = {}, boosters = {} }
        local n = SH.analyse(s, { n = 16 }).options[1].note
        SH.MAIN_FOCUS = 0
        return n
    end
    T.ok(planet_note(1, 'c_jupiter', 'Flush') > planet_note(0, 'c_jupiter', 'Flush'), 'main hand planet: more')
    T.ok(planet_note(1, 'c_uranus', 'Two Pair') <= planet_note(0, 'c_uranus', 'Two Pair'), 'another hand: not more')
end

-- Jokers that never carry a sticker (Balatro Wiki, pages Eternal and Perishable): growing jokers
-- are never Perishable, jokers that destroy or sell themselves never Eternal
function S.stickers_the_game_never_puts(T)
    local _, _, _, _, SH = env()
    local e, p = SH.sticker_compat('j_runner')
    T.ok(e, 'Runner can be Eternal'); T.no(p, 'Runner is never Perishable')
    e, p = SH.sticker_compat('j_cavendish')
    T.no(e, 'Cavendish is never Eternal'); T.ok(p)
    e, p = SH.sticker_compat('j_duo')
    T.ok(e and p, 'The Duo: both possible')
    local n = 0
    for _ in pairs(SH.NEVER_PERISHABLE) do n = n + 1 end
    T.eq(n, 18)
    n = 0
    for _ in pairs(SH.NEVER_ETERNAL) do n = n + 1 end
    T.eq(n, 11)
    -- every key is a real joker of the database
    local DB = BSCopilot.require('model/jokers_db')
    for k in pairs(SH.NEVER_PERISHABLE) do T.ok(DB.get(k), k) end
    for k in pairs(SH.NEVER_ETERNAL) do T.ok(DB.get(k), k) end
    -- the simulator keeps its own copy (it must also run older versions of the mod): the same
    local RU = dofile(T.REPO_ROOT .. '/tools/trainer/rules.lua')
    for k in pairs(SH.NEVER_ETERNAL) do T.ok(RU.NEVER_ETERNAL[k], 'simulator: ' .. k) end
    for k in pairs(RU.NEVER_ETERNAL) do T.ok(SH.NEVER_ETERNAL[k], 'mod: ' .. k) end
    for k in pairs(SH.NEVER_PERISHABLE) do T.ok(RU.NEVER_PERISHABLE[k], 'simulator: ' .. k) end
    for k in pairs(RU.NEVER_PERISHABLE) do T.ok(SH.NEVER_PERISHABLE[k], 'mod: ' .. k) end
end

-- High stakes: "safe" asks 95 % for the next blind and 85 % for the boss (white stake: 85 / 70);
-- with the same chances, the savings are kept at the White Stake and spent at the Black Stake
-- (measured on the simulator: +0.18 +- 0.26 blinds per run, noise level; docs/TRAINING.md)
function S.stricter_safety_at_high_stakes(T)
    local _, _, _, A = env()
    local function step(stake)
        local s = { phase = 'shop', econ = { dollars = 30, bankrupt_at = 0, reroll_cost = 6, base_reroll_cost = 5, interest_cap = 25 },
            run = { ante = 3, stake = stake }, jokers = { { key = 'j_joker', uid = 'a' }, { key = 'j_joker', uid = 'b' }, { key = 'j_joker', uid = 'c' } },
            joker_slots = 5, consumables = {}, consumable_slots = 2, vouchers = {} }
        local j = { kind = 'joker', uid = 'n', name = 'Gluttonous Joker', cost = 10, note = 65, affordable = true, interest_loss = 1, joker_kind = 'additive' }
        return A.shop_step(s, { options = { j }, sells = {}, base = { p_next = 0.90, p_boss = 0.80 }, plan = { gaps = {} } })
    end
    T.ok(step(1).action ~= 'buy', 'white stake: next blind 90 % and boss 80 % are safe, the interest is kept')
    T.eq(step(4).action, 'buy', 'black stake: not safe enough, the joker is bought')
    local S0 = A.settings()
    T.eq(S0.hs_safe_next, 0.95); T.eq(S0.hs_safe_boss, 0.85)
end

return S
