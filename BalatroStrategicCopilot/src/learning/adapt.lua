-- Balatro Strategic Copilot - learning/adapt.lua
-- After every run, the copilot recalculates its own development from what went wrong (the causes
-- found by the post-run review, learning/review.lua), and KEEPS ONLY WHAT PAYS OFF:
--   * after a loss, ONE change is put on trial: the settings that the most frequent cause of the
--     player's losses calls for, one bounded step each (e.g. "x Mult missing" -> x Mult more
--     urgent in the shop and a joker replaced more easily);
--   * it is played for TRIAL_RUNS runs, then judged on the results (ante reached, a win counts
--     as 9) against the average of the recorded runs before it: not worse -> kept, worse ->
--     undone, and the same cause is not tried again for COOLDOWN runs;
--   * every step is shown in the review with its cause and its verdict.
-- Why trials: measured on the simulator (docs/TRAINING.md), changing the settings directly after
-- each loss made the copilot WORSE (1 win in 10 instead of 4 on the same seeds; then 6 in 20
-- instead of 9 once only the causes that separate losses from wins were used): a cause of a
-- loss is a guess about what to change, not a proof. "A hand below the blind" and "power that
-- stopped following the blinds" are in every loss and never move anything.
-- The adjusted values apply on top of config.lua (engine/advice.lua, engine/skip.lua,
-- engine/plan.lua). Pure functions on the profile table (persisted by learning/runtime.lua,
-- local only).

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
    -- weights of the plan (engine/plan.lua): x Mult urgency in the shop, planets of the main hand
    xmult_urgency = { step = 0.25, lo = 0, hi = 0.5 },
    levels_urgency = { step = 0.25, lo = 0, hi = 0.5 },
}

-- cause of a loss -> settings to move (+1 = one step up, -1 = one step down)
AD.RULES = {
    idle_money = { excess_note = -1, excess_reserve = -1, idle_reserve = -1 },
    xmult = { xmult_urgency = 1, replace_note = -1 },
    levels = { levels_urgency = 1 },
    few_jokers = { first_jokers = 1, buy_note = -1 },
    no_upgrade = { excess_note = -1, buy_note = -1 },
    economy = { buy_note = 1, save_from_ante = -1 },
    margin = { safe_next = 1, safe_boss = 1, skip_p_follow = 1, skip_p_boss = 1 },
    boss = { safe_boss = 1, skip_p_boss = 1 },
    skip_lost = { skip_margin = 1, skip_p_follow = 1, skip_p_boss = 1 },
}

AD.TRIAL_RUNS = 3      -- runs played with a change before it is judged
AD.MIN_RESULTS = 3     -- recorded runs needed before the first trial (the comparison point)
AD.COOLDOWN = 10       -- an undone change is not tried again for this many runs
AD.MIN_LOSSES = 2      -- a cause must have been seen in this many losses
AD.MIN_LIFT = 0.2      -- ... and more often in losses than in wins by this much
AD.HISTORY_KEPT = 10
AD.RESULTS_KEPT = 20

local function round_to(v, step)
    return math.floor(v / step + 0.5) * step
end

local function mean(t)
    if #t == 0 then return nil end
    local s = 0
    for _, v in ipairs(t) do s = s + v end
    return s / #t
end

-- Result of a run for the comparisons: ante reached; a win counts as 9 (ante 8 beaten).
function AD.run_score(run)
    if run and run.won then return 9 end
    return (run and (run.final_ante or run.ante)) or 1
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

-- Is this cause typical of the player's losses (and not of the wins)? stats = profile.adapt.stats
-- P(cause | loss) - P(cause | win) >= MIN_LIFT (Laplace estimates; with no win recorded,
-- P(cause | win) starts at 1/2), seen in MIN_LOSSES losses at least.
function AD.discriminates(stats, key)
    if not stats then return false end
    local c = (stats.causes or {})[key] or {}
    local L, W = stats.losses or 0, stats.wins or 0
    local lc, wc = c.loss or 0, c.win or 0
    if lc < AD.MIN_LOSSES then return false end
    return (lc + 1) / (L + 2) - (wc + 1) / (W + 2) >= AD.MIN_LIFT - 1e-9
end

