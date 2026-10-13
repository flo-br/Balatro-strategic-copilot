-- Balatro Strategic Copilot - model/jokers_db.lua
-- Vanilla joker knowledge base (150 jokers).
--   * Trigger LOGIC is implemented here (ported from the vanilla rules; several pieces are
--     verified against vanilla code quoted by Steamodded patches, see docs/AUDIT.md).
--   * VALUES (mult, xmult, counters, odds...) are read in game from card.ability; the
--     `config` here is only a fallback for tests and for jokers seen in the shop.
-- Phase functions (all optional), called by engine/score.lua:
--   before(x, j)            context.before (may mutate j.ability / cards unless x.copying)
--   indiv(x, j, card)       scored card (context.individual, cardarea G.play) -> effect
--   rep(x, j, card, area)   repetitions for a card ('play' or 'hand') -> integer
--   held(x, j, card)        held card (context.individual, cardarea G.hand) -> effect
--   main(x, j)              context.joker_main -> effect
--   other(x, j, other)      context.other_joker -> effect
-- effect = { chips=, mult=, x_mult=, x_chips=, dollars= }
-- Economy/utility knowledge used by the shop analyzer: econ = {...}, tags = {...}.

local BSC = BSCopilot
local C = BSC.require('model/cards')

local DB = {}
local by_name = {}

local function A(j) return j.ability or {} end
local function E(j) return (j.ability and j.ability.extra) end
local function num(v, d) if type(v) == 'number' then return v end return d end

-- helpers ---------------------------------------------------------------------------------
local function suit_mult(suit_default, amount_default)
    return function(x, j, card)
        local ex = E(j)
        local suit = (type(ex) == 'table' and ex.suit) or suit_default
        local m = (type(ex) == 'table' and num(ex.s_mult, amount_default)) or amount_default
        if x.is_suit(card, suit) then return { mult = m } end
    end
end

local function type_mult(hand, amount)
    return function(x, j)
        local t = A(j).type or hand
        if x.contains[t] then return { mult = num(A(j).t_mult, amount) } end
    end
end

local function type_chips(hand, amount)
    return function(x, j)
        local t = A(j).type or hand
        if x.contains[t] then return { chips = num(A(j).t_chips, amount) } end
    end
end

local function type_xmult(hand, amount)
    return function(x, j)
        local t = A(j).type or hand
        local xm = num(A(j).x_mult, amount)
        if xm > 1 and (t == '' or x.contains[t]) then return { x_mult = xm } end
    end
end

local function current_xmult(x, j)
    local xm = num(A(j).x_mult, 1)
    if xm > 1 then return { x_mult = xm } end
end

local function current_mult(x, j)
    local m = num(A(j).mult, 0)
    if m > 0 then return { mult = m } end
end

local function extra_chips(x, j)
    local ex = E(j)
    local c = type(ex) == 'table' and num(ex.chips, 0) or 0
    if c > 0 then return { chips = c } end
end

local function def(key, t)
    t.key = key
    t.tags = t.tags or {}
    t.econ = t.econ or {}
    DB[key] = t
    by_name[t.name] = key
end

-- 1-16 commons with simple conditions ------------------------------------------------------
def('j_joker', { name = 'Joker', rarity = 1, cost = 2, bp = true, config = { mult = 4 }, tags = { 'mult' },
    main = function(x, j) return { mult = num(A(j).mult, 4) } end })
def('j_greedy_joker', { name = 'Greedy Joker', rarity = 1, cost = 5, bp = true,
    config = { extra = { s_mult = 3, suit = 'Diamonds' } }, tags = { 'mult', 'suit_Diamonds' }, indiv = suit_mult('Diamonds', 3) })
def('j_lusty_joker', { name = 'Lusty Joker', rarity = 1, cost = 5, bp = true,
    config = { extra = { s_mult = 3, suit = 'Hearts' } }, tags = { 'mult', 'suit_Hearts' }, indiv = suit_mult('Hearts', 3) })
def('j_wrathful_joker', { name = 'Wrathful Joker', rarity = 1, cost = 5, bp = true,
    config = { extra = { s_mult = 3, suit = 'Spades' } }, tags = { 'mult', 'suit_Spades' }, indiv = suit_mult('Spades', 3) })
def('j_gluttenous_joker', { name = 'Gluttonous Joker', rarity = 1, cost = 5, bp = true,
    config = { extra = { s_mult = 3, suit = 'Clubs' } }, tags = { 'mult', 'suit_Clubs' }, indiv = suit_mult('Clubs', 3) })
def('j_jolly', { name = 'Jolly Joker', rarity = 1, cost = 3, bp = true, config = { t_mult = 8, type = 'Pair' },
    tags = { 'mult', 'hand_Pair' }, main = type_mult('Pair', 8) })
def('j_zany', { name = 'Zany Joker', rarity = 1, cost = 4, bp = true, config = { t_mult = 12, type = 'Three of a Kind' },
    tags = { 'mult', 'hand_Three of a Kind' }, main = type_mult('Three of a Kind', 12) })
def('j_mad', { name = 'Mad Joker', rarity = 1, cost = 4, bp = true, config = { t_mult = 10, type = 'Two Pair' },
    tags = { 'mult', 'hand_Two Pair' }, main = type_mult('Two Pair', 10) })
def('j_crazy', { name = 'Crazy Joker', rarity = 1, cost = 4, bp = true, config = { t_mult = 12, type = 'Straight' },
    tags = { 'mult', 'hand_Straight' }, main = type_mult('Straight', 12) })
def('j_droll', { name = 'Droll Joker', rarity = 1, cost = 4, bp = true, config = { t_mult = 10, type = 'Flush' },
    tags = { 'mult', 'hand_Flush' }, main = type_mult('Flush', 10) })
def('j_sly', { name = 'Sly Joker', rarity = 1, cost = 3, bp = true, config = { t_chips = 50, type = 'Pair' },
    tags = { 'chips', 'hand_Pair' }, main = type_chips('Pair', 50) })
