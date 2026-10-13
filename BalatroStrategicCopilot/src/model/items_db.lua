-- Balatro Strategic Copilot - model/items_db.lua
-- Vanilla consumables, vouchers and boosters. Effects that the score engine can simulate are
-- flagged with `sim` (the shop analyzer then measures them); the others carry a documented
-- HEURISTIC base value in dollars-equivalent (`v`), adjusted by context (`ctx`), always shown
-- with method "heuristique" and limited confidence.

local IT = {}

-- sim kinds: level (planet), level_all (black hole), enhance(enh, n), suit(s, n), hands(+n),
-- discards(+n), hand_size(+n), slot(+n), interest_cap(+n), ante(-1)
IT.TAROTS = {
    c_fool = { v = 3, desc = 'copie le dernier consommable' },
    c_magician = { v = 3, sim = { enhance = 'm_lucky', n = 2 }, ctx = { lucky = 2 } },
    c_high_priestess = { v = 5, desc = '2 planètes' },
    c_empress = { v = 4, sim = { enhance = 'm_mult', n = 2 } },
    c_emperor = { v = 5, desc = '2 tarots' },
    c_heirophant = { v = 3, sim = { enhance = 'm_bonus', n = 2 } },
    c_lovers = { v = 3, sim = { enhance = 'm_wild', n = 1 }, ctx = { flush = 1.5 } },
    c_chariot = { v = 3, sim = { enhance = 'm_steel', n = 1 }, ctx = { deck_steel = 2, held = 1.5 } },
    c_justice = { v = 3, sim = { enhance = 'm_glass', n = 1 }, ctx = { glass = 2 } },
    c_hermit = { v = 0, money = 'double' },
    c_wheel_of_fortune = { v = 3, desc = '1/4 : édition sur un joker' },
    c_strength = { v = 3, desc = '+1 rang à 2 cartes' },
    c_hanged_man = { v = 3, desc = 'détruit 2 cartes (affinage)' },
    c_death = { v = 3, desc = 'copie une carte' },
    c_temperance = { v = 0, money = 'sell_values' },
    c_devil = { v = 3, sim = { enhance = 'm_gold', n = 1 }, ctx = { gold = 2 } },
    c_tower = { v = 2, sim = { enhance = 'm_stone', n = 1 }, ctx = { deck_stone = 2 } },
    c_star = { v = 3, sim = { suit = 'Diamonds', n = 3 } },
    c_moon = { v = 3, sim = { suit = 'Clubs', n = 3 } },
    c_sun = { v = 3, sim = { suit = 'Hearts', n = 3 } },
    c_world = { v = 3, sim = { suit = 'Spades', n = 3 } },
    c_judgement = { v = 5, desc = 'joker aléatoire' },
}

IT.SPECTRALS = {
    c_familiar = { v = 3 }, c_grim = { v = 3 }, c_incantation = { v = 3 },
    c_talisman = { v = 4, desc = 'sceau or' }, c_aura = { v = 5, desc = 'édition sur une carte' },
    c_wraith = { v = 6, desc = 'joker rare, argent à 0' }, c_sigil = { v = 4, ctx = { flush = 2 } },
    c_ouija = { v = 3, desc = 'une seule valeur, -1 taille de main' }, c_ectoplasm = { v = 7, desc = 'joker négatif, -1 taille de main' },
    c_immolate = { v = 6 }, c_ankh = { v = 5 }, c_deja_vu = { v = 4, desc = 'sceau rouge' }, c_hex = { v = 6 },
    c_trance = { v = 3 }, c_medium = { v = 3 }, c_cryptid = { v = 5 }, c_soul = { v = 15, desc = 'joker légendaire' },
    c_black_hole = { v = 8, sim = { level_all = 1 } },
}

IT.VOUCHERS = {
    v_overstock_norm = { v = 8 }, v_overstock_plus = { v = 8 },
    v_clearance_sale = { v = 8 }, v_liquidation = { v = 9 },
    v_hone = { v = 5 }, v_glow_up = { v = 6 },
    v_reroll_surplus = { v = 6 }, v_reroll_glut = { v = 6 },
    v_crystal_ball = { v = 5 }, v_omen_globe = { v = 3 },
    v_telescope = { v = 6 }, v_observatory = { v = 8, ctx = { planets_held = 3 } },
    v_grabber = { v = 10, sim = { hands = 1 } }, v_nacho_tong = { v = 10, sim = { hands = 1 } },
    v_wasteful = { v = 7, sim = { discards = 1 } }, v_recyclomancy = { v = 7, sim = { discards = 1 } },
    v_tarot_merchant = { v = 3 }, v_tarot_tycoon = { v = 3 }, v_planet_merchant = { v = 4 }, v_planet_tycoon = { v = 4 },
    v_seed_money = { v = 6, sim = { interest_cap = 25 } }, v_money_tree = { v = 7, sim = { interest_cap = 50 } },
    v_blank = { v = 1 }, v_antimatter = { v = 14, sim = { slot = 1 } },
    v_magic_trick = { v = 2 }, v_illusion = { v = 3 },
    v_hieroglyph = { v = 12, sim = { ante = -1, hands = -1 } }, v_petroglyph = { v = 12, sim = { ante = -1, discards = -1 } },
    v_directors_cut = { v = 4 }, v_retcon = { v = 4 },
    v_paint_brush = { v = 9, sim = { hand_size = 1 } }, v_palette = { v = 9, sim = { hand_size = 1 } },
}

-- Boosters by kind: expected value in $ (heuristic), size = cards shown, choose = picks
IT.BOOSTERS = {
    Arcana = { v = 3.5 }, Celestial = { v = 3.5, planet = true }, Spectral = { v = 4.5 },
    Standard = { v = 2 }, Buffoon = { v = 5, jokers = true },
}

function IT.consumable(key)
    return IT.TAROTS[key] or IT.SPECTRALS[key]
end

return IT
