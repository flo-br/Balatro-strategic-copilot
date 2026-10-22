-- Balatro Strategic Copilot - tools/trainer/branch.lua
-- Decision branching: plays simulated runs with the copilot (as run.lua) and, at the first step
-- of chosen shops, forks the process (fork() through the LuaJIT FFI, Linux) into one child per
-- alternative and per future: the copilot's own step, buying another item, leaving the shop,
-- rerolling. Every child applies its alternative, reseeds the simulator with the future's seed
-- (the same K futures for every alternative: common random numbers), then lets the copilot play
-- the rest of the run. The parent waits for the children, writes one JSON line per branch point,
-- then goes on with the copilot's own step (the run itself is unchanged).
-- Compared with two versions playing whole runs, the alternatives start from the SAME state:
-- only the future differs, which measures one decision with much less noise (docs/TRAINING.md).
-- Usage (repository root, Linux):
--   luajit tools/trainer/branch.lua <first_seed> <count> <out.jsonl> [key=value ...]
--     own options: antes=2-4 (antes branched), points=all|first (every shop or the first shop of
--     each ante), K=6 (futures per alternative), alts=3 (alternatives besides the copilot's step),
--     jobs=4 (processes at once), H=0 (antes played after the branch point before a future stops:
--     0 = to the end of the run); other options as run.lua (stake=4, rollouts=24...).
-- Score of a future: blinds won + fraction of the score reached against the blind lost (a win
-- counts 25), as in the comparisons of docs/TRAINING.md.

local first, n, out = tonumber(arg[1] or '1'), tonumber(arg[2] or '1'), arg[3] or 'branch.jsonl'
TRAINER_DIR = (arg[0]:match('^(.*)[/\\][^/\\]+$') or '.')
local REPO = TRAINER_DIR .. '/../..'
package.path = REPO .. '/tests/?.lua;' .. package.path
local T = require('testlib')
T.MOD_ROOT = os.getenv('BSC_MOD_ROOT') or (REPO .. '/BalatroStrategicCopilot')
T.REPO_ROOT = REPO
T.bootstrap()
local J = BSCopilot.require('core/json')
local Rng = BSCopilot.require('core/rng')

local ffi = require('ffi')
ffi.cdef [[
    int fork(void);
    int waitpid(int pid, int *status, int options);
    void _exit(int status);
]]

local cfg = dofile(T.MOD_ROOT .. '/config.lua')
local opts = { deck = 'b_red' }
cfg.compute.rollouts = 24
cfg.compute.shop_samples = 60
local OWN = { antes = true, points = true, K = true, alts = true, jobs = true, H = true }
dofile(TRAINER_DIR .. '/options.lua').apply(arg, 4, cfg, opts, OWN)
local X = opts.extra
local a1, a2 = tostring(X.antes or '2-4'):match('^(%d+)%-(%d+)$')
a1, a2 = tonumber(a1 or X.antes or 2), tonumber(a2 or X.antes or 4)
local K, ALTS, JOBS = tonumber(X.K or 6), tonumber(X.alts or 3), tonumber(X.jobs or 4)
local FIRST_ONLY = (X.points == 'first')
local HORIZON = tonumber(X.H or 0)

local Sim = dofile(TRAINER_DIR .. '/sim.lua')
local Player = dofile(TRAINER_DIR .. '/player.lua')

local function score_of(g)
    if g.won then return 25 end
    local won = 0
    for _, h in ipairs(g.history or {}) do if h.won then won = won + 1 end end
    local lt = g.lost_to
    if lt then won = won + math.min(1, (lt.scored or 0) / math.max(1, lt.required or 1)) end
    return won
end

-- what the branch point records about the state and each option
local function features(g, st, res)
    local b = res.base or {}
    local plan = res.plan or {}
    return { ante = g.ante, round = g.round, dollars = g.dollars, jokers = #g.jokers, slots = g.joker_slots,
        xmult = plan.xmult, p_next = b.p_next, p_boss = b.p_boss, p_next_raw = b.p_next_raw, p_boss_raw = b.p_boss_raw,
        median = b.median, falling_behind = plan.falling_behind, off_track = plan.off_track }
end

local function option_info(o)
    if not o then return nil end
    return { kind = o.kind, key = o.key, name = o.name, note = o.note, cost = o.cost, joker_kind = o.joker_kind,
        interest_loss = o.interest_loss, set = o.set }
end

-- the alternatives at a branch point: the copilot's step first
local function alternatives(g, st, res, step)
    local list = { { label = 'copilot', step = step } }
    local chosen = step.targets and step.targets[1]
    local function add(label, s, o) if #list <= ALTS then list[#list + 1] = { label = label, step = s, option = option_info(o) } end end
    if step.action ~= 'next_round' then add('leave', { action = 'next_round', text = 'leave' }) end
    local cons_full = #(g.consumables or {}) >= (g.consumable_slots or 2)
    local opts_sorted = {}
    for _, o in ipairs(res.options or {}) do opts_sorted[#opts_sorted + 1] = o end
    table.sort(opts_sorted, function(x, y) return (x.note or 0) > (y.note or 0) end)
    for _, o in ipairs(opts_sorted) do
        local consumable = (o.set == 'Planet' or o.set == 'Tarot' or o.set == 'Spectral')
        if o.affordable and not o.blocked and o.kind ~= 'replace' and o.uid ~= chosen and o.uid
            and not (consumable and cons_full) and (o.cost or 0) <= g.dollars then
            add('buy ' .. tostring(o.name or o.key), { action = 'buy', targets = { o.uid }, text = 'alt ' .. tostring(o.name), note = o.note }, o)
        end
    end
    local rc = (st.econ and st.econ.reroll_cost) or 5
    if step.action ~= 'reroll' and g.dollars >= rc then add('reroll', { action = 'reroll', text = 'alt reroll' }) end
    return list
end

local CHILD = nil
local CUR_G = nil
local done_points = {}
local fh_points = assert(io.open(out, 'a'))
local tmp_dir = out .. '.tmp'
os.execute('mkdir -p "' .. tmp_dir .. '"')

local function wait_one()
    local status = ffi.new('int[1]')
    return ffi.C.waitpid(-1, status, 0)
end

local function branch(p, g, st, res, step)
    local alts = alternatives(g, st, res, step)
    if #alts < 2 then return end
    local queue = {}
    for ai = 1, #alts do for f = 1, K do queue[#queue + 1] = { ai = ai, f = f } end end
    local running = 0
    local tag = string.format('%s_%d', g.seed, g.round)
    for _, q in ipairs(queue) do
        while running >= JOBS do if wait_one() > 0 then running = running - 1 end end
        io.stdout:flush(); io.stderr:flush(); fh_points:flush()
        local pid = ffi.C.fork()
        if pid == 0 then
            CHILD = { file = string.format('%s/%s_%d_%d', tmp_dir, tag, q.ai, q.f),
                stop_ante = (HORIZON > 0) and (g.ante + HORIZON) or nil }
            g.rng = Rng.new('sim:' .. g.seed .. ':branch:' .. g.round .. ':' .. q.f)
            return alts[q.ai].step
        elseif pid > 0 then
            running = running + 1
        else
            io.stderr:write('fork failed\n')
        end
    end
    while running > 0 do if wait_one() > 0 then running = running - 1 else break end end
    -- collect
    local rec = { seed = g.seed, state = features(g, st, res), copilot = { action = step.action, text = step.text, note = step.note,
        option = (function() for _, o in ipairs(res.options or {}) do if step.targets and o.uid == step.targets[1] then return option_info(o) end end end)() },
        alts = {} }
    for ai, a in ipairs(alts) do
        local scores = {}
        for f = 1, K do
            local fn = string.format('%s/%s_%d_%d', tmp_dir, tag, ai, f)
            local h = io.open(fn, 'r')
            local v = h and tonumber(h:read('*l'))
            if h then h:close(); os.remove(fn) end
            scores[f] = v or false
        end
        rec.alts[ai] = { label = a.label, action = a.step.action, option = a.option, scores = scores }
    end
    fh_points:write(J.encode(rec), '\n')
    fh_points:flush()
    return nil
end

local orig_shop = Player.play_shop
function Player:play_shop(g) CUR_G = g; return orig_shop(self, g) end
local function child_done(g, ok)
    local h = io.open(CHILD.file, 'w')
    if h then h:write(ok and tostring(score_of(g)) or 'nan', '\n'); h:close() end
    ffi.C._exit(0)
end

local orig_step = Player.step
function Player:step(phase, st, res)
    -- a future past its horizon stops at the next blind choice (blinds won so far)
    if CHILD and CHILD.stop_ante and phase == 'blind_select' and CUR_G and CUR_G.ante > CHILD.stop_ante then
        child_done(CUR_G, true)
    end
    local step, err = orig_step(self, phase, st, res)
    if CHILD or phase ~= 'shop' or not step or not CUR_G then return step, err end
    local g = CUR_G
    if g.ante < a1 or g.ante > a2 or done_points[g.seed .. ':' .. g.round] then return step, err end
    if FIRST_ONLY and done_points[g.seed .. ':ante' .. g.ante] then return step, err end
    done_points[g.seed .. ':' .. g.round] = true
    done_points[g.seed .. ':ante' .. g.ante] = true
    -- a consumable used first (planets, money tarots) is not a choice worth branching
    if step.action ~= 'buy' and step.action ~= 'next_round' and step.action ~= 'reroll' then return step, err end
    local forced = branch(self, g, st, res, step)
    if forced then return forced end
    return step, err
end

local fh_runs = assert(io.open(out .. '.runs.jsonl', 'a'))
for seed = first, first + n - 1 do
    local g = Sim.new(seed, opts)
    local p = Player.new(cfg, opts)
    local ok, summary = pcall(function() return p:play_run(g) end)
    if CHILD then child_done(g, ok) end
    if ok then fh_runs:write(J.encode({ seed = seed, won = summary.won, ante = summary.ante, score = score_of(g) }), '\n') end
    fh_runs:flush()
    io.stdout:write(string.format('seed %d: %s ante %d\n', seed, (ok and summary.won) and 'WIN ' or 'loss', g.ante))
    io.stdout:flush()
end
fh_points:close()
fh_runs:close()
