local T = ...
local S = {}

local function env()
    local AD = BSCopilot.require('learning/adapt')
    local LE = BSCopilot.require('learning/learning')
    return AD, LE
end

local function review(...)
    local causes = {}
    for i, k in ipairs({ ... }) do causes[i] = { key = k, text = k } end
    return { causes = causes, result = 'loss' }
end

local function loss(id, ante) return { id = id, won = false, final_ante = ante or 5 } end
local function win(id) return { id = id, won = true, final_ante = 8 } end

function S.a_change_is_tried_only_after_a_repeated_cause(T)
    local AD, LE = env()
    local prof = LE.new_profile(0)
    -- "hand below the blind" and "power drop" are in every loss: they have no rule
    T.eq(AD.RULES.deficit, nil); T.eq(AD.RULES.power_drop, nil)
    -- one loss is not a pattern, and 3 runs are needed as a comparison point
    T.eq(#AD.update(prof, review('few_jokers', 'deficit', 'power_drop'), loss('r1')), 0)
    T.eq(#AD.update(prof, review('few_jokers', 'deficit', 'power_drop'), loss('r2')), 0, 'no comparison point yet')
    -- the cause keeps coming back in the losses: ONE change on trial
    local ch = AD.update(prof, review('few_jokers', 'deficit', 'power_drop'), loss('r3'))
    T.ok(#ch >= 1 and ch[1].verdict == 'trial', 'on trial')
    local d = AD.deltas(prof)
    T.eq(d.first_jokers, 1); T.eq(d.buy_note, -1)
    T.eq(d.safe_next, nil); T.eq(d.save_from_ante, nil)
    T.ok(prof.adapt.trial and prof.adapt.trial.cause == 'few_jokers')
    -- the same run is never counted twice
    AD.update(prof, review('few_jokers'), loss('r3'))
    T.eq(#prof.adapt.trial.scores, 0)
    -- an abandoned run says nothing
    T.eq(#AD.update(prof, review('few_jokers'), { id = 'ab', won = false, final_ante = 1, end_reason = 'abandoned' }), 0)
    T.eq(#prof.adapt.trial.scores, 0)
end

function S.a_trial_is_kept_only_if_the_results_are_not_worse(T)
    local AD, LE = env()
    -- results before the trial: ante 5, 5, 5 -> the trial must do at least as well
    local function start(prof)
        AD.update(prof, review('few_jokers'), loss('a1', 5))
        AD.update(prof, review('few_jokers'), loss('a2', 5))
        AD.update(prof, review('few_jokers'), loss('a3', 5))
        return prof.adapt.trial
    end
    local good = LE.new_profile(0)
    T.ok(start(good), 'trial started')
    AD.update(good, review(), win('g1'))
    AD.update(good, review(), loss('g2', 6))
    local ch = AD.update(good, review(), loss('g3', 6))
    T.eq(ch[1].verdict, 'kept')
    T.eq(AD.deltas(good).first_jokers, 1, 'kept')
    T.eq(good.adapt.trial, nil)
    local bad = LE.new_profile(0)
    start(bad)
    AD.update(bad, review(), loss('b1', 3))
    AD.update(bad, review(), loss('b2', 2))
    ch = AD.update(bad, review('few_jokers'), loss('b3', 3))
    T.eq(ch[1].verdict, 'undone')
    T.eq(AD.deltas(bad).first_jokers, nil, 'back to config.lua')
    T.ok(bad.adapt.cooldown.few_jokers, 'not tried again for a while')
    -- the next loss with the same cause does not start the same trial again
    AD.update(bad, review('few_jokers'), loss('b4', 3))
    T.eq(bad.adapt.trial, nil)
end

function S.bounds_are_never_crossed(T)
    local AD, LE = env()
    local prof = LE.new_profile(0)
    for i = 1, 60 do AD.update(prof, review('idle_money'), loss('r' .. i, 5)) end
    T.ok(AD.deltas(prof).excess_note >= AD.PARAMS.excess_note.lo, 'never below the bound')
    T.ok(#prof.adapt.history <= AD.HISTORY_KEPT)
    T.ok(#prof.adapt.results <= AD.RESULTS_KEPT)
end

function S.adjustments_apply_to_the_advice_and_skips(T)
    local AD, LE = env()
    local A = BSCopilot.require('engine/advice')
    local cfg = { advice = { excess_note = 54 }, adapt_deltas = { excess_note = -4, first_jokers = 1, skip_margin = 2 } }
    local st = A.settings(cfg)
    T.eq(st.excess_note, 50)
    T.eq(st.first_jokers, 4)
    T.eq(st.buy_note, 56, 'untouched settings keep config.lua')
    local SK = BSCopilot.require('engine/skip')
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local s = F.state({ dollars = 4 })
    s.blind_tags = { Small = 'tag_investment', Big = 'tag_rare' }
    local r = SK.evaluate(s, { current = { slot = 'Small', reward = 3, chips = 300 }, p_following = 0.97, p_boss = 0.95,
        median = 200, plan = { gaps = {} } }, cfg)
    T.ok(r.margin ~= nil)
    -- the plan's x Mult urgency follows the trial (engine/plan.lua)
    local PL = BSCopilot.require('engine/plan')
    BSCopilot.learning_runtime = { adapt_deltas = function() return { xmult_urgency = 0.25 } end }
    T.near(PL.lesson('xmult'), 1.25, 1e-9)
    BSCopilot.learning_runtime = nil
    T.eq(PL.lesson('xmult'), 1)
    -- the review shows what changed, why, and the verdict
    local RV = BSCopilot.require('learning/review')
    local txt = RV.adapt_text({ key = 'excess_note', from = 0, to = -2, causes = { 'idle_money' }, verdict = 'trial' })
    T.ok(txt:find('argent dormant', 1, true) and txt:find('-2', 1, true) and txt:find('essai', 1, true), txt)
    txt = RV.adapt_text({ key = 'excess_note', from = -2, to = 0, causes = { 'idle_money' }, verdict = 'undone', trial_mean = 4.3, base_mean = 5.7 })
    T.ok(txt:find('annulé', 1, true) and txt:find('4,3', 1, true) and txt:find('5,7', 1, true), txt)
end

return S
