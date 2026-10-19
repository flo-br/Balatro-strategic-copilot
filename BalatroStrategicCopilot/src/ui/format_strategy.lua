-- Balatro Strategic Copilot - ui/format_strategy.lua
-- Panels for the shop, blind selection, booster packs and end of round (pure, testable).

local BSC = BSCopilot
local U = BSC.require('core/util')
local I = BSC.require('core/i18n')
local Fmt = BSC.require('ui/format')
local BL = BSC.require('model/blinds_db')

local FS = {}
local T = I.T
local SK = BSC.require('engine/skip')

local function seg(t, c) return { t = t, c = c or 'text' } end
local function line(...) return { ... } end

local function signed_pct(d)
    if d == nil then return '' end
    local v = math.floor(d * 100 + (d >= 0 and 0.5 or -0.5))
    if v == 0 then return '±0 pt' end
    return (v > 0 and '+' or '') .. v .. ' pts'
end
FS.signed_pct = signed_pct

local function prob_line(label, p, extra, lo, hi, method)
    local cls = Fmt.class_prob(p)
    return line(seg(Fmt.mark(cls) .. ' ', cls), seg(label .. ' : ' .. Fmt.prob_text(p, method or 'monte_carlo', lo, hi), cls),
        seg(extra and ('  ' .. extra) or '', 'dim'))
end

local function posture(danger)
    if danger == nil then return nil end
    if danger >= 0.5 then return 'critique : priorité à la survie', 'bad' end
    if danger >= 0.2 then return 'tendue : renforcer le score', 'mid' end
    return 'confortable : investir (économie, progression)', 'good'
end

