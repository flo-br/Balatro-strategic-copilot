-- Balatro Strategic Copilot - learning/learning.lua  (LearningEngine)
-- Pure functions: raw run logs (recorder) -> learned statistics (profile).
-- Methods (deliberately simple, see docs/LEARNING.md):
--   * calibration of blind/hand win probabilities (learning/calibration.lua, validated in time);
--   * Beta-Binomial counts with credible intervals (win rates, decision follow-up);
--   * power growth per ante (geometric mean, shrunk toward a prior in strategy.lua);
--   * measured joker contributions (mean share of the score, with counts);
--   * residual multiplier of unknown (modded) jokers: actual / predicted score;
--   * score prediction accuracy (exact predictions must match; others: relative error).
-- A decision is never judged by its outcome: outcomes only feed aggregated statistics that are
-- stratified by danger, reported with intervals, and never used to flip a single estimate.

local BSC = BSCopilot
local U = BSC.require('core/util')
local Cal = BSC.require('learning/calibration')
local PR = BSC.require('engine/probability')

local LE = {}
LE.SCHEMA = 2

function LE.new_profile(now)
    return {
        schema = LE.SCHEMA, created_at = now or 0, updated_at = now or 0,
        runs = 0, wins = 0, processed = {}, by_context = {},
        antes = { sum = 0, max = 0 },
        calibration = { blind = Cal.new(), hand = Cal.new() },
        score_pred = { n = 0, exact_n = 0, exact_mismatch = 0, sum_rel_err = 0, sum_rel_err_sq = 0, mismatches = {} },
        growth = { n = 0, sum_log = 0, sum_log2 = 0 },
        jokers = {},
        unknown_jokers = {},
        decisions = { followed = { n = 0, ok = 0 }, deviated = { n = 0, ok = 0 }, by_danger = {} },
        weights = nil,
        history = {},           -- compact per-run summaries (kept forever, small)
    }
end

-- migrations[v] : profile schema v -> v + 1
LE.migrations = {
    [1] = function(p)
        p.unknown_jokers = p.unknown_jokers or {}
        p.history = p.history or {}
        p.calibration = p.calibration or { blind = Cal.new(), hand = Cal.new() }
        p.calibration.hand = p.calibration.hand or Cal.new()
        p.schema = 2
        return p
    end,
}

local function bucket(danger)
    if danger == nil then return 'unknown' end
    if danger >= 0.5 then return 'high' end
    if danger >= 0.2 then return 'mid' end
    return 'low'
end

-- Outcome helpers -----------------------------------------------------------------------------
local function next_blind_outcome(run, ante, round)
    for _, b in ipairs(run.blinds or {}) do
        if (b.ante or 0) > ante or ((b.ante or 0) == ante and (b.round or 0) >= (round or 0)) then
            if b.cleared ~= nil then return b.cleared end
        end
    end
    return nil
end