def('j_wily', { name = 'Wily Joker', rarity = 1, cost = 4, bp = true, config = { t_chips = 100, type = 'Three of a Kind' },
    tags = { 'chips', 'hand_Three of a Kind' }, main = type_chips('Three of a Kind', 100) })
def('j_clever', { name = 'Clever Joker', rarity = 1, cost = 4, bp = true, config = { t_chips = 80, type = 'Two Pair' },
    tags = { 'chips', 'hand_Two Pair' }, main = type_chips('Two Pair', 80) })
def('j_devious', { name = 'Devious Joker', rarity = 1, cost = 4, bp = true, config = { t_chips = 100, type = 'Straight' },
    tags = { 'chips', 'hand_Straight' }, main = type_chips('Straight', 100) })
def('j_crafty', { name = 'Crafty Joker', rarity = 1, cost = 4, bp = true, config = { t_chips = 80, type = 'Flush' },
    tags = { 'chips', 'hand_Flush' }, main = type_chips('Flush', 80) })
def('j_half', { name = 'Half Joker', rarity = 1, cost = 5, bp = true, config = { extra = { mult = 20, size = 3 } },
    tags = { 'mult', 'small_hands' },
    main = function(x, j)
        local ex = E(j) or {}
        if #x.full <= num(ex.size, 3) then return { mult = num(ex.mult, 20) } end
    end })

-- 17-40 ------------------------------------------------------------------------------------
def('j_stencil', { name = 'Joker Stencil', rarity = 2, cost = 8, bp = true, tags = { 'xmult', 'empty_slots' },
    main = function(x, j)
        -- vanilla: x_mult = empty joker slots + number of Joker Stencils (recomputed every frame)
        local xm = x.stencil_xmult()
        if xm > 1 then return { x_mult = xm } end
    end })
def('j_four_fingers', { name = 'Four Fingers', rarity = 2, cost = 7, bp = false, rule = 'four_fingers', tags = { 'rule', 'hand_Flush', 'hand_Straight' } })
def('j_mime', { name = 'Mime', rarity = 2, cost = 5, bp = true, config = { extra = 1 }, tags = { 'retrigger', 'held' },
    rep = function(x, j, card, area)
        if area == 'hand' then return num(E(j), 1) end
    end })
def('j_credit_card', { name = 'Credit Card', rarity = 1, cost = 1, bp = false, config = { extra = 20 }, tags = { 'econ' },
    econ = { debt = 20 } })
def('j_ceremonial', { name = 'Ceremonial Dagger', rarity = 2, cost = 6, bp = true, config = { mult = 0 },
    tags = { 'mult', 'scaling', 'destroys_jokers' }, main = current_mult, scaling = { per_round_mult = 6 } })
def('j_banner', { name = 'Banner', rarity = 1, cost = 5, bp = true, config = { extra = 30 }, tags = { 'chips', 'discards' },
    main = function(x, j)
        if x.discards_left > 0 then return { chips = x.discards_left * num(E(j), 30) } end
    end })
def('j_mystic_summit', { name = 'Mystic Summit', rarity = 1, cost = 5, bp = true, config = { extra = { mult = 15, d_remaining = 0 } },
    tags = { 'mult', 'no_discards' },
    main = function(x, j)
        local ex = E(j) or {}
        if x.discards_left == num(ex.d_remaining, 0) then return { mult = num(ex.mult, 15) } end
    end })
def('j_marble', { name = 'Marble Joker', rarity = 2, cost = 6, bp = true, tags = { 'deck_stone', 'utility' } })
def('j_loyalty_card', { name = 'Loyalty Card', rarity = 2, cost = 5, bp = true, config = { extra = { Xmult = 4, every = 5 } },
    tags = { 'xmult', 'periodic' },
    main = function(x, j)
        local ex = E(j) or {}
        local every = num(ex.every, 5)
        local created = num(A(j).hands_played_at_create, 0)
        local remaining = (every - 1 - (x.hands_played - created)) % (every + 1)
        if remaining == every then return { x_mult = num(ex.Xmult, 4) } end
    end })
def('j_8_ball', { name = '8 Ball', rarity = 1, cost = 5, bp = true, config = { extra = 4 }, tags = { 'tarot_gen' } })
def('j_misprint', { name = 'Misprint', rarity = 1, cost = 4, bp = true, config = { extra = { max = 23, min = 0 } }, tags = { 'mult', 'random' },
    main = function(x, j)
        local ex = E(j) or {}
        return { mult = x.rand:int(num(ex.min, 0), num(ex.max, 23), 'misprint') }
    end })
def('j_dusk', { name = 'Dusk', rarity = 2, cost = 5, bp = true, config = { extra = 1 }, tags = { 'retrigger', 'last_hand' },
    rep = function(x, j, card, area)
        if area == 'play' and x.hands_left_eval == 0 then return num(E(j), 1) end
    end })
def('j_raised_fist', { name = 'Raised Fist', rarity = 1, cost = 5, bp = true, tags = { 'mult', 'held' },
    held = function(x, j, card)
        local raised, temp_id, temp_mult = nil, 15, 15
        for _, c in ipairs(x.held) do
            if C.has_rank(c) and temp_id >= c.id then temp_mult = c.nominal; temp_id = c.id; raised = c end
        end
        if raised == card and not card.debuff then return { mult = 2 * temp_mult } end
    end })
def('j_chaos', { name = 'Chaos the Clown', rarity = 1, cost = 4, bp = false, config = { extra = 1 }, tags = { 'econ', 'reroll' },
    econ = { free_rerolls = 1 } })
def('j_fibonacci', { name = 'Fibonacci', rarity = 2, cost = 8, bp = true, config = { extra = 8 }, tags = { 'mult', 'ranks_fib' },
    indiv = function(x, j, card)
        local id = card.id
        if C.has_rank(card) and (id == 2 or id == 3 or id == 5 or id == 8 or id == 14) then return { mult = num(E(j), 8) } end
    end })
