-- Balatro Strategic Copilot - engine/plan.lua
-- The run's game plan, as top players reason about it (docs/PRO_LESSONS.md): blind sizes grow
-- about x2.5 per ante, +Chips and +Mult add up linearly, so a build only keeps up with
-- MULTIPLIERS (xMult jokers, Polychrome, Steel / Glass cards) and with jokers that grow.
-- From the state, this module tells
--   * the main hand (most played, or highest level) the planets should feed;
--   * the xMult sources on the board versus the number expected at this ante;
--   * the gaps the shop should fill first ('xmult', 'scaling', 'power', 'economy');
--   * the phase of the run (early: ante 1-2, mid: 3-5, late: 6+).
-- Pure function of the state: no randomness, no game access.

local BSC = BSCopilot
local DB = BSC.require('model/jokers_db')
local H = BSC.require('model/hands')
local BL = BSC.require('model/blinds_db')

local PL = {}

-- xMult sources expected on the board at each ante (top players' consensus, docs/PRO_LESSONS.md:
-- start looking at ante 3-4, at least 1 by ante 5, 2 to 3 by ante 7-8)
PL.XMULT_TARGET = { 0, 0, 0, 1, 1, 2, 2, 3 }

-- "Falling behind": top players want a typical hand to score the ante's base chips (the boss,
-- 2x base, in two hands). The copilot's typical hand is measured on random hands WITHOUT
-- discards, which roughly halves it: the threshold is 0.5 x base. Calibrated on simulated runs
-- (docs/TRAINING.md): above 0.5 the ante's boss was beaten 87-100 % of the time, below 0.3
-- only 55 %.
PL.BEHIND_RATIO = 0.5
-- Track of the runs that WIN (1.0.10, simulated runs, docs/TRAINING.md): a typical hand (no
-- discards) at antes 2-4 stays above 1.2 x the ante's base chips in 3 winning runs out of 4
-- (q25 1.86 / 1.33 / 1.17), 0.79 at ante 5, 0.47 at ante 6; the median LOSING run is at 1.47 /
-- 1.31 / 1.00 / 0.62 / 0.46. Below the track, the board is not ready for the next ante (the
-- base chips grow x2.5 to x3 per ante, faster from the Green Stake): money goes into power
-- before interest even when the current ante looks safe. TRACK_SCALE 0 disables it.
PL.TRACK_RATIO = { 0, 1.2, 1.2, 1.1, 0.75, 0.45, 0.35, 0.3 }
PL.TRACK_SCALE = 1

local function has_tag(def, tag)
    for _, t in ipairs((def and def.tags) or {}) do if t == tag then return true end end
    return false
end
PL.has_tag = has_tag

-- Kind of a joker for planning: 'xmult', 'scaling', 'econ', 'additive' (+chips/+mult only),
-- 'utility' (rules, copies, generators).
function PL.joker_kind(def)
    if not def then return 'unknown' end
    if has_tag(def, 'xmult') then return 'xmult' end
    if has_tag(def, 'copy') then return 'xmult' end -- Blueprint / Brainstorm copy the best joker
    if has_tag(def, 'scaling') then return 'scaling' end
    if has_tag(def, 'econ') then return 'econ' end
    if has_tag(def, 'retrigger') then return 'retrigger' end
    if has_tag(def, 'mult') or has_tag(def, 'chips') then return 'additive' end
    return 'utility'
end

function PL.phase(ante)
    if (ante or 1) <= 2 then return 'early' end
    if ante <= 5 then return 'mid' end
    return 'late'
end

