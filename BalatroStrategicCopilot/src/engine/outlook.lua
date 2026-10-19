-- Balatro Strategic Copilot - engine/outlook.lua
-- Blind selection analysis: next blind and boss (full round rollouts), run outlook,
-- skip-or-play advice (tag value vs lost reward and shop), joker contributions and order.

local BSC = BSCopilot
local U = BSC.require('core/util')
local BL = BSC.require('model/blinds_db')
local ST = BSC.require('engine/strategy')
local SY = BSC.require('engine/synergy')
local E = BSC.require('engine/economy')
local SK = BSC.require('engine/skip')
local PL = BSC.require('engine/plan')

local O = {}

-- Tag value in $ equivalents (engine/skip.lua; kept for callers of the old API).
function O.tag_value(key, state)
    return (SK.tag_value(key, state or {}, {}))
end

local function noop() end

function O.analyse(state, opts, task)
    opts = opts or {}
    local check = (task and task.check) or noop
    local publish = (task and task.publish) or noop
    local res = { blinds = {} }
    local current, boss
    for _, b in ipairs(state.upcoming or {}) do
        if b.state ~= 'Defeated' and b.state ~= 'Skipped' then
            if not current then current = b end
            if b.boss then boss = b end
        end
    end
    res.current, res.boss = current, boss
    local ps = ST.power_samples(state, { n = opts.samples or 64, seed = 'outlook', task = task, keep_plays = true })
    res.power = { mean = ps.mean, median = ps.median, q25 = ps.q25, q75 = ps.q75, usage = ST.usage_fractions(ps) }
    res.coverage = ps.coverage
    publish(res)
    if current then
        local p, lo, hi = ST.p_clear_rollouts(state, current.chips, { n = opts.rollouts or 48, task = task,
            boss = current.boss and current.key or nil, seed = 'next' })
        if opts.calibrate then p = opts.calibrate(p) end
        res.p_current = { p = p, lo = lo, hi = hi, n = opts.rollouts or 48, method = 'monte_carlo' }
        local h = (state.round and state.round.round_hands) or 4
        res.needed_per_hand = current.chips / math.max(1, h)
        publish(res)
    end
    if boss and boss ~= current then
        local p, lo, hi = ST.p_clear_rollouts(state, boss.chips, { n = opts.rollouts or 48, task = task, boss = boss.key, seed = 'boss' })
        if opts.calibrate then p = opts.calibrate(p) end
        res.p_boss = { p = p, lo = lo, hi = hi, n = opts.rollouts or 48, method = 'monte_carlo' }
    elseif boss then
        res.p_boss = res.p_current
    end
    res.boss_info = boss and BL.get(boss.key) or nil
    res.outlook = ST.run_outlook(state, ps, { profile = opts.profile, calibrate = opts.calibrate })
    res.danger = ST.danger(res.p_current and res.p_current.p, res.p_boss and res.p_boss.p)
    publish(res)

    -- skip advice (only for Small/Big blinds): engine/skip.lua
    if current and not current.boss then
        local following
        for _, b in ipairs(state.upcoming or {}) do
            if b ~= current and b.state ~= 'Defeated' and b.state ~= 'Skipped' then following = b; break end
        end
        -- the blind that follows, played with the current deck: full round rollouts (with
        -- discards, like the real play; the quick bootstrap of typical hands, without discards,
        -- was far too pessimistic: 0.7-0.8 for an ante 1 Big Blind the copilot's play won 28
        -- times out of 28, docs/TRAINING.md)
        local p_follow = 1
        if following and following.boss and res.p_boss then p_follow = res.p_boss.p
        elseif following then
            p_follow = ST.p_clear_rollouts(state, following.chips, { n = opts.rollouts or 48, task = task,
                boss = following.boss and following.key or nil, seed = 'follow' })
            if opts.calibrate then p_follow = opts.calibrate(p_follow) end
        end
        local tag = state.blind_tags and state.blind_tags[current.slot]
        local p_generic
        if tag == 'tag_boss' and boss then
            -- an ordinary boss of the same size, to see what rerolling this one would bring
            p_generic = ST.p_clear_rollouts(state, boss.chips, { n = 24, task = task, seed = 'generic' })
            if opts.calibrate then p_generic = opts.calibrate(p_generic) end
        end
        local plan = PL.analyse(state, { p_next = res.p_current and res.p_current.p, p_boss = res.p_boss and res.p_boss.p, median = ps.median })
        res.plan = plan
        res.skip = SK.evaluate(state, { current = current, following = following, p_following = p_follow,
            p_boss = res.p_boss and res.p_boss.p, p_boss_generic = p_generic, median = ps.median,
            usage = res.power.usage, plan = plan, boss = boss,
            orbital_hand = state.orbital_hands and state.orbital_hands[current.slot] }, opts.cfg)
    end
    check()
    res.contributions = SY.contributions(state, ps, task)
    res.order = SY.best_order(state, ps, task)
    res.active_synergies = SY.active(state, ps)
    local dollars = (state.econ and state.econ.dollars) or 0
    res.interest = { now = E.interest(dollars, state.econ), next_step = E.next_step(dollars, state.econ) }
    return res
end

return O
