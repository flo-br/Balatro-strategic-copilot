-- Balatro Strategic Copilot - learning/runtime.lua
-- Glue between the controller (events, states, analyses), the recorder (raw run log),
-- the learning engine (profile) and the persistence manager.
-- Raw data (runs/*) and learned statistics (profile) are stored separately.

local BSC = BSCopilot
local U = BSC.require('core/util')
local L = BSC.require('core/log')
local LE = BSC.require('learning/learning')
local Rec = BSC.require('learning/recorder')
local RV = BSC.require('learning/review')
local AD = BSC.require('learning/adapt')

local RT = {}

RT.PROFILE = 'profile'
RT.INDEX = 'runs/index'
RT.ACTIVE = 'runs/active'
RT.RUN_SCHEMA = 1
RT.INDEX_SCHEMA = 1

local function cfg() return (BSC.config and BSC.config.learning) or {} end

function RT.init(store)
    RT.store = store
    if store then
        RT.profile_data = store:load(RT.PROFILE, LE.SCHEMA, function() return LE.new_profile(os.time()) end, LE.migrations)
        RT.index = store:load(RT.INDEX, RT.INDEX_SCHEMA, function() return { runs = {} } end, {})
        RT.active = store:load(RT.ACTIVE, RT.RUN_SCHEMA, function() return nil end, {})
    else
        RT.profile_data = LE.new_profile(os.time())
        RT.index = { runs = {} }
    end
    RT.rec = Rec.new({ version = BSC.VERSION })
    RT.cal_cache = {}
    return RT
end

function RT.profile() return RT.profile_data end

function RT.calibrator(kind)
    return function(p)
        local f = RT.cal_cache[kind or 'blind']
        if not f then
            f = LE.calibrator(RT.profile_data, kind)
            RT.cal_cache[kind or 'blind'] = f
        end
        return f(p)
    end
end

function RT.weights() return RT.profile_data and RT.profile_data.weights end
-- settings the copilot adjusted after its past runs (learning/adapt.lua)
function RT.adapt_deltas()
    if cfg().enabled == false or cfg().adapt == false or not RT.profile_data then return nil end
    return AD.deltas(RT.profile_data)
end

-- Learned score multipliers for jokers the engine does not know (modded), if any data.
function RT.unknown_multipliers(state)
    local DB = BSC.require('model/jokers_db')
    local out
    for _, j in ipairs(state.jokers or {}) do
        if j.key and not DB.get(j.key, j.name) then
            local m, n = LE.unknown_multiplier(RT.profile_data, j.key)
            if m and n and n >= 3 then out = out or {}; out[j.key] = m end
        end
    end
    return out
end

local function save(name, schema, data)
    if not RT.store then return false end
    local ok, err = RT.store:save(name, schema, data)
    if not ok then L.warn('learning', 'save %s failed: %s', name, tostring(err)) end
    return ok
end

function RT.save_active()
    if RT.rec and RT.rec.run then
        save(RT.ACTIVE, RT.RUN_SCHEMA, RT.rec.run)
        RT.rec.dirty = false
    end
end

function RT.prune()
    local keep = cfg().max_runs_kept or 300
    local runs = RT.index.runs
    while #runs > keep do
        local old = table.remove(runs, 1)
        if RT.store and old and old.id then RT.store:delete('runs/' .. old.id) end
    end
end

function RT.finish_run(run)
    if not run or #(run.blinds or {}) == 0 then
        if RT.store then RT.store:delete(RT.ACTIVE) end
        return nil
    end
    save('runs/' .. run.id, RT.RUN_SCHEMA, run)
    RT.index.runs[#RT.index.runs + 1] = { id = run.id, won = run.won, ante = run.final_ante, deck = run.deck, stake = run.stake,
        ended_at = run.ended_at, reason = run.end_reason }
    RT.prune()
    save(RT.INDEX, RT.INDEX_SCHEMA, RT.index)
    if cfg().enabled ~= false then
        LE.process_run(RT.profile_data, run, { min_samples = cfg().min_samples_calibration or 30, now = os.time() })
        RT.cal_cache = {}
        save(RT.PROFILE, LE.SCHEMA, RT.profile_data)
    end
    if RT.store then RT.store:delete(RT.ACTIVE) end
    RT.last_review = RV.build(run, RT.profile_data)
    -- the causes of the last losses are kept in the profile (shown; the plan of the next runs
    -- only changes through the trials of learning/adapt.lua)
    if not run.won and cfg().enabled ~= false and RT.last_review.lessons and #RT.last_review.lessons > 0 then
        LE.add_lessons(RT.profile_data, RT.last_review.lessons, run.id)
    end
    -- and the copilot recalculates its own development (learning/adapt.lua): one change on
    -- trial after a loss, kept only if the next runs are not worse; shown in the review
    if cfg().enabled ~= false and cfg().adapt ~= false then
        local okA, changes = pcall(AD.update, RT.profile_data, RT.last_review, run)
        if okA then RT.last_review.adapt = changes end
        save(RT.PROFILE, LE.SCHEMA, RT.profile_data)
    end
    L.info('learning', 'run %s finished (%s, ante %s)', run.id, tostring(run.end_reason), tostring(run.final_ante))
    return RT.last_review
end

function RT.attach(Ctl)
    BSC.learning_runtime = RT
    RT.init(BSC.store)
    Ctl.on(function(kind, data)
        if cfg().enabled == false then return end
        if kind == 'state' then
            local s = data.state
            -- resume a saved active run (game reloaded from its own save)
            if not RT.rec.run and RT.active and s and s.run and RT.active.identity then
                local id = table.concat({ tostring(s.run.seed), tostring(s.run.deck_key), tostring(s.run.stake), tostring(s.run.challenge) }, '|')
                if id == RT.active.identity then RT.rec:resume(RT.active) end
                RT.active = nil
            end
            local finished = RT.rec:on_state(data.prev, s, Ctl.results)
            if finished then RT.finish_run(finished) end
            local prev_phase = data.prev and data.prev.phase
            if RT.rec.dirty and s and s.phase ~= prev_phase and (s.phase == 'shop' or s.phase == 'blind_select' or s.phase == 'round_eval') then
                RT.save_active()
            end
        elseif kind == 'event' then
            RT.rec:on_event(data, { results = Ctl.results, state = Ctl.state })
        elseif kind == 'analysis' then
            RT.rec:on_analysis(data.phase, data.result, data.state)
        end
    end)
    Ctl.register('game_over', function() return RT.last_review end, RV.panel, nil)
    return true
end

-- History view (main menu): last review + objective learning summary.
function RT.menu_lines(detail)
    local I = BSC.require('core/i18n')
    local function seg(t, c) return { t = t, c = c or 'text' } end
    local lines = {}
    local sm = LE.summary(RT.profile_data)
    if not sm or (sm.runs or 0) == 0 then
        lines[#lines + 1] = { seg(I.T('learning_none'), 'dim') }
        return lines
    end
    lines[#lines + 1] = { seg(string.format('%d parties, %d victoires (%s, intervalle %s–%s)', sm.runs, sm.wins,
        I.pct(sm.win_rate), I.pct(sm.win_lo), I.pct(sm.win_hi)), 'text') }
    lines[#lines + 1] = { seg(string.format('Ante moyenne %.1f, maximale %d', sm.mean_ante or 0, sm.max_ante or 0), 'dim') }
    local cal = sm.calibration or {}
    if cal.n and cal.n > 0 then
        lines[#lines + 1] = { seg(string.format('Prédictions de blinde : %d, Brier %.3f, ECE %.3f, calibration %s', cal.n,
            cal.brier or 0, cal.ece or 0, cal.enabled and 'active' or 'inactive (' .. tostring(cal.reason) .. ')'), 'dim') }
    end
    if sm.score and sm.score.n and sm.score.n > 0 then
        lines[#lines + 1] = { seg(string.format('Scores : erreur relative moyenne %s ; exacts vérifiés %d/%d', I.pct(sm.score.mean_rel_err or 0),
            (sm.score.exact_n or 0) - (sm.score.exact_mismatch or 0), sm.score.exact_n or 0), 'dim') }
    end
    if sm.followed and sm.deviated then
        lines[#lines + 1] = { seg(string.format('Blinde suivante gagnée : %s en suivant les conseils (n=%d), %s sinon (n=%d) — descriptif, pas causal',
            I.pct(sm.followed.p), sm.followed.n, I.pct(sm.deviated.p), sm.deviated.n), 'dim') }
    end
    local tr = LE.trend(RT.profile_data)
    if tr.enough then
        lines[#lines + 1] = { seg(string.format('Tendance : %s → %s de victoires (%s)', I.pct(tr.old.win), I.pct(tr.new.win),
            tr.significant and 'différence significative' or 'différence non significative'), tr.significant and 'accent' or 'dim') }
    end
    if RT.last_review then
        lines[#lines + 1] = { seg(I.T('review_title'), 'title') }
        for _, l in ipairs(RV.panel(nil, RT.last_review, detail)) do lines[#lines + 1] = l end
    end
    return lines
end

-- Export / import / reset --------------------------------------------------------------------
function RT.export()
    if not RT.store then return nil, 'no storage' end
    local runs = {}
    for _, r in ipairs(RT.index.runs) do
        local data = RT.store:load('runs/' .. r.id, RT.RUN_SCHEMA, function() return nil end, {})
        if data then runs[#runs + 1] = data end
    end
    local path, err = RT.store:export({ profile = RT.profile_data, index = RT.index, runs = runs, mod_version = BSC.VERSION })
    return path, err
end

function RT.import()
    if not RT.store then return 0 end
    local bundles, bad = RT.store:read_imports()
    local added = 0
    for _, b in ipairs(bundles) do
        for _, run in ipairs(b.bundle.runs or {}) do
            if type(run) == 'table' and run.id and not RT.profile_data.processed[run.id] then
                save('runs/' .. run.id, RT.RUN_SCHEMA, run)
                RT.index.runs[#RT.index.runs + 1] = { id = run.id, won = run.won, ante = run.final_ante, deck = run.deck, stake = run.stake,
                    ended_at = run.ended_at, reason = run.end_reason, imported = true }
                LE.process_run(RT.profile_data, run, { min_samples = cfg().min_samples_calibration or 30 })
                added = added + 1
            end
        end
        RT.store:mark_imported(b.path)
    end
    RT.prune()
    save(RT.INDEX, RT.INDEX_SCHEMA, RT.index)
    save(RT.PROFILE, LE.SCHEMA, RT.profile_data)
    RT.cal_cache = {}
    return added, #bad
end

function RT.reset()
    if RT.store then RT.store:backup(RT.PROFILE, 'reset') end
    RT.profile_data = LE.new_profile(os.time())
    RT.cal_cache = {}
    save(RT.PROFILE, LE.SCHEMA, RT.profile_data)
    return true
end

return RT
