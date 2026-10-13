-- Builders for synthetic game snapshots (same shape as game/state_reader.lua output).
local F = {}

function F.joker(key, ability, extra)
    local DB = BSCopilot.require('model/jokers_db')
    local U = BSCopilot.require('core/util')
    local def = DB.get(key)
    local ab = {}
    if def and def.config then ab = U.deepcopy(def.config, 10) end
    -- mimic get_default_ability_vars: Xmult -> x_mult
    if ab.Xmult then ab.x_mult = ab.Xmult end
    ab.x_mult = ab.x_mult or 1
    ab.mult = ab.mult or 0
    if ability then
        for k, v in pairs(ability) do
            if k == 'extra' and type(v) == 'table' and type(ab.extra) == 'table' then
                for k2, v2 in pairs(v) do ab.extra[k2] = v2 end
            else
                ab[k] = v
            end
        end
    end
    local j = { key = key, name = def and def.name or key, ability = ab, rarity = def and def.rarity or 1,
        blueprint_compat = def and def.bp, sell_cost = def and math.floor((def.cost or 4) / 2) or 2 }
    if extra then for k, v in pairs(extra) do j[k] = v end end
    return j
end

function F.state(o)
    o = o or {}
    local H = BSCopilot.require('model/hands')
    local hands = H.default_table()
    if o.levels then for name, lv in pairs(o.levels) do H.set_level(hands, name, lv) end end
    if o.hands_patch then for name, p in pairs(o.hands_patch) do for k, v in pairs(p) do hands[name][k] = v end end end
    local s = {
        phase = o.phase or 'hand',
        run = { ante = o.ante or 1, round = o.round_n or 1, win_ante = 8, stake = o.stake or 1, deck_key = o.deck_key or 'b_red',
            hands_played = o.hands_played or 0, skips = o.skips or 0, tarots_used = o.tarots_used or 0 },
        econ = { dollars = o.dollars or 4, interest_cap = 25, interest_amount = 1, reroll_cost = 5 },
        blind = o.blind or { key = 'bl_small', name = 'Small Blind', boss = false, chips_required = o.required or 300, chips_scored = o.scored or 0 },
        round = { hands_left = o.hands_left or 4, discards_left = o.discards_left or 3, hand_size = o.hand_size or 8 },
        hands = hands,
        jokers = o.jokers or {},
        joker_slots = o.joker_slots or 5,
        consumables = o.consumables or {},
        vouchers = o.vouchers or {},
        hand_cards = o.hand_cards or {},
        deck = o.deck or {},
        deck_count = o.deck_count or (o.deck and #o.deck) or 44,
        full_deck_stats = o.deck_stats or { size = 52, starting_size = 52, steel = 0, stone = 0, enhanced = 0, gold = 0 },
        targets = o.targets or {},
        probabilities_normal = o.prob or 1,
        flags = o.flags or {},
    }
    if s.blind.chips_required == nil then s.blind.chips_required = o.required or 300 end
    return s
end

return F
