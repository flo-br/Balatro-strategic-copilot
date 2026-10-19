-- Balatro Strategic Copilot - game/register_strategy.lua
-- Registers the strategic analyses (shop, blind selection, packs, end of round) on the
-- controller, and raises alerts from their results.

local BSC = BSCopilot
local I = BSC.require('core/i18n')
local L = BSC.require('core/log')
local SH = BSC.require('engine/shop')
local O = BSC.require('engine/outlook')
local FS = BSC.require('ui/format_strategy')
local Fmt = BSC.require('ui/format')

local RS = {}

local function learning() return BSC.learning_runtime end

local function model_opts(c)
    local lr = learning()
    return {
        profile = lr and lr.profile and lr.profile(),
        calibrate = lr and lr.calibrator and lr.calibrator('blind'),
        weights = lr and lr.weights and lr.weights(),
    }
end

function RS.attach(Ctl)
    Ctl.register('shop', function(state, task, c)
        local o = model_opts(c)
        o.n = math.max(24, math.floor((c.compute.shop_samples or 120) / 2.5))
        o.publish = task.publish
        return SH.analyse(state, o, task)
    end, FS.shop_panel, FS.shop_badges)

    Ctl.register('blind_select', function(state, task, c)
        local o = model_opts(c)
        o.samples = c.compute.shop_samples and math.floor(c.compute.shop_samples / 2) or 60
        o.rollouts = math.max(24, math.floor((c.compute.rollouts or 64) * 0.75))
        o.cfg = c
        return O.analyse(state, o, task)
    end, FS.blind_panel, nil)

    Ctl.register('pack', function(state, task, c)
        local o = model_opts(c)
        o.n = 32
        o.pack_items = (state.pack and state.pack.cards) or {}
        o.publish = task.publish
        return SH.analyse(state, o, task)
    end, FS.pack_panel, FS.shop_badges)

    Ctl.register('round_eval', function(state) return { econ = state.econ } end, FS.round_panel, nil)

    -- alerts from completed analyses
    Ctl.on(function(kind, data)
        if kind ~= 'analysis' then return end
        local c = BSC.config or {}
        local a = c.alerts or {}
        local r = data.result
        if data.phase == 'shop' and r then
            local best = r.options and r.options[1]
            if best and best.affordable and (best.note or 0) >= (a.great_buy_note or 80) then
                Ctl.alert('buy:' .. tostring(best.uid), I.T('alert_great_buy', best.name or best.key or '?'), 'good')
            end
            if r.order and r.order.gain and r.order.gain >= (a.joker_order_gain or 0.1) then
                Ctl.alert('order', I.T('alert_joker_order', math.floor(r.order.gain * 100 + 0.5)), 'mid')
            end
            local p = r.base and (r.base.p_boss or r.base.p_next)
            if p and p < (a.danger_threshold or 0.5) then
                Ctl.alert('danger:shop', I.T('alert_danger', I.pct(1 - p)), 'bad')
            end
        elseif data.phase == 'blind_select' and r then
            local p = r.p_current and r.p_current.p
            if p and p < (a.danger_threshold or 0.5) then
                Ctl.alert('danger:blind', I.T('alert_danger', I.pct(1 - p)), 'bad')
            end
        end
        if r and r.coverage and r.coverage.unsupported and #r.coverage.unsupported > 0 then
            Ctl.alert('compat', I.T('alert_compat') .. ' : ' .. table.concat(r.coverage.unsupported, ', '), 'mid')
        end
    end)

    -- alerts on player actions (after the fact, informative only)
    local reroll_streak = 0
    Ctl.on(function(kind, ev)
        if kind ~= 'event' then return end
        local r = Ctl.results.shop
        if ev.kind == 'reroll_shop' then
            reroll_streak = reroll_streak + 1
            if r and r.reroll and not r.reroll.worth and reroll_streak >= 2 then
                Ctl.alert('reroll', I.T('alert_bad_reroll'), 'mid')
            end
        elseif ev.kind == 'buying_card' then
            reroll_streak = 0
            if r and r.interest and r.danger and r.danger < 0.2 then
                for _, o in ipairs(r.options or {}) do
                    if o.uid == ev.uid and (o.interest_loss or 0) >= 2 and (o.note or 50) < 55 then
                        Ctl.alert('econ', I.T('alert_economy'), 'mid')
                    end
                end
            end
        elseif ev.kind == 'ending_shop' then
            reroll_streak = 0
        end
    end)
    return true
end

return RS
