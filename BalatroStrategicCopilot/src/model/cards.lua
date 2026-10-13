-- Balatro Strategic Copilot - model/cards.lua
-- Normalized playing-card model used by every analysis module. Cards are plain tables;
-- the reader builds them from the game, tests build them with C.parse("Ah", {...}).

local C = {}

C.SUITS = { 'Spades', 'Hearts', 'Clubs', 'Diamonds' }
C.SUIT_NOMINAL = { Diamonds = 0.01, Clubs = 0.02, Hearts = 0.03, Spades = 0.04 }
C.SUIT_SHORT = { S = 'Spades', H = 'Hearts', C = 'Clubs', D = 'Diamonds' }
C.SUIT_LETTER = { Spades = 'S', Hearts = 'H', Clubs = 'C', Diamonds = 'D' }
C.SUIT_SYMBOL = { Spades = '♠', Hearts = '♥', Clubs = '♣', Diamonds = '♦' }
C.RED = { Hearts = true, Diamonds = true }

-- rank value (base.value) -> id, nominal chips, face nominal (tie-break used by get_nominal)
C.RANKS = {
    ['2'] = { id = 2, nominal = 2, face_nominal = 0 },
    ['3'] = { id = 3, nominal = 3, face_nominal = 0 },
    ['4'] = { id = 4, nominal = 4, face_nominal = 0 },
    ['5'] = { id = 5, nominal = 5, face_nominal = 0 },
    ['6'] = { id = 6, nominal = 6, face_nominal = 0 },
    ['7'] = { id = 7, nominal = 7, face_nominal = 0 },
    ['8'] = { id = 8, nominal = 8, face_nominal = 0 },
    ['9'] = { id = 9, nominal = 9, face_nominal = 0 },
    ['10'] = { id = 10, nominal = 10, face_nominal = 0 },
    Jack = { id = 11, nominal = 10, face_nominal = 0.1, face = true },
    Queen = { id = 12, nominal = 10, face_nominal = 0.2, face = true },
    King = { id = 13, nominal = 10, face_nominal = 0.3, face = true },
    Ace = { id = 14, nominal = 11, face_nominal = 0.4 },
}
C.RANK_ORDER = { '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King', 'Ace' }
C.ID_TO_RANK = {}
for _, r in ipairs(C.RANK_ORDER) do C.ID_TO_RANK[C.RANKS[r].id] = r end
C.SHORT_RANK = { T = '10', J = 'Jack', Q = 'Queen', K = 'King', A = 'Ace' }
C.RANK_LETTER = { ['10'] = '10', Jack = 'J', Queen = 'Q', King = 'K', Ace = 'A' }

-- Default values of vanilla enhancements (used only if the game did not provide ability values)
C.ENHANCEMENTS = {
    m_bonus = { bonus = 30 },
    m_mult = { mult = 4 },
    m_wild = { any_suit = true },
    m_glass = { x_mult = 2, glass_odds = 4 },
    m_steel = { h_x_mult = 1.5 },
    m_stone = { bonus = 50, no_rank = true, no_suit = true, always_scores = true },
    m_gold = { h_dollars = 3 },
    m_lucky = { mult = 20, p_dollars = 20, lucky = true },
}
C.EDITIONS = {
    e_foil = { chips = 50 },
    e_holo = { mult = 10 },
    e_polychrome = { x_mult = 1.5 },
    e_negative = {},
}

local uid_counter = 0
local function next_uid()
    uid_counter = uid_counter + 1
    return 100000 + uid_counter
end

-- Build a normalized card. fields may override anything.
function C.new(rank, suit, fields)
    local r = C.RANKS[rank]
    local card = {
        uid = next_uid(),
        rank = rank,
        id = r and r.id or 0,
        suit = suit,
        nominal = r and r.nominal or 0,
        face_nominal = r and r.face_nominal or 0,
        suit_nominal = C.SUIT_NOMINAL[suit] or 0,
        bonus = 0, perma_bonus = 0, perma_mult = 0, perma_x_mult = 0,
        perma_h_mult = 0, perma_h_x_mult = 0, perma_p_dollars = 0,
        mult = 0, x_mult = 1, h_x_mult = 1, h_mult = 0, p_dollars = 0, h_dollars = 0,
    }
    fields = fields or {}
    if fields.enh then card.enh = fields.enh end
    C.apply_enhancement_defaults(card)
    for k, v in pairs(fields) do
        if k ~= 'enh' then card[k] = v end
    end
    return card