def('j_steel_joker', { name = 'Steel Joker', rarity = 2, cost = 7, bp = true, config = { extra = 0.2 }, tags = { 'xmult', 'deck_steel' },
    main = function(x, j)
        local n = x.deck_stat('steel')
        if n > 0 then return { x_mult = 1 + num(E(j), 0.2) * n } end
    end })
def('j_scary_face', { name = 'Scary Face', rarity = 1, cost = 4, bp = true, config = { extra = 30 }, tags = { 'chips', 'faces' },
    indiv = function(x, j, card) if x.is_face(card) then return { chips = num(E(j), 30) } end end })
def('j_abstract', { name = 'Abstract Joker', rarity = 1, cost = 4, bp = true, config = { extra = 3 }, tags = { 'mult', 'joker_count' },
    main = function(x, j) return { mult = x.joker_count() * num(E(j), 3) } end })
def('j_delayed_grat', { name = 'Delayed Gratification', rarity = 1, cost = 4, bp = false, config = { extra = 2 }, tags = { 'econ', 'no_discards' },
    econ = { per_unused_discard_if_none_used = 2 } })
def('j_hack', { name = 'Hack', rarity = 2, cost = 6, bp = true, config = { extra = 1 }, tags = { 'retrigger', 'ranks_low' },
    rep = function(x, j, card, area)
        local id = card.id
        if area == 'play' and C.has_rank(card) and id >= 2 and id <= 5 then return num(E(j), 1) end
    end })
def('j_pareidolia', { name = 'Pareidolia', rarity = 2, cost = 5, bp = false, rule = 'pareidolia', tags = { 'rule', 'faces' } })
def('j_gros_michel', { name = 'Gros Michel', rarity = 1, cost = 5, bp = true, config = { extra = { odds = 6, mult = 15 } },
    tags = { 'mult', 'fragile' }, main = function(x, j) return { mult = num((E(j) or {}).mult, 15) } end,
    risk = { destroy_odds = 6 } })
def('j_even_steven', { name = 'Even Steven', rarity = 1, cost = 4, bp = true, config = { extra = 4 }, tags = { 'mult', 'ranks_even' },
    indiv = function(x, j, card)
        local id = card.id
        if C.has_rank(card) and id <= 10 and id % 2 == 0 then return { mult = num(E(j), 4) } end
    end })
def('j_odd_todd', { name = 'Odd Todd', rarity = 1, cost = 4, bp = true, config = { extra = 31 }, tags = { 'chips', 'ranks_odd' },
    indiv = function(x, j, card)
        local id = card.id
        if C.has_rank(card) and ((id <= 10 and id % 2 == 1) or id == 14) then return { chips = num(E(j), 31) } end
    end })

-- 41-70 ------------------------------------------------------------------------------------
def('j_scholar', { name = 'Scholar', rarity = 1, cost = 4, bp = true, config = { extra = { mult = 4, chips = 20 } }, tags = { 'chips', 'mult', 'ranks_ace' },
    indiv = function(x, j, card)
        if C.has_rank(card) and card.id == 14 then
            local ex = E(j) or {}
            return { chips = num(ex.chips, 20), mult = num(ex.mult, 4) }
        end
    end })
def('j_business', { name = 'Business Card', rarity = 1, cost = 4, bp = true, config = { extra = 2 }, tags = { 'econ', 'faces' },
    indiv = function(x, j, card)
        if x.is_face(card) and x.rand:chance(x.prob_normal / num(E(j), 2), 'business') then return { dollars = 2 } end
    end, econ = { per_face_scored = 1 } })
def('j_supernova', { name = 'Supernova', rarity = 1, cost = 5, bp = true, tags = { 'mult', 'repeat_hand' },
    main = function(x, j) return { mult = x.hand_played_count() } end })
def('j_ride_the_bus', { name = 'Ride the Bus', rarity = 1, cost = 6, bp = true, config = { extra = 1 }, tags = { 'mult', 'scaling', 'no_faces' },
    before = function(x, j)
        if x.copying then return end
        local faces = false
        for _, c in ipairs(x.scoring) do if x.is_face(c) then faces = true end end
        if faces then j.ability.mult = 0 else j.ability.mult = num(j.ability.mult, 0) + num(E(j), 1) end
    end,
    main = current_mult, scaling = { per_hand_mult = 1 } })
def('j_space', { name = 'Space Joker', rarity = 2, cost = 5, bp = true, config = { extra = 4 }, tags = { 'levels', 'random' },
    before = function(x, j)
        if x.rand:chance(x.prob_normal / num(E(j), 4), 'space') then x.level_up(1) end
    end })
def('j_egg', { name = 'Egg', rarity = 1, cost = 4, bp = false, config = { extra = 3 }, tags = { 'econ', 'sell_value' },
    econ = { sell_value_per_round = 3 } })
def('j_burglar', { name = 'Burglar', rarity = 2, cost = 6, bp = false, config = { extra = 3 }, tags = { 'hands' } })
def('j_blackboard', { name = 'Blackboard', rarity = 2, cost = 6, bp = true, config = { extra = 3 }, tags = { 'xmult', 'suit_dark', 'held' },
    main = function(x, j)
        for _, c in ipairs(x.held) do
            if not (x.is_suit_flush(c, 'Clubs') or x.is_suit_flush(c, 'Spades')) then return end
        end
        return { x_mult = num(E(j), 3) }
    end })
def('j_runner', { name = 'Runner', rarity = 1, cost = 5, bp = true, config = { extra = { chips = 0, chip_mod = 15 } }, tags = { 'chips', 'scaling', 'hand_Straight' },
    before = function(x, j)
        if x.copying then return end
        if x.contains['Straight'] then
            local ex = E(j); ex.chips = num(ex.chips, 0) + num(ex.chip_mod, 15)
        end
    end, main = extra_chips })
