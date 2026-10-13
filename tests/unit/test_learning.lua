-- Synthetic scenarios with known ground truth.
local T = ...
local S = {}

local function env()
    local Cal = BSCopilot.require('learning/calibration')
    local LE = BSCopilot.require('learning/learning')
    local R = BSCopilot.require('core/rng')
    return Cal, LE, R
end

-- run factory: n blinds with predicted p and outcomes
local function make_run(id, blinds, extra)
    local run = { id = id, won = false, final_ante = 3, deck = 'b_red', stake = 1, blinds = {}, hands = {}, decisions = {}, power = {}, economy = {} }
    for i, b in ipairs(blinds) do run.blinds[i] = { ante = 1, round = i, key = 'bl_small', p_pred = b[1], cleared = b[2] } end
    if extra then for k, v in pairs(extra) do run[k] = v end end
    return run
end

function S.few_observations_never_give_certainty(T)
    local Cal, LE = env()
    local p = LE.new_profile(0)
    -- three failures at p = 0.9 must not turn 0.9 into ~0
    LE.process_run(p, make_run('a', { { 0.9, false }, { 0.9, false }, { 0.9, false } }), { min_samples = 2 })
    local f = Cal.fit(p.calibration.blind.pairs)
    local v = f(0.9)
    T.ok(v > 0.6, 'shrinkage keeps the estimate far from 0: ' .. v)
    T.ok(v < 0.9, 'but moves it in the right direction')
    -- and validation refuses to enable calibration with so little data
    T.no(Cal.validate(p.calibration.blind, 30).enabled)
end

