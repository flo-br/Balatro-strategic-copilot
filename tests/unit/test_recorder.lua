local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    local Rec = BSCopilot.require('learning/recorder')
    return F, C, Rec
end

local function st(F, C, o)
    local s = F.state(o)
    s.run.seed = o.seed or 'SEED'
    s.run.round = o.round or 1
    s.blind.chips_scored = o.scored or 0
    s.blind.key = o.blind_key or 'bl_small'
    s.blind.name = 'Small Blind'
    s.meta = { game_version = '1.0.1o' }
    s.econ.dollars = o.dollars or 4
    return s
end

function S.full_round_is_recorded(T)
    local F, C, Rec = env()
    local t = 100
    local rec = Rec.new({ now = function() t = t + 1; return t end, version = 'test' })
    local hand = C.parse_list('Ah Ad 7c 9s 2h Kh 5d 3c')
    for i, c in ipairs(hand) do c.uid = 'u' .. i end
    -- 1. blind selection result then hand phase
    local s1 = st(F, C, { phase = 'hand', hand_cards = hand, required = 300 })
    s1.phase = 'hand'
    local results = { blind_select = { current = { key = 'bl_small' }, p_current = { p = 0.8 } },
        hand = { round = { p_clear = 0.75 }, recommendation = { type = 'play', ref = { uids = { 'u1', 'u2' } }, p_clear = 0.75 },
            candidates = { { type = 'play', ref = { uids = { 'u1', 'u2' } }, p_clear = 0.75 } } } }
    rec:on_state(nil, s1, results)
    T.ok(rec.run, 'run started')
    T.eq(#rec.run.blinds, 1); T.eq(rec.run.blinds[1].p_pred, 0.8)
    -- 2. the player plays the recommended pair
    rec:on_event({ kind = 'before', uids = { 'u1', 'u2' }, scoring_name = 'Pair', chips_before = 0 }, { results = results, state = s1 })
    T.eq(#rec.run.hands, 1)
    T.eq(rec.run.hands[1].predicted, 64); T.ok(rec.run.hands[1].exact); T.ok(rec.run.hands[1].followed)
    -- 3. score lands, round evaluated
    local s2 = st(F, C, { scored = 64, required = 300 }); s2.phase = 'hand'
    rec:on_state(s1, s2, results)
    T.eq(rec.run.hands[1].actual, 64)
    local s3 = st(F, C, { scored = 320, required = 300 }); s3.phase = 'round_eval'
    rec:on_state(s2, s3, results)
    T.eq(rec.run.blinds[1].cleared, true)
    T.eq(rec.run.hands[1].blind_cleared, true)
    -- 4. shop: buy the best option
    local s4 = st(F, C, { round = 1 }); s4.phase = 'shop'
    local shop_results = { shop = { options = { { uid = 'j1', key = 'j_duo', note = 82, name = 'The Duo' }, { uid = 'j2', key = 'j_joker', note = 60 } }, danger = 0.1 } }
    rec:on_state(s3, s4, shop_results)
    rec:on_event({ kind = 'buying_card', key = 'j_duo', uid = 'j1', cost = 8 }, { results = shop_results, state = s4 })
    local d = rec.run.decisions[#rec.run.decisions]
    T.eq(d.kind, 'buying_card'); T.ok(d.followed); T.eq(d.chosen_note, 82)
    -- the log is JSON-serializable (no cycles)
    local J = BSCopilot.require('core/json')
    local ok, txt = pcall(J.encode, rec.run)
    T.ok(ok, 'serializable: ' .. tostring(txt))
end

function S.game_over_finishes_run(T)
    local F, C, Rec = env()
    local rec = Rec.new()
    local s1 = st(F, C, { required = 300 }); s1.phase = 'hand'
    rec:on_state(nil, s1, {})
    rec:on_event({ kind = 'end_of_round', game_over = true }, { results = {}, state = s1 })
    local s2 = st(F, C, {}); s2.phase = 'game_over'
    local finished = rec:on_state(s1, s2, {})
    T.ok(finished, 'run finished')
    T.eq(finished.blinds[1].cleared, false)
    T.eq(finished.end_reason, 'lost')
    T.eq(rec.run, nil)
end

function S.new_seed_abandons_previous_run(T)
    local F, C, Rec = env()
    local rec = Rec.new()
    local s1 = st(F, C, { seed = 'A' }); s1.phase = 'hand'
    rec:on_state(nil, s1, {})
    local s2 = st(F, C, { seed = 'B' }); s2.phase = 'hand'
    local finished = rec:on_state(s1, s2, {})
    T.ok(finished); T.eq(finished.end_reason, 'abandoned')
    T.ok(rec.run and rec.run.seed == 'B')
end

return S
