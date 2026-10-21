-- Balatro Strategic Copilot - tools/trainer/run.lua
-- Plays simulated runs with the copilot as the only decision maker and writes one JSON line
-- per run (see docs/TRAINING.md).
-- Usage (repository root):
--   luajit tools/trainer/run.lua <first_seed> <count> <out.jsonl> [key=value ...]
--     options: deck=b_red  rollouts=32  shop_samples=80  <advice setting>=<value>
-- Example: luajit tools/trainer/run.lua 1 20 /tmp/runs.jsonl rollouts=32

local first, n, out = tonumber(arg[1] or '1'), tonumber(arg[2] or '1'), arg[3] or 'runs.jsonl'
TRAINER_DIR = (arg[0]:match('^(.*)[/\\][^/\\]+$') or '.')
local REPO = TRAINER_DIR .. '/../..'
package.path = REPO .. '/tests/?.lua;' .. package.path
local T = require('testlib')
-- BSC_MOD_ROOT: evaluate another version of the mod (e.g. a git worktree of a release)
T.MOD_ROOT = os.getenv('BSC_MOD_ROOT') or (REPO .. '/BalatroStrategicCopilot')
T.REPO_ROOT = REPO
T.bootstrap()
local U = BSCopilot.require('core/util')
local J = BSCopilot.require('core/json')
local Sched = BSCopilot.require('core/scheduler')

local cfg = dofile(T.MOD_ROOT .. '/config.lua')
local opts = { deck = 'b_red' }
cfg.compute.rollouts = 32
cfg.compute.shop_samples = 80
for i = 4, #arg do
    local k, v = arg[i]:match('^([%w_]+)=(.+)$')
    if k then
        local num = tonumber(v)
        if v == 'true' then num = true elseif v == 'false' then num = false end
        if k == 'deck' then opts.deck = v
        elseif k == 'track_scale' then BSCopilot.require('engine/plan').TRACK_SCALE = num
        elseif k == 'future_blend' then BSCopilot.require('engine/shop').FUTURE_BLEND = num
        elseif k == 'main_focus' then BSCopilot.require('engine/shop').MAIN_FOCUS = num
        elseif k == 'pack_free' then BSCopilot.require('engine/shop').PACK_JOKERS_FREE = (num == 1 or num == true)
        elseif k == 'pack_penalty' then BSCopilot.require('engine/shop').PACK_PENALTY = num
        elseif k == 'prior_cal' then BSCopilot.require('engine/shop').PRIOR_CALIBRATION = (num == 1 or num == true)
        elseif k == 'hidden_discards' then BSCopilot.require('engine/hand_advisor').HIDDEN_DISCARDS = (num == 1 or num == true)
        elseif k == 'hs_rules' then BSCopilot.require('engine/plan').HIGH_STAKE_RULES = (num == 1 or num == true)
        elseif k == 'stake' then opts.stake = tonumber(v)
        elseif k == 'learn' then
            -- learn=1: lessons + settings; learn=lessons / learn=adapt: one mechanism only
            opts.learn = (v == '1' or v == 'true' or v == 'lessons' or v == 'adapt')
            opts.learn_lessons = opts.learn and v ~= 'adapt'
            opts.learn_adapt = opts.learn and v ~= 'lessons'
        elseif cfg.compute[k] ~= nil then cfg.compute[k] = num
        else cfg.advice[k] = (num ~= nil) and num or v end
    end
end

local Sim = dofile(TRAINER_DIR .. '/sim.lua')
local Player = dofile(TRAINER_DIR .. '/player.lua')

-- learn=1: the runs of the batch share one profile, as the player's runs do in the game: after
-- each run the mod's review finds the causes, the lessons feed the plan and the copilot
-- recalculates its own settings (learning/adapt.lua) for the next run
local profile, RV, LE, AD, BR
if opts.learn then
    RV = BSCopilot.require('learning/review')
    LE = BSCopilot.require('learning/learning')
    AD = BSCopilot.require('learning/adapt')
    BR = dofile(TRAINER_DIR .. '/bridge.lua')
    profile = LE.new_profile(0)
    BSCopilot.learning_runtime = { profile = function() return profile end,
        adapt_deltas = function() return opts.learn_adapt and AD.deltas(profile) or nil end }
end

local fh = assert(io.open(out, 'a'))
local wins, antes = 0, 0
for seed = first, first + n - 1 do
    local t0 = os.clock()
    local g = Sim.new(seed, opts)
    local p = Player.new(cfg, opts)
    local ok, summary = pcall(function() return p:play_run(g) end)
    if ok and profile then
        local run = BR.to_run(summary)
        local rv = RV.build(run, profile)
        if opts.learn_lessons and not run.won and rv.lessons and #rv.lessons > 0 then LE.add_lessons(profile, rv.lessons, run.id) end
        if opts.learn_adapt then
            summary.adapt = AD.update(profile, rv, run)
            summary.adapt_deltas = AD.deltas(profile)
        end
    end
    if not ok then
        summary = { seed = tostring(seed), error = tostring(summary), ante = g.ante, history = g.history, decisions = p.decisions,
            anomalies = p.anomalies }
        io.stderr:write('seed ' .. seed .. ' crashed: ' .. tostring(summary.error) .. '\n')
    end
    summary.cpu_s = os.clock() - t0
    summary.settings = cfg.advice
    fh:write(J.encode(summary), '\n')
    fh:flush()
    if summary.won then wins = wins + 1 end
    antes = antes + (summary.ante or 0)
    io.stdout:write(string.format('seed %d: %s ante %d%s (%.0f s)\n', seed, summary.won and 'WIN ' or 'loss',
        summary.ante or 0, summary.lost_to and (' vs ' .. tostring(summary.lost_to.name)) or '', summary.cpu_s))
    io.stdout:flush()
end
fh:close()
print(string.format('%d runs, %d wins, average ante %.2f', n, wins, antes / math.max(1, n)))