end

-- Fill enhancement-dependent numeric fields with vanilla defaults.
function C.apply_enhancement_defaults(card)
    local e = card.enh and C.ENHANCEMENTS[card.enh]
    card.bonus = 0; card.mult = 0; card.x_mult = 1; card.h_x_mult = 1; card.p_dollars = 0; card.h_dollars = 0
    card.no_rank, card.no_suit, card.any_suit, card.always_scores, card.lucky = nil, nil, nil, nil, nil
    if e then
        for k, v in pairs(e) do card[k] = v end
    end
    if card.no_rank then card.id = 0 end
    return card
end

-- Change enhancement in place (used by simulations of Vampire, Midas Mask, tarots).
function C.set_enhancement(card, enh)
    local keep_id = C.RANKS[card.rank] and C.RANKS[card.rank].id or 0
    card.enh = enh
    card.id = keep_id
    C.apply_enhancement_defaults(card)
end

-- "Ah", "Td", "10s", "Qc" ; opts: {enh=..., edition=..., seal=..., debuff=...}
function C.parse(code, opts)
    local rs, ss = code:match('^(%w-)(%a)$')
    if not rs then error('bad card code ' .. tostring(code)) end
    local rank = C.SHORT_RANK[rs:upper()] or rs
    local suit = C.SUIT_SHORT[ss:upper()]
    if not C.RANKS[rank] or not suit then error('bad card code ' .. tostring(code)) end
    return C.new(rank, suit, opts)
end

function C.parse_list(str, opts)
    local out = {}
    for code in tostring(str):gmatch('%S+') do out[#out + 1] = C.parse(code, opts) end
    return out
end

function C.copy(card)
    local c = {}
    for k, v in pairs(card) do c[k] = v end
    return c
end

function C.label(card)
    if card.face_down then return '??' end
    if card.no_rank then return 'Pierre' end
    local r = C.RANK_LETTER[card.rank] or card.rank or '?'
    return r .. (C.SUIT_SYMBOL[card.suit] or '?')
end

-- Rules flags (rules table comes from the snapshot: four_fingers, shortcut, smeared, pareidolia, splash)

function C.has_rank(card)
    return not card.no_rank and card.id and card.id > 0
end

-- Vanilla Card:is_face(): debuffed cards are not faces for joker purposes.
function C.is_face(card, rules, from_boss)
    if card.debuff and not from_boss then return false end
    if rules and rules.pareidolia then return true end
    if not C.has_rank(card) then return false end
    return card.id == 11 or card.id == 12 or card.id == 13
end

-- Vanilla Card:is_suit(suit, bypass_debuff, flush_calc)
function C.is_suit(card, suit, rules, bypass_debuff, flush_calc)
    if flush_calc then
        if card.no_suit then return false end
        if card.any_suit and not card.debuff then return true end
        if rules and rules.smeared and card.suit and (C.RED[card.suit] or false) == (C.RED[suit] or false) then return true end
        return card.suit == suit
    end
    if card.debuff and not bypass_debuff then return false end
    if card.no_suit then return false end
    if card.any_suit then return true end
    if rules and rules.smeared and card.suit and (C.RED[card.suit] or false) == (C.RED[suit] or false) then return true end
    return card.suit == suit
end

-- Vanilla Card:get_nominal() ordering key (highest card).
function C.nominal_key(card)
    if card.no_rank then return -10000 + (card.suit_nominal or 0) end
    return 10 * (card.nominal or 0) + 10 * (card.face_nominal or 0) + (card.suit_nominal or 0)
end

-- A standard 52-card deck (useful in tests and as a prior).
function C.standard_deck()
    local d = {}
    for _, s in ipairs(C.SUITS) do
        for _, r in ipairs(C.RANK_ORDER) do d[#d + 1] = C.new(r, s) end
    end
    return d
end

return C
