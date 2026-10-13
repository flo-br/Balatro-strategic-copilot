-- Balatro Strategic Copilot - model/blinds_db.lua
-- Vanilla blinds: size multipliers and the constraints they impose on analysis.
-- In game, sizes are computed with the game's own get_blind_amount() when available.

local B = {}

-- effect tags used by the analyzers:
--   debuff_suit / debuff_face / debuff_played_ante / debuff_all : cards debuffed
--   hands_1, no_discards, hand_size_minus, draw_face_down, ...  : resource constraints
B.BLINDS = {
    bl_small = { name = 'Small Blind', mult = 1, boss = false },
    bl_big = { name = 'Big Blind', mult = 1.5, boss = false },
    bl_hook = { name = 'The Hook', mult = 2, boss = true, min = 1, effect = 'discard_2_random' },
    bl_ox = { name = 'The Ox', mult = 2, boss = true, min = 6, effect = 'most_played_money' },
    bl_house = { name = 'The House', mult = 2, boss = true, min = 2, effect = 'first_hand_face_down' },
    bl_wall = { name = 'The Wall', mult = 4, boss = true, min = 2, effect = 'big' },
    bl_wheel = { name = 'The Wheel', mult = 2, boss = true, min = 2, effect = 'face_down_1_in_7' },
    bl_arm = { name = 'The Arm', mult = 2, boss = true, min = 2, effect = 'level_down' },
    bl_club = { name = 'The Club', mult = 2, boss = true, min = 1, effect = 'debuff_suit', suit = 'Clubs' },
    bl_fish = { name = 'The Fish', mult = 2, boss = true, min = 2, effect = 'face_down_after_play' },
    bl_psychic = { name = 'The Psychic', mult = 2, boss = true, min = 1, effect = 'five_cards' },
    bl_goad = { name = 'The Goad', mult = 2, boss = true, min = 1, effect = 'debuff_suit', suit = 'Spades' },
    bl_water = { name = 'The Water', mult = 2, boss = true, min = 2, effect = 'no_discards' },
    bl_window = { name = 'The Window', mult = 2, boss = true, min = 1, effect = 'debuff_suit', suit = 'Diamonds' },
    bl_manacle = { name = 'The Manacle', mult = 2, boss = true, min = 1, effect = 'hand_size_minus' },
    bl_eye = { name = 'The Eye', mult = 2, boss = true, min = 3, effect = 'no_repeat_hand' },
    bl_mouth = { name = 'The Mouth', mult = 2, boss = true, min = 2, effect = 'one_hand_type' },
    bl_plant = { name = 'The Plant', mult = 2, boss = true, min = 4, effect = 'debuff_face' },
    bl_serpent = { name = 'The Serpent', mult = 2, boss = true, min = 5, effect = 'draw_3' },
    bl_pillar = { name = 'The Pillar', mult = 2, boss = true, min = 1, effect = 'debuff_played_ante' },
    bl_needle = { name = 'The Needle', mult = 1, boss = true, min = 2, effect = 'hands_1' },
    bl_head = { name = 'The Head', mult = 2, boss = true, min = 1, effect = 'debuff_suit', suit = 'Hearts' },
    bl_tooth = { name = 'The Tooth', mult = 2, boss = true, min = 3, effect = 'money_per_card' },
    bl_flint = { name = 'The Flint', mult = 2, boss = true, min = 2, effect = 'halve_base' },
    bl_mark = { name = 'The Mark', mult = 2, boss = true, min = 2, effect = 'faces_face_down' },
    bl_final_acorn = { name = 'Amber Acorn', mult = 2, boss = true, final = true, effect = 'jokers_hidden' },
    bl_final_leaf = { name = 'Verdant Leaf', mult = 2, boss = true, final = true, effect = 'debuff_all' },
    bl_final_vessel = { name = 'Violet Vessel', mult = 6, boss = true, final = true, effect = 'big' },
    bl_final_heart = { name = 'Crimson Heart', mult = 2, boss = true, final = true, effect = 'random_joker_disabled' },
    bl_final_bell = { name = 'Cerulean Bell', mult = 2, boss = true, final = true, effect = 'forced_card' },
}

-- Vanilla get_blind_amount (base chips per ante) for the three scaling modes
-- (G.GAME.modifiers.scaling: 1 by default, 2 from Green Stake, 3 from Purple Stake).
local AMOUNTS = {
    [1] = { 300, 800, 2000, 5000, 11000, 20000, 35000, 50000 },
    [2] = { 300, 900, 2600, 8000, 20000, 36000, 60000, 100000 },
    [3] = { 300, 1000, 3200, 9000, 25000, 60000, 110000, 200000 },
}

function B.base_amount(ante, scaling)
    scaling = scaling or 1
    local amounts = AMOUNTS[scaling] or AMOUNTS[1]
    if ante < 1 then return 100 end
    if ante <= 8 then return amounts[ante] end
    local k = 0.75
    local a, b, c, d = amounts[8], 1.6, ante - 8, 1 + 0.2 * (ante - 8)
    local amount = math.floor(a * (b + (k * c) ^ d) ^ c)
    local p = 10 ^ math.floor(math.log10(amount) - 1)
    amount = amount - amount % p
    return amount
end

function B.get(key) return B.BLINDS[key] end

function B.size(key, ante, scaling, ante_scaling)
    local b = B.BLINDS[key]
    local m = b and b.mult or 2
    return math.floor(B.base_amount(ante, scaling) * m * (ante_scaling or 1))
end

return B
