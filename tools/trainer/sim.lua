-- Balatro Strategic Copilot - tools/trainer/sim.lua
-- A simplified Balatro (vanilla 1.0.1 rules, White Stake) used to TRAIN and evaluate the
-- copilot: full runs whose decisions are all taken by the copilot's own advice engine (see
-- player.lua). Scoring uses the mod's exact score engine; the game around it (draws, blinds,
-- bosses, money, shops, packs, consumables, vouchers, tags, joker events) is re-implemented
-- here from the vanilla rules. It is NOT the real game: the simplifications are listed in
-- docs/TRAINING.md. Nothing here is loaded by the mod.

local BSC = BSCopilot
local U = BSC.require('core/util')
local Rng = BSC.require('core/rng')
local C = BSC.require('model/cards')
local H = BSC.require('model/hands')
local DB = BSC.require('model/jokers_db')
local IT = BSC.require('model/items_db')
local BL = BSC.require('model/blinds_db')
local Score = BSC.require('engine/score')
local SH = BSC.require('engine/shop')
local SR = BSC.require('game/state_reader')

local RU = dofile(TRAINER_DIR .. '/rules.lua')

local Sim = {}
Sim.__index = Sim
Sim.RULES = RU

-- helpers ------------------------------------------------------------------------------------
local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
local function remove_value(list, x)
    for i, v in ipairs(list) do if v == x then table.remove(list, i); return true end end
    return false
end
local function by_uid(list, uid)
    for i, v in ipairs(list) do if tostring(v.uid) == tostring(uid) then return v, i end end
end
local function count(list, f) local n = 0 for _, v in ipairs(list) do if f(v) then n = n + 1 end end return n end

function Sim:new_uid()
    self.uid_counter = self.uid_counter + 1
    return self.uid_counter
end

