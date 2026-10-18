-- Balatro Strategic Copilot - learning/recorder.lua  (RunRecorder)
-- Builds the raw log of a run from state transitions and observed events:
--   decisions (options available, recommendation shown, choice actually made),
--   hands (predicted vs actual score), blinds (predicted P(clear) vs outcome),
--   power and economy over time, final result.
-- Only game data is stored (no personal data). The recorder never judges a decision.

local BSC = BSCopilot
local U = BSC.require('core/util')
local DB = BSC.require('model/jokers_db')
local Score = BSC.require('engine/score')

local Rec = {}
Rec.__index = Rec
Rec.SCHEMA = 1

function Rec.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Rec)
    self.now = opts.now or os.time
    self.version = opts.version or '?'
    self.run = nil
    self.pending_hand = nil
    self.current_blind = nil
    self.dirty = false
    return self
end

local function identity(s)
    local r = s.run or {}
    return table.concat({ tostring(r.seed), tostring(r.deck_key), tostring(r.stake), tostring(r.challenge) }, '|')
end

local function set_of(uids)
    local t = {}
    for _, u in ipairs(uids or {}) do t[tostring(u)] = true end
    return t
end

local function same_set(a, b)
    local sa, sb = set_of(a), set_of(b)
    for k in pairs(sa) do if not sb[k] then return false end end
    for k in pairs(sb) do if not sa[k] then return false end end
    return true
end

function Rec:start(s)
    local r = s.run or {}
    self.run = {
        id = 'run_' .. tostring(self.now()) .. '_' .. string.format('%08x', U.hash32(identity(s))),
        schema = Rec.SCHEMA, mod_version = self.version,
        game_version = s.meta and s.meta.game_version, smods_version = s.meta and s.meta.smods_version,
        deck = r.deck_key, stake = r.stake, challenge = r.challenge, seed = r.seed, seeded = r.seeded,
        identity = identity(s), started_at = self.now(),
        won = false, final_ante = r.ante or 1, final_round = r.round or 0,
        blinds = {}, hands = {}, decisions = {}, power = {}, economy = {},
    }
    self.current_blind = nil
    self.pending_hand = nil
    self.dirty = true
    return self.run
end

-- Resume a run saved earlier (game reloaded from a save file).
function Rec:resume(run)
    self.run = run
    local n = run.blinds and #run.blinds or 0
    self.current_blind = n > 0 and run.blinds[n] or nil
    self.current_blind_idx = n > 0 and n or nil
    if self.current_blind and self.current_blind.cleared ~= nil then self.current_blind = nil; self.current_blind_idx = nil end
end

-- Close the current blind: outcome propagated to the hands played in it.
local function close_blind(self, cleared, score)
    local cb = self.current_blind
    if not cb then return end
    if cb.cleared == nil then cb.cleared = cleared end
    if score ~= nil and cb.score == nil then cb.score = score end
    for _, h in ipairs(self.run.hands) do
        if h.blind_idx == self.current_blind_idx then h.blind_cleared = cb.cleared end
    end
    self.current_blind = nil
    self.current_blind_idx = nil
    self.dirty = true
end

local function finalize(self, reason)
    local run = self.run
    if not run then return nil end
    run.ended_at = self.now()
    run.end_reason = reason
    -- blinds without outcome are left as unknown (nil)
    local finished = run
    self.run = nil
    self.current_blind = nil
    self.pending_hand = nil
    self.dirty = true
    return finished
end