def('j_ice_cream', { name = 'Ice Cream', rarity = 1, cost = 5, bp = true, config = { extra = { chips = 100, chip_mod = 5 } }, tags = { 'chips', 'decaying' },
    main = extra_chips })
def('j_dna', { name = 'DNA', rarity = 3, cost = 8, bp = true, tags = { 'deck_copy', 'utility' } })
def('j_splash', { name = 'Splash', rarity = 1, cost = 3, bp = false, rule = 'splash', tags = { 'rule' } })
def('j_blue_joker', { name = 'Blue Joker', rarity = 1, cost = 5, bp = true, config = { extra = 2 }, tags = { 'chips', 'deck_size' },
    main = function(x, j) return { chips = num(E(j), 2) * x.deck_count } end })
def('j_sixth_sense', { name = 'Sixth Sense', rarity = 2, cost = 6, bp = false, tags = { 'spectral_gen' } })
def('j_constellation', { name = 'Constellation', rarity = 2, cost = 6, bp = true, config = { extra = 0.1, Xmult = 1 },
    tags = { 'xmult', 'scaling', 'planets' }, main = current_xmult, scaling = { per_planet_xmult = 0.1 } })
def('j_hiker', { name = 'Hiker', rarity = 2, cost = 5, bp = true, config = { extra = 5 }, tags = { 'chips', 'permanent' },
    indiv = function(x, j, card)
        card.perma_bonus = num(card.perma_bonus, 0) + num(E(j), 5)
    end })
def('j_faceless', { name = 'Faceless Joker', rarity = 1, cost = 4, bp = true, config = { extra = { dollars = 5, faces = 3 } }, tags = { 'econ', 'faces' },
    econ = { conditional_discard = 5 } })
def('j_green_joker', { name = 'Green Joker', rarity = 1, cost = 4, bp = true, config = { extra = { hand_add = 1, discard_sub = 1 } },
    tags = { 'mult', 'scaling' },
    before = function(x, j)
        if x.copying then return end
        j.ability.mult = num(j.ability.mult, 0) + num((E(j) or {}).hand_add, 1)
    end, main = current_mult, scaling = { per_hand_mult = 1 } })
def('j_superposition', { name = 'Superposition', rarity = 1, cost = 4, bp = true, tags = { 'tarot_gen' } })
def('j_todo_list', { name = 'To Do List', rarity = 1, cost = 4, bp = true, config = { extra = { dollars = 4, poker_hand = 'High Card' } }, tags = { 'econ' },
    before = function(x, j)
        local ex = E(j) or {}
        if x.hand == ex.poker_hand then x.earn(num(ex.dollars, 4)) end
    end, econ = { avg_per_round = 1 } })
def('j_cavendish', { name = 'Cavendish', rarity = 1, cost = 4, bp = true, config = { extra = { odds = 1000, Xmult = 3 } }, tags = { 'xmult' },
    main = function(x, j) return { x_mult = num((E(j) or {}).Xmult, 3) } end, risk = { destroy_odds = 1000 } })
def('j_card_sharp', { name = 'Card Sharp', rarity = 2, cost = 6, bp = true, config = { extra = { Xmult = 3 } }, tags = { 'xmult', 'repeat_hand' },
    main = function(x, j)
        if x.hand_played_this_round() > 1 then return { x_mult = num((E(j) or {}).Xmult, 3) } end
    end })
def('j_red_card', { name = 'Red Card', rarity = 1, cost = 5, bp = true, config = { extra = 3 }, tags = { 'mult', 'scaling', 'skip_packs' },
    main = current_mult })
def('j_madness', { name = 'Madness', rarity = 2, cost = 7, bp = true, config = { extra = 0.5 }, tags = { 'xmult', 'scaling', 'destroys_jokers' },
    main = current_xmult, scaling = { per_round_xmult = 0.5 } })
def('j_square', { name = 'Square Joker', rarity = 1, cost = 4, bp = true, config = { extra = { chips = 0, chip_mod = 4 } }, tags = { 'chips', 'scaling', 'four_cards' },
    before = function(x, j)
        if x.copying then return end
        if #x.full == 4 then local ex = E(j); ex.chips = num(ex.chips, 0) + num(ex.chip_mod, 4) end
    end, main = extra_chips })
def('j_seance', { name = 'Seance', rarity = 2, cost = 6, bp = true, tags = { 'spectral_gen', 'hand_Straight Flush' } })
def('j_riff_raff', { name = 'Riff-raff', rarity = 1, cost = 6, bp = true, config = { extra = 2 }, tags = { 'joker_gen' } })
def('j_vampire', { name = 'Vampire', rarity = 2, cost = 7, bp = true, config = { extra = 0.1, Xmult = 1 }, tags = { 'xmult', 'scaling', 'anti_enhance' },
    before = function(x, j)
        if x.copying then return end
        local n = 0
        for _, c in ipairs(x.scoring) do
            if c.enh and c.enh ~= 'm_base' and not c.debuff and not c.vampired then
                n = n + 1
                c.vampired = true
                C.set_enhancement(c, nil)
            end
        end
        if n > 0 then j.ability.x_mult = num(j.ability.x_mult, 1) + num(E(j), 0.1) * n end
    end, main = current_xmult })
def('j_shortcut', { name = 'Shortcut', rarity = 2, cost = 7, bp = false, rule = 'shortcut', tags = { 'rule', 'hand_Straight' } })
def('j_hologram', { name = 'Hologram', rarity = 2, cost = 7, bp = true, config = { extra = 0.25, Xmult = 1 }, tags = { 'xmult', 'scaling', 'add_cards' },
    main = current_xmult })

