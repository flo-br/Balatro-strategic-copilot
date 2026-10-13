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
