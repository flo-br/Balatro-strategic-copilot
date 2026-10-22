-- Balatro Strategic Copilot - game/state_reader.lua  (GameStateReader)
-- The ONLY module that reads the game (global G). It never writes to it and never calls a
-- function that changes the game. It returns a plain-table snapshot (see docs/ARCHITECTURE.md).
-- Information discipline:
--   known    : what the player can see (hand, jokers, money, deck composition via deck view...)
--   inferred : computed from known data (unseen cards, next blind sizes...)
--   unknown  : never read or deliberately discarded (deck ORDER, face-down cards, future shop)

local BSC = BSCopilot
local U = BSC.require('core/util')
local L = BSC.require('core/log')
local C = BSC.require('model/cards')
local H = BSC.require('model/hands')
local DB = BSC.require('model/jokers_db')
local BL = BSC.require('model/blinds_db')
local CM = BSC.require('game/compat')
local num = CM.num -- tolerant to Talisman big numbers

local SR = {}

local function G_() return rawget(_G, 'G') end

local function get(f, default)
    local ok, v = pcall(f)
    if ok and v ~= nil then return v end
    return default
end

function SR.available()
    local G = G_()
    return type(G) == 'table' and type(G.STATES) == 'table' and G.STATE ~= nil
end

function SR.in_run()
    local G = G_()
    return SR.available() and type(G.GAME) == 'table' and G.STAGES ~= nil and G.STAGE == G.STAGES.RUN
end

local PACK_STATES = { 'TAROT_PACK', 'PLANET_PACK', 'SPECTRAL_PACK', 'STANDARD_PACK', 'BUFFOON_PACK', 'SMODS_BOOSTER_OPENED' }

function SR.phase()
    local G = G_()
    if not SR.available() then return 'none' end
    if not SR.in_run() then return 'menu' end
    local s, S = G.STATE, G.STATES
    if s == S.SELECTING_HAND then return 'hand' end
    if s == S.SHOP then return 'shop' end
    if s == S.BLIND_SELECT then return 'blind_select' end
    if s == S.ROUND_EVAL then return 'round_eval' end
    if s == S.GAME_OVER then return 'game_over' end
    for _, k in ipairs(PACK_STATES) do
        if S[k] ~= nil and s == S[k] then return 'pack' end
    end
    return 'busy'
end

local function edition_key(ed)
    if type(ed) ~= 'table' then return nil end
    if type(ed.key) == 'string' then return ed.key end
    if type(ed.type) == 'string' then return 'e_' .. ed.type end
    if ed.foil then return 'e_foil' elseif ed.holo then return 'e_holo'
    elseif ed.polychrome then return 'e_polychrome' elseif ed.negative then return 'e_negative' end
    return 'e_unknown'
end
SR.edition_key = edition_key

local function center_key(card)
    return get(function() return card.config.center.key end, nil)
end