-- 71-100 -----------------------------------------------------------------------------------
def('j_vagabond', { name = 'Vagabond', rarity = 3, cost = 8, bp = true, config = { extra = 4 }, tags = { 'tarot_gen', 'poor' } })
def('j_baron', { name = 'Baron', rarity = 3, cost = 8, bp = true, config = { extra = 1.5 }, tags = { 'xmult', 'held', 'ranks_king' },
    held = function(x, j, card)
        if C.has_rank(card) and card.id == 13 then return { x_mult = num(E(j), 1.5) } end
    end })
def('j_cloud_9', { name = 'Cloud 9', rarity = 2, cost = 7, bp = false, config = { extra = 1 }, tags = { 'econ', 'ranks_nine' },
    econ = { per_nine_per_round = 1 } })
def('j_rocket', { name = 'Rocket', rarity = 2, cost = 6, bp = false, config = { extra = { dollars = 1, increase = 2 } }, tags = { 'econ', 'scaling' },
    econ = { per_round_field = 'dollars' } })
def('j_obelisk', { name = 'Obelisk', rarity = 3, cost = 8, bp = true, config = { extra = 0.2, Xmult = 1 }, tags = { 'xmult', 'scaling', 'varied_hands' },
    before = function(x, j)
        if x.copying then return end
        local play_more_than = x.hand_played_count()
        local reset = true
        for name, h in pairs(x.hands_table) do
            if name ~= x.hand and (h.played or 0) >= play_more_than and h.visible ~= false then reset = false end
        end
        if reset then j.ability.x_mult = 1 else j.ability.x_mult = num(j.ability.x_mult, 1) + num(E(j), 0.2) end
    end, main = current_xmult })
def('j_midas_mask', { name = 'Midas Mask', rarity = 2, cost = 7, bp = false, tags = { 'faces', 'gold' },
    before = function(x, j)
        if x.copying then return end
        for _, c in ipairs(x.scoring) do
            if x.is_face(c) then C.set_enhancement(c, 'm_gold') end
        end
    end })
def('j_luchador', { name = 'Luchador', rarity = 2, cost = 5, bp = false, tags = { 'boss_disable' } })
def('j_photograph', { name = 'Photograph', rarity = 1, cost = 5, bp = true, config = { extra = 2 }, tags = { 'xmult', 'faces' },
    indiv = function(x, j, card)
        local first
        for _, c in ipairs(x.scoring) do if x.is_face(c) then first = c; break end end
        if card == first then return { x_mult = num(E(j), 2) } end
    end })
def('j_gift', { name = 'Gift Card', rarity = 2, cost = 6, bp = false, config = { extra = 1 }, tags = { 'econ', 'sell_value' },
    econ = { sell_value_all_per_round = 1 } })
def('j_turtle_bean', { name = 'Turtle Bean', rarity = 2, cost = 6, bp = false, config = { extra = { h_size = 5, h_mod = 1 } }, tags = { 'hand_size' } })
def('j_erosion', { name = 'Erosion', rarity = 2, cost = 6, bp = true, config = { extra = 4 }, tags = { 'mult', 'small_deck' },
    main = function(x, j)
        local diff = x.deck_stat('starting_size') - x.deck_stat('size')
        if diff > 0 then return { mult = diff * num(E(j), 4) } end
    end })
def('j_reserved_parking', { name = 'Reserved Parking', rarity = 1, cost = 6, bp = true, config = { extra = { odds = 2, dollars = 1 } }, tags = { 'econ', 'faces', 'held' },
    held = function(x, j, card)
        local ex = E(j) or {}
        if x.is_face(card) and x.rand:chance(x.prob_normal / num(ex.odds, 2), 'parking') then return { dollars = num(ex.dollars, 1) } end
    end })
def('j_mail', { name = 'Mail-In Rebate', rarity = 1, cost = 4, bp = true, config = { extra = 5 }, tags = { 'econ', 'discards' },
    econ = { per_matching_discard = 5 } })
def('j_to_the_moon', { name = 'To the Moon', rarity = 2, cost = 5, bp = false, config = { extra = 1 }, tags = { 'econ', 'interest' },
    econ = { interest_bonus = 1 } })
def('j_hallucination', { name = 'Hallucination', rarity = 1, cost = 4, bp = true, config = { extra = 2 }, tags = { 'tarot_gen' } })
def('j_fortune_teller', { name = 'Fortune Teller', rarity = 1, cost = 6, bp = true, config = { extra = 1 }, tags = { 'mult', 'tarots' },
    main = function(x, j)
        local n = x.tarots_used()
        if n > 0 then return { mult = n * num(E(j), 1) } end
    end })
def('j_juggler', { name = 'Juggler', rarity = 1, cost = 4, bp = false, config = { h_size = 1 }, tags = { 'hand_size' } })
def('j_drunkard', { name = 'Drunkard', rarity = 1, cost = 4, bp = false, config = { d_size = 1 }, tags = { 'discards' } })
def('j_stone', { name = 'Stone Joker', rarity = 2, cost = 6, bp = true, config = { extra = 25 }, tags = { 'chips', 'deck_stone' },
    main = function(x, j)
        local n = x.deck_stat('stone')
        if n > 0 then return { chips = n * num(E(j), 25) } end
    end })
def('j_golden', { name = 'Golden Joker', rarity = 1, cost = 6, bp = false, config = { extra = 4 }, tags = { 'econ' },
    econ = { per_round = 4 } })
def('j_lucky_cat', { name = 'Lucky Cat', rarity = 2, cost = 6, bp = true, config = { Xmult = 1, extra = 0.25 }, tags = { 'xmult', 'scaling', 'lucky' },
    indiv = function(x, j, card)
        if card.lucky_trigger and not x.copying then j.ability.x_mult = num(j.ability.x_mult, 1) + num(E(j), 0.25) end
    end, main = current_xmult })
def('j_baseball', { name = 'Baseball Card', rarity = 3, cost = 8, bp = true, config = { extra = 1.5 }, tags = { 'xmult', 'uncommons' },
    other = function(x, j, other)
        if other ~= j and other.rarity == 2 then return { x_mult = num(E(j), 1.5) } end
    end })