-- The steps a rule would make now (nothing if every setting is already at its bound).
local function steps_of(rule, deltas)
    local steps = {}
    local keys = {}
    for k in pairs(rule) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local p = AD.PARAMS[k]
        local old = deltas[k] or 0
        local new = round_to(math.max(p.lo, math.min(p.hi, old + rule[k] * p.step)), p.step)
        if math.abs(new - old) > 1e-9 then steps[#steps + 1] = { key = k, from = old, to = new } end
    end
    return steps
end

-- Update the profile after a run. review: learning/review.lua output (causes); run: the
-- recorder's run (won, final_ante). Returns the list of changes
-- { key, from, to, causes = {...}, verdict = 'trial'|'kept'|'undone', trial_mean, base_mean }.
function AD.update(profile, review, run)
    if not profile then return {} end
    -- an abandoned run says nothing about the settings
    if run and run.end_reason == 'abandoned' then return {} end
    profile.adapt = profile.adapt or {}
    local A = profile.adapt
    A.deltas = A.deltas or {}
    A.history = A.history or {}
    A.results = A.results or {}
    A.cooldown = A.cooldown or {}
    local run_id = run and run.id
    for _, h in ipairs(A.history) do if run_id and h.id == run_id then return h.changes or {} end end
    local won = run and run.won and true or false
    local score = AD.run_score(run)

    -- causes seen in wins and in losses (each key once per run)
    A.stats = A.stats or { wins = 0, losses = 0, causes = {} }
    local st = A.stats
    st.causes = st.causes or {}
    if won then st.wins = (st.wins or 0) + 1 else st.losses = (st.losses or 0) + 1 end
    local seen, keys = {}, {}
    for _, c in ipairs((review and review.causes) or {}) do
        if c.key and not seen[c.key] then
            seen[c.key] = true
            keys[#keys + 1] = c.key
            local e = st.causes[c.key] or { win = 0, loss = 0 }
            if won then e.win = e.win + 1 else e.loss = e.loss + 1 end
            st.causes[c.key] = e
        end
    end

    local changes = {}
    -- 1. the change on trial is judged once it has been played TRIAL_RUNS times
    local tr = A.trial
    if tr then
        tr.scores = tr.scores or {}
        tr.scores[#tr.scores + 1] = score
        if #tr.scores >= AD.TRIAL_RUNS then
            local mt = mean(tr.scores)
            local keep = mt >= (tr.baseline or 0) - 1e-9
            for _, s in ipairs(tr.steps or {}) do
                if keep then
                    changes[#changes + 1] = { key = s.key, from = s.from, to = s.to, causes = { tr.cause }, verdict = 'kept',
                        trial_mean = mt, base_mean = tr.baseline }
                else
                    A.deltas[s.key] = (s.from ~= 0) and s.from or nil
                    changes[#changes + 1] = { key = s.key, from = s.to, to = s.from, causes = { tr.cause }, verdict = 'undone',
                        trial_mean = mt, base_mean = tr.baseline }
                end
            end
            if not keep then A.cooldown[tr.cause] = AD.COOLDOWN end
            A.trial = nil
        end
    end
    -- results of the recorded runs (the comparison point of the next trials)
    A.results[#A.results + 1] = score
    while #A.results > AD.RESULTS_KEPT do table.remove(A.results, 1) end
    for k, v in pairs(A.cooldown) do A.cooldown[k] = (v > 1) and (v - 1) or nil end

    -- 2. after a loss, with no change on trial: try what the most frequent cause calls for
    if not won and not A.trial and #A.results >= AD.MIN_RESULTS then
        local best, best_n, best_steps
        for _, key in ipairs(keys) do
            local rule = AD.RULES[key]
            if rule and not A.cooldown[key] and AD.discriminates(st, key) then
                local steps = steps_of(rule, A.deltas)
                local n = (st.causes[key] or {}).loss or 0
                if #steps > 0 and (not best or n > best_n) then best, best_n, best_steps = key, n, steps end
            end
        end
        if best then
            for _, s in ipairs(best_steps) do
                A.deltas[s.key] = s.to
                changes[#changes + 1] = { key = s.key, from = s.from, to = s.to, causes = { best }, verdict = 'trial' }
            end
            A.trial = { cause = best, steps = best_steps, scores = {}, baseline = mean(A.results) }
        end
    end

    A.history[#A.history + 1] = { id = run_id, won = won, changes = changes }
    while #A.history > AD.HISTORY_KEPT do table.remove(A.history, 1) end
    return changes
end

return AD
