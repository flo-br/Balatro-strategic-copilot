-- Performance measurements (printed) with generous bounds (machines differ).
-- The key fluidity metric is the longest single scheduler slice: the game only
-- waits for one slice per frame.
local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    return F, C
end

local function clock() return os.clock() end

local REPORT = {}
local function report(name, v, unit) REPORT[#REPORT + 1] = string.format('    %-46s %9.2f %s', name, v, unit or 'ms') end

local function heavy_state(F, C, phase)
    local jokers = {}
    for _, k in ipairs({ 'j_joker', 'j_greedy_joker', 'j_scary_face', 'j_hack', 'j_blueprint', 'j_cavendish', 'j_baron', 'j_misprint' }) do
        jokers[#jokers + 1] = F.joker(k)
    end
    local hand = C.parse_list('Ah Ad 7c 9s 2h Kh 5d 3c')
    local deck = {}
    local used = {}
    for _, c in ipairs(hand) do used[c.rank .. c.suit] = true end
    for _, c in ipairs(C.standard_deck()) do if not used[c.rank .. c.suit] then deck[#deck + 1] = c end end
    local s = F.state({ jokers = jokers, joker_slots = 8, hand_cards = hand, deck = deck, required = 3000, phase = phase })
    s.full_deck = C.standard_deck()
    s.round.round_hands, s.round.round_discards, s.round.hand_size = 4, 3, 8
    s.upcoming = { { slot = 'Small', key = 'bl_small', chips = 3000, state = 'Select' },
        { slot = 'Boss', key = 'bl_club', chips = 6000, boss = true, state = 'Upcoming' } }
    return s, hand
end

function S.exact_hand_evaluation(T)
    local F, C = env()
    local Score = BSCopilot.require('engine/score')
    local R = BSCopilot.require('core/rng')
    local s, hand = heavy_state(F, C)
    s.jokers[8] = F.joker('j_joker') -- remove Misprint (random) for a deterministic eval
    local P = Score.prepare(s)
    local rng = R.new(1)
    local n = 2000
    local t0 = clock()
    for _ = 1, n do Score.quick(P, { hand[1], hand[2] }, { hand[3], hand[4], hand[5] }, rng, 1) end
    local per = (clock() - t0) / n * 1000
    report('score exact (8 jokers)', per)
    T.ok(per < 1.0, string.format('%.3f ms per evaluation', per))
end

function S.snapshot_read(T)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    FG.install({ mod_root = T.MOD_ROOT })
    local SR = BSCopilot.require('game/state_reader')
    local n = 200
    local t0 = clock()
    for _ = 1, n do SR.snapshot() end
    local per = (clock() - t0) / n * 1000
    report('snapshot (lecture de l\'état)', per)
    T.ok(per < 10, string.format('%.2f ms', per))
    FG.uninstall()
end

local function run_sliced(name, fn, budget)
    local Sched = BSCopilot.require('core/scheduler')
    local sch = Sched.new(os.clock)
    local result
    sch:submit(name, fn, function(r, err) result = r or err end)
    local max_slice, total, slices = 0, 0, 0
    while sch:busy() do
        local t0 = clock()
        sch:step(budget)
        local dt = clock() - t0
        total = total + dt
        slices = slices + 1
        if dt > max_slice then max_slice = dt end
    end
    return result, total * 1000, max_slice * 1000, slices
end

function S.hand_analysis_sliced(T)
    local F, C = env()
    local HA = BSCopilot.require('engine/hand_advisor')
    local s = heavy_state(F, C)
    local res, total, max_slice, slices = run_sliced('hand', function(task) return HA.analyse(s, { rollouts = 64 }, task) end, 0.004)
    T.ok(type(res) == 'table' and res.recommendation, 'analysis completed: ' .. tostring(res))
    report('analyse de main complète (CPU total)', total)
    report('  tranche maximale (budget 4 ms)', max_slice)
    report('  nombre de tranches', slices, '')
    T.ok(total < 8000, 'total ' .. total)
    T.ok(max_slice < 25, string.format('longest slice %.1f ms', max_slice))
end

function S.shop_analysis_sliced(T)
    local F, C = env()
    local SH = BSCopilot.require('engine/shop')
    local s = heavy_state(F, C, 'shop')
    s.jokers = { s.jokers[1], s.jokers[2], s.jokers[6] }
    s.joker_slots = 5
    s.shop = { jokers = {
        { set = 'Joker', key = 'j_duo', name = 'The Duo', cost = 8, uid = 'a', joker = F.joker('j_duo') },
        { set = 'Planet', key = 'c_mercury', name = 'Mercury', cost = 3, uid = 'b', hand_type = 'Pair' } },
        vouchers = { { set = 'Voucher', key = 'v_grabber', name = 'Grabber', cost = 10, uid = 'c' } }, boosters = {} }
    -- n as in the game (register_strategy: shop_samples 60 / 2.5 = 24 since 1.0.11)
    local res, total, max_slice, slices = run_sliced('shop', function(task) return SH.analyse(s, { n = 24 }, task) end, 0.004)
    T.ok(type(res) == 'table' and res.options, 'shop analysis completed: ' .. tostring(res))
    report('analyse de boutique complète (CPU total)', total)
    report('  tranche maximale (budget 4 ms)', max_slice)
    T.ok(total < 15000, 'total ' .. total)
    T.ok(max_slice < 40, string.format('longest slice %.1f ms', max_slice))
end

function S.persistence_save(T)
    local P = BSCopilot.require('io/persistence')
    local LE = BSCopilot.require('learning/learning')
    local st = P.new(P.memory_backend()); st:init()
    local prof = LE.new_profile(0)
    for i = 1, 2000 do prof.calibration.blind.pairs[i] = { (i % 100) / 100, i % 2, i } end
    local t0 = clock()
    st:save('profile', LE.SCHEMA, prof)
    local ms = (clock() - t0) * 1000
    report('sauvegarde du profil (2000 paires)', ms)
    T.ok(ms < 500, ms)
end

function S.zz_print_report(T)
    io.write('\n  Mesures de performance (' .. ((jit and jit.version) or _VERSION) .. ') :\n')
    for _, l in ipairs(REPORT) do io.write(l .. '\n') end
end

return S