-- Called on every new stable snapshot. results = controller results (latest analyses).
-- Returns a finished run when a run ends (loss, abandon), else nil.
function Rec:on_state(prev, s, results)
    if not s or not s.run then return nil end
    local finished
    if s.phase == 'menu' or s.phase == 'none' then return nil end
    if self.run and self.run.identity ~= identity(s) then
        finished = finalize(self, 'abandoned')
    end
    if not self.run then self:start(s) end
    local run = self.run
    run.final_ante = math.max(run.final_ante or 1, s.run.ante or 1)
    run.final_round = s.run.round or run.final_round

    -- resolve the score of the last hand
    if self.pending_hand then
        local ph = self.pending_hand
        local scored = s.blind and s.blind.chips_scored
        if s.phase ~= 'busy' and scored ~= nil and ph.chips_before ~= nil then
            if (s.run.round or 0) == ph.round then
                ph.entry.actual = scored - ph.chips_before
            elseif s.phase == 'round_eval' or s.phase == 'shop' or s.phase == 'game_over' then
                ph.entry.actual = scored - ph.chips_before
            end
            self.pending_hand = nil
            self.dirty = true
            if ph.entry.actual then
                local okc, CM = pcall(BSC.require, 'game/compat')
                if okc and CM then CM.record_score(ph.entry.predicted, ph.entry.actual, ph.entry.exact) end
            end
        end
    end

    -- blind start
    if s.phase == 'hand' and s.blind and s.blind.key then
        local cb = self.current_blind
        if not cb or cb.round ~= s.run.round then
            local p_pred, method
            local bs = results and results.blind_select
            if bs and bs.current and bs.current.key == s.blind.key and bs.p_current then
                p_pred, method = bs.p_current.p, 'rollouts'
            end
            local entry = { ante = s.run.ante, round = s.run.round, key = s.blind.key, name = s.blind.name,
                chips = s.blind.chips_required, boss = s.blind.boss, p_pred = p_pred, p_method = method }
            run.blinds[#run.blinds + 1] = entry
            self.current_blind = entry
            self.current_blind_idx = #run.blinds
            self.dirty = true
        end
        -- first in-round prediction if none from blind selection
        local cb2 = self.current_blind
        if cb2 and not cb2.p_pred and results and results.hand and results.hand.round and (s.round.hands_played or 0) == 0 then
            cb2.p_pred = results.hand.round.p_clear
            cb2.p_method = 'hand_' .. tostring(results.hand.round.method)
        end
    end

    -- blind cleared (round evaluation or shop reached)
    if (s.phase == 'round_eval' or s.phase == 'shop') and self.current_blind then
        close_blind(self, true, prev and prev.blind and prev.blind.chips_scored)
    end

    -- win
    if s.run.won and not run.won then
        run.won = true
        run.won_at_ante = s.run.ante
        self.dirty = true
    end

    -- economy trace (one point per round)
    local last_e = run.economy[#run.economy]
    if s.econ and (not last_e or last_e.round ~= s.run.round) then
        run.economy[#run.economy + 1] = { ante = s.run.ante, round = s.run.round, dollars = s.econ.dollars }
    end

    if s.phase == 'game_over' then
        if self.current_blind then
            run.lost_to = self.current_blind.key
            close_blind(self, false, s.blind and s.blind.chips_scored or (prev and prev.blind and prev.blind.chips_scored))
        end
        finished = finalize(self, run.won and 'won_then_lost' or 'lost')
    end
    return finished
end

-- Power estimates from analyses (shop / blind selection).
function Rec:on_analysis(phase, result, s)
    if not self.run or not result then return end
    local med
    if phase == 'shop' and result.base then med = result.base.median end
    if phase == 'blind_select' and result.power then med = result.power.median end
    if med and s and s.run then
        local last = self.run.power[#self.run.power]
        if not last or last.ante ~= s.run.ante then
            self.run.power[#self.run.power + 1] = { ante = s.run.ante, round = s.run.round, median = med, mean = med }
        else
            last.median = med
        end
        self.dirty = true
    end
    -- the build at each shop: what the post-run review compares with the plan (engine/plan.lua)
    if phase == 'shop' and result.plan and s and s.run then
        local pl = result.plan
        local main = pl.main_hand and s.hands and s.hands[pl.main_hand]
        local entry = { ante = s.run.ante, round = s.run.round, dollars = s.econ and s.econ.dollars,
            cap = s.econ and s.econ.interest_cap, xmult = pl.xmult, xmult_target = pl.xmult_target,
            gap_xmult = pl.gaps and pl.gaps.xmult and true or nil, gap_power = pl.gaps and pl.gaps.power and true or nil,
            main_hand = pl.main_hand, main_level = main and main.level, jokers = #(s.jokers or {}),
            slots = s.joker_slots, p_boss = result.base and result.base.p_boss, p_win = result.base and result.base.p_win }
        self.run.builds = self.run.builds or {}
        local lb = self.run.builds[#self.run.builds]
        if lb and lb.round == entry.round then self.run.builds[#self.run.builds] = entry else self.run.builds[#self.run.builds + 1] = entry end
        self.dirty = true
    end
end

-- Measured contributions of each joker on an actual hand (score with vs without).
local function hand_contributions(state, played, held)
    local out, unknown = {}, {}
    local jokers = state.jokers or {}
    local base = Score.evaluate(state, played, held, { max_branches = 16, samples = 40 })
    for i, j in ipairs(jokers) do
        if not j.debuff then
            if DB.get(j.key, j.name) then
                local rest = {}
                for k, jj in ipairs(jokers) do if k ~= i then rest[#rest + 1] = jj end end
                local s2 = {}
                for k, v in pairs(state) do s2[k] = v end
                s2.jokers = rest
                local without = Score.evaluate(s2, played, held, { max_branches = 16, samples = 40 }).mean
                if base.mean > 0 and j.key then out[j.key] = 1 - without / base.mean end
            else
                unknown[#unknown + 1] = j.key or j.name
            end
        end
    end
    return out, unknown, base
end

-- Events (from mod.calculate observation). ctx = { results = Ctl.results, state = Ctl.state }
function Rec:on_event(ev, ctx)
    if not self.run then return end
    local run = self.run
    local s = ctx.state or {}
    local results = ctx.results or {}
    local ante = s.run and s.run.ante or 0
    local round = s.run and s.run.round or 0
    local d = { kind = ev.kind, ante = ante, round = round, t = self.now() }

    if ev.kind == 'before' then
        local hr = results.hand
        local entry = { ante = ante, round = round, blind = s.blind and s.blind.key, n_cards = #(ev.uids or {}),
            hand = ev.scoring_name, hands_left = s.round and s.round.hands_left, discards_left = s.round and s.round.discards_left,
            blind_idx = self.current_blind_idx }
        local by_uid = {}
        for _, c in ipairs(s.hand_cards or {}) do by_uid[tostring(c.uid)] = c end
        local played, set = {}, {}
        for _, u in ipairs(ev.uids or {}) do
            local c = by_uid[tostring(u)]
            if c then played[#played + 1] = c; set[c] = true end
        end
        if #played == #(ev.uids or {}) and #played > 0 then
            local held = {}
            for _, c in ipairs(s.hand_cards or {}) do if not set[c] then held[#held + 1] = c end end
            local ok, contrib, unknown, base = pcall(hand_contributions, s, played, held)
            if ok then
                entry.predicted, entry.pmin, entry.pmax = base.mean, base.min, base.max
                entry.exact, entry.method = base.exact, base.method
                entry.contributions = contrib
                entry.unknown = unknown
                entry.jokers = {}
                for _, j in ipairs(s.jokers or {}) do entry.jokers[#entry.jokers + 1] = j.key end
            end
        end
        if hr then
            entry.p_clear_before = hr.round and hr.round.p_clear
            local rec = hr.recommendation
            if rec then
                entry.rec_type = rec.type
                local rec_uids = (rec.ref and rec.ref.uids) or {}
                if rec.type == 'play' then
                    entry.followed = same_set(rec_uids, ev.uids)
                else
                    entry.followed = false
                end
                d.followed = entry.followed
                d.p_before = hr.round and hr.round.p_clear
                -- what did the analysis think of the chosen play?
                for _, cand in ipairs(hr.candidates or {}) do
                    if cand.type == 'play' and cand.ref and same_set(cand.ref.uids, ev.uids) then d.p_chosen = cand.p_clear end
                end
                d.p_best = rec.p_clear
            end
        end
        d.danger = entry.p_clear_before and (1 - entry.p_clear_before) or nil
        run.hands[#run.hands + 1] = entry
        self.pending_hand = { entry = entry, chips_before = ev.chips_before, round = round }
    elseif ev.kind == 'pre_discard' then
        local hr = results.hand
        if hr and hr.recommendation then
            local rec = hr.recommendation
            d.followed = rec.type == 'discard' and same_set(U.map(rec.cards or {}, function(c) return c.uid end), ev.uids)
            d.p_before = hr.round and hr.round.p_clear
            d.p_best = rec.p_clear
            for _, cand in ipairs(hr.candidates or {}) do
                if cand.type == 'discard' and same_set(U.map(cand.cards or {}, function(c) return c.uid end), ev.uids) then d.p_chosen = cand.p_clear end
            end
            d.danger = d.p_before and (1 - d.p_before) or nil
        end
        d.n_cards = #(ev.uids or {})
    elseif ev.kind == 'buying_card' or ev.kind == 'selling_card' then
        d.key, d.uid, d.cost = ev.key, ev.uid, ev.cost
        local sr = results.shop or results.pack
        if sr and sr.options then
            local best = sr.options[1]
            d.best_key, d.best_note = best and best.key, best and best.note
            for _, o in ipairs(sr.options) do
                if tostring(o.uid) == tostring(ev.uid) then d.chosen_note = o.note; d.chosen_name = o.name end
            end
            if ev.kind == 'buying_card' then d.followed = best and tostring(best.uid) == tostring(ev.uid) or false end
            d.danger = sr.danger
            if ev.kind == 'selling_card' then
                for _, sl in ipairs(sr.sells or {}) do
                    if tostring(sl.uid) == tostring(ev.uid) then d.chosen_note = sl.note; d.contribution = sl.contribution end
                end
            end
        end
    elseif ev.kind == 'reroll_shop' then
        local sr = results.shop
        if sr then
            -- followed = the "À FAIRE" step was RELANCER (free, worth it, once, money to spare)
            local okA, A = pcall(BSC.require, 'engine/advice')
            local st = okA and A.step('shop', s, sr, BSC.config) or nil
            d.followed = (st and st.action == 'reroll') or (sr.reroll and sr.reroll.worth) or false
            d.danger = sr.danger
        end
    elseif ev.kind == 'skip_blind' then
        local bs = results.blind_select
        if bs and bs.skip then d.followed = bs.skip.recommended and true or false; d.danger = bs.danger end
    elseif ev.kind == 'end_of_round' then
        if self.current_blind and self.current_blind.cleared == nil then
            self.current_blind.cleared = not ev.game_over
        end
        return
    elseif ev.kind == 'using_consumeable' or ev.kind == 'open_booster' then
        d.key = ev.key
    else
        return
    end
    run.decisions[#run.decisions + 1] = d
    self.dirty = true
end

return Rec
