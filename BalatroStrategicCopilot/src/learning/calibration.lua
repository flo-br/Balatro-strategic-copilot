-- Balatro Strategic Copilot - learning/calibration.lua
-- Calibration of predicted probabilities against observed outcomes.
--   * reliability table (10 bins), Brier score, log loss, expected calibration error (ECE);
--   * Bayesian bin calibration: each bin's calibrated value is the posterior mean of a Beta
--     prior centred on the bin's own mean prediction (strength K), so a handful of outcomes
--     can never make a probability certain; values are then made monotone (pool adjacent
--     violators) and interpolated;
--   * temporal validation: fitted on the oldest 75 % of the pairs, evaluated on the newest
--     25 %; the calibration is applied only if it improves the holdout Brier score and the
--     sample is large enough.

local Cal = {}

Cal.BINS = 10
Cal.PRIOR_K = 10
Cal.MAX_PAIRS = 2000

local function clamp01(p) if p < 0 then return 0 end if p > 1 then return 1 end return p end

function Cal.new()
    return { pairs = {}, status = { enabled = false } }
end

-- Add an observation (p predicted, y in {0,1}, t sequence/time).
function Cal.add(cal, p, y, t)
    if type(p) ~= 'number' or p ~= p then return end
    cal.pairs[#cal.pairs + 1] = { clamp01(p), y and 1 or 0, t or #cal.pairs }
    while #cal.pairs > Cal.MAX_PAIRS do table.remove(cal.pairs, 1) end
end

function Cal.metrics(pairs, f)
    f = f or function(p) return p end
    local n = #pairs
    if n == 0 then return { n = 0 } end
    local brier, logloss = 0, 0
    local bins = {}
    for b = 1, Cal.BINS do bins[b] = { n = 0, sum_p = 0, hits = 0 } end
    for _, pr in ipairs(pairs) do
        local p = clamp01(f(pr[1]))
        local y = pr[2]
        brier = brier + (p - y) ^ 2
        local pe = math.min(math.max(p, 1e-4), 1 - 1e-4)
        logloss = logloss - (y * math.log(pe) + (1 - y) * math.log(1 - pe))
        local b = math.min(Cal.BINS, math.floor(p * Cal.BINS) + 1)
        bins[b].n = bins[b].n + 1
        bins[b].sum_p = bins[b].sum_p + p
        bins[b].hits = bins[b].hits + y
    end
    local ece = 0
    for _, bin in ipairs(bins) do
        if bin.n > 0 then ece = ece + bin.n / n * math.abs(bin.sum_p / bin.n - bin.hits / bin.n) end
    end
    return { n = n, brier = brier / n, logloss = logloss / n, ece = ece, bins = bins }
end

-- Fit a monotone Bayesian bin map from pairs; returns a function p -> calibrated p.
function Cal.fit(pairs)
    local bins = {}
    for b = 1, Cal.BINS do bins[b] = { n = 0, sum_p = 0, hits = 0 } end
    for _, pr in ipairs(pairs) do
        local b = math.min(Cal.BINS, math.floor(pr[1] * Cal.BINS) + 1)
        bins[b].n = bins[b].n + 1
        bins[b].sum_p = bins[b].sum_p + pr[1]
        bins[b].hits = bins[b].hits + pr[2]
    end
    local centres, values, weights = {}, {}, {}
    for b = 1, Cal.BINS do
        local bin = bins[b]
        local centre = (b - 0.5) / Cal.BINS
        local mean_p = bin.n > 0 and bin.sum_p / bin.n or centre
        local k = Cal.PRIOR_K
        local post = (bin.hits + k * mean_p) / (bin.n + k)
        centres[b] = mean_p
        values[b] = post
        weights[b] = bin.n + k
    end
    -- pool adjacent violators (monotone non-decreasing)
    local blocks = {}
    for b = 1, Cal.BINS do
        blocks[#blocks + 1] = { v = values[b], w = weights[b], from = b, to = b }
        while #blocks >= 2 and blocks[#blocks - 1].v > blocks[#blocks].v do
            local a, c = blocks[#blocks - 1], blocks[#blocks]
            local w = a.w + c.w
            blocks[#blocks - 1] = { v = (a.v * a.w + c.v * c.w) / w, w = w, from = a.from, to = c.to }
            blocks[#blocks] = nil
        end
    end
    for _, bl in ipairs(blocks) do for b = bl.from, bl.to do values[b] = bl.v end end
    return function(p)
        p = clamp01(p)
        if p <= centres[1] then
            -- interpolate towards (0,0)
            return values[1] * (centres[1] > 0 and p / centres[1] or 1)
        end
        for b = 1, Cal.BINS - 1 do
            if p <= centres[b + 1] then
                local span = centres[b + 1] - centres[b]
                local w = span > 0 and (p - centres[b]) / span or 0
                return clamp01(values[b] + w * (values[b + 1] - values[b]))
            end
        end
        local last = Cal.BINS
        return clamp01(values[last] + (p - centres[last]) / math.max(1e-9, 1 - centres[last]) * (1 - values[last]))
    end, { centres = centres, values = values }
end

-- Temporal validation; updates cal.status and returns it.
function Cal.validate(cal, min_samples)
    min_samples = min_samples or 30
    local pairs = cal.pairs
    local n = #pairs
    local st = { enabled = false, n = n }
    if n < min_samples then
        st.reason = 'insufficient_data'
        cal.status = st
        return st
    end
    local sorted = {}
    for i, pr in ipairs(pairs) do sorted[i] = pr end
    table.sort(sorted, function(a, b) return a[3] < b[3] end)
    local cut = math.floor(n * 0.75)
    local train, test = {}, {}
    for i, pr in ipairs(sorted) do if i <= cut then train[#train + 1] = pr else test[#test + 1] = pr end end
    local f = Cal.fit(train)
    local raw = Cal.metrics(test)
    local calm = Cal.metrics(test, f)
    st.holdout_raw_brier, st.holdout_cal_brier = raw.brier, calm.brier
    st.holdout_raw_ece, st.holdout_cal_ece = raw.ece, calm.ece
    st.enabled = calm.brier < raw.brier - 0.002
    st.reason = st.enabled and 'improves_holdout' or 'no_holdout_gain'
    st.overall = Cal.metrics(pairs)
    cal.status = st
    return st
end

-- Function to apply (identity unless validated), fitted on all pairs.
function Cal.mapper(cal)
    if not cal or not cal.status or not cal.status.enabled then return function(p) return p end end
    local f = Cal.fit(cal.pairs)
    return f
end

return Cal
