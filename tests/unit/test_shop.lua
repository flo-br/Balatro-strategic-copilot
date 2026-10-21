local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    local SH = BSCopilot.require('engine/shop')
    return F, C, SH
end

local function shop_state(F, C, o)
    o = o or {}
    local s = F.state({ jokers = o.jokers or {}, dollars = o.dollars or 10, joker_slots = o.slots or 5, levels = o.levels })
    s.phase = 'shop'
    s.full_deck = C.standard_deck()
    s.round.round_hands, s.round.round_discards, s.round.hand_size = 4, 3, 8
    s.run.ante = 2
    s.upcoming = {
        { slot = 'Small', key = 'bl_small', chips = 800, state = 'Select' },
        { slot = 'Big', key = 'bl_big', chips = 1200, state = 'Upcoming' },
        { slot = 'Boss', key = 'bl_hook', chips = 1600, boss = true, state = 'Upcoming' },
    }
    local items = {}
    for i, it in ipairs(o.items or {}) do it.uid = it.uid or ('item' .. i); items[i] = it end
    s.shop = { jokers = items, vouchers = o.vouchers or {}, boosters = o.boosters or {} }
    return s
end

local function joker_item(F, key, cost, ability)
    local j = F.joker(key, ability)
    return { set = 'Joker', key = key, name = j.name, cost = cost or 5, joker = j }
end

function S.strong_joker_beats_weak(T)
    local F, C, SH = env()
    local s = shop_state(F, C, { items = { joker_item(F, 'j_credit_card', 1), joker_item(F, 'j_duo', 8) }, dollars = 12 })
    local r = SH.analyse(s, { n = 24 })
    T.eq(r.options[1].key, 'j_duo', 'The Duo ranked first')
    T.ok(r.options[1].note > r.options[2].note)
    T.ok(r.options[1].ratio > 1.3, 'Duo raises power')
    T.ok(r.options[1].note >= 0 and r.options[1].note <= 100)
    T.ok(r.base.p_next ~= nil and r.base.p_boss ~= nil)
end

function S.rental_priced_over_the_rounds_kept(T)
    -- gold stake: a $1 rental costs $3 at the end of every round; two of them in ante 1 used to
    -- eat all the money of a simulated run (bought at notes 83 and 64 because they cost "$1")
    local F, C, SH = env()
    local plain = joker_item(F, 'j_lusty_joker', 1)
    local rented = joker_item(F, 'j_lusty_joker', 1)
    rented.joker.rental = true
    rented.uid = 'rented'
    local function board() return { F.joker('j_joker'), F.joker('j_greedy_joker'), F.joker('j_jolly') } end
    local r1 = SH.analyse(shop_state(F, C, { items = { plain }, dollars = 6, jokers = board() }), { n = 24 })
    local r2 = SH.analyse(shop_state(F, C, { items = { rented }, dollars = 6, jokers = board() }), { n = 24 })
    T.ok(r2.options[1].rental, 'flagged as a rental')
    T.ok(r2.options[1].note + 10 <= r1.options[1].note,
        string.format('rental note %d well below %d', r2.options[1].note, r1.options[1].note))
end

function S.scaling_joker_sale_counts_its_growth(T)
    -- a fresh Runner adds nothing yet (+0 chips) but +15 chips per straight: not "useless"
    local F, C, SH = env()
    local s = shop_state(F, C, { jokers = { F.joker('j_joker'), F.joker('j_runner', { extra = { chips = 0 } }) } })
    local r = SH.analyse(s, { n = 24 })
    local runner
    for _, sl in ipairs(r.sells) do if sl.name == 'Runner' then runner = sl end end
    T.ok(runner, 'Runner in the sales')
    T.ok(runner.growth and runner.growth > 0, 'growth counted')
    T.ok(runner.contribution > 0.03, string.format('contribution with growth %.3f', runner.contribution))
end

function S.unaffordable_is_flagged(T)
    local F, C, SH = env()
    local s = shop_state(F, C, { items = { joker_item(F, 'j_duo', 8) }, dollars = 3 })
    local r = SH.analyse(s, { n = 16 })
    T.eq(r.options[1].affordable, false)
end