function S.calibration_corrects_overconfidence(T)
    local Cal, LE, R = env()
    local rng = R.new('cal')
    local cal = Cal.new()
    -- predictor says p, truth is 0.5 * p (overconfident)
    for i = 1, 1500 do
        local p = rng:float()
        cal.pairs[#cal.pairs + 1] = { p, rng:float() < 0.5 * p and 1 or 0, i }
    end
    local st = Cal.validate(cal, 30)
    T.ok(st.enabled, 'calibration validated on the temporal holdout')
    T.ok(st.holdout_cal_brier < st.holdout_raw_brier)
    local f = Cal.mapper(cal)
    T.near(f(0.8), 0.4, 0.08, 'calibrated 0.8 -> ~0.4')
    T.near(f(0.4), 0.2, 0.08)
    -- monotone
    local prev = -1
    for i = 0, 20 do local v = f(i / 20); T.ok(v >= prev - 1e-12); prev = v end
end

function S.well_calibrated_predictor_left_alone(T)
    local Cal, LE, R = env()
    local rng = R.new('good')
    local cal = Cal.new()
    for i = 1, 1500 do
        local p = rng:float()
        cal.pairs[#cal.pairs + 1] = { p, rng:float() < p and 1 or 0, i }
    end
    local st = Cal.validate(cal, 30)
    local m = Cal.metrics(cal.pairs)
    T.ok(m.ece < 0.05, 'measured ECE small: ' .. m.ece)
    local f = Cal.mapper(cal)
    T.near(f(0.7), 0.7, 0.08)
end

function S.metrics_known_values(T)
    local Cal = env()
    local m = Cal.metrics({ { 1, 1, 1 }, { 0, 0, 2 } })
    T.near(m.brier, 0, 1e-12)
    local m2 = Cal.metrics({ { 0.5, 1, 1 }, { 0.5, 0, 2 } })
    T.near(m2.brier, 0.25, 1e-12)
    T.near(m2.logloss, math.log(2), 1e-9)
end

function S.processing_is_idempotent(T)
    local _, LE = env()
    local p = LE.new_profile(0)
    local run = make_run('same', { { 0.8, true } }, { won = true })
    LE.process_run(p, run)
    local _, again = LE.process_run(p, run)
    T.no(again)
    T.eq(p.runs, 1); T.eq(p.wins, 1)
end

function S.defeat_is_not_a_bad_decision(T)
    local _, LE = env()
    local RV = BSCopilot.require('learning/review')
    -- every decision followed the recommendation, the boss was lost at p = 0.85
    local run = make_run('loss', { { 0.95, true }, { 0.9, true }, { 0.85, false } }, {
        decisions = {
            { kind = 'buying_card', ante = 1, round = 1, key = 'j_duo', chosen_note = 80, best_note = 80, best_key = 'j_duo', followed = true },
            { kind = 'before', ante = 1, round = 3, p_best = 0.85, p_chosen = 0.85, followed = true },
        },
        lost_to = 'bl_wall', end_reason = 'lost',
    })
    local p = LE.new_profile(0)
    LE.process_run(p, run)
    local rv = RV.build(run, p)
    T.eq(#rv.mistakes, 0, 'no mistake invented from the outcome')
    T.eq(#rv.bad_luck, 1, 'loss attributed to probable bad luck')
    T.eq(rv.result, 'loss')
end

function S.real_mistakes_are_judged_at_decision_time(T)
    local _, LE = env()
    local RV = BSCopilot.require('learning/review')
    local run = make_run('mist', { { 0.6, true } }, {
        won = true,
        decisions = {
            { kind = 'buying_card', ante = 2, round = 4, key = 'j_credit_card', chosen_note = 40, best_note = 78, best_key = 'j_duo' },
            { kind = 'before', ante = 2, round = 4, p_best = 0.9, p_chosen = 0.5 },
            { kind = 'reroll_shop', ante = 2, round = 4, followed = false },
            { kind = 'reroll_shop', ante = 2, round = 4, followed = false },
        },
    })
    local rv = RV.build(run, LE.new_profile(0))
    T.eq(#rv.mistakes, 3, 'shop gap, risky play, useless rerolls')
    -- winning does not erase mistakes either
    T.eq(rv.result, 'win')
end

function S.positive_results_do_not_validate_strategy(T)
    local _, LE = env()
    local p = LE.new_profile(0)
    -- two decisions followed, both cleared: interval must stay very wide
    local run = make_run('two', { { 0.5, true }, { 0.5, true } }, { decisions = {
        { kind = 'before', ante = 1, round = 1, followed = true }, { kind = 'before', ante = 1, round = 2, followed = true } } })
    LE.process_run(p, run)
    local sm = LE.summary(p)
    T.ok(sm.followed.n == 2)
    T.ok(sm.followed.hi - sm.followed.lo > 0.5, 'wide interval with 2 samples')
    local tr = LE.trend(p)
    T.no(tr.enough, 'no trend claimed with few runs')
end

function S.growth_and_contributions_learned(T)
    local _, LE = env()
    local p = LE.new_profile(0)
    local run = make_run('g', { { 0.7, true } }, {
        power = { { ante = 1, median = 100 }, { ante = 2, median = 250 }, { ante = 3, median = 500 } },
        hands = { { predicted = 100, actual = 100, exact = true, contributions = { j_joker = 0.4 } },
                  { predicted = 200, actual = 220, exact = false, contributions = { j_joker = 0.2 } },
                  { predicted = 100, actual = 150, unknown = { 'j_modded' } } },
    })
    LE.process_run(p, run)
    T.eq(p.growth.n, 2)
    T.near(p.growth.sum_log, math.log(2.5) + math.log(2), 1e-9)
    T.eq(p.jokers.j_joker.n, 2); T.near(p.jokers.j_joker.sum, 0.6, 1e-9)
    T.eq(p.score_pred.exact_n, 1); T.eq(p.score_pred.exact_mismatch, 0)
    local mult, n = LE.unknown_multiplier(p, 'j_modded')
    T.eq(n, 1)
    T.ok(mult > 1 and mult < 1.1, 'one observation barely moves the learned multiplier: ' .. mult)
end

function S.exact_mismatch_reported(T)
    local _, LE = env()
    local p = LE.new_profile(0)
    LE.process_run(p, make_run('mm', {}, { hands = { { predicted = 100, actual = 130, exact = true, hand = 'Pair' } } }))
    T.eq(p.score_pred.exact_mismatch, 1)
    T.eq(#p.score_pred.mismatches, 1)
end

function S.profile_persists_across_restart(T)
    local _, LE = env()
    local P = BSCopilot.require('io/persistence')
    local J = BSCopilot.require('core/json')
    local be = P.memory_backend()
    local st = P.new(be); st:init()
    local p = LE.new_profile(0)
    for i = 1, 40 do LE.process_run(p, make_run('r' .. i, { { 0.7, i % 3 ~= 0 } })) end
    T.ok(st:save('profile', LE.SCHEMA, p))
    -- "restart": new store instance on the same files
    local p2 = P.new(be):load('profile', LE.SCHEMA, function() return LE.new_profile(0) end, LE.migrations)
    T.eq(p2.runs, 40)
    T.eq(#p2.calibration.blind.pairs, 40)
    T.ok(p2.processed.r7)
    -- processing again after restart stays idempotent
    local _, again = LE.process_run(p2, make_run('r7', { { 0.7, true } }))
    T.no(again)
end

function S.profile_migration_v1(T)
    local _, LE = env()
    local old = { schema = 1, runs = 5, wins = 1, processed = {}, by_context = {}, antes = { sum = 10, max = 4 },
        calibration = { blind = { pairs = {}, status = {} } }, score_pred = { n = 0, exact_n = 0, exact_mismatch = 0, sum_rel_err = 0, sum_rel_err_sq = 0, mismatches = {} },
        growth = { n = 0, sum_log = 0, sum_log2 = 0 }, jokers = {}, decisions = { followed = { n = 0, ok = 0 }, deviated = { n = 0, ok = 0 }, by_danger = {} } }
    local new = LE.migrations[1](old)
    T.eq(new.schema, 2); T.ok(new.calibration.hand); T.ok(new.unknown_jokers); T.eq(new.runs, 5)
end

return S
