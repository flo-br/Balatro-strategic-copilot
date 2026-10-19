-- Balatro Strategic Copilot - tools/trainer/report.lua
-- Summary of simulated runs (run.lua output): win rate, antes reached, bosses that ended runs,
-- and the causes found by the mod's own post-run review (learning/review.lua) on every loss.
-- Usage: luajit tools/trainer/report.lua runs.jsonl [more.jsonl ...]

TRAINER_DIR = (arg[0]:match('^(.*)[/\\][^/\\]+$') or '.')
local REPO = TRAINER_DIR .. '/../..'
package.path = REPO .. '/tests/?.lua;' .. package.path
local T = require('testlib')
T.MOD_ROOT = os.getenv('BSC_MOD_ROOT') or (REPO .. '/BalatroStrategicCopilot')
T.REPO_ROOT = REPO
T.bootstrap()
local J = BSCopilot.require('core/json')
local RV = BSCopilot.require('learning/review')
local LE = BSCopilot.require('learning/learning')
local H = BSCopilot.require('model/hands')

local BR = dofile(TRAINER_DIR .. '/bridge.lua')
local to_run = BR.to_run

local runs, wins, antes, crashes = 0, 0, 0, 0
local by_ante, by_boss, causes, anomalies = {}, {}, {}, {}
for i = 1, #arg do
    for line in io.lines(arg[i]) do
        local ok, r = pcall(J.decode, line)
        if ok and r then
            runs = runs + 1
            if r.error then crashes = crashes + 1 end
            if r.won then wins = wins + 1 end
            antes = antes + (r.ante or 0)
            by_ante[r.ante or 0] = (by_ante[r.ante or 0] or 0) + 1
            if not r.won and r.lost_to then
                local k = r.lost_to.name or r.lost_to.key
                by_boss[k] = (by_boss[k] or 0) + 1
                local rv = RV.build(to_run(r), LE.new_profile(0))
                for _, c in ipairs(rv.causes or {}) do causes[c.key] = (causes[c.key] or 0) + 1 end
            end
            for _, a in ipairs(r.anomalies or {}) do anomalies[a.what] = (anomalies[a.what] or 0) + 1 end
        end
    end
end
local function sorted(t)
    local out = {}
    for k, v in pairs(t) do out[#out + 1] = { k = k, v = v } end
    table.sort(out, function(a, b) return a.v > b.v end)
    return out
end
print(string.format('runs %d  wins %d (%.0f %%)  average ante %.2f  crashes %d', runs, wins, 100 * wins / math.max(1, runs),
    antes / math.max(1, runs), crashes))
local line = {}
for a = 1, 8 do line[#line + 1] = string.format('%d:%d', a, by_ante[a] or 0) end
print('final ante: ' .. table.concat(line, '  '))
-- survival curve: share of runs that reached each ante (less noisy than the win rate alone)
local surv, reached = {}, 0
for a = 8, 1, -1 do
    reached = reached + (by_ante[a] or 0)
    surv[a] = reached
end
line = {}
for a = 2, 8 do line[#line + 1] = string.format('%d:%.0f%%', a, 100 * (surv[a] or 0) / math.max(1, runs)) end
print('reached ante: ' .. table.concat(line, '  '))
print('ended by:')
for _, e in ipairs(sorted(by_boss)) do print(string.format('  %-16s %d', e.k, e.v)) end
print('causes found by the review (losses):')
for _, e in ipairs(sorted(causes)) do print(string.format('  %-16s %d', e.k, e.v)) end
if next(anomalies) then
    print('anomalies:')
    for _, e in ipairs(sorted(anomalies)) do print(string.format('  %-16s %d', e.k, e.v)) end
end