local function outlook_lines(lines, r)
    if r.p_win ~= nil then
        if r.endless then
            lines[#lines + 1] = line(seg(string.format('Progression attendue : ~%.1f blindes (confiance limitée)', r.expected_blinds or 0), 'dim'))
        else
            local cls = Fmt.class_prob(r.p_win)
            -- model estimate: never displayed as certain
            local pw = math.max(0.001, math.min(0.999, r.p_win))
            lines[#lines + 1] = line(seg(Fmt.mark(cls) .. ' ', cls), seg(T('win_run', I.pct(pw)), cls),
                seg('  (confiance ' .. T('conf_low') .. ', croissance ×' .. string.format('%.1f', r.growth or 2) .. '/ante ' ..
                    (r.growth_source == 'learned' and 'apprise' or 'a priori') .. ')', 'dim'))
        end
    end
end

-- Shop ----------------------------------------------------------------------------------------
local KIND_LABEL = { joker = 'Joker', planet = 'Planète', tarot = 'Tarot', spectral = 'Spectrale', voucher = 'Bon',
    booster = 'Paquet', card = 'Carte', replace = 'Joker' }

function FS.option_line(o)
    local cls = Fmt.class_note(o.note)
    local name = o.name or o.key or '?'
    local action = (o.kind == 'replace') and ('Remplacer ' .. tostring(o.replaces) .. ' par ' .. name) or (T('buy_label') .. ' ' .. name)
    local l = line(seg(Fmt.mark(cls) .. ' ' .. T('shop_note', o.note or '?') .. ' ', cls),
        seg(action, o.affordable == false and 'dim' or 'text'),
        seg(string.format(' (%d $)', o.cost or 0), 'money'))
    return l
end

function FS.option_detail(o)
    local parts = {}
    if o.d_boss then parts[#parts + 1] = 'boss ' .. signed_pct(o.d_boss) end
    if o.d_next then parts[#parts + 1] = 'blinde ' .. signed_pct(o.d_next) end
    if o.ratio and o.ratio ~= 1 then parts[#parts + 1] = string.format('puissance ×%.2f', o.ratio) end
    if o.method == 'heuristic' then parts[#parts + 1] = T('method_heuristic') end
    if o.method == 'simulation_approx' then parts[#parts + 1] = 'simulation approchée' end
    if o.interest_loss and o.interest_loss > 0 then parts[#parts + 1] = '-' .. o.interest_loss .. ' $ intérêts' end
    local out = { line(seg('    ' .. table.concat(parts, ' · '), 'dim')) }
    if o.reasons and #o.reasons > 0 then
        out[#out + 1] = line(seg('    + ' .. table.concat(o.reasons, ', '), 'good'))
    end
    if o.risks and #o.risks > 0 then
        out[#out + 1] = line(seg('    ! ' .. table.concat(o.risks, ', '), 'mid'))
    end
    return out
end

-- Plan lines: main hand and its level, multipliers present / expected, what is missing.
function FS.plan_lines(plan, state)
    local out = {}
    if not plan then return out end
    local parts = {}
    if plan.main_hand then
        local h = state and state.hands and state.hands[plan.main_hand]
        parts[#parts + 1] = T('plan_main', I.hand_name(plan.main_hand), h and h.level or 1)
    end
    parts[#parts + 1] = T('plan_xmult', plan.xmult or 0, plan.xmult_target or 0)
    local l = line(seg(T('plan_title'), 'title'), seg(table.concat(parts, ' · '), 'text'))
    out[#out + 1] = l
    local gaps = {}
    local g = plan.gaps or {}
    if g.scoring then gaps[#gaps + 1] = T('plan_gap_scoring') end
    if g.xmult then gaps[#gaps + 1] = T('plan_gap_xmult') end
    if plan.falling_behind then gaps[#gaps + 1] = T('plan_gap_behind', U.fmt_num(plan.base_chips or 0)) end
    if g.scaling then gaps[#gaps + 1] = T('plan_gap_scaling') end
    if g.economy then gaps[#gaps + 1] = T('plan_gap_economy') end
    if #gaps > 0 then out[#out + 1] = line(seg('  ' .. T('plan_missing') .. table.concat(gaps, ', '), 'mid')) end
    -- the most advanced build of top players under way (engine/builds.lua)
    local b = plan.builds and plan.builds[1]
    if b then
        out[#out + 1] = line(seg('  ' .. T('plan_build', b.name), 'accent'),
            seg((#b.missing > 0) and ('  ' .. T('plan_build_missing', table.concat(b.missing, ', '))) or '', 'dim'))
        if b.tip then out[#out + 1] = line(seg('    ' .. b.tip, 'dim')) end
    end
    return out
end

function FS.shop_panel(state, r, detail)
    local lines = {}
    if not r or not r.base then lines[#lines + 1] = line(seg(T('computing'), 'dim')); return lines end
    local b = r.base
    if r.next_blind and b.p_next then
        lines[#lines + 1] = prob_line('Victoire prochaine blinde', b.p_next, U.fmt_num(r.next_blind.chips) .. ' requis', b.p_next_lo, b.p_next_hi)
    end
    if r.boss and b.p_boss then
        lines[#lines + 1] = prob_line('Victoire boss ' .. tostring(r.boss.name or ''), b.p_boss, '', b.p_boss_lo, b.p_boss_hi)
    end
    outlook_lines(lines, b)
    lines[#lines + 1] = line(seg(T('build_power', U.fmt_num(b.median or b.mean or 0)) .. ' (médiane, simulation)', 'chips'))
    local pt, pc = posture(r.danger)
    if pt then lines[#lines + 1] = line(seg('Situation ' .. pt, pc)) end
    -- the run's plan (engine/plan.lua): what the shop should bring
    for _, l in ipairs(FS.plan_lines(r.plan, state)) do lines[#lines + 1] = l end
    -- the ante's boss is known from the start of the ante: what it demands
    local BL = BSC.require('model/blinds_db')
    local prep = r.boss and r.boss.key and BL.PREP[r.boss.key]
    if prep then lines[#lines + 1] = line(seg(T('boss_prep', tostring(r.boss.name or r.boss.key)), 'title'), seg(prep, 'mid')) end
    -- options
    local shown = 0
    for _, o in ipairs(r.options or {}) do
        if shown >= (detail and 5 or 3) then break end
        lines[#lines + 1] = FS.option_line(o)
        if detail then for _, d in ipairs(FS.option_detail(o)) do lines[#lines + 1] = d end end
        shown = shown + 1
    end
    if #(r.options or {}) > 0 and (r.options[1].note or 0) < 50 then
        lines[#lines + 1] = line(seg('→ ' .. T('shop_keep_money'), 'good'))
    end
    -- reroll
    if r.reroll then
        local rr = r.reroll
        local verdict = rr.worth and T('reroll_ok') or T('reroll_ko')
        lines[#lines + 1] = line(seg(T('shop_reroll', rr.cost, verdict), rr.worth and 'good' or 'mid'),
            seg(string.format('  (%s d\'amélioration, n=%d)', I.pct(rr.p_improve), rr.n or 0), 'dim'))
    end
    -- sells
    if r.sells and r.sells[1] and r.sells[1].note >= 58 then
        local s = r.sells[1]
        lines[#lines + 1] = line(seg(T('sell', s.name, s.sell), 'accent'),
            seg(string.format('  (score sans lui : -%s)', I.pct(math.max(0, s.contribution or 0))), 'dim'))
    end
    -- order
    if r.order and r.order.gain and r.order.gain >= 0.05 then
        lines[#lines + 1] = line(seg(T('joker_order_suggest', table.concat(r.order.names, ', ')), 'accent'),
            seg(string.format(' (+%d %%)', math.floor(r.order.gain * 100 + 0.5)), 'good'))
    end
    -- interest
    if r.interest then
        lines[#lines + 1] = line(seg(T('interest', r.interest.now, r.interest.next_step or '-'), 'money'))
    end
    if r.coverage and #(r.coverage.unsupported or {}) > 0 then
        lines[#lines + 1] = line(seg(T('coverage_partial', table.concat(r.coverage.unsupported, ', ')), 'bad'))
    end
    return lines
end

function FS.shop_badges(r)
    local out = {}
    if not r or not r.options then return out end
    for _, o in ipairs(r.options) do
        if o.uid and o.note then
            local cls = Fmt.class_note(o.note)
            out[o.uid] = { text = o.note .. '/100 ' .. Fmt.mark(cls), class = cls }
        end
    end
    for _, s in ipairs(r.sells or {}) do
        if s.uid and s.note >= 58 then out[s.uid] = { text = 'Vendre ? ' .. s.note .. '/100', class = 'mid' } end
    end
    return out
end

-- Blind selection -------------------------------------------------------------------------------
function FS.blind_panel(state, r, detail)
    local lines = {}
    if not r then lines[#lines + 1] = line(seg(T('computing'), 'dim')); return lines end
    if r.current then
        lines[#lines + 1] = line(seg(T('next_blind', r.current.name or r.current.key or '?', U.fmt_num(r.current.chips)), 'text'))
        if r.p_current then
            lines[#lines + 1] = prob_line('Victoire blinde', r.p_current.p, Fmt.method_text('monte_carlo', r.p_current.n), r.p_current.lo, r.p_current.hi)
        else
            lines[#lines + 1] = line(seg(T('computing'), 'dim'))
        end
        if r.needed_per_hand then
            lines[#lines + 1] = line(seg(T('needed_per_hand', U.fmt_num(r.needed_per_hand)), 'dim'),
                seg('   ' .. T('build_power', U.fmt_num(r.power and r.power.median or 0)), 'chips'))
        end
    end
    if r.boss and r.boss ~= r.current then
        lines[#lines + 1] = line(seg(T('boss_upcoming', r.boss.name or r.boss.key or '?') .. ' (' .. U.fmt_num(r.boss.chips) .. ')', 'title'))
        if r.p_boss then lines[#lines + 1] = prob_line('Victoire boss', r.p_boss.p, '', r.p_boss.lo, r.p_boss.hi) end
    end
    if r.boss_info and r.boss_info.effect then
        local fx = I.T('boss_effects')
        local txt = (type(fx) == 'table' and fx[r.boss_info.effect]) or r.boss_info.effect
        if r.boss_info.suit then txt = txt .. ' (' .. I.suit_name(r.boss_info.suit) .. ')' end
        lines[#lines + 1] = line(seg('  effet : ' .. txt, 'dim'))
    end
    if r.outlook then outlook_lines(lines, { p_win = r.outlook.p_win, endless = r.outlook.endless, expected_blinds = r.outlook.expected_blinds,
        growth = r.outlook.growth, growth_source = r.outlook.growth_source }) end
    local pt, pc = posture(r.danger)
    if pt then lines[#lines + 1] = line(seg('Situation ' .. pt, pc)) end
    if r.skip and r.skip.tag then
        local s = r.skip
        local function d(x) return math.floor((x or 0) + 0.5) end
        lines[#lines + 1] = line(seg(T(s.recommended and 'skip_verdict_yes' or 'skip_verdict_no'), s.recommended and 'good' or 'mid'))
        lines[#lines + 1] = line(seg('  ' .. T('skip_tag_line', SK.tag_name(state, r.current and r.current.slot, s.tag), d(s.tag_value)), 'text'),
            seg('  ' .. T(s.value_why or 'tag_unknown', s.value_detail or ''), 'dim'))
        local p = s.parts or {}
        local list = {}
        for _, k in ipairs({ 'reward', 'hands', 'interest', 'jokers', 'shop', 'growth', 'throwback', 'pillar' }) do
            if p[k] and math.abs(p[k]) >= 0.5 then list[#list + 1] = T('skip_part_' .. k, d(p[k])) end
        end
        lines[#lines + 1] = line(seg('  ' .. T('skip_cost_line', d(s.lost), table.concat(list, ', ')), 'dim'))
        if s.p_following then
            lines[#lines + 1] = line(seg('  ' .. T('skip_follow_line', T(s.following_is_boss and 'skip_follow_boss' or 'skip_follow_big'),
                I.pct(math.max(0.001, math.min(0.999, s.p_following))), I.pct(s.p_needed or 0)), 'dim'))
        end
    end
    if detail and r.contributions and #r.contributions > 0 then
        lines[#lines + 1] = line(seg('Contribution mesurée (score sans le joker)', 'title'))
        for _, c in ipairs(r.contributions) do
            local drop = math.max(0, c.share or 0)
            lines[#lines + 1] = line(seg('  ' .. tostring(c.name) .. ' : ', 'text'), seg('-' .. I.pct(drop), drop > 0.05 and 'chips' or 'dim'))
        end
    end
    if r.order and r.order.gain and r.order.gain >= 0.05 then
        lines[#lines + 1] = line(seg(T('joker_order_suggest', table.concat(r.order.names, ', ')), 'accent'),
            seg(string.format(' (+%d %%)', math.floor(r.order.gain * 100 + 0.5)), 'good'))
    end
    return lines
end

-- Packs -------------------------------------------------------------------------------------------
function FS.pack_panel(state, r, detail)
    local lines = {}
    if not r or not r.options then lines[#lines + 1] = line(seg(T('computing'), 'dim')); return lines end
    local best = r.options[1]
    if best and (best.note or 0) >= 45 then
        lines[#lines + 1] = line(seg(T('pack_pick', best.name or best.key or '?'), Fmt.class_note(best.note)),
            seg('  ' .. best.note .. '/100', 'dim'))
    else
        lines[#lines + 1] = line(seg(T('pack_skip'), 'mid'))
    end
    for i = 2, math.min(4, #r.options) do
        local o = r.options[i]
        lines[#lines + 1] = line(seg('  ' .. (o.name or o.key or '?') .. ' ' .. (o.note or '?') .. '/100', 'dim'))
    end
    if detail and best then for _, d in ipairs(FS.option_detail(best)) do lines[#lines + 1] = d end end
    return lines
end

-- End of round ----------------------------------------------------------------------------------
function FS.round_panel(state, r)
    local lines = {}
    local econ = state.econ or {}
    local E = BSC.require('engine/economy')
    lines[#lines + 1] = line(seg(T('interest', E.interest(econ.dollars or 0, econ), E.next_step(econ.dollars or 0, econ) or '-'), 'money'))
    return lines
end

return FS