-- Process one completed (or abandoned) run. Idempotent: a run id is only counted once.
function LE.process_run(profile, run, opts)
    opts = opts or {}
    if not run or not run.id then return profile, false end
    if profile.processed[run.id] then return profile, false end
    profile.processed[run.id] = true
    profile.runs = profile.runs + 1
    if run.won then profile.wins = profile.wins + 1 end
    local ctx = tostring(run.deck or '?') .. '|' .. tostring(run.stake or '?')
    local c = profile.by_context[ctx] or { runs = 0, wins = 0, ante_sum = 0 }
    c.runs = c.runs + 1
    if run.won then c.wins = c.wins + 1 end
    c.ante_sum = c.ante_sum + (run.final_ante or 0)
    profile.by_context[ctx] = c
    profile.antes.sum = profile.antes.sum + (run.final_ante or 0)
    profile.antes.max = math.max(profile.antes.max, run.final_ante or 0)

    -- calibration pairs
    local seq = profile.calibration.seq or 0
    for _, b in ipairs(run.blinds or {}) do
        if b.p_pred and b.cleared ~= nil then
            seq = seq + 1
            Cal.add(profile.calibration.blind, b.p_pred, b.cleared, seq)
        end
    end
    for _, h in ipairs(run.hands or {}) do
        if h.p_clear_before and h.blind_cleared ~= nil then
            seq = seq + 1
            Cal.add(profile.calibration.hand, h.p_clear_before, h.blind_cleared, seq)
        end
    end
    profile.calibration.seq = seq
    local min_s = opts.min_samples or 30
    Cal.validate(profile.calibration.blind, min_s)
    Cal.validate(profile.calibration.hand, min_s)

    -- score predictions
    local sp = profile.score_pred
    for _, h in ipairs(run.hands or {}) do
        if h.predicted and h.actual then
            sp.n = sp.n + 1
            local err = (h.actual > 0) and math.abs(h.predicted - h.actual) / h.actual or (h.predicted > 0 and 1 or 0)
            sp.sum_rel_err = sp.sum_rel_err + err
            sp.sum_rel_err_sq = sp.sum_rel_err_sq + err * err
            if h.exact then
                sp.exact_n = sp.exact_n + 1
                if math.abs(h.predicted - h.actual) > 0.5 then
                    sp.exact_mismatch = sp.exact_mismatch + 1
                    if #sp.mismatches < 50 then
                        sp.mismatches[#sp.mismatches + 1] = { hand = h.hand, predicted = h.predicted, actual = h.actual, jokers = h.jokers }
                    end
                end
            end
        end
        -- unknown jokers: residual ratio actual / predicted (only when everything else is known)
        if h.unknown and #h.unknown == 1 and h.predicted and h.predicted > 0 and h.actual and h.actual > 0 then
            local k = h.unknown[1]
            local u = profile.unknown_jokers[k] or { n = 0, sum_log = 0 }
            u.n = u.n + 1
            u.sum_log = u.sum_log + math.log(h.actual / h.predicted)
            profile.unknown_jokers[k] = u
        end
        -- measured joker contributions
        for key, share in pairs(h.contributions or {}) do
            local js = profile.jokers[key] or { n = 0, sum = 0, sum2 = 0, runs = 0, wins = 0, last_run = nil }
            js.n = js.n + 1
            js.sum = js.sum + share
            js.sum2 = js.sum2 + share * share
            if js.last_run ~= run.id then
                js.runs = js.runs + 1
                if run.won then js.wins = js.wins + 1 end
                js.last_run = run.id
            end
            profile.jokers[key] = js
        end
    end

    -- power growth per ante
    local by_ante = {}
    for _, pw in ipairs(run.power or {}) do
        if pw.ante and pw.median and pw.median > 0 then by_ante[pw.ante] = pw.median end
    end
    local antes = {}
    for a in pairs(by_ante) do antes[#antes + 1] = a end
    table.sort(antes)
    for i = 2, #antes do
        local a0, a1 = antes[i - 1], antes[i]
        if a1 == a0 + 1 then
            local g = math.log(by_ante[a1] / by_ante[a0])
            profile.growth.n = profile.growth.n + 1
            profile.growth.sum_log = profile.growth.sum_log + g
            profile.growth.sum_log2 = profile.growth.sum_log2 + g * g
        end
    end

    -- decisions vs recommendations (descriptive, stratified by danger)
    for _, d in ipairs(run.decisions or {}) do
        if d.followed ~= nil then
            local outcome = next_blind_outcome(run, d.ante or 0, d.round or 0)
            if outcome ~= nil then
                local grp = d.followed and profile.decisions.followed or profile.decisions.deviated
                grp.n = grp.n + 1
                if outcome then grp.ok = grp.ok + 1 end
                local b = bucket(d.danger)
                local bd = profile.decisions.by_danger[b] or { followed = { n = 0, ok = 0 }, deviated = { n = 0, ok = 0 } }
                local g2 = d.followed and bd.followed or bd.deviated
                g2.n = g2.n + 1
                if outcome then g2.ok = g2.ok + 1 end
                profile.decisions.by_danger[b] = bd
            end
        end
    end

    -- compact history (kept even when raw logs are pruned)
    local hist = profile.history
    hist[#hist + 1] = { id = run.id, won = run.won and true or false, ante = run.final_ante, deck = run.deck, stake = run.stake,
        t = run.ended_at, brier = LE.run_brier(run) }
    while #hist > 2000 do table.remove(hist, 1) end
    profile.updated_at = opts.now or profile.updated_at
    return profile, true
end

-- Causes found by the post-run review of the last losses (learning/review.lua). When the same
-- cause keeps coming back, the plan gives it more weight (bounded: x1 to x1.5).
LE.LESSONS_KEPT = 10
function LE.add_lessons(profile, keys, run_id)
    profile.lessons = profile.lessons or { recent = {} }
    local L = profile.lessons
    for _, r in ipairs(L.recent) do if r.id == run_id then return false end end
    L.recent[#L.recent + 1] = { id = run_id, keys = keys or {} }
    while #L.recent > LE.LESSONS_KEPT do table.remove(L.recent, 1) end
    return true
end

function LE.lesson_weight(profile, key)
    local L = profile and profile.lessons
    if not L or #L.recent == 0 then return 1 end
    local n = 0
    for _, r in ipairs(L.recent) do
        for _, k in ipairs(r.keys) do if k == key then n = n + 1; break end end
    end
    return 1 + 0.5 * n / #L.recent
end

function LE.run_brier(run)
    local s, n = 0, 0
    for _, b in ipairs(run.blinds or {}) do
        if b.p_pred and b.cleared ~= nil then s = s + (b.p_pred - (b.cleared and 1 or 0)) ^ 2; n = n + 1 end
    end
    return n > 0 and s / n or nil
end

function LE.calibrator(profile, kind)
    local cal = profile and profile.calibration and profile.calibration[kind or 'blind']
    return Cal.mapper(cal)
end

-- Learned multiplier for an unknown joker (shrunk toward 1 with 10 pseudo-observations).
function LE.unknown_multiplier(profile, key)
    local u = profile and profile.unknown_jokers and profile.unknown_jokers[key]
    if not u or u.n == 0 then return nil end
    local k = 10
    return math.exp(u.sum_log / (u.n + k)), u.n
end

-- Summary for UI / review.
function LE.summary(profile)
    if not profile or profile.runs == 0 then return { runs = 0 } end
    local p, lo, hi = PR.wilson(profile.wins, profile.runs)
    local cal = profile.calibration.blind
    local st = cal.status or {}
    local sp = profile.score_pred
    local function rate(g) if g.n == 0 then return nil end local r, l, h = PR.wilson(g.ok, g.n) return { p = r, lo = l, hi = h, n = g.n } end
    return {
        runs = profile.runs, wins = profile.wins, win_rate = p, win_lo = lo, win_hi = hi,
        mean_ante = profile.antes.sum / profile.runs, max_ante = profile.antes.max,
        calibration = { enabled = st.enabled, n = st.n or #cal.pairs, brier = st.overall and st.overall.brier,
            ece = st.overall and st.overall.ece, reason = st.reason, holdout_raw = st.holdout_raw_brier, holdout_cal = st.holdout_cal_brier },
        score = { n = sp.n, mean_rel_err = sp.n > 0 and sp.sum_rel_err / sp.n or nil, exact_n = sp.exact_n,
            exact_mismatch = sp.exact_mismatch },
        followed = rate(profile.decisions.followed), deviated = rate(profile.decisions.deviated),
        growth_n = profile.growth.n,
    }
end

-- Recent vs older comparison (temporal split) of win rate and calibration: objective evaluation
-- of whether things improve, with intervals (no claim when intervals overlap).
function LE.trend(profile)
    local h = profile and profile.history or {}
    local n = #h
    if n < 20 then return { enough = false, n = n } end
    local half = math.floor(n / 2)
    local function stats(from, to)
        local w, ante, b, bn = 0, 0, 0, 0
        for i = from, to do
            if h[i].won then w = w + 1 end
            ante = ante + (h[i].ante or 0)
            if h[i].brier then b = b + h[i].brier; bn = bn + 1 end
        end
        local cnt = to - from + 1
        local p, lo, hi = PR.wilson(w, cnt)
        return { n = cnt, win = p, lo = lo, hi = hi, ante = ante / cnt, brier = bn > 0 and b / bn or nil }
    end
    local old, new = stats(1, half), stats(half + 1, n)
    local significant = new.lo > old.hi or new.hi < old.lo
    return { enough = true, old = old, new = new, significant = significant }
end

return LE
