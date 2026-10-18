local T = ...
local S = {}

function S.interest_rules(T)
    local E = BSCopilot.require('engine/economy')
    T.eq(E.interest(0), 0)
    T.eq(E.interest(4), 0)
    T.eq(E.interest(5), 1)
    T.eq(E.interest(24), 4)
    T.eq(E.interest(25), 5)
    T.eq(E.interest(100), 5)                                    -- capped at $25 -> $5
    T.eq(E.interest(100, { interest_cap = 50 }), 10)            -- Seed Money
    T.eq(E.interest(100, { interest_cap = 100 }), 20)           -- Money Tree
    T.eq(E.interest(30, { interest_amount = 2 }), 10)           -- To the Moon
    T.eq(E.interest(30, { no_interest = true }), 0)
    T.eq(E.interest(-5), 0)
end

function S.next_step_and_loss(T)
    local E = BSCopilot.require('engine/economy')
    T.eq(E.next_step(12), 15)
    T.eq(E.next_step(25), nil)
    T.eq(E.interest_loss(26, 6), 1)   -- 26 -> 20 : 5 -> 4
    T.eq(E.interest_loss(26, 1), 0)
    T.eq(E.interest_loss(10, 10), 2)
end

function S.joker_income(T)
    local E = BSCopilot.require('engine/economy')
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local s = F.state({ jokers = { F.joker('j_golden'), F.joker('j_cloud_9') }, deck_stats = { nines = 4, size = 52, starting_size = 52 } })
    local total = E.joker_income(s)
    T.eq(total, 4 + 4)
end

-- Rental sticker: $3 at the end of every round.
function S.rental_costs_money(T)
    local E = BSCopilot.require('engine/economy')
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local s = F.state({ jokers = { F.joker('j_golden'), F.joker('j_joker', nil, { rental = true }) } })
    T.eq(E.joker_income(s), 4 - 3)
end

return S
