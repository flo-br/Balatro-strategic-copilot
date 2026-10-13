local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    local Score = BSCopilot.require('engine/score')
    local DB = BSCopilot.require('model/jokers_db')
    return F, C, Score, DB
end

local function score(o, played, held)
    local F, C, Score = env()
    local p = type(played) == 'string' and C.parse_list(played) or played
    local h = type(held) == 'string' and C.parse_list(held) or (held or {})
    return Score.evaluate(F.state(o), p, h).mean
end

local function with(key, ability, o)
    local F = env()
    o = o or {}
    o.jokers = { F.joker(key, ability) }
    return o
end

function S.database_has_150_vanilla_jokers(T)
    local _, _, _, DB = env()
    T.eq(#DB.all_keys(), 150)
    for _, k in ipairs(DB.all_keys()) do
        local d = DB.get(k)
        T.ok(d.name and d.rarity and d.cost, k)
        T.eq(DB.get(nil, d.name), d, 'lookup by name ' .. d.name)
    end
end

function S.rank_jokers(T)
    -- Pair of 8s (Fibonacci +8 each): 10+16 = 26 x (2+16) = 468
    T.eq(score(with('j_fibonacci'), '8s 8h'), 468)
    -- Even Steven on 8s: +4 each -> 26 x 10 = 260 ; Odd Todd on 9s: +31 each -> (10+18+62) x 2 = 180
    T.eq(score(with('j_even_steven'), '8s 8h'), 260)
    T.eq(score(with('j_odd_todd'), '9s 9h'), 180)
    -- Scholar on Aces: +20 chips +4 mult each -> (32+40) x 10 = 720
    T.eq(score(with('j_scholar'), 'As Ah'), 720)
    -- Walkie Talkie on 4s: (10+8+20) x (2+8) = 380
    T.eq(score(with('j_walkie_talkie'), '4s 4h'), 380)
    -- Triboulet on Kings: x2 x2 -> 30 x 8 = 240
    T.eq(score(with('j_triboulet'), 'Ks Kh'), 240)
end

function S.suit_jokers(T)
    -- Greedy on two diamonds (pair): 10+22 = 32 x (2+6) = 256
    T.eq(score(with('j_greedy_joker'), 'Ad Ad'), 256)
    -- Smeared Joker makes hearts count as diamonds
    local F = env()
    T.eq(score({ jokers = { F.joker('j_greedy_joker'), F.joker('j_smeared') } }, 'Ah Ad'), 256)
    -- Arrowhead +50 per spade, Onyx +7 mult per club
    T.eq(score(with('j_arrowhead'), 'As Ah'), (32 + 50) * 2)
    T.eq(score(with('j_onyx_agate'), 'Ac Ah'), 32 * 9)
    -- Wild card counts as every suit for suit jokers
    local _, C = env()
    local wild = C.parse('Ah', { enh = 'm_wild' })
    T.eq(score(with('j_arrowhead'), { wild, C.parse('Ad') }), (32 + 50) * 2)
    -- Ancient Joker on the current suit
    T.eq(score(with('j_ancient', nil, { targets = { ancient_suit = 'Spades' } }), 'As Ah'), 32 * 3)
    -- The Idol needs rank AND suit
    T.eq(score(with('j_idol', nil, { targets = { idol = { id = 14, suit = 'Spades' } } }), 'As Ah'), 32 * 4)
end

function S.hand_type_jokers(T)
    -- Jolly (+8 on Pair) also triggers on Full House (contains a Pair)
    T.eq(score(with('j_jolly'), 'As Ah'), 32 * 10)
    T.eq(score(with('j_jolly'), 'As Ah Ad Ks Kh'), (40 + 11 * 3 + 20) * 12)
    T.eq(score(with('j_sly'), 'As Ah'), (32 + 50) * 2)
    -- The Duo x2 on Pair; The Tribe needs a Flush
    T.eq(score(with('j_duo'), 'As Ah'), 32 * 4)
    T.eq(score(with('j_tribe'), 'As Ah'), 64)
    T.eq(score(with('j_half'), 'As Ah 2c'), 32 * 22)
    T.eq(score(with('j_half'), 'As Ah 2c 3d'), 64)
end

function S.state_jokers(T)
    -- Banner: 30 chips per discard left (3) ; Mystic Summit only with 0 discards
    T.eq(score(with('j_banner'), 'As Ah'), (32 + 90) * 2)
    T.eq(score(with('j_mystic_summit', nil, { discards_left = 0 }), 'As Ah'), 32 * 17)
    T.eq(score(with('j_mystic_summit', nil, { discards_left = 1 }), 'As Ah'), 64)
    -- Blue Joker: 2 per card left in deck (44) ; Abstract: 3 per joker
    T.eq(score(with('j_blue_joker', nil, { deck_count = 44 }), 'As Ah'), (32 + 88) * 2)
    T.eq(score(with('j_abstract'), 'As Ah'), 32 * 5)
    -- Erosion: 4 mult per card under starting size (52 -> 48)
    T.eq(score(with('j_erosion', nil, { deck_stats = { size = 48, starting_size = 52 } }), 'As Ah'), 32 * 18)
    -- Steel Joker: 1 + 0.2 * 5 steel = x2 ; Stone Joker: 25 per stone (2)
    T.eq(score(with('j_steel_joker', nil, { deck_stats = { steel = 5, size = 52, starting_size = 52 } }), 'As Ah'), 128)
    T.eq(score(with('j_stone', nil, { deck_stats = { stone = 2, size = 52, starting_size = 52 } }), 'As Ah'), (32 + 50) * 2)
    -- Driver's License needs 16 enhanced cards
    T.eq(score(with('j_drivers_license', nil, { deck_stats = { enhanced = 16, size = 52, starting_size = 52 } }), 'As Ah'), 192)
    T.eq(score(with('j_drivers_license', nil, { deck_stats = { enhanced = 15, size = 52, starting_size = 52 } }), 'As Ah'), 64)
    -- Bootstraps: +2 mult per $5 ($23 -> 4) ; Bull: 2 chips per $
    T.eq(score(with('j_bootstraps', nil, { dollars = 23 }), 'As Ah'), 32 * 10)
    T.eq(score(with('j_bull', nil, { dollars = 0 }), 'As Ah'), 64)
    -- Fortune Teller: +1 per tarot used ; Throwback: +0.25x per skip
    T.eq(score(with('j_fortune_teller', nil, { tarots_used = 6 }), 'As Ah'), 32 * 8)
    T.eq(score(with('j_throwback', nil, { skips = 4 }), 'As Ah'), 128)
end

function S.scaling_jokers_read_current_values(T)
    T.eq(score(with('j_green_joker', { mult = 5 }), 'As Ah'), 32 * (2 + 6))   -- +1 before scoring
    T.eq(score(with('j_runner', { extra = { chips = 30 } }), '9s Th Jd Qc Kh'), (30 + 49 + 45) * 4) -- Straight -> +15
    T.eq(score(with('j_square', { extra = { chips = 8 } }), 'As Ah 2c 3d'), (32 + 12) * 2)  -- 4 cards -> +4
    T.eq(score(with('j_trousers', { mult = 4 }), 'As Ah Kc Kd'), (20 + 42) * (2 + 6))      -- Two Pair -> +2
    T.eq(score(with('j_constellation', { x_mult = 1.5 }), 'As Ah'), 96)
    T.eq(score(with('j_ice_cream', { extra = { chips = 60 } }), 'As Ah'), (32 + 60) * 2)
    T.eq(score(with('j_caino', { caino_xmult = 3 }), 'As Ah'), 192)
    T.eq(score(with('j_yorick', { x_mult = 2 }), 'As Ah'), 128)
    T.eq(score(with('j_popcorn', { mult = 12 }), 'As Ah'), 32 * 14)
    T.eq(score(with('j_ceremonial', { mult = 0 }), 'As Ah'), 64)
end

function S.loyalty_card_cycle(T)
    -- every = 5 -> triggers on the 6th hand after creation (hands_played - created = 5)
    T.eq(score(with('j_loyalty_card', { hands_played_at_create = 0 }, { hands_played = 5 }), 'As Ah'), 256)
    T.eq(score(with('j_loyalty_card', { hands_played_at_create = 0 }, { hands_played = 4 }), 'As Ah'), 64)
    T.eq(score(with('j_loyalty_card', { hands_played_at_create = 0 }, { hands_played = 11 }), 'As Ah'), 256)
end

function S.held_jokers(T)
    -- Shoot the Moon: +13 per Queen held ; Blackboard: x3 if all held are spades/clubs
    T.eq(score(with('j_shoot_the_moon'), 'As Ah', 'Qs Qd 2c'), 32 * 28)
    T.eq(score(with('j_blackboard'), 'As Ah', 'Qs 2c'), 192)
    T.eq(score(with('j_blackboard'), 'As Ah', 'Qs 2d'), 64)
    T.eq(score(with('j_blackboard'), 'As Ah', ''), 192) -- empty hand: vanilla condition holds
end

function S.money_jokers(T)
    local F, C, Score = env()
    local s = F.state(with('j_ticket'))
    local r = Score.evaluate(s, { C.parse('As', { enh = 'm_gold' }) }, {})
    T.eq(r.dollars, 4)
    s = F.state(with('j_rough_gem'))
    r = Score.evaluate(s, C.parse_list('Ad Ah'), {})
    T.eq(r.dollars, 1)
    s = F.state(with('j_business'))
    r = Score.evaluate(s, C.parse_list('Kd Kh'), {})
    T.near(r.dollars, 2, 1e-9) -- two faces, 1/2 chance each, $2 each
    s = F.state(with('j_todo_list', { extra = { poker_hand = 'Pair' } }))
    r = Score.evaluate(s, C.parse_list('Kd Kh'), {})
    T.eq(r.dollars, 4)
end

function S.lucky_cat_gains_on_lucky_trigger(T)
    local F, C, Score = env()
    local s = F.state(with('j_lucky_cat', { x_mult = 2 }))
    local r = Score.evaluate(s, { C.parse('As', { enh = 'm_lucky' }) }, {})
    -- outcomes: mult hit (1/5) and/or money hit (1/15): a trigger raises the cat to x2.25
    T.ok(r.max >= math.floor(16 * 21 * 2.25))
    T.eq(r.min, 32)
end

function S.bloodstone_two_hearts(T)
    local F, C, Score = env()
    local s = F.state(with('j_bloodstone'))
    local r = Score.evaluate(s, C.parse_list('Ah Kh'), {})
    -- High card (Ah) only: one heart scored, 1/2 chance x1.5 -> 16 or 24
    T.near(r.mean, 0.5 * 16 + 0.5 * 24, 1e-9)
end

function S.all_jokers_survive_fuzzing(T)
    local F, C, Score, DB = env()
    local R = BSCopilot.require('core/rng')
    local rng = R.new('fuzz')
    local deck = C.standard_deck()
    local enh = { nil, 'm_bonus', 'm_mult', 'm_wild', 'm_glass', 'm_steel', 'm_stone', 'm_gold', 'm_lucky' }
    local keys = DB.all_keys()
    for round = 1, 40 do
        local jokers = {}
        for _ = 1, 5 do jokers[#jokers + 1] = F.joker(keys[rng:int(1, #keys)]) end
        local cards = rng:sample(deck, 8)
        local copies = {}
        for i, c in ipairs(cards) do
            local cc = C.copy(c)
            cc.uid = 1000 + i
            local e = enh[rng:int(1, #enh)]
            if e then C.set_enhancement(cc, e) end
            if rng:chance(0.2) then cc.seal = ({ 'Red', 'Gold', 'Blue', 'Purple' })[rng:int(1, 4)] end
            if rng:chance(0.2) then cc.edition = ({ 'e_foil', 'e_holo', 'e_polychrome' })[rng:int(1, 3)] end
            copies[i] = cc
        end
        local n = rng:int(1, 5)
        local played, held = {}, {}
        for i = 1, 8 do if i <= n then played[#played + 1] = copies[i] else held[#held + 1] = copies[i] end end
        local s = F.state({ jokers = jokers, dollars = rng:int(0, 30), targets = { ancient_suit = 'Hearts', idol = { id = 14, suit = 'Spades' } } })
        local ok, r = pcall(Score.evaluate, s, played, held, { max_branches = 64, samples = 50 })
        T.ok(ok, 'round ' .. round .. ': ' .. tostring(r))
        T.ok(r.mean >= 0 and r.mean == r.mean, 'finite score')
    end
end

return S