def('j_bull', { name = 'Bull', rarity = 2, cost = 6, bp = true, config = { extra = 2 }, tags = { 'chips', 'money' },
    main = function(x, j)
        local d = x.dollars()
        if d > 0 then return { chips = num(E(j), 2) * d } end
    end })
def('j_diet_cola', { name = 'Diet Cola', rarity = 2, cost = 6, bp = false, tags = { 'tag_gen' } })
def('j_trading', { name = 'Trading Card', rarity = 2, cost = 6, bp = false, config = { extra = 3 }, tags = { 'econ', 'deck_thin' },
    econ = { first_discard_single = 3 } })
def('j_flash', { name = 'Flash Card', rarity = 2, cost = 5, bp = true, config = { extra = 2, mult = 0 }, tags = { 'mult', 'scaling', 'reroll' },
    main = current_mult })
def('j_popcorn', { name = 'Popcorn', rarity = 1, cost = 5, bp = true, config = { mult = 20, extra = 4 }, tags = { 'mult', 'decaying' },
    main = current_mult })
def('j_trousers', { name = 'Spare Trousers', rarity = 2, cost = 6, bp = true, config = { extra = 2 }, tags = { 'mult', 'scaling', 'hand_Two Pair' },
    before = function(x, j)
        if x.copying then return end
        if x.contains['Two Pair'] or x.contains['Full House'] then
            j.ability.mult = num(j.ability.mult, 0) + num(E(j), 2)
        end
    end, main = current_mult })
def('j_ancient', { name = 'Ancient Joker', rarity = 3, cost = 8, bp = true, config = { extra = 1.5 }, tags = { 'xmult', 'suit_rotating' },
    indiv = function(x, j, card)
        local suit = x.targets.ancient_suit
        if suit and x.is_suit(card, suit) then return { x_mult = num(E(j), 1.5) } end
    end })
def('j_ramen', { name = 'Ramen', rarity = 2, cost = 6, bp = true, config = { Xmult = 2, extra = 0.01 }, tags = { 'xmult', 'decaying' },
    main = current_xmult })

-- 101-130 ----------------------------------------------------------------------------------
def('j_walkie_talkie', { name = 'Walkie Talkie', rarity = 1, cost = 4, bp = true, config = { extra = { chips = 10, mult = 4 } }, tags = { 'chips', 'mult', 'ranks_10_4' },
    indiv = function(x, j, card)
        if C.has_rank(card) and (card.id == 10 or card.id == 4) then
            local ex = E(j) or {}
            return { chips = num(ex.chips, 10), mult = num(ex.mult, 4) }
        end
    end })
def('j_selzer', { name = 'Seltzer', rarity = 2, cost = 6, bp = true, config = { extra = 10 }, tags = { 'retrigger', 'decaying' },
    rep = function(x, j, card, area) if area == 'play' then return 1 end end })
def('j_castle', { name = 'Castle', rarity = 2, cost = 6, bp = true, config = { extra = { chips = 0, chip_mod = 3 } }, tags = { 'chips', 'scaling', 'discards' },
    main = extra_chips })
def('j_smiley', { name = 'Smiley Face', rarity = 1, cost = 4, bp = true, config = { extra = 5 }, tags = { 'mult', 'faces' },
    indiv = function(x, j, card) if x.is_face(card) then return { mult = num(E(j), 5) } end end })
def('j_campfire', { name = 'Campfire', rarity = 3, cost = 9, bp = true, config = { extra = 0.25 }, tags = { 'xmult', 'scaling', 'selling' },
    main = current_xmult })
def('j_ticket', { name = 'Golden Ticket', rarity = 1, cost = 5, bp = true, config = { extra = 4 }, tags = { 'econ', 'gold' },
    indiv = function(x, j, card) if card.enh == 'm_gold' then return { dollars = num(E(j), 4) } end end })
def('j_mr_bones', { name = 'Mr. Bones', rarity = 2, cost = 5, bp = false, tags = { 'survival' } })
def('j_acrobat', { name = 'Acrobat', rarity = 2, cost = 6, bp = true, config = { extra = 3 }, tags = { 'xmult', 'last_hand' },
    main = function(x, j) if x.hands_left_eval == 0 then return { x_mult = num(E(j), 3) } end end })
def('j_sock_and_buskin', { name = 'Sock and Buskin', rarity = 2, cost = 6, bp = true, config = { extra = 1 }, tags = { 'retrigger', 'faces' },
    rep = function(x, j, card, area) if area == 'play' and x.is_face(card) then return num(E(j), 1) end end })
def('j_swashbuckler', { name = 'Swashbuckler', rarity = 1, cost = 4, bp = true, config = { mult = 1 }, tags = { 'mult', 'sell_value' },
    main = function(x, j)
        local m = x.other_jokers_sell_value(j)
        if m > 0 then return { mult = m } end
    end })
def('j_troubadour', { name = 'Troubadour', rarity = 2, cost = 6, bp = false, config = { extra = { h_size = 2, h_plays = -1 } }, tags = { 'hand_size' } })
def('j_certificate', { name = 'Certificate', rarity = 2, cost = 6, bp = true, tags = { 'deck_add', 'seals' } })
def('j_smeared', { name = 'Smeared Joker', rarity = 2, cost = 7, bp = false, rule = 'smeared', tags = { 'rule', 'hand_Flush' } })
def('j_throwback', { name = 'Throwback', rarity = 2, cost = 6, bp = true, config = { extra = 0.25 }, tags = { 'xmult', 'skips' },
    main = function(x, j)
        local xm = num(A(j).x_mult, 1)
        if xm <= 1 then xm = 1 + x.skips() * num(E(j), 0.25) end
        if xm > 1 then return { x_mult = xm } end
    end })
def('j_hanging_chad', { name = 'Hanging Chad', rarity = 1, cost = 4, bp = true, config = { extra = 2 }, tags = { 'retrigger' },
    rep = function(x, j, card, area) if area == 'play' and card == x.scoring[1] then return num(E(j), 2) end end })
