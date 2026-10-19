-- Balatro Strategic Copilot - learning/adapt.lua
-- After every run, the copilot recalculates its own settings from what went wrong (the causes
-- found by the post-run review, learning/review.lua): one bounded step per setting and per run,
-- in the direction the cause calls for; after a win every adjusted setting moves one step back
-- toward its base value (no drift on luck). The adjusted values apply on top of config.lua
-- (engine/advice.lua, engine/skip.lua) and every change is shown with its reason.
-- Pure functions on the profile table (persisted by learning/runtime.lua, local only).

local AD = {}

-- step: one adjustment; lo / hi: bounds of the total adjustment (relative to config.lua)
AD.PARAMS = {
    buy_note = { step = 1, lo = -4, hi = 3 },
    excess_note = { step = 2, lo = -8, hi = 4 },
    excess_reserve = { step = 2, lo = -5, hi = 3 },
    idle_reserve = { step = 4, lo = -12, hi = 5 },
    save_from_ante = { step = 1, lo = -1, hi = 2 },
    safe_next = { step = 0.02, lo = -0.05, hi = 0.10 },
    safe_boss = { step = 0.03, lo = -0.05, hi = 0.15 },
    skip_p_follow = { step = 0.02, lo = -0.02, hi = 0.07 },
    skip_p_boss = { step = 0.02, lo = -0.02, hi = 0.07 },
    skip_margin = { step = 2, lo = -1, hi = 6 },
    first_jokers = { step = 1, lo = 0, hi = 2 },
    replace_note = { step = 2, lo = -6, hi = 4 },
}

-- cause of a loss -> settings to move (+1 = one step up, -1 = one step down)
AD.RULES = {
    idle_money = { excess_note = -1, excess_reserve = -1, idle_reserve = -1 },
    power_drop = { excess_note = -1, buy_note = -1, save_from_ante = 1 },
    deficit = { safe_next = 1, safe_boss = 1 },
    xmult = { replace_note = -1 },
    few_jokers = { first_jokers = 1, buy_note = -1 },
    no_upgrade = { excess_note = -1, buy_note = -1 },
    economy = { buy_note = 1, save_from_ante = -1 },
    margin = { safe_next = 1, safe_boss = 1, skip_p_follow = 1, skip_p_boss = 1 },
    boss = { safe_boss = 1, skip_p_boss = 1 },
    skip_lost = { skip_margin = 1, skip_p_follow = 1, skip_p_boss = 1 },
}

AD.HISTORY_KEPT = 10

local function round_to(v, step)
    return math.floor(v / step + 0.5) * step
end

function AD.deltas(profile)
    return (profile and profile.adapt and profile.adapt.deltas) or {}
end

-- Value of a setting with the learned adjustment (clamped to the bounds).
function AD.apply(key, base, deltas)
    local p = AD.PARAMS[key]
    local d = deltas and deltas[key]
    if not p or type(base) ~= 'number' or not d or d == 0 then return base end
    return base + math.max(p.lo, math.min(p.hi, d))
end

-- Update the profile after a run. review: learning/review.lua output (causes); run: the
-- recorder's run (won). Returns the list of changes { key, from, to, causes = {...} }.
function AD.update(profile, review, run)
    if not profile then return {} end
    profile.adapt = profile.adapt or { deltas = {}, history = {} }
    local A = profile.adapt
    A.deltas = A.deltas or {}
    A.history = A.history or {}
    local run_id = run and run.id
    for _, h in ipairs(A.history) do if run_id and h.id == run_id then return h.changes or {} end end
    local won = run and run.won
    local votes, why = {}, {}
    if not won then
        for _, c in ipairs((review and review.causes) or {}) do
            local rule = AD.RULES[c.key]
            if rule then
                for k, dir in pairs(rule) do
                    votes[k] = (votes[k] or 0) + dir
                    why[k] = why[k] or {}
                    why[k][#why[k] + 1] = c.key
                end
            end
        end
    end
    local changes = {}
    for k, p in pairs(AD.PARAMS) do
        local old = A.deltas[k] or 0
        local new = old
        if won then
            -- a win: one step back toward the base value
            if old > 0 then new = math.max(0, old - p.step) elseif old < 0 then new = math.min(0, old + p.step) end
        elseif votes[k] and votes[k] ~= 0 then
            new = old + ((votes[k] > 0) and p.step or -p.step)
        end
        new = round_to(math.max(p.lo, math.min(p.hi, new)), p.step)
        if math.abs(new - old) > 1e-9 then
            A.deltas[k] = new
            changes[#changes + 1] = { key = k, from = old, to = new, causes = why[k] or {}, won = won and true or nil }
        end
    end
    table.sort(changes, function(a, b) return a.key < b.key end)
    A.history[#A.history + 1] = { id = run_id, won = won and true or false, changes = changes }
    while #A.history > AD.HISTORY_KEPT do table.remove(A.history, 1) end
    return changes
end

return AD
