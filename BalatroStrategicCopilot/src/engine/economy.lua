-- Balatro Strategic Copilot - engine/economy.lua
-- Money rules (vanilla): interest = interest_amount * min(floor(dollars/5), cap/5),
-- end-of-round income (blind reward, $ per remaining hand, interest, joker income),
-- and the opportunity cost of spending.

local BSC = BSCopilot
local U = BSC.require('core/util')

local E = {}

function E.interest(dollars, econ)
    econ = econ or {}
    if econ.no_interest then return 0 end
    local cap = econ.interest_cap or 25
    local amount = econ.interest_amount or 1
    local d = math.max(0, dollars or 0)
    return amount * math.min(math.floor(d / 5), math.floor(cap / 5))
end

-- Next interest step: dollars needed for +1 interest (nil if at cap).
function E.next_step(dollars, econ)
    econ = econ or {}
    local cap = econ.interest_cap or 25
    local d = math.max(0, dollars or 0)
    if d >= cap then return nil end
    return (math.floor(d / 5) + 1) * 5
end

-- Interest lost next round if `cost` is spent now.
function E.interest_loss(dollars, cost, econ)
    return E.interest(dollars, econ) - E.interest((dollars or 0) - (cost or 0), econ)
end

-- Joker income per round (only deterministic or expected parts; documented heuristics).
function E.joker_income(state)
    local total = 0
    local parts = {}
    local stats = state.full_deck_stats or {}
    for _, j in ipairs(state.jokers or {}) do
        if not j.debuff then
            local ex = j.ability and j.ability.extra
            local v = 0
            if j.key == 'j_golden' then v = U.num(ex, 4)
            elseif j.key == 'j_cloud_9' then v = U.num(ex, 1) * (stats.nines or 0)
            elseif j.key == 'j_rocket' then v = type(ex) == 'table' and U.num(ex.dollars, 1) or 1
            elseif j.key == 'j_satellite' then v = U.num(ex, 1) * (state.run and state.run.planet_types_used or 0)
            elseif j.key == 'j_delayed_grat' then v = U.num(ex, 2) * ((state.round and state.round.round_discards) or 3) * 0.5
            elseif j.key == 'j_egg' then v = U.num(ex, 3) -- sell value growth
            elseif j.key == 'j_gift' then v = U.num(ex, 1) * #(state.jokers or {}) -- sell value growth (all jokers)
            end
            if v ~= 0 then total = total + v; parts[#parts + 1] = { key = j.key, name = j.name, value = v } end
        end
        -- rental sticker: $3 at the end of each round, even when debuffed
        if j.rental then
            total = total - 3
            parts[#parts + 1] = { key = j.key, name = j.name, value = -3, rental = true }
        end
    end
    return total, parts
end

-- Expected money at the end of the current/next round (rough, documented).
-- reward: blind reward; hands_left: hands expected to remain.
function E.end_of_round(state, opts)
    opts = opts or {}
    local econ = state.econ or {}
    local d = (opts.dollars ~= nil) and opts.dollars or (econ.dollars or 0)
    local reward = opts.reward or 4
    local hands_left = opts.hands_left or 1
    local per_hand = econ.money_per_hand or 1
    local jinc = E.joker_income(state)
    local gold = (state.full_deck_stats and state.full_deck_stats.gold or 0) * 3 * (opts.gold_held_ratio or 0.3)
    local interest = E.interest(d, econ)
    return d + reward + hands_left * per_hand + interest + jinc + gold, interest
end

-- Value of keeping money (in "$ per remaining round of the ante"): interest preserved
-- plus the option value of future purchases (simple, documented heuristic).
function E.money_value(dollars, cost, econ, rounds)
    rounds = rounds or 2
    local loss = E.interest_loss(dollars, cost, econ) * rounds
    return loss
end

return E
