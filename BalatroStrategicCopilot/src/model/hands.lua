-- Balatro Strategic Copilot - model/hands.lua
-- Vanilla poker hands, in G.handlist priority order. In game the actual chips/mult/level
-- are read from G.GAME.hands; these defaults are used for tests and as a fallback.

local H = {}

H.ORDER = {
    'Flush Five', 'Flush House', 'Five of a Kind', 'Straight Flush', 'Four of a Kind',
    'Full House', 'Flush', 'Straight', 'Three of a Kind', 'Two Pair', 'Pair', 'High Card',
}

-- base chips, base mult, chips per level, mult per level (vanilla G:init_game_object().hands)
H.BASE = {
    ['Flush Five']      = { chips = 160, mult = 16, l_chips = 50, l_mult = 3, visible = false },
    ['Flush House']     = { chips = 140, mult = 14, l_chips = 40, l_mult = 4, visible = false },
    ['Five of a Kind']  = { chips = 120, mult = 12, l_chips = 35, l_mult = 3, visible = false },
    ['Straight Flush']  = { chips = 100, mult = 8, l_chips = 40, l_mult = 4, visible = true },
    ['Four of a Kind']  = { chips = 60, mult = 7, l_chips = 30, l_mult = 3, visible = true },
    ['Full House']      = { chips = 40, mult = 4, l_chips = 25, l_mult = 2, visible = true },
    ['Flush']           = { chips = 35, mult = 4, l_chips = 15, l_mult = 2, visible = true },
    ['Straight']        = { chips = 30, mult = 4, l_chips = 30, l_mult = 3, visible = true },
    ['Three of a Kind'] = { chips = 30, mult = 3, l_chips = 20, l_mult = 2, visible = true },
    ['Two Pair']        = { chips = 20, mult = 2, l_chips = 20, l_mult = 1, visible = true },
    ['Pair']            = { chips = 10, mult = 2, l_chips = 15, l_mult = 1, visible = true },
    ['High Card']       = { chips = 5, mult = 1, l_chips = 10, l_mult = 1, visible = true },
}

-- planet key -> hand
H.PLANETS = {
    c_pluto = 'High Card', c_mercury = 'Pair', c_uranus = 'Two Pair', c_venus = 'Three of a Kind',
    c_saturn = 'Straight', c_jupiter = 'Flush', c_earth = 'Full House', c_mars = 'Four of a Kind',
    c_neptune = 'Straight Flush', c_planet_x = 'Five of a Kind', c_ceres = 'Flush House', c_eris = 'Flush Five',
}

-- Values at a given level (vanilla level_up_hand: chips/mult grow linearly, mult >= 1, chips >= 0).
function H.values_at(name, level, base)
    local b = base or H.BASE[name]
    if not b then return 0, 1 end
    local s_chips = b.s_chips or b.chips_base or H.BASE[name] and H.BASE[name].chips or b.chips
    local s_mult = b.s_mult or b.mult_base or H.BASE[name] and H.BASE[name].mult or b.mult
    local chips = math.max(s_chips + b.l_chips * (level - 1), 0)
    local mult = math.max(s_mult + b.l_mult * (level - 1), 1)
    return chips, mult
end

-- Default per-hand table as the snapshot provides it (level 1, never played).
function H.default_table()
    local t = {}
    for _, name in ipairs(H.ORDER) do
        local b = H.BASE[name]
        t[name] = {
            level = 1, chips = b.chips, mult = b.mult, l_chips = b.l_chips, l_mult = b.l_mult,
            s_chips = b.chips, s_mult = b.mult,
            played = 0, played_this_round = 0, visible = b.visible,
        }
    end
    return t
end

function H.set_level(hands, name, level)
    local h = hands[name]
    h.level = level
    h.chips, h.mult = H.values_at(name, level, h)
    return h
end

H.RANK = {}
for i, name in ipairs(H.ORDER) do H.RANK[name] = i end

return H
