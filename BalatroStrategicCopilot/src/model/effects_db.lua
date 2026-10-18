-- Balatro Strategic Copilot - model/effects_db.lua
-- Everything that can modify a card or a joker, in one place: enhancements, editions, seals and
-- joker stickers. Effects are the vanilla rules (exact scoring is done by engine/score.lua with
-- the values read in the game); this table adds what the DECISIONS need:
--   role  'play'  worth playing (it acts when it scores)
--         'hold'  worth keeping in hand (it acts while held / at the end of the round)
--         'discard' worth discarding (Purple seal: a tarot)
--         'careful' play it only when it is needed (Glass: may break)
--   value  rough worth in points for ordering cards (keep / discard / copy), same scale as
--          the card's own chips (an Ace is 11)
-- Names and descriptions shown to the player are in core/i18n.lua (eff_<key>, effs_<key>).

local EF = {}

EF.ENHANCEMENTS = {
    m_bonus = { role = 'play', chips = 30, value = 30 },                         -- +30 chips when scored
    m_mult = { role = 'play', mult = 4, value = 24 },                            -- +4 Mult when scored
    m_wild = { role = 'play', any_suit = true, value = 12 },                     -- every suit
    m_glass = { role = 'careful', x_mult = 2, break_odds = 4, value = 40 },      -- x2 Mult, 1 in 4 destroyed when scored
    m_steel = { role = 'hold', h_x_mult = 1.5, value = 30 },                     -- x1.5 Mult while held in hand
    m_stone = { role = 'play', chips = 50, no_rank = true, value = 40 },         -- +50 chips, no rank or suit, always scores
    m_gold = { role = 'hold', h_dollars = 3, value = 14 },                       -- $3 if held at the end of the round
    m_lucky = { role = 'play', lucky_mult = 20, mult_odds = 5, lucky_dollars = 20, dollars_odds = 15, value = 22 },
}

EF.EDITIONS = {
    e_foil = { chips = 50, value = 15 },          -- +50 chips
    e_holo = { mult = 10, value = 25 },           -- +10 Mult
    e_polychrome = { x_mult = 1.5, value = 30 },  -- x1.5 Mult
    e_negative = { slot = 1, value = 30 },        -- joker / consumable: +1 slot
}

EF.SEALS = {
    Gold = { role = 'play', dollars = 3, value = 8 },       -- $3 when played and scored
    Red = { role = 'play', retrigger = 1, value = 15 },     -- retriggers the card
    Blue = { role = 'hold', planet = true, value = 10 },    -- planet of the last hand played, if held at the end of the round
    Purple = { role = 'discard', tarot = true, value = -15 }, -- a tarot when discarded
}

-- Joker stickers (stakes): eternal from Black Stake, perishable from Orange Stake, rental from
-- Gold Stake.
EF.STICKERS = {
    eternal = { can_sell = false },                   -- cannot be sold or destroyed
    perishable = { rounds = 5 },                      -- debuffed after 5 rounds
    rental = { buy_cost = 1, per_round = 3 },         -- bought for $1, costs $3 at the end of each round
}

-- Worth of a playing card for ordering (keep / discard / copy targets): its chips plus what its
-- modifiers bring. Probabilities are expected values (Lucky: +20 Mult 1 time in 5 = +4).
function EF.card_value(c)
    if not c then return 0 end
    local v = (c.nominal or 0) + (c.bonus or 0) + (c.perma_bonus or 0)
    local mult = (c.mult or 0)
    if c.lucky or c.enh == 'm_lucky' then
        -- +20 Mult 1 time in 5 and $20 1 time in 15
        mult = mult / EF.ENHANCEMENTS.m_lucky.mult_odds
        v = v + 3 * (c.p_dollars or 0) / EF.ENHANCEMENTS.m_lucky.dollars_odds
    end
    v = v + 6 * (mult + (c.perma_mult or 0))
    if (c.x_mult or 1) > 1 then v = v + 40 * (c.x_mult - 1) end
    if (c.h_x_mult or 1) > 1 then v = v + 60 * (c.h_x_mult - 1) end
    if (c.h_dollars or 0) > 0 then v = v + 4 * c.h_dollars end
    if c.any_suit or c.enh == 'm_wild' then v = v + EF.ENHANCEMENTS.m_wild.value end
    local ed = c.edition and EF.EDITIONS[c.edition]
    if ed then v = v + ed.value end
    local seal = c.seal and EF.SEALS[c.seal]
    if seal then v = v + seal.value end
    if c.debuff then v = v - 50 end
    return v
end

-- Role of a card for the current hand: 'hold' (steel, gold, blue seal), 'discard' (purple
-- seal), 'careful' (glass) or 'play'.
function EF.role(c)
    if not c or c.debuff then return 'play' end
    if c.seal == 'Purple' then return 'discard' end
    local e = c.enh and EF.ENHANCEMENTS[c.enh]
    if e and e.role == 'hold' then return 'hold' end
    if c.seal == 'Blue' then return 'hold' end
    if e and e.role == 'careful' then return 'careful' end
    return 'play'
end

-- Modifier keys of a card, for display: { 'm_steel', 'e_holo', 'seal_Red' }.
function EF.modifiers(c)
    local out = {}
    if not c or c.face_down then return out end
    if c.enh and c.enh ~= 'c_base' then out[#out + 1] = c.enh end
    if c.edition then out[#out + 1] = c.edition end
    if c.seal then out[#out + 1] = 'seal_' .. tostring(c.seal) end
    return out
end

-- Sticker keys of a joker: { 'eternal', 'perishable', 'rental' }.
function EF.stickers(j)
    local out = {}
    if not j then return out end
    if j.eternal then out[#out + 1] = 'eternal' end
    if j.perishable then out[#out + 1] = 'perishable' end
    if j.rental then out[#out + 1] = 'rental' end
    return out
end

-- Rounds left before a perishable joker is debuffed (nil when not perishable).
function EF.perish_left(j)
    if not j or not j.perishable then return nil end
    local t = tonumber(j.perish_tally)
    if t then return math.max(0, t) end
    return EF.STICKERS.perishable.rounds
end

function EF.can_sell(j)
    return j ~= nil and not j.eternal
end

return EF