function S.full_slots_offer_replacement(T)
    local F, C, SH = env()
    local jokers = {}
    for _ = 1, 5 do jokers[#jokers + 1] = F.joker('j_credit_card') end
    local s = shop_state(F, C, { jokers = jokers, items = { joker_item(F, 'j_duo', 8) }, dollars = 20 })
    local r = SH.analyse(s, { n = 16 })
    T.eq(r.options[1].kind, 'replace')
    T.eq(r.options[1].replaces, 'Credit Card')
end

function S.planet_for_played_hand(T)
    local F, C, SH = env()
    local s = shop_state(F, C, { items = {
        { set = 'Planet', key = 'c_mercury', name = 'Mercury', cost = 3, hand_type = 'Pair' },
        { set = 'Planet', key = 'c_eris', name = 'Eris', cost = 3, hand_type = 'Flush Five' },
    } })
    local r = SH.analyse(s, { n = 24 })
    local notes = {}
    for _, o in ipairs(r.options) do notes[o.key] = o end
    T.ok(notes.c_mercury.ratio > 1.0, 'Mercury helps (pairs are common)')
    T.near(notes.c_eris.ratio, 1, 1e-9, 'Flush Five never played: no gain')
    T.ok(notes.c_mercury.note > notes.c_eris.note)
end

function S.variant_level_up(T)
    local F, C, SH = env()
    local s = shop_state(F, C)
    local v = SH.variant(s, { level = 'Pair', n = 1 })
    T.eq(v.hands.Pair.level, 2); T.eq(v.hands.Pair.chips, 25); T.eq(v.hands.Pair.mult, 3)
    T.eq(s.hands.Pair.level, 1, 'original state untouched')
    local v2 = SH.variant(s, { enhance = 'm_mult', n = 2 })
    local n = 0
    for _, c in ipairs(v2.full_deck) do if c.enh == 'm_mult' then n = n + 1 end end
    T.eq(n, 2)
    for _, c in ipairs(s.full_deck) do T.no(c.enh) end
end

function S.reroll_estimate(T)
    local F, C, SH = env()
    local s = shop_state(F, C, { items = { joker_item(F, 'j_duo', 8) }, dollars = 30 })
    local r = SH.analyse(s, { n = 16 })
    T.ok(r.reroll and r.reroll.n > 0)
    T.ok(r.reroll.p_improve >= 0 and r.reroll.p_improve <= 1)
    T.eq(r.reroll.method, 'monte_carlo')
    -- full slots of weak jokers: a reroll can still find a better one (measured as a replacement)
    local weak = {}
    for _ = 1, 5 do weak[#weak + 1] = F.joker('j_credit_card') end
    local s2 = shop_state(F, C, { jokers = weak, items = { joker_item(F, 'j_credit_card', 1) }, dollars = 60 })
    local r2 = SH.analyse(s2, { n = 16 })
    T.ok(r2.reroll.p_improve > 0.2, 'full slots: rerolls are not worthless ' .. r2.reroll.p_improve)
end

function S.note_weights_follow_danger(T)
    local _, _, SH = env()
    local calm, crit = SH.weights(0), SH.weights(1)
    T.ok(crit.impact > calm.impact, 'danger raises the weight of immediate impact')
    T.ok(crit.econ < calm.econ, 'danger lowers the weight of economy')
    T.eq(SH.note({}, calm), 50)
end

-- Boosters valued by their content: Buffoon packs carry jokers measured by simulation, Arcana
-- packs tarots scored like in the shop (but free), Standard packs stay low.
function S.boosters_valued_by_content(T)
    local F, C, SH = env()
    local function pack(uid, kind, cost, size, choose)
        return { uid = uid, set = 'Booster', key = 'p_' .. kind:lower(), name = kind .. ' Pack', kind = kind, cost = cost, pack_size = size, choose = choose }
    end
    local s = shop_state(F, C, { dollars = 12, boosters = { pack('buf', 'Buffoon', 4, 2, 1), pack('arc', 'Arcana', 4, 3, 1),
        pack('std', 'Standard', 4, 3, 1), pack('mega', 'Buffoon', 8, 4, 2) } })
    local r = SH.analyse(s, { n = 16 })
    local by = {}
    for _, o in ipairs(r.options) do by[o.uid] = o end
    for _, o in ipairs(r.options) do
        T.eq(o.kind, 'booster')
        T.ok(o.note >= 0 and o.note <= 100)
        local shown = tonumber(o.reasons[1]:match('~(%d+)/100'))
        T.ok(shown and shown <= 100, o.reasons[1])
    end
    T.ok(by.buf.note > by.std.note, 'Buffoon above Standard')
    T.ok(by.arc.note > by.std.note, 'Arcana above Standard')
    T.ok(by.mega.note >= by.buf.note - 5, 'Mega Buffoon: 2 jokers among 4')
    T.ok(by.buf.note >= 52, 'a Buffoon pack is worth buying with free slots')
end

function S.buffoon_pack_counts_the_stake_stickers(T)
    -- gold stake: pack jokers can be rentals / perishable / eternal; the pack is worth less
    local F, C, SH = env()
    local function note(stake)
        local s = shop_state(F, C, { dollars = 8, jokers = { F.joker('j_joker'), F.joker('j_greedy_joker') },
            boosters = { { uid = 'buf', set = 'Booster', key = 'p_buffoon', name = 'Buffoon Pack', kind = 'Buffoon', cost = 4, pack_size = 2, choose = 1 } } })
        s.run.stake = stake
        local r = SH.analyse(s, { n = 16 })
        for _, o in ipairs(r.options) do if o.uid == 'buf' then return o.note end end
    end
    local white, gold = note(1), note(8)
    T.ok(gold < white, string.format('gold %d below white %d', gold, white))
end

-- A joker taken from a Buffoon Pack is free: only the pack price is paid (before, the jokers of
-- the pack were also charged their shop price, a pack worth ~5 to 12 points less when money is low)
function S.buffoon_pack_jokers_are_free(T)
    local F, C, SH = env()
    local function note(free)
        local was = SH.PACK_JOKERS_FREE
        SH.PACK_JOKERS_FREE = free
        local s = shop_state(F, C, { dollars = 6, jokers = { F.joker('j_joker') },
            boosters = { { uid = 'buf', set = 'Booster', key = 'p_buffoon', name = 'Buffoon Pack', kind = 'Buffoon', cost = 4, pack_size = 2, choose = 1 } } })
        local r = SH.analyse(s, { n = 16 })
        SH.PACK_JOKERS_FREE = was
        for _, o in ipairs(r.options) do if o.uid == 'buf' then return o.note end end
    end
    local paid, free = note(false), note(true)
    T.ok(free > paid, string.format('free jokers %d above paid ones %d', free, paid))
end

-- Playing cards are worth their modifiers; Judgement with full slots is measured as a swap.
function S.cards_and_judgement_with_full_slots(T)
    local F, C, SH = env()
    local poly, plain = C.parse('Ks'), C.parse('Kh')
    poly.edition = 'e_polychrome'; C.set_enhancement(poly, 'm_steel')
    local s = shop_state(F, C, { dollars = 10, items = {
        { uid = 'poly', set = 'Default', key = 'c_base', name = 'K', cost = 4, card = poly },
        { uid = 'plain', set = 'Default', key = 'c_base', name = 'K', cost = 4, card = plain } } })
    local r = SH.analyse(s, { n = 16 })
    local by = {}
    for _, o in ipairs(r.options) do by[o.uid] = o end
    T.ok(by.poly.note > by.plain.note + 10, 'steel polychrome card above a plain one')
    T.ok(by.plain.note < 50, 'a plain card dilutes the deck')
    local jokers = {}
    for _ = 1, 5 do jokers[#jokers + 1] = F.joker('j_credit_card') end
    local s2 = shop_state(F, C, { jokers = jokers, dollars = 10, items = { { uid = 'jg', set = 'Tarot', key = 'c_judgement', name = 'Judgement', cost = 3 } } })
    local r2 = SH.analyse(s2, { n = 16 })
    local o = r2.options[1]
    T.ok(o.swap and o.swap.worth, 'Credit Cards are worth replacing by a random joker')
    T.eq(o.swap.sell.key, 'j_credit_card')
    T.ok(r2.slot_swaps and r2.slot_swaps.any)
end

-- Hex / Ankh destroy the other jokers: measured on the boards they leave, never a fixed value.
function S.destructive_spectrals_are_measured(T)
    local F, C, SH = env()
    local jokers = { F.joker('j_duo'), F.joker('j_joker'), F.joker('j_abstract'), F.joker('j_greedy_joker') }
    local s = shop_state(F, C, { jokers = jokers, dollars = 10, items = {
        { uid = 'hex', set = 'Spectral', key = 'c_hex', name = 'Hex', cost = 4 },
        { uid = 'ankh', set = 'Spectral', key = 'c_ankh', name = 'Ankh', cost = 4 } } })
    local r = SH.analyse(s, { n = 16 })
    for _, o in ipairs(r.options) do
        T.ok(o.note < 50, o.name .. ' on a 4-joker board: ' .. o.note)
        T.ok(o.risks[1] and o.risks[1]:find('détruit', 1, true), o.name)
    end
    -- a single joker carries the run: Hex (Polychrome on it) is welcome
    local s1 = shop_state(F, C, { jokers = { F.joker('j_duo') }, dollars = 10, items = {
        { uid = 'hex', set = 'Spectral', key = 'c_hex', name = 'Hex', cost = 4 } } })
    local r1 = SH.analyse(s1, { n = 16 })
    T.ok(r1.options[1].note > 50, 'Hex on a lone joker: ' .. r1.options[1].note)
end

return S
