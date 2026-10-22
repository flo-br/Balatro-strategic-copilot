-- Balatro Strategic Copilot - game/controller.lua
-- Orchestrates: change detection -> snapshot -> analyses (scheduled) -> UI model, plus
-- the event queue fed by Steamodded contexts (observation only).
-- Everything that touches G is guarded; a module that keeps failing is disabled
-- (circuit breaker) while the rest of the mod keeps working.

local BSC = BSCopilot
local U = BSC.require('core/util')
local L = BSC.require('core/log')
local I = BSC.require('core/i18n')
local Sched = BSC.require('core/scheduler')
local SR = BSC.require('game/state_reader')
local Score = BSC.require('engine/score')
local HA = BSC.require('engine/hand_advisor')
local Fmt = BSC.require('ui/format')
local EF = BSC.require('game/event_fallback')
local Advice = BSC.require('engine/advice')
local SY = BSC.require('engine/synergy')
local UT = BSC.require('game/ui_targets')
local FI = BSC.require('game/feedback_input')

local Ctl = {}

Ctl.analyzers = {}       -- phase -> function(state, task, cfg) -> result
Ctl.formatters = {}      -- phase -> function(state, result, detail) -> lines
Ctl.badgers = {}         -- phase -> function(result) -> { [uid] = badge }
Ctl.results = {}         -- phase -> result
Ctl.partial = {}         -- phase -> true while the result is still being refined
Ctl.state = nil          -- last stable snapshot
Ctl.version = 0
Ctl.events = {}          -- queue of observed game events
Ctl.alerts = {}
Ctl.alert_seen = {}
Ctl.failures = {}
Ctl.disabled = {}
Ctl.listeners = {}       -- functions(kind, data) called for transitions/events (recorder)
Ctl.selection = nil      -- exact score of the currently highlighted cards
Ctl.uid_cards = {}       -- uid -> game card object (for badge placement)

local function cfg() return BSC.config or {} end

local function jokers_sig(state)
    local t = {}
    for i, j in ipairs((state and state.jokers) or {}) do t[i] = tostring(j.uid) end
    return table.concat(t, ',')
end