function Sim:event(kind, data)
    data = data or {}
    data.kind = kind
    data.ante, data.round = self.ante, self.round
    self.events[#self.events + 1] = data
end

-- set a playing card's rank in place (Strength, Ouija...)
local function set_rank(c, rank)
    local r = C.RANKS[rank]
    c.rank = rank
    if not c.no_rank then c.id = r.id end
    c.nominal = r.nominal
    c.face_nominal = r.face_nominal
end

local function set_suit(c, suit)
    c.suit = suit
    c.suit_nominal = C.SUIT_NOMINAL[suit] or 0
end

-- New run -------------------------------------------------------------------------------------
function Sim.new(seed, opts)
    opts = opts or {}
    local g = setmetatable({}, Sim)
    g.seed = tostring(seed)
    g.rng = Rng.new('sim:' .. g.seed)
    g.uid_counter = 700000
    g.deck_key = opts.deck or 'b_red'
    g.stake = math.max(1, math.min(8, tonumber(opts.stake) or 1))
    local d = RU.DECKS[g.deck_key] or {}
    g.deck_rules = d
    g.dollars = RU.START.dollars + (d.dollars or 0)
    g.round_hands = RU.START.hands + (d.hands or 0)
    g.round_discards = RU.START.discards + (d.discards or 0) - ((g.stake >= 5) and 1 or 0)
    g.hand_size = RU.START.hand_size + (d.hand_size or 0)
    g.joker_slots = RU.START.joker_slots + (d.joker_slots or 0)
    g.consumable_slots = RU.START.consumable_slots + (d.consumable_slots or 0)
    g.interest_cap = RU.START.interest_cap
    g.reroll_base = RU.START.reroll_cost
    g.shop_slots = 2
    g.discount = 0
    g.edition_rate = 1
    g.rates = copy(RU.SHOP_RATES)
    if d.spectral_rate then g.rates.spectral = d.spectral_rate end
    g.scaling = (g.stake >= 6) and 3 or ((g.stake >= 3) and 2 or 1)
    g.ante_scaling = d.ante_scaling or 1
    g.ante, g.round = 1, 0
    g.cards = C.standard_deck()
    if d.cards == 'no_faces' then
        local keep = {}
        for _, c in ipairs(g.cards) do if not (c.id >= 11 and c.id <= 13) then keep[#keep + 1] = c end end
        g.cards = keep
    elseif d.cards == 'checkered' then
        for _, c in ipairs(g.cards) do
            if c.suit == 'Clubs' then c.suit = 'Spades' elseif c.suit == 'Diamonds' then c.suit = 'Hearts' end
        end
    end
    for _, c in ipairs(g.cards) do c.uid = g:new_uid() end
    g.hands = H.default_table()
    g.jokers, g.consumables, g.vouchers = {}, {}, {}
    g.tags = {}
    g.bosses_used = {}
    g.stats = { hands_played = 0, skips = 0, tarots_used = 0, planets_used = 0, planet_types = {}, rerolls = 0,
        unused_discards = 0, last_used = nil }
    g.events = {}
    g.history = {}
    g.won, g.lost = false, false
    if d.cards == 'erratic' then
        for _, c in ipairs(g.cards) do
            local nc = C.standard_deck()[g.rng:int(1, 52)]
            set_rank(c, nc.rank); c.suit = nc.suit
        end
    end
    for _, v in ipairs(d.vouchers or {}) do g:apply_voucher(v) end
    for _, k in ipairs(d.consumables or {}) do
        local set = (k == 'c_hex') and 'Spectral' or 'Tarot'
        g.consumables[#g.consumables + 1] = g:make_consumable(k, set)
    end
    g:new_ante()
    return g
end

-- Blinds of the ante ------------------------------------------------------------------------
function Sim:pick_boss()
    local cands, least = {}, math.huge
    local final = (self.ante % RU.START.win_ante == 0)
    for key, b in pairs(BL.BLINDS) do
        if b.boss then
            local ok
            if final then ok = b.final else ok = (not b.final) and (b.min or 1) <= self.ante end
            if ok then
                local used = self.bosses_used[key] or 0
                if used < least then least = used; cands = { key } elseif used == least then cands[#cands + 1] = key end
            end
        end
    end
    table.sort(cands)
    local key = cands[self.rng:int(1, #cands)]
    self.bosses_used[key] = (self.bosses_used[key] or 0) + 1
    return key
end

function Sim:pick_tag()
    local list = {}
    for _, t in ipairs(RU.TAGS) do if t[2] <= self.ante then list[#list + 1] = t[1] end end
    return list[self.rng:int(1, #list)]
end

function Sim:new_ante()
    local amount = BL.base_amount(self.ante, self.scaling or 1) * (self.ante_scaling or 1)
    local boss = self:pick_boss()
    local bb = BL.get(boss)
    self.upcoming = {
        { slot = 'Small', key = 'bl_small', name = 'Small Blind', boss = false, chips = math.floor(amount * 1),
            reward = (self.stake >= 2) and 0 or RU.BLIND_REWARD.Small, state = 'Select' },
        { slot = 'Big', key = 'bl_big', name = 'Big Blind', boss = false, chips = math.floor(amount * 1.5), reward = RU.BLIND_REWARD.Big, state = 'Upcoming' },
        { slot = 'Boss', key = boss, name = bb.name, boss = true, chips = math.floor(amount * (bb.mult or 2)), reward = RU.BLIND_REWARD.Boss, state = 'Upcoming' },
    }
    self.blind_tags = { Small = self:pick_tag(), Big = self:pick_tag() }
    -- the hand each Orbital Tag would level up is shown on the blind select screen
    local names = {}
    for _, n in ipairs(H.ORDER) do if self.hands[n] and self.hands[n].visible ~= false then names[#names + 1] = n end end
    self.orbital_hands = { Small = names[self.rng:int(1, #names)], Big = names[self.rng:int(1, #names)] }
    self.voucher_offer = self:pick_voucher()
    for _, c in ipairs(self.cards) do c.played_this_ante = nil end
end

function Sim:current_blind_entry()
    for _, b in ipairs(self.upcoming) do if b.state == 'Select' or b.state == 'Current' then return b end end
end

function Sim:advance_blind(state_of_current)
    local cur = self:current_blind_entry()
    if not cur then return end
    cur.state = state_of_current
    for i, b in ipairs(self.upcoming) do
        if b == cur and self.upcoming[i + 1] then self.upcoming[i + 1].state = 'Select' end
    end
end

-- Snapshot (same shape as game/state_reader.lua) --------------------------------------------
local function mask(c, pos)
    if c.face_down then
        return { uid = c.uid, face_down = true, id = 0, nominal = 0, unknown = true, pos_x = pos, debuff = c.debuff, forced = c.forced }
    end
    local o = C.copy(c)
    o.pos_x = pos
    return o
end

local function joker_copy(j)
    local o = copy(j)
    o.ability = U.deepcopy(j.ability, 6) or {}
    return o
end

function Sim:most_played_hand()
    local best, bn = 'High Card', -1
    for _, name in ipairs(H.ORDER) do
        local h = self.hands[name]
        if h and (h.played or 0) > bn then best, bn = name, h.played or 0 end
    end
    return best
end

function Sim:snapshot(phase)
    local s = { phase = phase, errors = {}, knowledge = {} }
    s.run = { ante = self.ante, round = self.round, win_ante = RU.START.win_ante, stake = self.stake, deck_key = self.deck_key,
        hands_played = self.stats.hands_played, skips = self.stats.skips, tarots_used = self.stats.tarots_used,
        planets_used = self.stats.planets_used, planet_types_used = 0,
        scaling = self.scaling or 1, ante_scaling = self.ante_scaling or 1, endless = false }
    local nt = 0
    for _ in pairs(self.stats.planet_types) do nt = nt + 1 end
    s.run.planet_types_used = nt
    local credit = 0
    for _, j in ipairs(self.jokers) do if j.key == 'j_credit_card' and not j.debuff then credit = credit - 20 end end
    local free = 0
    for _, j in ipairs(self.jokers) do if j.key == 'j_chaos' and not j.debuff then free = free + 1 end end
    local dr = self.deck_rules or {}
    s.econ = { dollars = self.dollars, interest_cap = self.interest_cap, interest_amount = 1, no_interest = dr.no_interest and true or false,
        money_per_hand = dr.money_per_hand or 1, money_per_discard = dr.money_per_discard or 0,
        reroll_cost = self.shop and self.shop.reroll_cost or self.reroll_base,
        free_rerolls = self.shop and self.shop.free_rerolls or free, base_reroll_cost = self.reroll_base,
        temp_reroll_cost = self.shop and self.shop.temp_reroll_cost or nil,
        bankrupt_at = credit, discount_percent = self.discount, inflation = 0,
        rates = { joker = self.rates.joker, tarot = self.rates.tarot, planet = self.rates.planet, spectral = self.rates.spectral,
            playing_card = self.rates.playing_card, edition = self.edition_rate } }
    if self.blind then
        s.blind = { key = self.blind.key, name = self.blind.name, boss = self.blind.boss, chips_required = self.blind.chips,
            chips_scored = self.blind.scored, disabled = self.blind.disabled, in_blind = true,
            hands_used = copy(self.blind.hands_used or {}), only_hand = self.blind.only_hand, known_key = true }
    else
        local cur = self:current_blind_entry()
        s.blind = cur and { key = cur.key, name = cur.name, boss = cur.boss, chips_required = cur.chips, chips_scored = 0 } or {}
    end
    s.upcoming = {}
    for i, b in ipairs(self.upcoming) do s.upcoming[i] = copy(b) end
    local cur = self:current_blind_entry()
    s.blind_on_deck = cur and cur.slot
    local r = self.blind or {}
    s.round = { hands_left = r.hands_left or self:round_hands_now(), discards_left = r.discards_left or self:round_discards_now(),
        hands_played = r.hands_played or 0, discards_used = r.discards_used or 0, hand_size = r.hand_size or self:hand_size_now(),
        round_hands = self:round_hands_now(), round_discards = self:round_discards_now() }
    s.hands = U.deepcopy(self.hands, 3)
    s.jokers = {}
    for i, j in ipairs(self.jokers) do s.jokers[i] = joker_copy(j) end
    s.joker_slots = self.joker_slots
    s.consumables = {}
    for i, c in ipairs(self.consumables) do s.consumables[i] = copy(c) end
    s.consumable_slots = self.consumable_slots
    s.vouchers = copy(self.vouchers)
    s.flags = { observatory_x = 1.5, plasma = (self.deck_rules and self.deck_rules.plasma) and true or false }
    s.hand_cards, s.deck = {}, {}
    if self.blind then
        for i, c in ipairs(self.blind.hand) do s.hand_cards[i] = mask(c, i) end
        for i, c in ipairs(self.blind.draw) do local o = C.copy(c); o.face_down = nil; s.deck[i] = o end
    elseif self.pack and self.pack.hand then
        for i, c in ipairs(self.pack.hand) do s.hand_cards[i] = mask(c, i) end
        for i, c in ipairs(self.pack.draw or {}) do s.deck[i] = C.copy(c) end
    end
    s.deck_count = #s.deck
    s.full_deck = {}
    for i, c in ipairs(self.cards) do local o = C.copy(c); o.face_down = nil; o.debuff = nil; s.full_deck[i] = o end
    s.full_deck_stats = SR.deck_stats(s.full_deck, 52)
    if phase == 'shop' and self.shop then
        s.shop = { jokers = {}, vouchers = {}, boosters = {} }
        for i, it in ipairs(self.shop.cards) do s.shop.jokers[i] = copy(it) end
        for i, it in ipairs(self.shop.vouchers) do s.shop.vouchers[i] = copy(it) end
        for i, it in ipairs(self.shop.boosters) do s.shop.boosters[i] = copy(it) end
    end
    if phase == 'pack' and self.pack then
        s.pack = { cards = {}, choices_left = self.pack.choices_left }
        for i, it in ipairs(self.pack.items) do s.pack.cards[i] = copy(it) end
    end
    s.blind_tags = copy(self.blind_tags or {})
    s.tags_held = {}
    for _ = 1, (self.double_next or 0) do s.tags_held[#s.tags_held + 1] = 'tag_double' end
    for _, t in ipairs(self.tags or {}) do s.tags_held[#s.tags_held + 1] = t end
    s.orbital_hands = copy(self.orbital_hands or {})
    local idol = self.targets or {}
    s.targets = { ancient_suit = idol.ancient_suit, castle_suit = idol.castle_suit, idol = idol.idol, mail_id = idol.mail_id,
        most_played_hand = self:most_played_hand() }
    s.probabilities_normal = 1
    for _, j in ipairs(self.jokers) do if j.key == 'j_oops' and not j.debuff then s.probabilities_normal = s.probabilities_normal * 2 end end
    return s
end

-- Round resources (vouchers and jokers that change them) ------------------------------------
function Sim:round_hands_now()
    local h = self.round_hands
    for _, j in ipairs(self.jokers) do
        if j.key == 'j_troubadour' and not j.debuff then h = h - 1 end
        if j.key == 'j_burglar' and not j.debuff then h = h + 3 end
    end
    return math.max(1, h)
end

function Sim:round_discards_now()
    local d = self.round_discards
    for _, j in ipairs(self.jokers) do
        if not j.debuff then
            if j.key == 'j_drunkard' then d = d + 1 end
            if j.key == 'j_merry_andy' then d = d + 3 end
            if j.key == 'j_burglar' then d = 0; break end
        end
    end
    return math.max(0, d)
end

function Sim:hand_size_now()
    local hs = self.hand_size
    for _, j in ipairs(self.jokers) do
        if not j.debuff then
            local ex = j.ability and j.ability.extra
            if j.key == 'j_juggler' then hs = hs + 1 end
            if j.key == 'j_troubadour' then hs = hs + 2 end
            if j.key == 'j_merry_andy' then hs = hs - 1 end
            if j.key == 'j_stuntman' then hs = hs - 2 end
            if j.key == 'j_turtle_bean' and type(ex) == 'table' then hs = hs + (ex.h_size or 0) end
        end
    end
    return math.max(1, hs)
end

-- Jokers and consumables ---------------------------------------------------------------------
function Sim:make_joker(key, opts)
    opts = opts or {}
    local e = SH.joker_entry_from_def(key)
    local j = { uid = self:new_uid(), key = key, name = e.name, ability = e.ability, rarity = e.rarity,
        blueprint_compat = e.blueprint_compat, cost = e.cost or 4, edition = opts.edition }
    j.cost = math.max(1, math.floor((j.cost + (j.edition and RU.EDITION_COST[j.edition] or 0)) * (100 - self.discount) / 100))
    j.sell_cost = math.max(1, math.floor(j.cost / 2))
    if key == 'j_invisible' then j.ability.invis_rounds = 0 end
    if key == 'j_yorick' and type(j.ability.extra) == 'table' then j.ability.yorick_discards = j.ability.extra.discards end
    return j
end

-- Stake stickers on shop and pack jokers (vanilla create_card): Black Stake +: Eternal 30 %;
-- Orange Stake +: Perishable 30 % (when not Eternal); Gold Stake: Rental 30 % ($1 to buy).
-- Jokers that cannot carry a sticker: RU.NEVER_ETERNAL / RU.NEVER_PERISHABLE (lists of the
-- Balatro Wiki; before 1.0.10 approximated by the joker tags: Cavendish and Turtle Bean could be
-- Eternal, Campfire and Hit the Road never Perishable)
function Sim:roll_stickers(j)
    if (self.stake or 1) < 4 then return j end
    local r = self.rng:float()
    local eternal_ok, perishable_ok = not RU.NEVER_ETERNAL[j.key], not RU.NEVER_PERISHABLE[j.key]
    if r > 0.7 and eternal_ok then
        j.eternal = true
    elseif self.stake >= 7 and r > 0.4 and r <= 0.7 and perishable_ok then
        j.perishable = true; j.perish_tally = 5
    end
    if self.stake >= 8 and self.rng:float() > 0.7 then
        j.rental = true; j.cost = 1; j.sell_cost = 1
    end
    return j
end

function Sim:roll_edition(mult)
    local x = self.rng:float()
    local acc = 0
    for _, e in ipairs(RU.EDITION_ODDS) do
        acc = acc + e[2] * (mult or 1) * (e[1] == 'e_negative' and 1 or self.edition_rate)
        if x < acc then return e[1] end
    end
    return nil
end

function Sim:random_joker_key(rarity)
    local pool = SH.joker_pool(self:snapshot('shop'))
    local r = rarity or self.rng:weighted(RU.RARITY_WEIGHTS)
    if r == 4 then
        local keys = {}
        for _, k in ipairs(DB.all_keys()) do if DB.get(k).rarity == 4 then keys[#keys + 1] = k end end
        table.sort(keys)
        return keys[self.rng:int(1, #keys)]
    end
    local list = pool[r]
    if not list or #list == 0 then list = pool[1] end
    if not list or #list == 0 then return 'j_joker' end
    table.sort(list)
    return list[self.rng:int(1, #list)]
end

function Sim:add_joker(j)
    local negative = j.edition == 'e_negative'
    if not negative and #self.jokers >= self.joker_slots then return false end
    self.jokers[#self.jokers + 1] = j
    if negative then self.joker_slots = self.joker_slots + 1 end
    if j.key == 'j_credit_card' then end
    return true
end

function Sim:remove_joker(j)
    if remove_value(self.jokers, j) then
        if j.edition == 'e_negative' then self.joker_slots = self.joker_slots - 1 end
        return true
    end
    return false
end

function Sim:make_consumable(key, set)
    local name = RU.TAROT_NAMES[key] or RU.SPECTRAL_NAMES[key] or RU.PLANET_NAMES[key] or key
    local c = { uid = self:new_uid(), key = key, name = name, set = set }
    if set == 'Planet' then c.hand_type = H.PLANETS[key] end
    c.cost = math.floor((RU.CONSUMABLE_COST[set] or 3) * (100 - self.discount) / 100)
    c.sell_cost = math.max(1, math.floor(c.cost / 2))
    return c
end

function Sim:add_consumable(c)
    if #self.consumables >= self.consumable_slots then return false end
    self.consumables[#self.consumables + 1] = c
    return true
end

function Sim:random_tarot() return RU.TAROTS[self.rng:int(1, #RU.TAROTS)] end
function Sim:random_planet()
    local list = {}
    for _, k in ipairs(RU.PLANETS) do list[#list + 1] = k end
    for k, hand in pairs(RU.SECRET_PLANETS) do if (self.hands[hand].played or 0) > 0 then list[#list + 1] = k end end
    table.sort(list)
    return list[self.rng:int(1, #list)]
end
function Sim:random_spectral() return RU.SPECTRALS[self.rng:int(1, #RU.SPECTRALS)] end

-- level up a poker hand (planets, Space Joker, Burnt Joker, Orbital tag)
function Sim:level_up(hand, n)
    local h = self.hands[hand]
    if not h then return end
    H.set_level(self.hands, hand, math.max(1, h.level + (n or 1)))
end

-- Blind play ---------------------------------------------------------------------------------
local FACE = { [11] = true, [12] = true, [13] = true }

function Sim:boss_effect()
    local b = self.blind
    if not b or not b.boss or b.disabled then return nil end
    local d = BL.get(b.key)
    return d and d.effect, d
end

-- debuffs from the boss on a card (recomputed when cards are drawn)
function Sim:apply_debuff(c)
    local eff, d = self:boss_effect()
    c.debuff = nil
    if not eff then return end
    -- vanilla Blind:debuff_card: is_suit(suit, true) and is_face(true) (Wild cards, Smeared Joker,
    -- Pareidolia)
    local rules = {}
    for _, j in ipairs(self.jokers) do
        if j.key == 'j_smeared' and not j.debuff then rules.smeared = true end
        if j.key == 'j_pareidolia' and not j.debuff then rules.pareidolia = true end
    end
    if eff == 'debuff_suit' and C.is_suit(c, d.suit, rules, true) then c.debuff = true end
    if eff == 'debuff_face' and C.is_face(c, rules, true) then c.debuff = true end
    if eff == 'debuff_played_ante' and c.played_this_ante then c.debuff = true end
    if eff == 'debuff_all' and not self.blind.leaf_cleared then c.debuff = true end
end

function Sim:draw_cards(n, face_down)
    local b = self.blind
    local eff = self:boss_effect()
    for _ = 1, n do
        local c = table.remove(b.draw, 1)
        if not c then break end
        self:apply_debuff(c)
        c.face_down = nil
        if face_down then c.face_down = true end
        if eff == 'face_down_1_in_7' and self.rng:chance(1 / 7) then c.face_down = true end
        if eff == 'faces_face_down' and C.has_rank(c) and FACE[c.id] then c.face_down = true end
        b.hand[#b.hand + 1] = c
    end
end

function Sim:fill_hand(face_down)
    local b = self.blind
    local eff = self:boss_effect()
    if eff == 'draw_3' and b.hands_played + b.discards_used > 0 then
        self:draw_cards(3, face_down)
    else
        self:draw_cards(math.max(0, b.hand_size - #b.hand), face_down)
    end
    -- Cerulean Bell (Blind:drawn_to_hand): after each draw, if no card is forced, a random card
    -- of the hand is forced (always selected)
    if eff == 'forced_card' and #b.hand > 0 then
        local any = false
        for _, c in ipairs(b.hand) do if c.forced then any = true end end
        if not any then b.hand[self.rng:int(1, #b.hand)].forced = true end
    end
end

-- Cerulean Bell: the forced card is always selected, so it goes with every play and discard
-- (the player cannot unselect it)
local function with_forced(hand, uids)
    local out, set = {}, {}
    for _, u in ipairs(uids or {}) do out[#out + 1] = u; set[tostring(u)] = true end
    for _, c in ipairs(hand) do
        if c.forced and not set[tostring(c.uid)] then out[#out + 1] = c.uid end
    end
    return out
end

function Sim:start_blind()
    local cur = self:current_blind_entry()
    cur.state = 'Current'
    self.round = self.round + 1
    local b = { key = cur.key, name = cur.name, boss = cur.boss, chips = cur.chips, scored = 0, slot = cur.slot,
        reward = cur.reward, hands_used = {}, hands_played = 0, discards_used = 0, disabled = false }
    self.blind = b
    -- Chicot disables every boss blind
    if b.boss then
        for _, j in ipairs(self.jokers) do if j.key == 'j_chicot' and not j.debuff then b.disabled = true end end
    end
    -- Blind:set_blind debuffs every playing card at once (draw pile included)
    for _, c in ipairs(self.cards) do self:apply_debuff(c) end
    -- "when Blind is selected" jokers (vanilla): Madness (Small / Big Blind only) gains x0.5 and
    -- destroys a random other joker that is not Eternal; Ceremonial Dagger destroys the joker to
    -- its right and gains twice its sell value as Mult
    local i = 1
    while i <= #self.jokers do
        local j = self.jokers[i]
        if not j.debuff and j.key == 'j_madness' and not b.boss then
            j.ability.x_mult = (j.ability.x_mult or 1) + (tonumber(j.ability.extra) or 0.5)
            local pool = {}
            for _, o in ipairs(self.jokers) do if o ~= j and not o.eternal then pool[#pool + 1] = o end end
            if #pool > 0 then
                local victim = pool[self.rng:int(1, #pool)]
                self:remove_joker(victim)
                self:event('destroyed', { key = victim.key, by = 'j_madness' })
            end
        elseif not j.debuff and j.key == 'j_ceremonial' then
            local right = self.jokers[i + 1]
            if right and not right.eternal then
                j.ability.mult = (j.ability.mult or 0) + 2 * (right.sell_cost or 1)
                self:remove_joker(right)
                self:event('destroyed', { key = right.key, by = 'j_ceremonial' })
            end
        end
        i = i + 1
    end
    b.hands_left = self:round_hands_now()
    b.discards_left = self:round_discards_now()
    b.hand_size = self:hand_size_now() + (self.juggle or 0)
    self.juggle = nil
    local eff = self:boss_effect()
    if eff == 'hands_1' then b.hands_left = 1 end
    if eff == 'no_discards' then b.discards_left = 0 end
    if eff == 'hand_size_minus' then b.hand_size = b.hand_size - 1 end
    if eff == 'jokers_hidden' then self.rng:shuffle(self.jokers) end
    b.draw = {}
    for i, c in ipairs(self.cards) do b.draw[i] = c end
    self.rng:shuffle(b.draw)
    b.hand = {}
    b.start_dollars = self.dollars
    -- round targets (Ancient Joker, Castle, Idol, Mail-In Rebate change every round)
    local any = self.cards[self.rng:int(1, #self.cards)]
    self.targets = { ancient_suit = C.SUITS[self.rng:int(1, 4)], castle_suit = C.SUITS[self.rng:int(1, 4)],
        idol = any and { id = any.id, suit = any.suit, rank = any.rank } or nil, mail_id = self.rng:int(2, 14) }
    self:fill_hand(eff == 'first_hand_face_down')
    if eff == 'random_joker_disabled' then self:heart_disable() end
end

function Sim:heart_disable()
    for _, j in ipairs(self.jokers) do j.debuff = nil end
    if #self.jokers > 0 then self.jokers[self.rng:int(1, #self.jokers)].debuff = true end
end

local function split(hand, uids)
    local set = {}
    for _, u in ipairs(uids or {}) do set[tostring(u)] = true end
    local picked, rest = {}, {}
    for _, c in ipairs(hand) do
        if set[tostring(c.uid)] then picked[#picked + 1] = c else rest[#rest + 1] = c end
    end
    return picked, rest
end

-- Play a hand. Returns the score.
function Sim:play(uids)
    local b = self.blind
    local played, held = split(b.hand, with_forced(b.hand, uids))
    if #played == 0 or #played > 5 then return nil, 'invalid play' end
    local eff = self:boss_effect()
    local st = self:snapshot('hand')
    -- the score engine sees the REAL cards (face-down ones are scored by what they are)
    local P = Score.prepare(st)
    local most_before = self:most_played_hand()
    local s, hname, _, r = Score.quick(P, played, held, self.rng, 1)
    s = s or 0
    b.scored = b.scored + s
    b.hands_left = b.hands_left - 1
    b.hands_played = b.hands_played + 1
    self.stats.hands_played = self.stats.hands_played + 1
    self.dollars = self.dollars + (r and r.dollars or 0)
    -- jokers updated while scoring (Ride the Bus, Green Joker, Runner, Square, Obelisk, Lucky Cat...)
    if r and r.jokers_after then
        for i, j in ipairs(self.jokers) do
            local a = r.jokers_after[i]
            if a and a.key == j.key then j.ability = a.ability end
        end
    end
    local h = self.hands[hname]
    if h and not (r and r.debuffed_hand) then
        h.played = (h.played or 0) + 1
        h.played_this_round = (h.played_this_round or 0) + 1
    end
    b.hands_used[hname] = true
    if eff == 'one_hand_type' and not b.only_hand then b.only_hand = hname end
    if eff == 'level_down' and h and h.level > 1 then self:level_up(hname, -1) end
    if eff == 'most_played_money' and hname == most_before then self.dollars = 0 end
    if eff == 'money_per_card' then self.dollars = self.dollars - #played end
    -- permanent effects on the played cards
    local scoring = {}
    for _, u in ipairs((r and r.scoring_uids) or {}) do scoring[tostring(u)] = true end
    for _, c in ipairs(played) do
        c.played_this_ante = true
        if scoring[tostring(c.uid)] and not c.debuff then
            for _, j in ipairs(self.jokers) do
                if not j.debuff then
                    if j.key == 'j_hiker' then c.perma_bonus = (c.perma_bonus or 0) + (tonumber(j.ability.extra) or 5) end
                    if j.key == 'j_midas_mask' and C.has_rank(c) and FACE[c.id] then C.set_enhancement(c, 'm_gold') end
                    if j.key == 'j_vampire' and c.enh and c.enh ~= 'm_stone' then C.set_enhancement(c, nil) end
                end
            end
        end
    end
    local destroyed = {}
    for _, c in ipairs(played) do
        if c.enh == 'm_glass' and scoring[tostring(c.uid)] and not c.debuff and self.rng:chance(1 / 4) then destroyed[#destroyed + 1] = c end
    end
    -- DNA: first hand of the round with a single card -> a copy goes to the deck
    for _, j in ipairs(self.jokers) do
        if j.key == 'j_dna' and not j.debuff and b.hands_played == 1 and #played == 1 then
            local nc = C.copy(played[1]); nc.uid = self:new_uid(); self.cards[#self.cards + 1] = nc
        end
        if j.key == 'j_space' and not j.debuff and self.rng:chance(1 / 4) then self:level_up(hname, 1) end
        if j.key == 'j_ice_cream' and type(j.ability.extra) == 'table' then
            j.ability.extra.chips = (j.ability.extra.chips or 100) - (j.ability.extra.chip_mod or 5)
            if j.ability.extra.chips <= 0 then self:remove_joker(j) end
        end
        if j.key == 'j_selzer' then
            j.ability.extra = (tonumber(j.ability.extra) or 10) - 1
            if j.ability.extra <= 0 then self:remove_joker(j) end
        end
    end
    for _, c in ipairs(destroyed) do
        remove_value(self.cards, c)
        for _, j in ipairs(self.jokers) do
            if j.key == 'j_glass' then j.ability.x_mult = (j.ability.x_mult or 1) + (tonumber(j.ability.extra) or 0.75) end
        end
    end
    b.hand = held
    self:event('play', { hand = hname, score = s, cards = #played })
    if eff == 'discard_2_random' and #b.hand > 0 then
        for _ = 1, math.min(2, #b.hand) do table.remove(b.hand, self.rng:int(1, #b.hand)) end
    end
    if eff == 'random_joker_disabled' then self:heart_disable() end
    if b.scored < b.chips and b.hands_left > 0 then self:fill_hand(eff == 'face_down_after_play') end
    return s
end

function Sim:discard(uids)
    local b = self.blind
    if b.discards_left <= 0 then return nil, 'no discard left' end
    local cards, rest = split(b.hand, with_forced(b.hand, uids))
    if #cards == 0 or #cards > 5 then return nil, 'invalid discard' end
    b.discards_left = b.discards_left - 1
    b.discards_used = b.discards_used + 1
    b.hand = rest
    local faces = count(cards, function(c) return C.has_rank(c) and FACE[c.id] and not c.debuff end)
    for _, c in ipairs(cards) do
        if c.seal == 'Purple' and not c.debuff then
            self:add_consumable(self:make_consumable(self:random_tarot(), 'Tarot'))
        end
    end
    for _, j in ipairs(self.jokers) do
        if not j.debuff then
            local ex = j.ability.extra
            if j.key == 'j_green_joker' then j.ability.mult = math.max(0, (j.ability.mult or 0) - ((type(ex) == 'table' and ex.discard_sub) or 1)) end
            if j.key == 'j_ramen' then
                j.ability.x_mult = (j.ability.x_mult or 2) - (tonumber(ex) or 0.01) * #cards
                if j.ability.x_mult <= 1 then self:remove_joker(j) end
            end
            if j.key == 'j_castle' and type(ex) == 'table' then
                ex.chips = (ex.chips or 0) + (ex.chip_mod or 3) * count(cards, function(c) return c.suit == self.targets.castle_suit end)
            end
            if j.key == 'j_hit_the_road' then
                j.ability.x_mult = (j.ability.x_mult or 1) + (tonumber(ex) or 0.5) * count(cards, function(c) return c.id == 11 end)
            end
            if j.key == 'j_mail' then self.dollars = self.dollars + (tonumber(ex) or 5) * count(cards, function(c) return c.id == self.targets.mail_id end) end
            if j.key == 'j_faceless' and type(ex) == 'table' and faces >= (ex.faces or 3) then self.dollars = self.dollars + (ex.dollars or 5) end
            if j.key == 'j_trading' and b.discards_used == 1 and #cards == 1 then
                remove_value(self.cards, cards[1]); self.dollars = self.dollars + (tonumber(ex) or 3)
            end
            if j.key == 'j_yorick' then
                j.ability.yorick_discards = (j.ability.yorick_discards or 23) - #cards
                while j.ability.yorick_discards <= 0 and type(ex) == 'table' do
                    ex.xmult = (ex.xmult or 1) + 1; j.ability.x_mult = ex.xmult
                    j.ability.yorick_discards = j.ability.yorick_discards + (ex.discards or 23)
                end
            end
            if j.key == 'j_burnt' and b.discards_used == 1 then
                local PE = BSC.require('engine/poker_eval')
                local ev = PE.evaluate(cards, {})
                if ev and ev.name then self:level_up(ev.name, 1) end
            end
        end
    end
    self:event('discard', { cards = #cards })
    self:fill_hand(false)
    return true
end

-- Selling (any time): jokers and consumables
function Sim:sell(uid)
    local j = by_uid(self.jokers, uid)
    if j then
        if j.eternal then return nil, 'eternal' end
        self.dollars = self.dollars + (j.sell_cost or 1)
        self:remove_joker(j)
        for _, o in ipairs(self.jokers) do
            if o.key == 'j_campfire' and not o.debuff then o.ability.x_mult = (o.ability.x_mult or 1) + (tonumber(o.ability.extra) or 0.25) end
        end
        if j.key == 'j_luchador' and self.blind and self.blind.boss then
            self.blind.disabled = true
            for _, c in ipairs(self.cards) do c.debuff = nil; c.forced = nil end
        end
        if j.key == 'j_invisible' and (j.ability.invis_rounds or 0) >= (tonumber(j.ability.extra) or 2) and #self.jokers > 0 then
            local src = self.jokers[self.rng:int(1, #self.jokers)]
            local dup = joker_copy(src); dup.uid = self:new_uid()
            if dup.edition == 'e_negative' then dup.edition = nil end
            self:add_joker(dup)
        end
        if self.blind and self:boss_effect() == 'debuff_all' then
            self.blind.leaf_cleared = true
            self.blind.disabled = true
            for _, c in ipairs(self.cards) do c.debuff = nil end
        end
        self:event('sell', { key = j.key, value = j.sell_cost })
        return true
    end
    local c = by_uid(self.consumables, uid)
    if c then
        self.dollars = self.dollars + (c.sell_cost or 1)
        remove_value(self.consumables, c)
        for _, o in ipairs(self.jokers) do
            if o.key == 'j_campfire' and not o.debuff then o.ability.x_mult = (o.ability.x_mult or 1) + (tonumber(o.ability.extra) or 0.25) end
        end
        self:event('sell', { key = c.key, value = c.sell_cost })
        return true
    end
    return nil, 'nothing to sell'
end

-- Reorder the jokers (the player follows the copilot's order numbers)
function Sim:reorder(uids)
    local new = {}
    for _, u in ipairs(uids) do local j = by_uid(self.jokers, u); if j then new[#new + 1] = j end end
    if #new ~= #self.jokers then return false end
    self.jokers = new
    return true
end

-- End of the round: money, joker updates
function Sim:end_round(won)
    local b = self.blind
    local eff = self:boss_effect()
    local income = {}
    -- cards held at the end of the round: Gold cards, Blue seals
    for _, c in ipairs(b.hand) do
        if not c.debuff then
            if (c.h_dollars or 0) > 0 then self.dollars = self.dollars + c.h_dollars; income.gold = (income.gold or 0) + c.h_dollars end
            if c.seal == 'Blue' then
                local last
                for _, e in ipairs(self.events) do if e.kind == 'play' then last = e.hand end end
                for k, hand in pairs(H.PLANETS) do
                    if hand == last then self:add_consumable(self:make_consumable(k, 'Planet')); break end
                end
            end
        end
    end
    -- interest is computed on the money before the payouts (none with the Green Deck, which pays
    -- $2 per hand and $1 per discard left instead)
    local dr = self.deck_rules or {}
    local interest = dr.no_interest and 0 or math.min(math.floor(math.max(0, self.dollars) / 5), self.interest_cap / 5)
    local reward = b.skip_reward and 0 or b.reward
    local hands = b.hands_left * (dr.money_per_hand or 1) + b.discards_left * (dr.money_per_discard or 0)
    local jinc = 0
    for _, j in ipairs(self.jokers) do
        local ex = j.ability.extra
        if not j.debuff then
            if j.key == 'j_golden' then jinc = jinc + (tonumber(ex) or 4) end
            if j.key == 'j_cloud_9' then jinc = jinc + (tonumber(ex) or 1) * count(self.cards, function(c) return c.id == 9 end) end
            if j.key == 'j_rocket' and type(ex) == 'table' then
                jinc = jinc + (ex.dollars or 1)
                if b.boss then ex.dollars = (ex.dollars or 1) + (ex.increase or 2) end
            end
            if j.key == 'j_satellite' then
                local nt = 0 for _ in pairs(self.stats.planet_types) do nt = nt + 1 end
                jinc = jinc + (tonumber(ex) or 1) * nt
            end
            if j.key == 'j_delayed_grat' and b.discards_used == 0 then jinc = jinc + (tonumber(ex) or 2) * b.discards_left end
            if j.key == 'j_egg' then j.sell_cost = (j.sell_cost or 1) + (tonumber(ex) or 3) end
            if j.key == 'j_gift' then
                for _, o in ipairs(self.jokers) do o.sell_cost = (o.sell_cost or 1) + 1 end
                for _, o in ipairs(self.consumables) do o.sell_cost = (o.sell_cost or 1) + 1 end
            end
            if j.key == 'j_popcorn' then
                j.ability.mult = (j.ability.mult or 20) - (tonumber(ex) or 4)
                if j.ability.mult <= 0 then self:remove_joker(j) end
            end
            if j.key == 'j_turtle_bean' and type(ex) == 'table' then
                ex.h_size = (ex.h_size or 5) - (ex.h_mod or 1)
                if ex.h_size <= 0 then self:remove_joker(j) end
            end
            if j.key == 'j_campfire' and b.boss then j.ability.x_mult = 1 end
            if j.key == 'j_hit_the_road' then j.ability.x_mult = 1 end
            if j.key == 'j_invisible' then j.ability.invis_rounds = (j.ability.invis_rounds or 0) + 1 end
            if j.key == 'j_gros_michel' and self.rng:chance(1 / 6) then self:remove_joker(j); self.michel_extinct = true end
            if j.key == 'j_cavendish' and self.rng:chance(1 / 1000) then self:remove_joker(j) end
        end
        if j.rental then jinc = jinc - 3 end
        if j.perishable then
            j.perish_tally = (j.perish_tally or 5) - 1
            if j.perish_tally <= 0 then j.debuff = true end
        end
    end
    self.stats.unused_discards = self.stats.unused_discards + b.discards_left
    local pay = reward + hands + interest + jinc
    self.dollars = self.dollars + pay
    if b.boss and self.investment then self.dollars = self.dollars + 25 * self.investment; self.investment = nil end
    -- clean the cards for the next round
    for _, c in ipairs(self.cards) do c.debuff = nil; c.face_down = nil; c.forced = nil end
    for _, j in ipairs(self.jokers) do if not (j.perishable and (j.perish_tally or 1) <= 0) then j.debuff = nil end end
    for _, h in pairs(self.hands) do h.played_this_round = 0 end
    self.history[#self.history + 1] = { ante = self.ante, slot = b.slot, key = b.key, required = b.chips, scored = b.scored,
        won = won, hands_played = b.hands_played, discards_used = b.discards_used, dollars = self.dollars,
        reward = reward, interest = interest, joker_income = jinc, jokers = #self.jokers, p_pred = b.p_pred,
        joker_keys = (function() local t = {} for i, j in ipairs(self.jokers) do t[i] = j.key end return t end)() }
    self.blind = nil
    if not won then return pay end
    if b.boss then self:after_boss() else self:advance_after_round() end
    return pay
end

function Sim:advance_after_round()
    for i, bb in ipairs(self.upcoming) do
        if bb.state == 'Current' then
            bb.state = 'Defeated'
            if self.upcoming[i + 1] then self.upcoming[i + 1].state = 'Select' end
        end
    end
end

function Sim:after_boss()
    if self.ante >= RU.START.win_ante then self.won = true; return end
    if self.deck_rules and self.deck_rules.double_after_boss then self.double_next = (self.double_next or 0) + 1 end
    self.ante = self.ante + 1
    self:new_ante()
end

-- Shop ------------------------------------------------------------------------------------------
function Sim:pick_voucher()
    local cands = {}
    for k, v in pairs(RU.VOUCHERS) do
        if not self.vouchers[k] and (not v.req or self.vouchers[v.req]) then cands[#cands + 1] = k end
    end
    table.sort(cands)
    if #cands == 0 then return nil end
    return cands[self.rng:int(1, #cands)]
end

function Sim:shop_card()
    local kinds, weights = {}, {}
    for _, k in ipairs({ 'joker', 'tarot', 'planet', 'spectral', 'playing_card' }) do
        if (self.rates[k] or 0) > 0 then kinds[#kinds + 1] = k; weights[#weights + 1] = self.rates[k] end
    end
    local kind = kinds[self.rng:weighted(weights)]
    if kind == 'joker' then
        local key = self:random_joker_key()
        local j = self:roll_stickers(self:make_joker(key, { edition = self:roll_edition() }))
        return { uid = j.uid, key = key, name = j.name, set = 'Joker', area = 'shop', cost = j.cost, edition = j.edition, joker = j,
            eternal = j.eternal, perishable = j.perishable, rental = j.rental }
    elseif kind == 'tarot' or kind == 'planet' or kind == 'spectral' then
        local set = (kind == 'tarot') and 'Tarot' or (kind == 'planet') and 'Planet' or 'Spectral'
        local key = (kind == 'tarot') and self:random_tarot() or (kind == 'planet') and self:random_planet() or self:random_spectral()
        local c = self:make_consumable(key, set)
        return { uid = c.uid, key = key, name = c.name, set = set, area = 'shop', cost = c.cost, hand_type = c.hand_type, consumable = c }
    else
        local c = self:standard_card()
        return { uid = c.uid, key = c.enh or 'c_base', name = C.label(c), set = c.enh and 'Enhanced' or 'Default', area = 'shop',
            cost = math.floor(1 * (100 - self.discount) / 100) + 1, card = c }
    end
end

-- Shop tags (vanilla Tag:apply_to_run): the Uncommon / Rare Tag makes the first card created
-- for the next shop a free joker of that rarity ('store_joker_create'); an edition tag turns
-- the next base-edition joker that appears in a shop, rerolls included, into a free joker with
-- that edition ('store_joker_modify'). fresh: the cards just created.
local EDITION_TAGS = { tag_negative = 'e_negative', tag_foil = 'e_foil', tag_holo = 'e_holo', tag_polychrome = 'e_polychrome' }
function Sim:apply_store_tags(fresh)
    local keep = {}
    local created = false
    for _, t in ipairs(self.tags) do
        local used = false
        if (t == 'tag_uncommon' or t == 'tag_rare') and not created and fresh[1] then
            local key = self:random_joker_key(t == 'tag_rare' and 3 or 2)
            local j = self:make_joker(key)
            fresh[1] = { uid = j.uid, key = key, name = j.name, set = 'Joker', area = 'shop', cost = 0, joker = j, tagged = true }
            created, used = true, true
        elseif EDITION_TAGS[t] then
            for _, it in ipairs(fresh) do
                if it.set == 'Joker' and not it.edition and not it.tagged and it.joker then
                    it.edition = EDITION_TAGS[t]; it.joker.edition = EDITION_TAGS[t]
                    it.cost = 0; it.tagged = true
                    used = true
                    break
                end
            end
        end
        if not used then keep[#keep + 1] = t end
    end
    self.tags = keep
end

function Sim:booster_item()
    local w = {}
    for i, b in ipairs(RU.BOOSTERS) do w[i] = b.weight end
    local b = RU.BOOSTERS[self.rng:weighted(w)]
    return { uid = self:new_uid(), key = b.key, name = b.kind .. ' Pack', set = 'Booster', area = 'booster', kind = b.kind,
        pack_size = b.size, choose = b.choose, cost = math.floor(b.cost * (100 - self.discount) / 100) }
end

function Sim:open_shop()
    local free = 0
    for _, j in ipairs(self.jokers) do if j.key == 'j_chaos' and not j.debuff then free = free + 1 end end
    self.shop = { cards = {}, vouchers = {}, boosters = {}, reroll_cost = self.reroll_base, free_rerolls = free, rerolls = 0 }
    if self.d_six then self.shop.reroll_cost = 0; self.shop.temp_reroll_cost = 0; self.d_six = nil end
    for i = 1, self.shop_slots do self.shop.cards[i] = self:shop_card() end
    for i = 1, 2 do self.shop.boosters[i] = self:booster_item() end
    -- the first shop of a run always holds a normal Buffoon Pack (vanilla)
    if not self.first_shop_done then
        self.first_shop_done = true
        local b = RU.BOOSTERS[10]
        self.shop.boosters[1] = { uid = self:new_uid(), key = b.key, name = 'Buffoon Pack', set = 'Booster', area = 'booster', kind = 'Buffoon',
            pack_size = b.size, choose = b.choose, cost = b.cost }
    end
    if self.voucher_offer then
        self.shop.vouchers[1] = { uid = self:new_uid(), key = self.voucher_offer, name = self.voucher_offer, set = 'Voucher', area = 'voucher',
            cost = math.floor(RU.VOUCHER_COST * (100 - self.discount) / 100) }
    end
    -- tags waiting for the shop
    self:apply_store_tags(self.shop.cards)
    local keep = {}
    for _, t in ipairs(self.tags) do
        if t == 'tag_coupon' then
            for _, it in ipairs(self.shop.cards) do it.cost = 0 end
            for _, it in ipairs(self.shop.boosters) do it.cost = 0 end
        elseif t == 'tag_voucher' then
            local v = self:pick_voucher()
            if v and v ~= self.voucher_offer then
                self.shop.vouchers[#self.shop.vouchers + 1] = { uid = self:new_uid(), key = v, name = v, set = 'Voucher', area = 'voucher', cost = RU.VOUCHER_COST }
            end
        elseif t == 'tag_d_six' then
            self.shop.reroll_cost = 0; self.shop.temp_reroll_cost = 0
        else
            keep[#keep + 1] = t
        end
    end
    self.tags = keep
end

function Sim:reroll()
    local sh = self.shop
    if sh.free_rerolls > 0 then
        sh.free_rerolls = sh.free_rerolls - 1
    else
        if self.dollars - sh.reroll_cost < self:bankrupt_at() then return nil, 'no money' end
        self.dollars = self.dollars - sh.reroll_cost
        sh.reroll_cost = sh.reroll_cost + 1
    end
    sh.rerolls = sh.rerolls + 1
    self.stats.rerolls = self.stats.rerolls + 1
    for i = 1, self.shop_slots do sh.cards[i] = self:shop_card() end
    for i = #sh.cards, self.shop_slots + 1, -1 do table.remove(sh.cards, i) end
    self:apply_store_tags(sh.cards)
    for _, j in ipairs(self.jokers) do
        if j.key == 'j_flash' and not j.debuff then j.ability.mult = (j.ability.mult or 0) + (tonumber(j.ability.extra) or 2) end
    end
    self:event('reroll', { cost = sh.reroll_cost - 1 })
    return true
end

function Sim:bankrupt_at()
    local b = 0
    for _, j in ipairs(self.jokers) do if j.key == 'j_credit_card' and not j.debuff then b = b - 20 end end
    return b
end

function Sim:apply_voucher(key)
    self.vouchers[key] = true
    if key == 'v_overstock_norm' or key == 'v_overstock_plus' then self.shop_slots = self.shop_slots + 1 end
    if key == 'v_clearance_sale' then self.discount = 25 end
    if key == 'v_liquidation' then self.discount = 50 end
    if key == 'v_hone' then self.edition_rate = 2 end
    if key == 'v_glow_up' then self.edition_rate = 4 end
    if key == 'v_reroll_surplus' or key == 'v_reroll_glut' then self.reroll_base = self.reroll_base - 2 end
    if key == 'v_crystal_ball' then self.consumable_slots = self.consumable_slots + 1 end
    if key == 'v_grabber' or key == 'v_nacho_tong' then self.round_hands = self.round_hands + 1 end
    if key == 'v_wasteful' or key == 'v_recyclomancy' then self.round_discards = self.round_discards + 1 end
    if key == 'v_tarot_merchant' then self.rates.tarot = 9.6 end
    if key == 'v_tarot_tycoon' then self.rates.tarot = 32 end
    if key == 'v_planet_merchant' then self.rates.planet = 9.6 end
    if key == 'v_planet_tycoon' then self.rates.planet = 32 end
    if key == 'v_seed_money' then self.interest_cap = 50 end
    if key == 'v_money_tree' then self.interest_cap = 100 end
    if key == 'v_antimatter' then self.joker_slots = self.joker_slots + 1 end
    if key == 'v_magic_trick' then self.rates.playing_card = 4 end
    if key == 'v_hieroglyph' then self.ante = math.max(1, self.ante - 1); self.round_hands = self.round_hands - 1 end
    if key == 'v_petroglyph' then self.ante = math.max(1, self.ante - 1); self.round_discards = self.round_discards - 1 end
    if (key == 'v_hieroglyph' or key == 'v_petroglyph') and self.upcoming then
        -- the blinds of the ante are sized from the (lower) ante when they are played
        local amount = BL.base_amount(self.ante, self.scaling or 1) * (self.ante_scaling or 1)
        for _, b in ipairs(self.upcoming) do
            if b.state ~= 'Defeated' and b.state ~= 'Skipped' then
                local mult = (b.slot == 'Small') and 1 or ((b.slot == 'Big') and 1.5 or ((BL.get(b.key) or {}).mult or 2))
                b.chips = math.floor(amount * mult)
            end
        end
    end
    if key == 'v_paint_brush' or key == 'v_palette' then self.hand_size = self.hand_size + 1 end
end

-- Buy a shop item. Returns true, or nil + reason.
function Sim:buy(uid)
    local sh = self.shop
    local it, idx, list
    for _, l in ipairs({ sh.cards, sh.vouchers, sh.boosters }) do
        local x, i = by_uid(l, uid)
        if x then it, idx, list = x, i, l end
    end
    if not it then return nil, 'not in shop' end
    if self.dollars - (it.cost or 0) < self:bankrupt_at() then return nil, 'no money' end
    if it.set == 'Joker' then
        if not self:add_joker(it.joker) then return nil, 'no joker slot' end
    elseif it.set == 'Tarot' or it.set == 'Planet' or it.set == 'Spectral' then
        if not self:add_consumable(it.consumable) then return nil, 'no consumable slot' end
    elseif it.set == 'Voucher' then
        self:apply_voucher(it.key)
        if it.key == self.voucher_offer then self.voucher_offer = nil end
    elseif it.set == 'Booster' then
        -- opened at once
    elseif it.card then
        self.cards[#self.cards + 1] = it.card
    end
    self.dollars = self.dollars - (it.cost or 0)
    table.remove(list, idx)
    self:event('buy', { key = it.key, set = it.set, cost = it.cost, kind = it.kind })
    if it.set == 'Booster' then self:open_pack(it) end
    return true
end

-- Packs -----------------------------------------------------------------------------------------
function Sim:standard_card()
    local rank = C.RANK_ORDER[self.rng:int(1, 13)]
    local suit = C.SUITS[self.rng:int(1, 4)]
    local c = C.new(rank, suit)
    c.uid = self:new_uid()
    if self.rng:chance(RU.STANDARD.enhanced) then C.set_enhancement(c, RU.ENHANCEMENTS[self.rng:int(1, #RU.ENHANCEMENTS)]) end
    local x = self.rng:float()
    local acc = 0
    for _, e in ipairs(RU.STANDARD.editions) do acc = acc + e[2]; if x < acc then c.edition = e[1]; break end end
    if self.rng:chance(RU.STANDARD.seal) then c.seal = RU.SEALS[self.rng:int(1, #RU.SEALS)] end
    return c
end

function Sim:open_pack(it)
    local items = {}
    local seen = {}
    local function uniq(f)
        for _ = 1, 20 do local k = f(); if not seen[k] then seen[k] = true; return k end end
        return f()
    end
    for i = 1, it.pack_size or 3 do
        if it.kind == 'Buffoon' then
            local key = uniq(function() return self:random_joker_key() end)
            local j = self:roll_stickers(self:make_joker(key, { edition = self:roll_edition() }))
            items[i] = { uid = j.uid, key = key, name = j.name, set = 'Joker', area = 'pack', cost = 0, joker = j }
        elseif it.kind == 'Arcana' then
            local key = self.rng:chance(RU.SOUL_ODDS) and 'c_soul' or uniq(function() return self:random_tarot() end)
            local c = self:make_consumable(key, key == 'c_soul' and 'Spectral' or 'Tarot')
            items[i] = { uid = c.uid, key = key, name = c.name, set = c.set, area = 'pack', cost = 0, consumable = c }
        elseif it.kind == 'Celestial' then
            local key
            if i == 1 and self.vouchers.v_telescope then
                local mp = self:most_played_hand()
                for k, hand in pairs(H.PLANETS) do if hand == mp then key = k end end
            end
            key = key or (self.rng:chance(RU.BLACK_HOLE_ODDS) and 'c_black_hole') or uniq(function() return self:random_planet() end)
            local set = (key == 'c_black_hole') and 'Spectral' or 'Planet'
            local c = self:make_consumable(key, set)
            items[i] = { uid = c.uid, key = key, name = c.name, set = set, area = 'pack', cost = 0, hand_type = c.hand_type, consumable = c }
        elseif it.kind == 'Spectral' then
            local r = self.rng:float()
            local key = (r < RU.SOUL_ODDS and 'c_soul') or (r < 2 * RU.SOUL_ODDS and 'c_black_hole') or uniq(function() return self:random_spectral() end)
            local c = self:make_consumable(key, 'Spectral')
            items[i] = { uid = c.uid, key = key, name = c.name, set = 'Spectral', area = 'pack', cost = 0, consumable = c }
        else
            local c = self:standard_card()
            items[i] = { uid = c.uid, key = c.enh or 'c_base', name = C.label(c), set = c.enh and 'Enhanced' or 'Default', area = 'pack', cost = 0, card = c }
        end
    end
    self.pack = { kind = it.kind, items = items, choices_left = it.choose or 1 }
    -- Arcana / Spectral packs: a hand is drawn to use the cards on
    if it.kind == 'Arcana' or it.kind == 'Spectral' then
        local draw = {}
        for i, c in ipairs(self.cards) do draw[i] = c end
        self.rng:shuffle(draw)
        self.pack.hand = {}
        for i = 1, math.min(self:hand_size_now(), #draw) do self.pack.hand[i] = table.remove(draw, 1) end
        self.pack.draw = draw
    end
    self:event('open_pack', { kind = it.kind })
end

-- Take a card from the open pack. targets: uids of cards in the pack hand (tarots, spectrals).
function Sim:take(uid, targets)
    local pk = self.pack
    local it, idx = by_uid(pk.items, uid)
    if not it then return nil, 'not in pack' end
    if it.set == 'Joker' then
        if not self:add_joker(it.joker) then return nil, 'no joker slot' end
    elseif it.set == 'Planet' then
        self:use_consumable(it.consumable, {})
    elseif it.set == 'Tarot' or it.set == 'Spectral' then
        local ok, why = self:use_consumable(it.consumable, targets or {}, pk.hand)
        if not ok then return nil, why end
    elseif it.card then
        self.cards[#self.cards + 1] = it.card
    end
    table.remove(pk.items, idx)
    pk.choices_left = pk.choices_left - 1
    self:event('take', { key = it.key, set = it.set })
    if pk.choices_left <= 0 or #pk.items == 0 then self.pack = nil end
    return true
end

function Sim:skip_pack()
    self.pack = nil
    self:event('skip_pack', {})
    return true
end

-- Consumables ---------------------------------------------------------------------------------
local ENHANCE = { c_magician = { 'm_lucky', 2 }, c_empress = { 'm_mult', 2 }, c_heirophant = { 'm_bonus', 2 },
    c_lovers = { 'm_wild', 1 }, c_chariot = { 'm_steel', 1 }, c_justice = { 'm_glass', 1 }, c_devil = { 'm_gold', 1 },
    c_tower = { 'm_stone', 1 } }
local SUITS = { c_star = 'Diamonds', c_moon = 'Clubs', c_sun = 'Hearts', c_world = 'Spades' }
local SEALS = { c_talisman = 'Gold', c_deja_vu = 'Red', c_trance = 'Blue', c_medium = 'Purple' }

-- `pool` = the cards the targets are taken from (hand in a round, or the pack hand)
function Sim:use_consumable(c, targets, pool)
    pool = pool or (self.blind and self.blind.hand) or {}
    local sel = {}
    for _, u in ipairs(targets or {}) do local x = by_uid(pool, u); if x then sel[#sel + 1] = x end end
    local key = c.key
    local function room_joker() return #self.jokers < self.joker_slots end
    if c.set == 'Planet' then
        self:level_up(c.hand_type or H.PLANETS[key], 1)
        self.stats.planets_used = self.stats.planets_used + 1
        self.stats.planet_types[key] = true
        for _, j in ipairs(self.jokers) do
            if j.key == 'j_constellation' and not j.debuff then j.ability.x_mult = (j.ability.x_mult or 1) + (tonumber(j.ability.extra) or 0.1) end
        end
    elseif ENHANCE[key] then
        local e = ENHANCE[key]
        if #sel == 0 or #sel > e[2] then return nil, 'targets' end
        for _, x in ipairs(sel) do C.set_enhancement(x, e[1]) end
    elseif SUITS[key] then
        if #sel == 0 or #sel > 3 then return nil, 'targets' end
        for _, x in ipairs(sel) do set_suit(x, SUITS[key]) end
    elseif SEALS[key] then
        if #sel ~= 1 then return nil, 'targets' end
        sel[1].seal = SEALS[key]
    elseif key == 'c_strength' then
        if #sel == 0 or #sel > 2 then return nil, 'targets' end
        for _, x in ipairs(sel) do
            if C.has_rank(x) then
                local nxt = (x.id == 14) and '2' or C.ID_TO_RANK[x.id + 1]
                set_rank(x, nxt)
            end
        end
    elseif key == 'c_hanged_man' then
        if #sel == 0 or #sel > 2 then return nil, 'targets' end
        for _, x in ipairs(sel) do remove_value(self.cards, x); remove_value(pool, x) end
    elseif key == 'c_death' then
        if #sel ~= 2 then return nil, 'targets' end
        -- the LEFT card becomes a copy of the RIGHT one (the player put them in that order)
        local victim, model = sel[1], sel[2]
        local keep = victim.uid
        for k in pairs(victim) do victim[k] = nil end
        for k, v in pairs(model) do victim[k] = v end
        victim.uid = keep
    elseif key == 'c_hermit' then
        self.dollars = self.dollars + math.min(math.max(0, self.dollars), 20)
    elseif key == 'c_temperance' then
        local sv = 0
        for _, j in ipairs(self.jokers) do sv = sv + (j.sell_cost or 0) end
        self.dollars = self.dollars + math.min(sv, 50)
    elseif key == 'c_high_priestess' then
        for _ = 1, 2 do self:add_consumable(self:make_consumable(self:random_planet(), 'Planet')) end
    elseif key == 'c_emperor' then
        for _ = 1, 2 do self:add_consumable(self:make_consumable(self:random_tarot(), 'Tarot')) end
    elseif key == 'c_fool' then
        local last = self.stats.last_used
        if last and last ~= 'c_fool' then
            local set = H.PLANETS[last] and 'Planet' or 'Tarot'
            self:add_consumable(self:make_consumable(last, set))
        end
    elseif key == 'c_wheel_of_fortune' then
        local plain = {}
        for _, j in ipairs(self.jokers) do if not j.edition then plain[#plain + 1] = j end end
        if #plain > 0 and self.rng:chance(1 / 4) then
            local eds = { 'e_foil', 'e_holo', 'e_polychrome' }
            plain[self.rng:int(1, #plain)].edition = eds[self.rng:int(1, 3)]
        end
    elseif key == 'c_judgement' then
        if not room_joker() then return nil, 'no joker slot' end
        self:add_joker(self:make_joker(self:random_joker_key()))
    elseif key == 'c_wraith' then
        if not room_joker() then return nil, 'no joker slot' end
        self:add_joker(self:make_joker(self:random_joker_key(3)))
        self.dollars = 0
    elseif key == 'c_soul' then
        if not room_joker() then return nil, 'no joker slot' end
        self:add_joker(self:make_joker(self:random_joker_key(4)))
    elseif key == 'c_black_hole' then
        for name in pairs(self.hands) do self:level_up(name, 1) end
    elseif key == 'c_aura' then
        if #sel ~= 1 then return nil, 'targets' end
        local eds = { 'e_foil', 'e_holo', 'e_polychrome' }
        sel[1].edition = eds[self.rng:int(1, 3)]
    elseif key == 'c_cryptid' then
        if #sel ~= 1 then return nil, 'targets' end
        for _ = 1, 2 do local nc = C.copy(sel[1]); nc.uid = self:new_uid(); self.cards[#self.cards + 1] = nc end
    elseif key == 'c_familiar' or key == 'c_grim' or key == 'c_incantation' then
        if #pool > 0 then
            local x = pool[self.rng:int(1, #pool)]
            remove_value(self.cards, x); remove_value(pool, x)
        end
        local n = (key == 'c_familiar') and 3 or (key == 'c_grim') and 2 or 4
        for _ = 1, n do
            local rank
            if key == 'c_familiar' then rank = ({ 'Jack', 'Queen', 'King' })[self.rng:int(1, 3)]
            elseif key == 'c_grim' then rank = 'Ace'
            else rank = C.RANK_ORDER[self.rng:int(1, 9)] end
            local nc = C.new(rank, C.SUITS[self.rng:int(1, 4)])
            nc.uid = self:new_uid()
            C.set_enhancement(nc, RU.ENHANCEMENTS[self.rng:int(1, #RU.ENHANCEMENTS)])
            self.cards[#self.cards + 1] = nc
        end
    elseif key == 'c_sigil' then
        local suit = C.SUITS[self.rng:int(1, 4)]
        for _, x in ipairs(pool) do set_suit(x, suit) end
    elseif key == 'c_ouija' then
        local rank = C.RANK_ORDER[self.rng:int(1, 13)]
        for _, x in ipairs(pool) do set_rank(x, rank) end
        self.hand_size = self.hand_size - 1
    elseif key == 'c_ectoplasm' then
        local plain = {}
        for _, j in ipairs(self.jokers) do if not j.edition then plain[#plain + 1] = j end end
        if #plain > 0 then
            local j = plain[self.rng:int(1, #plain)]
            j.edition = 'e_negative'; self.joker_slots = self.joker_slots + 1
        end
        self.hand_size = self.hand_size - 1
    elseif key == 'c_immolate' then
        for _ = 1, math.min(5, #pool) do
            local x = pool[self.rng:int(1, #pool)]
            remove_value(self.cards, x); remove_value(pool, x)
        end
        self.dollars = self.dollars + 20
    elseif key == 'c_ankh' then
        if #self.jokers > 0 then
            local keep = self.jokers[self.rng:int(1, #self.jokers)]
            local others = {}
            for _, j in ipairs(self.jokers) do if j ~= keep and not j.eternal then others[#others + 1] = j end end
            for _, j in ipairs(others) do self:remove_joker(j) end
            local dup = joker_copy(keep); dup.uid = self:new_uid()
            if dup.edition == 'e_negative' then dup.edition = nil end
            self:add_joker(dup)
        end
    elseif key == 'c_hex' then
        local plain = {}
        for _, j in ipairs(self.jokers) do if not j.edition then plain[#plain + 1] = j end end
        if #plain > 0 then
            local keep = plain[self.rng:int(1, #plain)]
            keep.edition = 'e_polychrome'
            local others = {}
            for _, j in ipairs(self.jokers) do if j ~= keep and not j.eternal then others[#others + 1] = j end end
            for _, j in ipairs(others) do self:remove_joker(j) end
        end
    end
    if c.set == 'Tarot' then self.stats.tarots_used = self.stats.tarots_used + 1 end
    if key ~= 'c_fool' then self.stats.last_used = key end
    remove_value(self.consumables, c)
    self:event('use', { key = key, targets = #sel })
    return true
end

function Sim:use(uid, targets)
    local c = by_uid(self.consumables, uid)
    if not c then return nil, 'not held' end
    return self:use_consumable(c, targets)
end

-- Skip a blind: tag effects
function Sim:skip_blind()
    local cur = self:current_blind_entry()
    if not cur or cur.boss then return nil, 'boss' end
    local tag = self.blind_tags[cur.slot]
    cur.state = 'Skipped'
    for i, b in ipairs(self.upcoming) do if b == cur and self.upcoming[i + 1] then self.upcoming[i + 1].state = 'Select' end end
    self.stats.skips = self.stats.skips + 1
    for _, j in ipairs(self.jokers) do
        if j.key == 'j_throwback' then j.ability.x_mult = 1 + 0.25 * self.stats.skips end
    end
    self.orbital_hand = self.orbital_hands and self.orbital_hands[cur.slot]
    self:apply_tag(tag)
    self:event('skip', { tag = tag })
    return true
end

function Sim:apply_tag(tag)
    if tag == 'tag_investment' then self.investment = (self.investment or 0) + 1
    elseif tag == 'tag_economy' then self.dollars = self.dollars + math.min(math.max(0, self.dollars), 40)
    elseif tag == 'tag_handy' then self.dollars = self.dollars + self.stats.hands_played
    elseif tag == 'tag_garbage' then self.dollars = self.dollars + self.stats.unused_discards
    elseif tag == 'tag_skip' then self.dollars = self.dollars + 5 * self.stats.skips
    elseif tag == 'tag_juggle' then self.juggle = (self.juggle or 0) + 3
    elseif tag == 'tag_d_six' then self.d_six = true; self.tags[#self.tags + 1] = tag
    elseif tag == 'tag_top_up' then
        for _ = 1, 2 do if #self.jokers < self.joker_slots then self:add_joker(self:make_joker(self:random_joker_key(1))) end end
    elseif tag == 'tag_orbital' then
        local names = {}
        for _, n in ipairs(H.ORDER) do if self.hands[n].visible ~= false then names[#names + 1] = n end end
        self:level_up(self.orbital_hand or names[self.rng:int(1, #names)], 3)
    elseif tag == 'tag_boss' then
        self.upcoming[3].key = self:pick_boss()
        local bb = BL.get(self.upcoming[3].key)
        self.upcoming[3].name = bb.name
        self.upcoming[3].chips = math.floor(BL.base_amount(self.ante, self.scaling or 1) * (self.ante_scaling or 1) * (bb.mult or 2))
    elseif tag == 'tag_double' then
        self.double_next = (self.double_next or 0) + 1
    elseif tag == 'tag_charm' or tag == 'tag_meteor' or tag == 'tag_ethereal' or tag == 'tag_buffoon' or tag == 'tag_standard' then
        local kind = ({ tag_charm = 'Arcana', tag_meteor = 'Celestial', tag_ethereal = 'Spectral', tag_buffoon = 'Buffoon', tag_standard = 'Standard' })[tag]
        local size = ({ Arcana = 5, Celestial = 5, Spectral = 2, Buffoon = 4, Standard = 5 })[kind]
        local choose = (kind == 'Spectral') and 1 or 2
        self.pending_pack = { uid = self:new_uid(), key = 'tag_pack', kind = kind, pack_size = size, choose = choose, cost = 0 }
    elseif tag then
        self.tags[#self.tags + 1] = tag
    end
    -- every Double Tag held copies the next tag (they stack, e.g. Anaglyph Deck)
    if (self.double_next or 0) > 0 and tag ~= 'tag_double' then
        local n = self.double_next
        self.double_next = 0
        for _ = 1, n do self:apply_tag(tag) end
    end
end

-- Lost? Mr. Bones saves the run once (if 25 % of the blind was scored)
function Sim:check_loss()
    local b = self.blind
    for _, j in ipairs(self.jokers) do
        if j.key == 'j_mr_bones' and not j.debuff and b.scored >= b.chips * 0.25 then
            self:remove_joker(j)
            return false
        end
    end
    return true
end

return Sim
