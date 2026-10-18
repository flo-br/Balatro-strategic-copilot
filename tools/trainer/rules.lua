-- Balatro Strategic Copilot - tools/trainer/rules.lua
-- Static rules of the simplified Balatro used to TRAIN the copilot (vanilla 1.0.1 values,
-- White Stake). Only what the simulator needs; documented in docs/TRAINING.md. Not part of
-- the mod.

local R = {}

R.START = { dollars = 4, hands = 4, discards = 3, hand_size = 8, joker_slots = 5, consumable_slots = 2, interest_cap = 25,
    reroll_cost = 5, win_ante = 8 }

-- Decks (G.P_CENTERS.b_*): only what changes the simulation
R.DECKS = {
    b_red = { discards = 1 },          -- Red Deck: +1 discard every round
    b_blue = { hands = 1 },            -- Blue Deck: +1 hand
    b_yellow = { dollars = 10 },       -- Yellow Deck: +$10 at the start
}

R.BLIND_REWARD = { Small = 3, Big = 4, Boss = 5 }

-- Shop card slots: weights of each kind (G.GAME.*_rate)
R.SHOP_RATES = { joker = 20, tarot = 4, planet = 4, spectral = 0, playing_card = 0 }
R.RARITY_WEIGHTS = { 0.70, 0.25, 0.05 }
-- joker edition odds in the shop (poll_edition, rate 1): negative 0.3 %, polychrome 0.3 %,
-- holographic 1.4 %, foil 2 %
R.EDITION_ODDS = { { 'e_negative', 0.003 }, { 'e_polychrome', 0.003 }, { 'e_holo', 0.014 }, { 'e_foil', 0.02 } }
R.EDITION_COST = { e_foil = 2, e_holo = 3, e_polychrome = 5, e_negative = 5 }
R.CONSUMABLE_COST = { Tarot = 3, Planet = 3, Spectral = 4 }
R.VOUCHER_COST = 10

-- Boosters: { kind, size, choose, cost, weight }
R.BOOSTERS = {
    { key = 'p_arcana_normal', kind = 'Arcana', size = 3, choose = 1, cost = 4, weight = 4 },
    { key = 'p_arcana_jumbo', kind = 'Arcana', size = 5, choose = 1, cost = 6, weight = 2 },
    { key = 'p_arcana_mega', kind = 'Arcana', size = 5, choose = 2, cost = 8, weight = 0.5 },
    { key = 'p_celestial_normal', kind = 'Celestial', size = 3, choose = 1, cost = 4, weight = 4 },
    { key = 'p_celestial_jumbo', kind = 'Celestial', size = 5, choose = 1, cost = 6, weight = 2 },
    { key = 'p_celestial_mega', kind = 'Celestial', size = 5, choose = 2, cost = 8, weight = 0.5 },
    { key = 'p_standard_normal', kind = 'Standard', size = 3, choose = 1, cost = 4, weight = 4 },
    { key = 'p_standard_jumbo', kind = 'Standard', size = 5, choose = 1, cost = 6, weight = 2 },
    { key = 'p_standard_mega', kind = 'Standard', size = 5, choose = 2, cost = 8, weight = 0.5 },
    { key = 'p_buffoon_normal', kind = 'Buffoon', size = 2, choose = 1, cost = 4, weight = 1.2 },
    { key = 'p_buffoon_jumbo', kind = 'Buffoon', size = 4, choose = 1, cost = 6, weight = 0.6 },
    { key = 'p_buffoon_mega', kind = 'Buffoon', size = 4, choose = 2, cost = 8, weight = 0.15 },
    { key = 'p_spectral_normal', kind = 'Spectral', size = 2, choose = 1, cost = 4, weight = 0.6 },
    { key = 'p_spectral_jumbo', kind = 'Spectral', size = 4, choose = 1, cost = 6, weight = 0.3 },
    { key = 'p_spectral_mega', kind = 'Spectral', size = 4, choose = 2, cost = 8, weight = 0.07 },
}

-- Standard pack cards: enhancement 40 %, edition (foil 4 %, holo 2.8 %, poly 1.2 %), seal 20 %
R.STANDARD = { enhanced = 0.4, seal = 0.2, editions = { { 'e_polychrome', 0.012 }, { 'e_holo', 0.028 }, { 'e_foil', 0.04 } } }
R.ENHANCEMENTS = { 'm_bonus', 'm_mult', 'm_wild', 'm_glass', 'm_steel', 'm_stone', 'm_gold', 'm_lucky' }
R.SEALS = { 'Gold', 'Red', 'Blue', 'Purple' }

R.TAROTS = { 'c_fool', 'c_magician', 'c_high_priestess', 'c_empress', 'c_emperor', 'c_heirophant', 'c_lovers', 'c_chariot',
    'c_justice', 'c_hermit', 'c_wheel_of_fortune', 'c_strength', 'c_hanged_man', 'c_death', 'c_temperance', 'c_devil',
    'c_tower', 'c_star', 'c_moon', 'c_sun', 'c_judgement', 'c_world' }