-- Playing card -> normalized card. Face-down cards keep only what the player can see.
function SR.read_playing_card(card, opts)
    opts = opts or {}
    local uid = get(function() return card.sort_id end, nil) or get(function() return card.unique_val end, nil) or tostring(card)
    local face_down = get(function() return card.facing == 'back' end, false)
    -- horizontal position in its area (visible to the player): Death converts the LEFT
    -- selected card into the RIGHT one, so the advice needs the order on screen
    local pos_x = get(function() return card.T.x end, nil)
    if face_down and not opts.reveal then
        return { uid = uid, face_down = true, id = 0, nominal = 0, unknown = true, pos_x = pos_x,
            debuff = get(function() return card.debuff end, false) and true or false,
            forced = get(function() return card.ability.forced_selection end, false) and true or false }
    end
    local base = card.base or {}
    local ab = card.ability or {}
    local rank = base.value
    local c = C.new(rank, base.suit)
    c.uid = uid
    c.id = base.id or c.id
    c.nominal = base.nominal or c.nominal
    c.face_nominal = base.face_nominal or c.face_nominal
    c.suit_nominal = base.suit_nominal or c.suit_nominal
    local ck = center_key(card)
    if ck and ck ~= 'c_base' then
        c.enh = ck
        if not C.ENHANCEMENTS[ck] then c.unknown_enh = true end
    end
    C.apply_enhancement_defaults(c)
    if ck == 'm_stone' then c.id = 0 end
    -- read the real values from the game (they include modifications)
    c.bonus = num(ab.bonus, c.bonus)
    c.mult = num(ab.mult, c.mult)
    c.x_mult = num(ab.x_mult, c.x_mult)
    c.h_x_mult = num(ab.h_x_mult, c.h_x_mult)
    c.h_mult = num(ab.h_mult, c.h_mult)
    c.p_dollars = num(ab.p_dollars, c.p_dollars)
    c.h_dollars = num(ab.h_dollars, c.h_dollars)
    c.perma_bonus = num(ab.perma_bonus, 0)
    c.perma_mult = num(ab.perma_mult, 0)
    c.perma_x_mult = num(ab.perma_x_mult, 0)
    c.perma_h_mult = num(ab.perma_h_mult, 0)
    c.perma_h_x_mult = num(ab.perma_h_x_mult, 0)
    c.perma_p_dollars = num(ab.perma_p_dollars, 0)
    c.perma_repetitions = num(ab.perma_repetitions, 0)
    c.seal = card.seal
    if c.seal and not ({ Red = 1, Blue = 1, Gold = 1, Purple = 1 })[c.seal] then c.unknown_seal = true end
    c.edition = edition_key(card.edition)
    if c.edition and not C.EDITIONS[c.edition] then c.unknown_enh = true end
    c.debuff = card.debuff and true or false
    c.forced = ab.forced_selection and true or false
    c.played_this_ante = ab.played_this_ante and true or false
    c.highlighted = card.highlighted and true or false
    c.face_down = face_down or nil
    c.pos_x = pos_x
    return c
end

function SR.read_joker(card)
    local ck = center_key(card)
    local name = get(function() return card.ability.name end, nil)
    local def = DB.get(ck, name)
    return {
        uid = get(function() return card.sort_id end, nil) or tostring(card),
        key = ck or (def and def.key), name = name or (def and def.name) or ck,
        -- selected by the player (clicked): read by the "my choice" box (game/feedback_input.lua)
        highlighted = card.highlighted and true or nil,
        ability = U.deepcopy(card.ability, 5) or {},
        rarity = get(function() return card.config.center.rarity end, def and def.rarity),
        blueprint_compat = get(function() return card.config.center.blueprint_compat end, def and def.bp),
        edition = edition_key(card.edition),
        sell_cost = num(card.sell_cost, 0),
        cost = num(card.cost, def and def.cost or 0),
        debuff = card.debuff and true or false,
        face_down = get(function() return card.facing == 'back' end, false) or nil,
        eternal = get(function() return card.ability.eternal end, false) and true or nil,
        perishable = get(function() return card.ability.perishable end, false) and true or nil,
        perish_tally = get(function() return card.ability.perish_tally end, nil),
        rental = get(function() return card.ability.rental end, false) and true or nil,
        known = def ~= nil,
    }
end

function SR.read_consumable(card)
    local ab = card.ability or {}
    return {
        uid = get(function() return card.sort_id end, nil) or tostring(card),
        key = center_key(card), name = ab.name, set = ab.set,
        hand_type = get(function() return ab.consumeable.hand_type end, nil),
        edition = edition_key(card.edition),
        sell_cost = num(card.sell_cost, 0),
        debuff = card.debuff and true or false,
        highlighted = card.highlighted and true or nil,
    }
end