function Ctl.init()
    Ctl.sched = Sched.new()
    Sched.set_util(U)
    local c = cfg()
    Ctl.panel_open = c.ui and c.ui.panel_open or false
    Ctl.detail = not (c.ui and c.ui.detail == false)
    Ctl.show_badges = not (c.ui and c.ui.show_badges == false)
    Ctl.poll_timer = 0
    Ctl.last_sig = nil
    Ctl.last_sel_sig = nil
    Ctl.register('hand', function(state, task, c2)
        local res = HA.analyse(state, { rollouts = c2.compute.rollouts, max_branches = c2.compute.max_branches,
            samples = c2.compute.samples }, task)
        -- joker order on the plays of this hand (the order can be changed at any time)
        local ok, ord = Sched.protected(function()
            local plays = {}
            for i = 1, math.min(6, #(res.plays or {})) do
                local p = res.plays[i]
                if (p.hidden_n or 0) == 0 then plays[#plays + 1] = { played = p.cards, held = HA.minus(state.hand_cards or {}, p.cards) } end
            end
            if #plays == 0 then return nil end
            return SY.best_order(state, { plays = plays }, task)
        end)
        if ok then res.order = ord end
        return res
    end, Fmt.hand_panel, nil)
end

function Ctl.register(phase, analyzer, formatter, badger)
    Ctl.analyzers[phase] = analyzer
    Ctl.formatters[phase] = formatter
    Ctl.badgers[phase] = badger
end

function Ctl.on(listener) Ctl.listeners[#Ctl.listeners + 1] = listener end

local function emit(kind, data)
    for _, f in ipairs(Ctl.listeners) do
        local ok, err = pcall(f, kind, data)
        if not ok then L.error('listener', '%s: %s', kind, tostring(err)) end
    end
end
Ctl.emit = emit

-- circuit breaker
local function guarded(name, f, ...)
    if Ctl.disabled[name] then return nil end
    local ok, a, b = pcall(f, ...)
    if ok then
        Ctl.failures[name] = 0
        return a, b
    end
    Ctl.failures[name] = (Ctl.failures[name] or 0) + 1
    L.error(name, '%s', tostring(a))
    if Ctl.failures[name] >= 5 then
        Ctl.disabled[name] = tostring(a)
        L.error(name, 'module disabled after repeated errors')
        Ctl.alert('disabled:' .. name, I.T('disabled_module', name), 'bad')
    end
    return nil
end
Ctl.guarded = guarded

-- Cheap signature of what matters for the analyses (no snapshot needed).
local function area_sig(area)
    if type(area) ~= 'table' or type(area.cards) ~= 'table' then return '' end
    local t = {}
    for i, c in ipairs(area.cards) do
        -- (Cerulean Bell forces its card after the draw: that must start a new analysis)
        local forced = type(c.ability) == 'table' and c.ability.forced_selection
        t[i] = tostring(c.sort_id or '') .. (c.debuff and 'd' or '') .. (c.facing == 'back' and 'b' or '') .. (forced and 'f' or '')
    end
    return table.concat(t, ',')
end

function Ctl.signature()
    local G = rawget(_G, 'G')
    if not SR.in_run() then return 'out:' .. tostring(G and G.STATE) end
    local GG = G.GAME
    local cr = GG.current_round or {}
    return table.concat({
        SR.phase(), tostring(G.STATE), area_sig(G.hand), area_sig(G.jokers), area_sig(G.consumeables),
        area_sig(G.shop_jokers), area_sig(G.shop_vouchers), area_sig(G.shop_booster), area_sig(G.pack_cards),
        tostring(GG.dollars), tostring(GG.chips), tostring(cr.hands_left), tostring(cr.discards_left),
        tostring(G.deck and G.deck.cards and #G.deck.cards), tostring(GG.round), tostring(GG.won),
        tostring(G.GAME.blind and G.GAME.blind.disabled),
    }, '|')
end

local function selection_sig()
    local G = rawget(_G, 'G')
    if not (G and G.hand and G.hand.highlighted) then return '' end
    local t = {}
    for i, c in ipairs(G.hand.highlighted) do t[i] = tostring(c.sort_id) end
    return table.concat(t, ',')
end

local STABLE = { hand = true, shop = true, blind_select = true, pack = true, round_eval = true, game_over = true, menu = true }

function Ctl.refresh(force)
    local sig = Ctl.signature()
    if not force and sig == Ctl.last_sig then return false end
    local phase = SR.phase()
    if not STABLE[phase] then return false end -- wait for animations to settle
    Ctl.last_sig = sig
    local prev = Ctl.state
    local s = SR.snapshot()
    if BSC.learning_runtime and BSC.learning_runtime.unknown_multipliers then
        local okm, m = pcall(BSC.learning_runtime.unknown_multipliers, s)
        if okm then s.learned_multipliers = m end
    end
    -- event fallback for Steamodded versions that do not call mod.calculate: actions are
    -- rebuilt by comparing snapshots and emitted with the PREVIOUS state as context
    if BSC.events_mode == 'native' and EF.pending_play and (Ctl.native_seen or 0) == 0 then
        BSC.events_mode = 'polling'
        L.info('events', 'no event received from Steamodded: switching to state comparison')
    end
    if BSC.events_mode == 'polling' then
        local okd, evs = pcall(EF.diff, prev, s)
        if okd then
            for _, ev in ipairs(evs) do emit('event', ev) end
        else
            L.warn('events', 'fallback diff failed: %s', tostring(evs))
        end
    else
        EF.pending_play = nil
    end
    Ctl.state = s
    Ctl.version = Ctl.version + 1
    Ctl.selection = nil
    Ctl.last_sel_sig = nil
    emit('state', { prev = prev, state = s })
    -- schedule the analysis of this phase (replacing any stale one)
    for name in pairs(Ctl.analyzers) do
        if name ~= phase then Ctl.sched:cancel(name) end
    end
    local analyzer = Ctl.analyzers[phase]
    if analyzer and not Ctl.disabled[phase] then
        Ctl.results[phase] = nil
        local c = cfg()
        local version = Ctl.version
        Ctl.sched:submit(phase, function(task)
            local t0 = U.now()
            local r = analyzer(s, task, c)
            if type(r) == 'table' then r.jokers_sig = jokers_sig(s) end -- arrangement the order was computed for
            L.timing('analysis_' .. phase, U.now() - t0)
            return r
        end, function(res, err)
            if err then
                Ctl.failures[phase] = (Ctl.failures[phase] or 0) + 1
                L.error(phase, 'analysis failed: %s', tostring(err))
                if Ctl.failures[phase] >= 5 then Ctl.disabled[phase] = tostring(err) end
                return
            end
            if version == Ctl.version then
                Ctl.results[phase] = res
                Ctl.result_ver = (Ctl.result_ver or 0) + 1
                Ctl.partial[phase] = nil
                Ctl.failures[phase] = 0
                emit('analysis', { phase = phase, result = res, state = s })
            end
        end, function(partial)
            if version == Ctl.version then
                Ctl.results[phase] = partial
                Ctl.result_ver = (Ctl.result_ver or 0) + 1
                Ctl.partial[phase] = true
            end
        end)
    end
    return true
end

-- Exact evaluation of the highlighted cards (hand phase), cheap and synchronous.
function Ctl.update_selection()
    if SR.phase() ~= 'hand' or not Ctl.state then return end
    local sig = selection_sig()
    if sig == Ctl.last_sel_sig then return end
    Ctl.last_sel_sig = sig
    Ctl.selection = nil
    if sig == '' then return end
    local s = Ctl.state
    local by_uid = {}
    for _, c in ipairs(s.hand_cards or {}) do by_uid[tostring(c.uid)] = c end
    local played, set = {}, {}
    for uid in sig:gmatch('[^,]+') do
        local c = by_uid[uid]
        if not c then return end
        if c.face_down then return end
        played[#played + 1] = c
        set[c] = true
    end
    local held = {}
    for _, c in ipairs(s.hand_cards) do if not set[c] then held[#held + 1] = c end end
    local r = Score.evaluate(s, played, held, { max_branches = 64, samples = 200 })
    -- cross-check the hand name with the game's own evaluation of the same highlighted cards
    local G = rawget(_G, 'G')
    local CM = BSC.require('game/compat')
    if G and G.hand and G.hand.highlighted then
        local okc, same, native = pcall(CM.cross_check_hand, G.hand.highlighted, played, Score.prepare(s).rules)
        if okc and same == false then
            r.native_hand = native
            r.hand = native
            r.exact = false
            r.complete = false
        end
    end
    local remaining = math.max(0, (s.blind and s.blind.chips_required or 0) - (s.blind and s.blind.chips_scored or 0))
    r.p_win = remaining > 0 and r.p_at_least(remaining) or 1
    r.cards = played
    Ctl.selection = r
end

function Ctl.update(dt)
    if not BSC.config or BSC.config.enabled == false then return end
    Ctl.poll_timer = Ctl.poll_timer + (dt or 0)
    local c = cfg()
    local interval = (c.compute and c.compute.poll_interval) or 0.15
    -- every frame (cheap): the played cards stay in the play area only during the scoring
    guarded('capture', EF.capture)
    if Ctl.poll_timer >= interval then
        Ctl.poll_timer = 0
        guarded('refresh', Ctl.refresh)
        guarded('selection', Ctl.update_selection)
        Ctl.process_events()
    end
    local budget = ((c.compute and c.compute.budget_ms) or 4) / 1000
    guarded('scheduler', function() Ctl.sched:step(budget) end)
    Ctl.tick_alerts(dt or 0)
end

-- Events from SMODS contexts -----------------------------------------------------------------
local WATCH = {
    'setting_blind', 'skip_blind', 'end_of_round', 'buying_card', 'selling_card', 'reroll_shop',
    'open_booster', 'skipping_booster', 'using_consumeable', 'pre_discard', 'before', 'after',
    'ending_shop', 'starting_shop', 'first_hand_drawn', 'playing_card_added',
}

-- Called for EVERY calculate_context: must be cheap and must never alter the game.
function Ctl.observe(context)
    if type(context) ~= 'table' then return end
    Ctl.native_seen = (Ctl.native_seen or 0) + 1
    if context.individual or context.repetition or context.other_card and not context.selling_card and not context.buying_card then
        -- per-card sub-contexts are irrelevant to the decision log
        if not context.pre_discard then return end
    end
    if context.blueprint or context.retrigger_joker then return end
    for _, k in ipairs(WATCH) do
        if context[k] then
            if BSC.events_mode ~= 'native' then
                -- Steamodded does deliver events after all: never mix both sources
                BSC.events_mode = 'native'
                EF.pending_play = nil
            end
            local ev = { kind = k, t = U.now() }
            if k == 'before' or k == 'pre_discard' or k == 'after' then
                ev.uids = {}
                for i, c in ipairs(context.full_hand or {}) do ev.uids[i] = tostring(c.sort_id) end
                ev.scoring_name = context.scoring_name
                local G = rawget(_G, 'G')
                ev.chips_before = G and G.GAME and G.GAME.chips
            elseif context.card then
                local card = context.card
                ev.key = card.config and card.config.center and card.config.center.key
                ev.uid = tostring(card.sort_id)
                ev.cost = card.cost
                ev.sell_cost = card.sell_cost
                ev.set = card.ability and card.ability.set
            elseif context.consumeable then
                local card = context.consumeable
                ev.key = card.config and card.config.center and card.config.center.key
                ev.set = card.ability and card.ability.set
            end
            if k == 'end_of_round' then
                ev.game_over = context.game_over and true or false
                ev.beat_boss = context.beat_boss and true or false
            end
            if k == 'setting_blind' or k == 'skip_blind' then
                local G = rawget(_G, 'G')
                ev.blind = G and G.GAME and G.GAME.blind and G.GAME.blind.config and G.GAME.blind.config.blind and G.GAME.blind.config.blind.key
            end
            -- de-duplicate the same event fired by several areas in the same frame
            local last = Ctl.events[#Ctl.events]
            if not (last and last.kind == ev.kind and last.uid == ev.uid and last.t == ev.t) then
                Ctl.events[#Ctl.events + 1] = ev
            end
            if #Ctl.events > 500 then table.remove(Ctl.events, 1) end
            return
        end
    end
end

function Ctl.process_events()
    if #Ctl.events == 0 then return end
    local evs = Ctl.events
    Ctl.events = {}
    for _, ev in ipairs(evs) do emit('event', ev) end
end

-- Alerts --------------------------------------------------------------------------------------
function Ctl.alert(key, text, class)
    local c = cfg().alerts or {}
    if c.enabled == false then return end
    local now = U.now()
    local seen = Ctl.alert_seen[key]
    if seen and now - seen < (c.cooldown or 25) then return end
    Ctl.alert_seen[key] = now
    Ctl.alerts[#Ctl.alerts + 1] = { key = key, text = text, class = class or 'mid', t = now, ttl = c.duration or 5 }
    if #Ctl.alerts > 3 then table.remove(Ctl.alerts, 1) end
end

function Ctl.tick_alerts()
    local now = U.now()
    for i = #Ctl.alerts, 1, -1 do
        local a = Ctl.alerts[i]
        local age = now - a.t
        if age > a.ttl then table.remove(Ctl.alerts, i)
        else a.alpha = math.min(1, (a.ttl - age) / 0.6) end
    end
end

-- UI model ------------------------------------------------------------------------------------
local function card_rect(card)
    local G = rawget(_G, 'G')
    local T = card.VT or card.T
    if not (T and G and G.ROOM and G.ROOM.T and G.TILESCALE and G.TILESIZE) then return nil end
    local s = G.TILESCALE * G.TILESIZE
    return (T.x + G.ROOM.T.x) * s, (T.y + G.ROOM.T.y) * s, T.w * s, T.h * s
end
Ctl.card_rect = card_rect

local function collect_cards()
    local G = rawget(_G, 'G')
    local map = {}
    if not G then return map end
    for _, area in ipairs({ G.hand, G.jokers, G.consumeables, G.shop_jokers, G.shop_vouchers, G.shop_booster, G.pack_cards }) do
        if type(area) == 'table' and type(area.cards) == 'table' then
            for _, c in ipairs(area.cards) do map[tostring(c.sort_id)] = c end
        end
    end
    return map
end

function Ctl.selection_lines()
    local r = Ctl.selection
    if not r then return nil end
    local seg = function(t, c) return { t = t, c = c } end
    local l = { seg('Sélection : ' .. I.hand_name(r.hand or '?') .. ' ', 'text'), seg(Fmt.score_text(r), 'chips') }
    if r.debuffed_hand then l = { seg('Sélection : ' .. I.hand_name(r.hand or '?') .. ' : 0 (annulée par la blinde)', 'bad') } end
    return { l, { seg(I.T('p_now', I.pct(r.p_win)), Fmt.class_prob(r.p_win)) } }
end

-- Next step (engine/advice.lua) and joker order marks ---------------------------------------

function Ctl.step(phase)
    local s = Ctl.state
    if not s then return nil end
    local result = Ctl.results[phase]
    local key = tostring(phase) .. ':' .. tostring(Ctl.result_ver) .. ':' .. tostring(Ctl.version) .. ':' .. tostring(Ctl.partial[phase])
    if Ctl.step_cache and Ctl.step_cache.key == key then return Ctl.step_cache.step end
    local step, err = Advice.step(phase, s, result, cfg(), Ctl.partial[phase])
    if err then L.warn('advice', '%s', tostring(err)) end
    Ctl.step_cache = { key = key, step = step }
    return step
end

-- the latest joker order computed by any analysis, valid while the jokers stay the same
function Ctl.order_marks()
    local s = Ctl.state
    if not s then return nil end
    local sig = jokers_sig(s)
    for _, ph in ipairs({ 'hand', 'shop', 'blind_select' }) do
        local r = Ctl.results[ph]
        if r and r.order ~= nil and not Ctl.partial[ph] and r.jokers_sig == sig then
            Ctl.order_info = { sig = sig, order = r.order, ver = Ctl.version }
        end
    end
    local oi = Ctl.order_info
    if not oi or oi.sig ~= sig then return nil end
    return Advice.order_marks(s, oi.order, cfg())
end

local function step_lines(step, phase, partial)
    local seg = function(t, c) return { t = t, c = c or 'text' } end
    local out = {}
    if not step then
        if phase == 'hand' or phase == 'shop' or phase == 'pack' or phase == 'blind_select' then
            out[1] = { seg(I.T('todo_wait'), 'dim') }
        end
        return out
    end
    local l = { seg(I.T('todo'), 'title'), seg(step.label .. ' ', step.cls or 'good'), seg('— ' .. (step.text or ''), 'text') }
    if step.use_cards then
        -- cards to select for a tarot / spectral, with their role (Death: which one goes left)
        for i, card in ipairs(step.use_cards) do
            if i > 1 then l[#l + 1] = seg(' + ', 'text') end
            for _, sg in ipairs(Fmt.cards_segments({ card })) do l[#l + 1] = sg end
            local role = step.use_roles and step.use_roles[i]
            if role then l[#l + 1] = seg(' (' .. role .. ')', 'dim') end
        end
    elseif step.cards then
        for _, sg in ipairs(Fmt.cards_segments(step.cards)) do l[#l + 1] = sg end
    end
    out[1] = l
    if step.hint then out[#out + 1] = { seg('  ! ' .. step.hint, 'mid') } end
    local l2 = {}
    if step.hand and step.score then l2[#l2 + 1] = seg('  ' .. I.hand_name(step.hand) .. ' — ' .. Fmt.score_text(step.score) .. '  ', 'chips') end
    if step.target then l2[#l2 + 1] = seg('  ' .. Fmt.target_text(step.target) .. (step.p_complete and (' (' .. I.pct(step.p_complete) .. ')') or '') .. '  ', 'accent') end
    if step.why then l2[#l2 + 1] = seg((#l2 == 0 and '  ' or '') .. step.why, 'dim') end
    if #l2 > 0 then out[#out + 1] = l2 end
    if step.p then
        local cls = Fmt.class_prob(step.p)
        out[#out + 1] = { seg('  ' .. Fmt.mark(cls) .. ' ' .. (step.p_text or '') .. ' : ' .. (step.approx and '≈ ' or '')
            .. Fmt.prob_text(step.p, step.method, step.lo, step.hi), cls) }
    end
    return out
end

local function order_lines(om)
    if not om then return {} end
    local seg = function(t, c) return { t = t, c = c or 'text' } end
    local parts = {}
    for _, m in ipairs(om.marks) do parts[#parts + 1] = m.pos .. '. ' .. tostring(m.name) end
    return { { seg(I.T('order_title', math.floor((om.gain or 0) * 100 + 0.5)), 'accent'), seg(table.concat(parts, '  >  '), 'text') },
        { seg('  ' .. I.T('order_hint'), 'dim') } }
end

function Ctl.ui_model()
    local c = cfg()
    local phase = SR.phase()
    local s = Ctl.state
    local m = { panel_open = Ctl.panel_open, anchor = c.ui and c.ui.anchor, scale = c.ui and c.ui.scale or 1, alerts = Ctl.alerts,
        feedback = FI.model() }
    if phase == 'menu' or phase == 'none' then
        -- history and learning summary, only on demand (panel key) outside a run
        m.compact_lines = nil
        m.lines = nil
        local lr = BSC.learning_runtime
        if Ctl.panel_open and lr and lr.menu_lines then
            local ok, lines = pcall(lr.menu_lines, Ctl.detail)
            if ok then m.lines = lines; m.title = I.T('title') .. ' — Historique' end
        end
        return m
    end
    local view_phase = (phase == 'busy' and Ctl.last_phase) or phase
    Ctl.last_phase = view_phase
    local result = Ctl.results[view_phase]
    local fmt = Ctl.formatters[view_phase]
    -- formatted lines are cached until something they depend on changes
    local cache = Ctl.ui_cache
    local lines
    -- (results are published and then completed in place: the version counter tracks that)
    if cache and cache.phase == view_phase and cache.result == result and cache.ver == Ctl.result_ver
        and cache.state == s and cache.detail == Ctl.detail then
        lines = cache.lines
    else
        lines = {}
        if fmt and s then lines = fmt(s, result, Ctl.detail) or {} end
        Ctl.ui_cache = { phase = view_phase, result = result, ver = Ctl.result_ver, state = s, detail = Ctl.detail, lines = lines }
    end
    local copy = {}
    for i, l in ipairs(lines) do copy[i] = l end
    lines = copy
    local sel = Ctl.selection_lines()
    if sel and view_phase == 'hand' then
        for i = #sel, 1, -1 do table.insert(lines, 1, sel[i]) end
    end
    -- the next step comes first, then the joker order when it should change
    local step = Ctl.step(view_phase)
    local om = Ctl.order_marks()
    local head = step_lines(step, view_phase, Ctl.partial[view_phase])
    for _, l in ipairs(order_lines(om)) do head[#head + 1] = l end
    for i = #head, 1, -1 do table.insert(lines, 1, head[i]) end
    m.title = I.T('title') .. ' — ' .. I.T('phase_' .. view_phase)
    m.lines = lines
    if c.ui == nil or c.ui.show_compact ~= false then
        -- panel closed: the step (and the joker order), plus the score of the player's selection
        local compact = {}
        for i = 1, #head do compact[#compact + 1] = head[i] end
        if sel and view_phase == 'hand' then for _, l in ipairs(sel) do compact[#compact + 1] = l end end
        if #compact == 0 then for i = 1, math.min(#lines, 3) do compact[i] = lines[i] end end
        m.compact_lines = compact
    end
    -- the game's consumable area (top right) must stay visible: the panel goes below it
    local Gm = rawget(_G, 'G')
    if Gm and type(Gm.consumeables) == 'table' then
        local ax, ay, aw, ah = card_rect(Gm.consumeables)
        if ax then m.avoid = { x = ax, y = ay, w = aw, h = ah } end
    end
    local keys = c.keys or {}
    m.footer = I.T('keys_help', (keys.panel or 'c'):upper(), (keys.detail or 'v'):upper(), (keys.badges or 'b'):upper(),
        (keys.my_choice or 'x'):upper())
    -- badges: the step label above what to act on, order numbers under the jokers
    local show_badges = not (c.ui and c.ui.show_badges == false)
    if show_badges then
        local cards = collect_cards()
        m.badges = {}
        local function on_uid(uid, text, class, opts)
            local card = cards[tostring(uid)]
            if not card then return end
            local x, y, w, h = card_rect(card)
            if x then
                local b = { x = x, y = y, w = w, h = h, text = text, class = class }
                for k, v in pairs(opts or {}) do b[k] = v end
                m.badges[#m.badges + 1] = b
            end
        end
        if step then
            local text = step.label .. ((step.note and (step.action == 'buy' or step.action == 'take')) and (' · ' .. step.note .. '/100') or '')
            for _, uid in ipairs(step.targets or {}) do
                on_uid(uid, (step.target_labels and step.target_labels[uid]) or text, step.cls or 'good', { strong = true })
            end
            for uid, lbl in pairs(step.hold_labels or {}) do on_uid(uid, lbl, 'accent', { strong = true }) end
            for _, uid in ipairs(step.use_on or {}) do
                on_uid(uid, (step.use_labels and step.use_labels[uid]) or I.T('lbl_target'), 'accent', { strong = true })
            end
            if step.button then
                local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
                local okb, x, y, w, h = pcall(UT.button_rect, step.button, view_phase, now)
                if okb and x then
                    m.badges[#m.badges + 1] = { x = x, y = y, w = w, h = h, text = step.label, class = step.cls or 'good', strong = true }
                end
            end
        end
        if om then
            for _, mk in ipairs(om.marks) do on_uid(mk.uid, tostring(mk.pos), mk.moved and 'mid' or 'good', { pos = 'below', strong = true }) end
        end
    end
    return m
end

-- key actions
-- "Mon choix": the box reads what the player highlighted (a fresh snapshot: highlights do not
-- start a new analysis) and the advice of the moment (game/feedback_input.lua)
function Ctl.open_feedback()
    if FI.active then return end
    local fresh = SR.snapshot()
    local phase = SR.phase()
    if phase == 'busy' then phase = Ctl.last_phase end
    local ok, why = FI.open(fresh, phase, Ctl.step(phase))
    if not ok then
        Ctl.alert('feedback', I.T(why == 'no_run' and 'fb_no_run' or 'fb_select_first'), 'mid')
    end
end
FI.on_saved = function(changes)
    local txt = (changes and #changes > 0) and table.concat(changes, ' · ') or I.T('fb_kept')
    Ctl.alert('feedback_saved', I.T('fb_saved', txt), 'good')
    -- the notes change with the new preferences: analyse again
    Ctl.version = (Ctl.version or 0) + 1
    Ctl.last_sig = nil
end
function Ctl.toggle_panel() Ctl.panel_open = not Ctl.panel_open end
function Ctl.toggle_detail() Ctl.detail = not Ctl.detail end
function Ctl.toggle_badges()
    local c = cfg()
    c.ui = c.ui or {}
    c.ui.show_badges = (c.ui.show_badges == false)
    Ctl.show_badges = c.ui.show_badges
end

return Ctl