R.TAROT_NAMES = { c_fool = 'The Fool', c_magician = 'The Magician', c_high_priestess = 'The High Priestess',
    c_empress = 'The Empress', c_emperor = 'The Emperor', c_heirophant = 'The Hierophant', c_lovers = 'The Lovers',
    c_chariot = 'The Chariot', c_justice = 'Justice', c_hermit = 'The Hermit', c_wheel_of_fortune = 'The Wheel of Fortune',
    c_strength = 'Strength', c_hanged_man = 'The Hanged Man', c_death = 'Death', c_temperance = 'Temperance',
    c_devil = 'The Devil', c_tower = 'The Tower', c_star = 'The Star', c_moon = 'The Moon', c_sun = 'The Sun',
    c_judgement = 'Judgement', c_world = 'The World' }
R.SPECTRALS = { 'c_familiar', 'c_grim', 'c_incantation', 'c_talisman', 'c_aura', 'c_wraith', 'c_sigil', 'c_ouija',
    'c_ectoplasm', 'c_immolate', 'c_ankh', 'c_deja_vu', 'c_hex', 'c_trance', 'c_medium', 'c_cryptid' }
R.SPECTRAL_NAMES = { c_familiar = 'Familiar', c_grim = 'Grim', c_incantation = 'Incantation', c_talisman = 'Talisman',
    c_aura = 'Aura', c_wraith = 'Wraith', c_sigil = 'Sigil', c_ouija = 'Ouija', c_ectoplasm = 'Ectoplasm',
    c_immolate = 'Immolate', c_ankh = 'Ankh', c_deja_vu = 'Deja Vu', c_hex = 'Hex', c_trance = 'Trance',
    c_medium = 'Medium', c_cryptid = 'Cryptid', c_soul = 'The Soul', c_black_hole = 'Black Hole' }
-- base planets (Planet X, Ceres, Eris appear once their secret hand has been played)
R.PLANETS = { 'c_pluto', 'c_mercury', 'c_uranus', 'c_venus', 'c_saturn', 'c_jupiter', 'c_earth', 'c_mars', 'c_neptune' }
R.SECRET_PLANETS = { c_planet_x = 'Five of a Kind', c_ceres = 'Flush House', c_eris = 'Flush Five' }
R.PLANET_NAMES = { c_pluto = 'Pluto', c_mercury = 'Mercury', c_uranus = 'Uranus', c_venus = 'Venus', c_saturn = 'Saturn',
    c_jupiter = 'Jupiter', c_earth = 'Earth', c_mars = 'Mars', c_neptune = 'Neptune', c_planet_x = 'Planet X',
    c_ceres = 'Ceres', c_eris = 'Eris' }
R.SOUL_ODDS = 0.003         -- The Soul in an Arcana or Spectral pack
R.BLACK_HOLE_ODDS = 0.003   -- Black Hole in a Celestial or Spectral pack

-- Vouchers: prerequisite and what the simulator applies
R.VOUCHERS = {
    v_overstock_norm = {}, v_overstock_plus = { req = 'v_overstock_norm' },
    v_clearance_sale = {}, v_liquidation = { req = 'v_clearance_sale' },
    v_hone = {}, v_glow_up = { req = 'v_hone' },
    v_reroll_surplus = {}, v_reroll_glut = { req = 'v_reroll_surplus' },
    v_crystal_ball = {}, v_omen_globe = { req = 'v_crystal_ball' },
    v_telescope = {}, v_observatory = { req = 'v_telescope' },
    v_grabber = {}, v_nacho_tong = { req = 'v_grabber' },
    v_wasteful = {}, v_recyclomancy = { req = 'v_wasteful' },
    v_tarot_merchant = {}, v_tarot_tycoon = { req = 'v_tarot_merchant' },
    v_planet_merchant = {}, v_planet_tycoon = { req = 'v_planet_merchant' },
    v_seed_money = {}, v_money_tree = { req = 'v_seed_money' },
    v_blank = {}, v_antimatter = { req = 'v_blank' },
    v_magic_trick = {}, v_illusion = { req = 'v_magic_trick' },
    v_hieroglyph = {}, v_petroglyph = { req = 'v_hieroglyph' },
    v_directors_cut = {}, v_retcon = { req = 'v_directors_cut' },
    v_paint_brush = {}, v_palette = { req = 'v_paint_brush' },
}

-- Skip tags available in the simulator (others are not offered): { key, min_ante }
R.TAGS = {
    { 'tag_uncommon', 1 }, { 'tag_rare', 1 }, { 'tag_negative', 2 }, { 'tag_foil', 1 }, { 'tag_holo', 1 },
    { 'tag_polychrome', 1 }, { 'tag_investment', 1 }, { 'tag_voucher', 1 }, { 'tag_boss', 1 }, { 'tag_standard', 2 },
    { 'tag_charm', 1 }, { 'tag_meteor', 2 }, { 'tag_buffoon', 2 }, { 'tag_handy', 2 }, { 'tag_garbage', 2 },
    { 'tag_ethereal', 2 }, { 'tag_coupon', 1 }, { 'tag_double', 1 }, { 'tag_juggle', 1 }, { 'tag_d_six', 1 },
    { 'tag_top_up', 2 }, { 'tag_skip', 1 }, { 'tag_orbital', 2 }, { 'tag_economy', 1 },
}

return R
