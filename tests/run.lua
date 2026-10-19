-- Balatro Strategic Copilot - test runner (no dependencies).
-- Usage (from repository root):  luajit tests/run.lua [filter]
--                                lua5.1 tests/run.lua [filter]

local sep = package.config:sub(1, 1)
local script_dir = (arg and arg[0] and arg[0]:match('^(.*)[/\\]')) or 'tests'
local repo_root = script_dir .. sep .. '..'
local MOD_ROOT = repo_root .. sep .. 'BalatroStrategicCopilot'
package.path = script_dir .. sep .. '?.lua;' .. package.path

local T = require('testlib')
T.MOD_ROOT = MOD_ROOT
T.REPO_ROOT = repo_root

local filter = arg and arg[1]

local files = {
    -- unit
    'unit/test_util', 'unit/test_json', 'unit/test_rng', 'unit/test_scheduler',
    'unit/test_poker_eval', 'unit/test_score', 'unit/test_score_reference', 'unit/test_jokers',
    'unit/test_probability', 'unit/test_hand_advisor', 'unit/test_economy', 'unit/test_synergy',
    'unit/test_shop', 'unit/test_advice', 'unit/test_plan', 'unit/test_builds', 'unit/test_skip', 'unit/test_strategy', 'unit/test_persistence', 'unit/test_learning', 'unit/test_adapt',
    'unit/test_recorder', 'unit/test_format',
    -- integration
    'integration/test_mod_load', 'integration/test_state_reader', 'integration/test_compat', 'integration/test_full_flow', 'integration/test_old_smods', 'integration/test_standalone', 'integration/test_steps_ui',
    -- performance
    'unit/test_performance',
}

local t0 = os.clock()
for _, f in ipairs(files) do
    if not filter or f:find(filter, 1, true) then
        local path = script_dir .. sep .. f:gsub('/', sep) .. '.lua'
        local fh = io.open(path, 'r')
        if fh then
            fh:close()
            T.run_file(path, f)
        end
    end
end
local ok = T.report(os.clock() - t0)
os.exit(ok and 0 or 1)
