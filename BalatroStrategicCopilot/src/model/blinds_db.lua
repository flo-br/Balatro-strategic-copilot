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

-- What each boss demands, and how top players prepare for it (docs/PRO_LESSONS.md §8)
B.PREP = {
    bl_wall = 'blinde ×4 : il faut une marge de puissance (multiplicateurs) avant d\'y arriver',
    bl_final_vessel = 'blinde ×6 : seul un build à plusieurs ×Mult (ou qui grandit) passe, à préparer dès l\'ante 5',
    bl_needle = 'une seule main : il faut pouvoir marquer tout le score en une main (×Mult, main bien montée)',
    bl_psychic = '5 cartes obligatoires : prévoir une main à 5 cartes (Couleur, Suite, Full)',
    bl_water = 'aucune défausse : un deck régulier (Hanged Man pour l\'affiner, une couleur dominante)',
    bl_manacle = '−1 carte en main : un build qui ne dépend pas d\'une grosse main',
    bl_eye = 'jamais deux fois la même main : avoir une 2e main utilisable',
    bl_mouth = 'un seul type de main : rester sur la main principale',
    bl_plant = 'figures affaiblies : ne pas dépendre que des figures',
    bl_club = 'Trèfles affaiblis : ne pas dépendre d\'une seule couleur (ou Luchador / Chicot)',
    bl_goad = 'Piques affaiblis : ne pas dépendre d\'une seule couleur (ou Luchador / Chicot)',
    bl_window = 'Carreaux affaiblis : ne pas dépendre d\'une seule couleur (ou Luchador / Chicot)',
    bl_head = 'Cœurs affaiblis : ne pas dépendre d\'une seule couleur (ou Luchador / Chicot)',
    bl_pillar = 'cartes déjà jouées dans l\'ante affaiblies : garder de la marge pour le boss',
    bl_flint = 'jetons et multi de base divisés par 2 : les ×Mult des jokers comptent encore plus',
    bl_arm = 'baisse le niveau de la main jouée : marge sur la main principale',
    bl_ox = 'jouer sa main la plus jouée met l\'argent à 0 : jouer une autre main si possible',
    bl_hook = 'défausse 2 cartes au hasard à chaque main : préférer les mains courtes',
    bl_tooth = '−1 $ par carte jouée',
    bl_serpent = 'pioche toujours 3 cartes : jouer et défausser par petites quantités',
    bl_house = 'première main face cachée',
    bl_mark = 'figures face cachée',
    bl_wheel = '1 carte sur 7 face cachée',
    bl_fish = 'cartes face cachée après chaque main',
    bl_final_leaf = 'toutes les cartes affaiblies jusqu\'à la vente d\'un joker : garder un joker à vendre',
    bl_final_acorn = 'jokers retournés et mélangés : un build qui ne dépend pas de l\'ordre',
    bl_final_heart = 'un joker désactivé à chaque main : ne pas dépendre d\'un seul joker',
    bl_final_bell = 'une carte imposée dans chaque main',
}

function B.get(key) return B.BLINDS[key] end

function B.size(key, ante, scaling, ante_scaling)
    local b = B.BLINDS[key]
    local m = b and b.mult or 2
    return math.floor(B.base_amount(ante, scaling) * m * (ante_scaling or 1))
end

return B