def('j_rough_gem', { name = 'Rough Gem', rarity = 2, cost = 7, bp = true, config = { extra = 1 }, tags = { 'econ', 'suit_Diamonds' },
    indiv = function(x, j, card) if x.is_suit(card, 'Diamonds') then return { dollars = num(E(j), 1) } end end })
def('j_bloodstone', { name = 'Bloodstone', rarity = 2, cost = 7, bp = true, config = { extra = { odds = 2, Xmult = 1.5 } }, tags = { 'xmult', 'suit_Hearts', 'random' },
    indiv = function(x, j, card)
        local ex = E(j) or {}
        if x.is_suit(card, 'Hearts') and x.rand:chance(x.prob_normal / num(ex.odds, 2), 'bloodstone') then
            return { x_mult = num(ex.Xmult, 1.5) }
        end
    end })
def('j_arrowhead', { name = 'Arrowhead', rarity = 2, cost = 7, bp = true, config = { extra = 50 }, tags = { 'chips', 'suit_Spades' },
    indiv = function(x, j, card) if x.is_suit(card, 'Spades') then return { chips = num(E(j), 50) } end end })
def('j_onyx_agate', { name = 'Onyx Agate', rarity = 2, cost = 7, bp = true, config = { extra = 7 }, tags = { 'mult', 'suit_Clubs' },
    indiv = function(x, j, card) if x.is_suit(card, 'Clubs') then return { mult = num(E(j), 7) } end end })
def('j_glass', { name = 'Glass Joker', rarity = 2, cost = 6, bp = true, config = { extra = 0.75, Xmult = 1 }, tags = { 'xmult', 'scaling', 'glass' },
    main = current_xmult })
def('j_ring_master', { name = 'Showman', rarity = 2, cost = 5, bp = false, tags = { 'utility' } })
def('j_flower_pot', { name = 'Flower Pot', rarity = 2, cost = 6, bp = true, config = { extra = 3 }, tags = { 'xmult', 'all_suits' },
    main = function(x, j)
        -- vanilla: non-wild cards first (bypassing debuff, each card fills at most one missing
        -- suit in the order Hearts, Diamonds, Spades, Clubs), then each wild card fills one.
        local s = { Hearts = 0, Diamonds = 0, Spades = 0, Clubs = 0 }
        for _, c in ipairs(x.scoring) do
            if not c.any_suit then
                if x.is_suit(c, 'Hearts', true) and s.Hearts == 0 then s.Hearts = 1
                elseif x.is_suit(c, 'Diamonds', true) and s.Diamonds == 0 then s.Diamonds = 1
                elseif x.is_suit(c, 'Spades', true) and s.Spades == 0 then s.Spades = 1
                elseif x.is_suit(c, 'Clubs', true) and s.Clubs == 0 then s.Clubs = 1 end
            end
        end
        for _, c in ipairs(x.scoring) do
            if c.any_suit then
                if x.is_suit(c, 'Hearts') and s.Hearts == 0 then s.Hearts = 1
                elseif x.is_suit(c, 'Diamonds') and s.Diamonds == 0 then s.Diamonds = 1
                elseif x.is_suit(c, 'Spades') and s.Spades == 0 then s.Spades = 1
                elseif x.is_suit(c, 'Clubs') and s.Clubs == 0 then s.Clubs = 1 end
            end
        end
        if s.Hearts > 0 and s.Diamonds > 0 and s.Spades > 0 and s.Clubs > 0 then return { x_mult = num(E(j), 3) } end
    end })
def('j_blueprint', { name = 'Blueprint', rarity = 3, cost = 10, bp = true, copy = 'right', tags = { 'copy' } })
def('j_wee', { name = 'Wee Joker', rarity = 3, cost = 8, bp = true, config = { extra = { chips = 0, chip_mod = 8 } }, tags = { 'chips', 'scaling', 'ranks_two' },
    indiv = function(x, j, card)
        if C.has_rank(card) and card.id == 2 and not x.copying then
            local ex = E(j); ex.chips = num(ex.chips, 0) + num(ex.chip_mod, 8)
        end
    end, main = extra_chips })
def('j_merry_andy', { name = 'Merry Andy', rarity = 2, cost = 7, bp = false, config = { d_size = 3, h_size = -1 }, tags = { 'discards' } })
def('j_oops', { name = 'Oops! All 6s', rarity = 2, cost = 4, bp = false, tags = { 'probability' } })
def('j_idol', { name = 'The Idol', rarity = 2, cost = 6, bp = true, config = { extra = 2 }, tags = { 'xmult', 'specific_card' },
    indiv = function(x, j, card)
        local idol = x.targets.idol
        if idol and C.has_rank(card) and card.id == idol.id and x.is_suit(card, idol.suit) then return { x_mult = num(E(j), 2) } end
    end })
def('j_seeing_double', { name = 'Seeing Double', rarity = 2, cost = 6, bp = true, config = { extra = 2 }, tags = { 'xmult', 'suit_Clubs' },
    main = function(x, j)
        -- port of SMODS.seeing_double_check(scoring_hand, 'Clubs')
        local tally = { Spades = 0, Hearts = 0, Clubs = 0, Diamonds = 0 }
        for _, c in ipairs(x.scoring) do
            if not c.any_suit then
                for k in pairs(tally) do if x.is_suit(c, k) then tally[k] = tally[k] + 1 end end
            end
        end
        for _, c in ipairs(x.scoring) do
            if c.any_suit then
                if x.is_suit(c, 'Clubs') and tally.Clubs == 0 then tally.Clubs = 1
                else
                    for k in pairs(tally) do if x.is_suit(c, k) and tally[k] == 0 then tally[k] = 1 end end
                end
            end
        end
        local other = tally.Spades > 0 or tally.Hearts > 0 or tally.Diamonds > 0
        if tally.Clubs > 0 and other then return { x_mult = num(E(j), 2) } end
    end })
