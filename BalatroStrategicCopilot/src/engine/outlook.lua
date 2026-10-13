-- Balatro Strategic Copilot - engine/outlook.lua
-- Blind selection analysis: next blind and boss (full round rollouts), run outlook,
-- skip-or-play advice (tag value vs lost reward and shop), joker contributions and order.

local BSC = BSCopilot
local U = BSC.require('core/util')
local BL = BSC.require('model/blinds_db')
local ST = BSC.require('engine/strategy')
local SY = BSC.require('engine/synergy')
local E = BSC.require('engine/economy')

local O = {}

-- Heuristic tag values in dollars-equivalent (documented in docs/MATHS.md).
O.TAG_VALUES = {
    tag_uncommon = 5, tag_rare = 8, tag_negative = 10, tag_foil = 4, tag_holo = 5, tag_polychrome = 7,
    tag_investment = 15, tag_voucher = 9, tag_boss = 3, tag_standard = 3, tag_charm = 6, tag_meteor = 6,
    tag_buffoon = 7, tag_handy = 4, tag_garbage = 3, tag_ethereal = 5, tag_coupon = 6, tag_double = 4,
    tag_juggle = 2, tag_d_six = 4, tag_top_up = 5, tag_skip = 5, tag_orbital = 8, tag_economy = 0,
}

function O.tag_value(key, state)
    if key == 'tag_economy' then return math.min(40, (state.econ and state.econ.dollars) or 0) end
    return O.TAG_VALUES[key] or 4
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

    -- skip advice (only for Small/Big blinds)
    if current and not current.boss then
        local tag = state.blind_tags and state.blind_tags[current.slot]
        local tag_v = tag and O.tag_value(tag, state) or 0
        local lost = (current.reward or 3) + 2 -- reward + money for remaining hands (approx.)
        -- risk: the following blind is played without this round's shop and money
        local following
        for _, b in ipairs(state.upcoming or {}) do
            if b ~= current and b.state ~= 'Defeated' and b.state ~= 'Skipped' then following = b; break end
        end
        local p_follow = following and ST.p_clear_bootstrap(ps, following.chips, { seed = 'follow', B = 300 }) or 1
        if opts.calibrate then p_follow = opts.calibrate(p_follow) end
        local ok = (tag_v - lost) > 0 and p_follow >= 0.85
        res.skip = { tag = tag, tag_value = tag_v, lost = lost, p_following = p_follow, recommended = ok, method = 'heuristic' }
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