-- Shop / pack item (joker, consumable, voucher, booster or playing card)
function SR.read_item(card, area)
    local ab = card.ability or {}
    local set = ab.set or get(function() return card.config.center.set end, nil)
    local item = {
        uid = get(function() return card.sort_id end, nil) or tostring(card),
        key = center_key(card), name = ab.name, set = set, area = area,
        cost = num(card.cost, 0), edition = edition_key(card.edition),
        highlighted = card.highlighted and true or nil,
    }
    if set == 'Joker' then
        item.joker = SR.read_joker(card)
    elseif set == 'Default' or set == 'Enhanced' then
        item.card = SR.read_playing_card(card)
    elseif set == 'Planet' then
        item.hand_type = get(function() return ab.consumeable.hand_type end, nil)
    elseif set == 'Booster' then
        item.kind = get(function() return card.config.center.kind end, nil)
        item.pack_size = get(function() return card.config.center.config.extra end, nil)
        item.choose = get(function() return card.config.center.config.choose end, nil)
    end
    return item
end

local function read_area(area, reader, ...)
    local out = {}
    if type(area) ~= 'table' or type(area.cards) ~= 'table' then return out end
    for _, card in ipairs(area.cards) do
        local ok, v = pcall(reader, card, ...)
        if ok and v then out[#out + 1] = v else L.debug('reader', 'card read failed: %s', tostring(v)) end
    end
    return out
end

local function deck_sort(a, b)
    if (a.suit or '') ~= (b.suit or '') then return (a.suit or '') < (b.suit or '') end
    if (a.id or 0) ~= (b.id or 0) then return (a.id or 0) < (b.id or 0) end
    return tostring(a.uid) < tostring(b.uid)
end

function SR.deck_stats(cards, starting_size)
    local st = { size = #cards, starting_size = starting_size or 52, steel = 0, stone = 0, gold = 0, glass = 0,
        lucky = 0, wild = 0, enhanced = 0, faces = 0, nines = 0, suits = {}, ranks = {} }
    for _, c in ipairs(cards) do
        if c.enh then st.enhanced = st.enhanced + 1 end
        if c.enh == 'm_steel' then st.steel = st.steel + 1 end
        if c.enh == 'm_stone' then st.stone = st.stone + 1 end
        if c.enh == 'm_gold' then st.gold = st.gold + 1 end
        if c.enh == 'm_glass' then st.glass = st.glass + 1 end
        if c.enh == 'm_lucky' then st.lucky = st.lucky + 1 end
        if c.enh == 'm_wild' then st.wild = st.wild + 1 end
        if C.has_rank(c) then
            st.ranks[c.id] = (st.ranks[c.id] or 0) + 1
            if c.id >= 11 and c.id <= 13 then st.faces = st.faces + 1 end
            if c.id == 9 then st.nines = st.nines + 1 end
        end
        if c.suit and not c.no_suit then st.suits[c.suit] = (st.suits[c.suit] or 0) + 1 end
    end
    return st
end

local function read_hands(G)
    local hands = {}
    for name, h in pairs(G.GAME.hands or {}) do
        hands[name] = {
            level = num(h.level, 1), chips = num(h.chips, 0), mult = num(h.mult, 1),
            l_chips = num(h.l_chips, 0), l_mult = num(h.l_mult, 0),
            s_chips = num(h.s_chips, nil), s_mult = num(h.s_mult, nil),
            played = num(h.played, 0), played_this_round = num(h.played_this_round, 0),
            visible = h.visible ~= false, modded = H.BASE[name] == nil or nil,
        }
    end
    if next(hands) == nil then return H.default_table() end
    return hands
end

local function blind_amount(G, ante)
    local f = rawget(_G, 'get_blind_amount')
    if type(f) == 'function' then
        local ok, v = pcall(f, ante)
        if ok and type(v) == 'number' then return v end
    end
    return BL.base_amount(ante, get(function() return G.GAME.modifiers.scaling end, 1))
end

-- Upcoming blinds of the current ante (sizes from the game's own formula).
local function read_upcoming(G, ante)
    local out = {}
    local choices = get(function() return G.GAME.round_resets.blind_choices end, {})
    local states = get(function() return G.GAME.round_resets.blind_states end, {})
    local ante_scaling = get(function() return G.GAME.starting_params.ante_scaling end, 1)
    local amount = blind_amount(G, ante)
    -- Red Stake and above: the Small Blind pays no reward (G.GAME.modifiers.no_blind_reward)
    local no_reward = get(function() return G.GAME.modifiers.no_blind_reward end, nil)
    for _, slot in ipairs({ 'Small', 'Big', 'Boss' }) do
        local key = choices[slot]
        if key then
            local pb = get(function() return G.P_BLINDS[key] end, nil)
            local mult = (pb and pb.mult) or (BL.get(key) and BL.get(key).mult) or 1
            out[#out + 1] = {
                slot = slot, key = key, name = (pb and pb.name) or (BL.get(key) and BL.get(key).name) or key,
                boss = (pb and pb.boss) and true or (slot == 'Boss'), state = states[slot],
                chips = math.floor(amount * mult * ante_scaling),
                reward = (type(no_reward) == 'table' and no_reward[slot]) and 0
                    or (pb and pb.dollars) or (slot == 'Small' and 3 or slot == 'Big' and 4 or 5),
                known_key = BL.get(key) ~= nil,
            }
        end
    end
    return out
end

-- Main entry: returns snapshot (never raises).
function SR.snapshot(opts)
    opts = opts or {}
    local G = G_()
    local s = { phase = SR.phase(), errors = {}, knowledge = { known = {}, inferred = {}, unknown = {} } }
    if not SR.in_run() then return s end
    local t0 = U.now()

    local function section(name, f)
        local ok, err = pcall(f)
        if not ok then
            s.errors[name] = tostring(err)
            L.warn('reader', 'section %s failed: %s', name, tostring(err))
        end
    end

    section('meta', function()
        s.meta = { game_version = rawget(_G, 'VERSION') or get(function() return G.VERSION end, '?'),
            smods_version = rawget(_G, 'MODDED_VERSION') or '?' }
    end)

    section('run', function()
        local GG = G.GAME
        s.run = {
            ante = num(get(function() return GG.round_resets.ante end, 1), 1),
            round = num(GG.round, 0),
            win_ante = num(GG.win_ante, 8),
            stake = num(GG.stake, 1),
            deck_key = get(function() return GG.selected_back.effect.center.key end, nil),
            deck_name = get(function() return GG.selected_back.name end, nil),
            challenge = GG.challenge,
            seeded = GG.seeded and true or false,
            seed = get(function() return GG.pseudorandom.seed end, nil),
            won = GG.won and true or false,
            hands_played = num(GG.hands_played, 0),
            skips = num(GG.skips, 0),
            -- discards left unused at the end of rounds (Garbage Tag); nil when the game has none
            unused_discards = tonumber(get(function() return GG.unused_discards end, nil)),
            tarots_used = num(get(function() return GG.consumeable_usage_tally.tarot end, 0), 0),
            planets_used = num(get(function() return GG.consumeable_usage_tally.planet end, 0), 0),
            scaling = num(get(function() return GG.modifiers.scaling end, 1), 1),
            ante_scaling = num(get(function() return GG.starting_params.ante_scaling end, 1), 1),
            endless = (GG.won and true or false),
        }
    end)

    section('econ', function()
        local GG = G.GAME
        s.econ = {
            dollars = num(GG.dollars, 0),
            interest_cap = num(GG.interest_cap, 25),
            interest_amount = num(GG.interest_amount, 1),
            no_interest = get(function() return GG.modifiers.no_interest end, false) and true or false,
            money_per_hand = num(get(function() return GG.modifiers.money_per_hand end, nil), 1),
            money_per_discard = num(get(function() return GG.modifiers.money_per_discard end, nil), 0),
            reroll_cost = num(get(function() return GG.current_round.reroll_cost end, 5), 5),
            free_rerolls = num(get(function() return GG.current_round.free_rerolls end, 0), 0),
            base_reroll_cost = num(get(function() return GG.round_resets.reroll_cost end, 5), 5),
            -- read only when the game has it (reroll start price set by the D6 tag)
            temp_reroll_cost = get(function() return GG.round_resets.temp_reroll_cost end, nil),
            bankrupt_at = num(GG.bankrupt_at, 0),
            discount_percent = num(GG.discount_percent, 0),
            inflation = num(GG.inflation, 0),
            rates = {
                joker = num(GG.joker_rate, 20), tarot = num(GG.tarot_rate, 4), planet = num(GG.planet_rate, 4),
                spectral = num(GG.spectral_rate, 0), playing_card = num(GG.playing_card_rate, 0),
                edition = num(GG.edition_rate, 1),
            },
        }
    end)

    section('blind', function()
        local b = G.GAME.blind
        if type(b) == 'table' then
            s.blind = {
                key = get(function() return b.config.blind.key end, nil),
                name = b.name, boss = b.boss and true or false,
                chips_required = num(b.chips, 0), chips_scored = num(G.GAME.chips, 0),
                disabled = b.disabled and true or false,
                in_blind = b.in_blind and true or false,
                hands_used = U.deepcopy(b.hands, 2), only_hand = b.only_hand,
            }
            s.blind.known_key = s.blind.key == nil or BL.get(s.blind.key) ~= nil
        end
        s.upcoming = read_upcoming(G, s.run and s.run.ante or 1)
        s.blind_on_deck = G.GAME.blind_on_deck
    end)

    section('round', function()
        local cr = G.GAME.current_round or {}
        s.round = {
            hands_left = num(cr.hands_left, 0), discards_left = num(cr.discards_left, 0),
            hands_played = num(cr.hands_played, 0), discards_used = num(cr.discards_used, 0),
            hand_size = num(get(function() return G.hand.config.card_limit end, 8), 8),
            round_hands = num(get(function() return G.GAME.round_resets.hands end, 4), 4),
            round_discards = num(get(function() return G.GAME.round_resets.discards end, 3), 3),
        }
    end)

    section('hands', function() s.hands = read_hands(G) end)

    section('jokers', function()
        s.jokers = read_area(G.jokers, SR.read_joker)
        s.joker_slots = num(get(function() return G.jokers.config.card_limit end, 5), 5)
    end)

    section('consumables', function()
        s.consumables = read_area(G.consumeables, SR.read_consumable)
        s.consumable_slots = num(get(function() return G.consumeables.config.card_limit end, 2), 2)
        s.vouchers = U.deepcopy(G.GAME.used_vouchers, 2) or {}
        s.flags = s.flags or {}
        s.flags.observatory_x = num(get(function() return G.P_CENTERS.v_observatory.config.extra end, 1.5), 1.5)
    end)

    section('cards', function()
        s.hand_cards = read_area(G.hand, SR.read_playing_card)
        s.highlighted = {}
        for _, c in ipairs(s.hand_cards) do if c.highlighted then s.highlighted[#s.highlighted + 1] = c.uid end end
        -- remaining draw pile: composition only (order is hidden information)
        local deck = read_area(G.deck, SR.read_playing_card, { reveal = true })
        for _, c in ipairs(deck) do c.face_down = nil end
        table.sort(deck, deck_sort)
        s.deck = deck
        s.deck_count = #deck
        local full = read_area({ cards = G.playing_cards }, SR.read_playing_card, { reveal = true })
        for _, c in ipairs(full) do c.face_down = nil; c.highlighted = nil; c.forced = nil end
        table.sort(full, deck_sort)
        s.full_deck = full
        s.full_deck_stats = SR.deck_stats(full, num(G.GAME.starting_deck_size, 52))
    end)

    section('shop', function()
        if s.phase == 'shop' then
            s.shop = {
                jokers = read_area(G.shop_jokers, SR.read_item, 'shop'),
                vouchers = read_area(G.shop_vouchers, SR.read_item, 'voucher'),
                boosters = read_area(G.shop_booster, SR.read_item, 'booster'),
            }
        end
        if s.phase == 'pack' then
            s.pack = { cards = read_area(G.pack_cards, SR.read_item, 'pack'),
                choices_left = num(G.GAME.pack_choices, 1) }
        end
    end)

    -- joker pool as the game builds it (unlocked, enhancement gates, pool flags, bans)
    section('pool', function()
        if s.phase ~= 'shop' then return end
        local centers = get(function() return G.P_CENTER_POOLS.Joker end, nil)
        if type(centers) ~= 'table' then return end
        local flags = G.GAME.pool_flags or {}
        local banned = G.GAME.banned_keys or {}
        local enh_present = {}
        for _, c in ipairs(s.full_deck or {}) do if c.enh then enh_present[c.enh] = true end end
        local pool = {}
        for _, center in ipairs(centers) do
            if type(center) == 'table' and center.key then
                local avail = (center.unlocked ~= false) and not banned[center.key]
                if center.enhancement_gate then avail = avail and enh_present[center.enhancement_gate] == true end
                if center.yes_pool_flag then avail = avail and flags[center.yes_pool_flag] and true or false end
                if center.no_pool_flag and flags[center.no_pool_flag] then avail = false end
                pool[#pool + 1] = { key = center.key, rarity = center.rarity, available = avail and true or false }
            end
        end
        s.joker_pool = pool
    end)

    section('tags', function()
        local tags = get(function() return G.GAME.round_resets.blind_tags end, nil)
        if type(tags) == 'table' then
            s.blind_tags = { Small = tags.Small, Big = tags.Big }
            -- names as the game shows them (its own localization)
            s.blind_tag_names = {}
            for slot, key in pairs(s.blind_tags) do
                s.blind_tag_names[slot] = get(function() return G.localization.descriptions.Tag[key].name end, nil)
            end
        end
        -- tags already held (Double Tags copy the next tag obtained)
        local held = get(function() return G.GAME.tags end, nil)
        if type(held) == 'table' then
            s.tags_held = {}
            for _, t in ipairs(held) do
                local k = type(t) == 'table' and t.key
                if type(k) == 'string' then s.tags_held[#s.tags_held + 1] = k end
            end
        end
        -- the poker hand an Orbital Tag would level up (shown on the tag; nil when unknown)
        local ante = get(function() return G.GAME.round_resets.ante end, nil)
        local oc = ante and get(function() return G.GAME.orbital_choices[ante] end, nil)
        if type(oc) == 'table' then s.orbital_hands = { Small = oc.Small, Big = oc.Big } end
    end)

    section('targets', function()
        local cr = G.GAME.current_round or {}
        local idol = cr.idol_card
        local mail = cr.mail_card
        s.targets = {
            ancient_suit = get(function() return cr.ancient_card.suit end, nil),
            castle_suit = get(function() return cr.castle_card.suit end, nil),
            idol = idol and { id = num(idol.id, nil) or (C.RANKS[idol.rank] and C.RANKS[idol.rank].id), suit = idol.suit, rank = idol.rank } or nil,
            mail_id = mail and (num(mail.id, nil) or (C.RANKS[mail.rank] and C.RANKS[mail.rank].id)) or nil,
            most_played_hand = cr.most_played_poker_hand,
        }
    end)

    section('flags', function()
        s.probabilities_normal = num(get(function() return G.GAME.probabilities.normal end, 1), 1)
        s.flags = s.flags or {}
        s.flags.plasma = (s.run and s.run.deck_key == 'b_plasma') or false
    end)

    -- knowledge bookkeeping (for the UI and documentation of what is assumed)
    s.knowledge.known = { 'hand_cards', 'jokers', 'money', 'deck_composition', 'hand_levels', 'blind' }
    s.knowledge.inferred = { 'unseen_cards', 'upcoming_blind_sizes', 'interest' }
    s.knowledge.unknown = { 'deck_order', 'face_down_cards', 'future_shops' }
    local hidden = 0
    for _, c in ipairs(s.hand_cards or {}) do if c.face_down then hidden = hidden + 1 end end
    s.knowledge.hidden_hand_cards = hidden

    s.read_ms = (U.now() - t0) * 1000
    return s
end

return SR