def('j_matador', { name = 'Matador', rarity = 2, cost = 7, bp = true, config = { extra = 8 }, tags = { 'econ', 'boss' } })
def('j_hit_the_road', { name = 'Hit the Road', rarity = 3, cost = 8, bp = true, config = { extra = 0.5 }, tags = { 'xmult', 'scaling', 'discard_jacks' },
    main = current_xmult })

-- 131-150 ----------------------------------------------------------------------------------
def('j_duo', { name = 'The Duo', rarity = 3, cost = 8, bp = true, config = { Xmult = 2, type = 'Pair' }, tags = { 'xmult', 'hand_Pair' }, main = type_xmult('Pair', 2) })
def('j_trio', { name = 'The Trio', rarity = 3, cost = 8, bp = true, config = { Xmult = 3, type = 'Three of a Kind' }, tags = { 'xmult', 'hand_Three of a Kind' }, main = type_xmult('Three of a Kind', 3) })
def('j_family', { name = 'The Family', rarity = 3, cost = 8, bp = true, config = { Xmult = 4, type = 'Four of a Kind' }, tags = { 'xmult', 'hand_Four of a Kind' }, main = type_xmult('Four of a Kind', 4) })
def('j_order', { name = 'The Order', rarity = 3, cost = 8, bp = true, config = { Xmult = 3, type = 'Straight' }, tags = { 'xmult', 'hand_Straight' }, main = type_xmult('Straight', 3) })
def('j_tribe', { name = 'The Tribe', rarity = 3, cost = 8, bp = true, config = { Xmult = 2, type = 'Flush' }, tags = { 'xmult', 'hand_Flush' }, main = type_xmult('Flush', 2) })
def('j_stuntman', { name = 'Stuntman', rarity = 3, cost = 7, bp = true, config = { extra = { h_size = 2, chip_mod = 250 } }, tags = { 'chips', 'hand_size_minus' },
    main = function(x, j) return { chips = num((E(j) or {}).chip_mod, 250) } end })
def('j_invisible', { name = 'Invisible Joker', rarity = 3, cost = 8, bp = false, config = { extra = 2 }, tags = { 'joker_dup' } })
def('j_brainstorm', { name = 'Brainstorm', rarity = 3, cost = 10, bp = true, copy = 'leftmost', tags = { 'copy' } })
def('j_satellite', { name = 'Satellite', rarity = 2, cost = 6, bp = false, config = { extra = 1 }, tags = { 'econ', 'planets' },
    econ = { per_planet_type_per_round = 1 } })
def('j_shoot_the_moon', { name = 'Shoot the Moon', rarity = 1, cost = 5, bp = true, config = { extra = 13 }, tags = { 'mult', 'held', 'ranks_queen' },
    held = function(x, j, card)
        if C.has_rank(card) and card.id == 12 then return { mult = num(E(j), 13) } end
    end })
def('j_drivers_license', { name = "Driver's License", rarity = 3, cost = 7, bp = true, config = { extra = 3 }, tags = { 'xmult', 'enhanced_deck' },
    main = function(x, j)
        if x.deck_stat('enhanced') >= 16 then return { x_mult = num(E(j), 3) } end
    end })
def('j_cartomancer', { name = 'Cartomancer', rarity = 2, cost = 6, bp = true, tags = { 'tarot_gen' } })
def('j_astronomer', { name = 'Astronomer', rarity = 2, cost = 8, bp = false, tags = { 'econ', 'planets' } })
def('j_burnt', { name = 'Burnt Joker', rarity = 3, cost = 8, bp = true, tags = { 'levels', 'discards' } })
def('j_bootstraps', { name = 'Bootstraps', rarity = 2, cost = 7, bp = true, config = { extra = { mult = 2, dollars = 5 } }, tags = { 'mult', 'money' },
    main = function(x, j)
        local ex = E(j) or {}
        local d = x.dollars()
        local n = math.floor(d / num(ex.dollars, 5))
        if n > 0 then return { mult = n * num(ex.mult, 2) } end
    end })
def('j_caino', { name = 'Caino', rarity = 4, cost = 20, bp = true, config = { extra = 1 }, tags = { 'xmult', 'scaling', 'faces' },
    main = function(x, j)
        local xm = num(A(j).caino_xmult, 1)
        if xm > 1 then return { x_mult = xm } end
    end })
def('j_triboulet', { name = 'Triboulet', rarity = 4, cost = 20, bp = true, config = { extra = 2 }, tags = { 'xmult', 'ranks_king', 'ranks_queen' },
    indiv = function(x, j, card)
        if C.has_rank(card) and (card.id == 12 or card.id == 13) then return { x_mult = num(E(j), 2) } end
    end })
def('j_yorick', { name = 'Yorick', rarity = 4, cost = 20, bp = true, config = { extra = { xmult = 1, discards = 23 } }, tags = { 'xmult', 'scaling', 'discards' },
    main = current_xmult })
def('j_chicot', { name = 'Chicot', rarity = 4, cost = 20, bp = false, tags = { 'boss_disable' } })
def('j_perkeo', { name = 'Perkeo', rarity = 4, cost = 20, bp = false, config = { extra = 1 }, tags = { 'consumable_dup' } })

-- lookup ------------------------------------------------------------------------------------
function DB.get(key, name)
    return DB[key] or (name and DB[by_name[name]]) or nil
end

function DB.key_for_name(name) return by_name[name] end

-- Does this joker definition affect the score of a hand (directly or through rules)?
function DB.affects_score(def_)
    return def_ and (def_.before or def_.indiv or def_.rep or def_.held or def_.main or def_.other or def_.rule or def_.copy) and true or false
end

function DB.all_keys()
    local keys = {}
    for k, v in pairs(DB) do
        if type(v) == 'table' and v.key then keys[#keys + 1] = k end
    end
    table.sort(keys)
    return keys
end

return DB