-- Multiplier sources: xMult jokers, Polychrome jokers, Steel / Glass cards (a few count as one).
function PL.xmult_sources(state)
    local n, list = 0, {}
    for _, j in ipairs(state.jokers or {}) do
        if not j.debuff then
            local def = DB.get(j.key, j.name)
            if PL.joker_kind(def) == 'xmult' then n = n + 1; list[#list + 1] = j.name or j.key end
            if j.edition == 'e_polychrome' then n = n + 1; list[#list + 1] = (j.name or j.key) .. ' (poly)' end
        end
    end
    local st = state.full_deck_stats or {}
    local cards = (st.steel or 0) + (st.glass or 0)
    if cards >= 3 then n = n + 1; list[#list + 1] = cards .. ' cartes acier/verre' end
    return n, list
end

-- Main hand: the most played one; on a tie, the highest level.
function PL.main_hand(state)
    local best, bp, bl = nil, -1, -1
    for name, h in pairs(state.hands or {}) do
        local p, l = h.played or 0, h.level or 1
        if p > bp or (p == bp and l > bl) or (p == bp and l == bl and H.RANK[name] and best and H.RANK[name] < (H.RANK[best] or 99)) then
            best, bp, bl = name, p, l
        end
    end
    if bp <= 0 then
        -- nothing played yet: the highest level, else none
        best, bl = nil, 1
        for name, h in pairs(state.hands or {}) do if (h.level or 1) > bl then best, bl = name, h.level end end
    end
    return best
end

-- Weight of a lesson learned from the player's past runs: 1 + the urgency the copilot is
-- trying or has kept (learning/adapt.lua: changed after a loss, kept only if the next runs are
-- not worse). Before 1.0.9 the causes of the last losses weighed directly (x1 to x1.5) and
-- "power that stopped following the blinds", present in every loss, raised the x Mult urgency
-- after the first loss for good; measured worse on the simulator (docs/TRAINING.md).
local URGENCY = { xmult = 'xmult_urgency', levels = 'levels_urgency' }
local function lesson(key)
    local lr = BSC.learning_runtime
    local d = lr and lr.adapt_deltas and lr.adapt_deltas()
    local k = URGENCY[key]
    if not (d and k and type(d[k]) == 'number') then return 1 end
    return 1 + math.max(0, math.min(0.5, d[k]))
end
PL.lesson = lesson

-- The plan. base (optional): { p_next, p_boss, p_win, median = score of a typical hand }.
-- Blinds grow faster from Green Stake (scaling 2) and Purple Stake (scaling 3): the build must
-- be one or two antes ahead (lesson of real runs lost at Orange Stake with +Mult jokers only).
function PL.stake_shift(state)
    local scaling = (state.run and state.run.scaling) or 1
    return math.max(0, math.min(2, scaling - 1))
end

function PL.analyse(state, base)
    base = base or {}
    local ante = (state.run and state.run.ante) or 1
    local shift = PL.stake_shift(state)
    local eff = ante + shift -- the ante the build must be ready for
    local x, list = PL.xmult_sources(state)
    local target = PL.XMULT_TARGET[math.min(#PL.XMULT_TARGET, math.max(1, eff))] or 3
    local plan = { ante = ante, eff_ante = eff, stake_shift = shift, phase = PL.phase(eff), xmult = x, xmult_list = list,
        xmult_target = target, main_hand = PL.main_hand(state), gaps = {} }
    local kinds = { xmult = 0, scaling = 0, econ = 0, additive = 0, retrigger = 0, utility = 0, unknown = 0 }
    for _, j in ipairs(state.jokers or {}) do kinds[PL.joker_kind(DB.get(j.key, j.name))] = (kinds[PL.joker_kind(DB.get(j.key, j.name))] or 0) + 1 end
    plan.kinds = kinds
    -- the next multiplier is due one ante early: prepare it before the board falls behind
    local next_target = PL.XMULT_TARGET[math.min(#PL.XMULT_TARGET, eff + 1)] or 3
    plan.next_target = next_target
    if x < next_target then plan.gaps.xmult = next_target - x end
    if plan.phase ~= 'late' and kinds.scaling == 0 then plan.gaps.scaling = true end
    if (base.p_next or 1) < 0.8 or (base.p_boss or 1) < 0.6 then plan.gaps.power = true end
    -- falling behind (top players' health check): a typical hand must reach the ante's base
    -- chips, i.e. the boss (2x base) in two hands; below that, scoring comes before interest
    local scaling = (state.run and state.run.scaling) or 1
    plan.base_chips = BL.base_amount(ante, scaling)
    if base.median and base.median < PL.BEHIND_RATIO * plan.base_chips then plan.gaps.power = true; plan.falling_behind = true end
    local track = (PL.TRACK_RATIO[math.min(#PL.TRACK_RATIO, math.max(1, ante))] or 0) * (PL.TRACK_SCALE or 0)
    plan.track_chips = track * plan.base_chips
    if base.median and track > 0 and base.median < plan.track_chips then plan.gaps.power = true; plan.off_track = true end
    -- ante 1-2: the first scoring jokers come before everything else
    if plan.phase == 'early' and (kinds.additive + kinds.xmult + kinds.scaling + kinds.retrigger) <= 1 then plan.gaps.scoring = true end
    if plan.phase == 'early' and kinds.econ == 0 and ((state.econ and state.econ.dollars) or 0) < 10 then plan.gaps.economy = true end
    -- additive jokers are outgrown in the late game: replacing them by multipliers pays
    plan.additive_late = (plan.phase == 'late') and kinds.additive or 0
    -- urgency of multipliers / planets tried (and kept only if it pays) after losses
    plan.xmult_weight = lesson('xmult')
    plan.levels_weight = lesson('levels')
    -- builds of top players under way (engine/builds.lua; loaded lazily: it requires this module)
    local okb, BD = pcall(BSC.require, 'engine/builds')
    if okb and BD then plan.builds = BD.active(state) end
    return plan
end

-- Planning bonus of a joker for the shop note, in "potential" units (engine/shop.lua):
-- multipliers become essential as antes go by, growing jokers are worth more early, pure
-- additive jokers are outgrown late. Returns value, reason (or nil).
function PL.joker_bonus(def, plan)
    if not plan or not def then return 0, nil end
    local kind = PL.joker_kind(def)
    local v, why = 0, nil
    if kind == 'xmult' then
        v = 0.1 + 0.07 * math.max(0, (plan.eff_ante or plan.ante) - 2)
        if plan.gaps.xmult then
            v = v + 0.3 * (plan.xmult_weight or 1)
            why = string.format('multiplicateur ×Mult : %d sur %d attendus à cette ante', plan.xmult, plan.xmult_target)
        end
    elseif kind == 'retrigger' then
        v = (plan.phase == 'late') and 0.2 or 0.05
    elseif kind == 'scaling' then
        v = (plan.phase == 'late') and 0 or 0.2
        if plan.gaps.scaling then v = v + 0.1; why = 'joker qui grandit : utile tôt dans la partie' end
    elseif kind == 'additive' then
        if plan.phase == 'late' then v = -0.25; why = '+Mult / +Jetons : vite dépassé en fin de partie' end
        if plan.gaps.scoring then v = v + 0.2; why = 'premiers jokers de score : la priorité des antes 1-2' end
    elseif kind == 'econ' then
        v = (plan.phase == 'early') and 0.15 or ((plan.phase == 'late') and -0.2 or 0)
    end
    return v, why
end

-- Replacing a x Mult joker by a joker that is not one: the board loses a multiplier it needs
-- for the next ante (seen in simulated runs: Baron sold in ante 3 for Crafty Joker, the run then
-- lost at ante 6 without any x Mult). Returns the extra loss in "potential" units, reason.
function PL.replace_penalty(old_def, new_def, plan)
    if not plan or not old_def then return 0, nil end
    if PL.joker_kind(old_def) ~= 'xmult' or (new_def and PL.joker_kind(new_def) == 'xmult') then return 0, nil end
    if (plan.xmult or 0) - 1 < (plan.next_target or 0) then
        return 0.3 * (plan.xmult_weight or 1), 'perd un multiplicateur ×Mult nécessaire à l\'ante suivante'
    end
    return 0, nil
end

return PL
