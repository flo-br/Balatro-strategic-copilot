-- Balatro Strategic Copilot - tools/trainer/player.lua
-- A "player" who does exactly what the copilot says: at every moment the copilot's analysis
-- of the current phase runs on the simulated state, engine/advice.lua gives the step, and the
-- player performs it (play, discard, use with targets, buy, sell, reroll, next blind, take or
-- skip a pack card, play or skip a blind, reorder the jokers along the order numbers).
-- When the copilot gives no step, the fallback is logged as an anomaly (a gap to fix).

local BSC = BSCopilot
local U = BSC.require('core/util')
local HA = BSC.require('engine/hand_advisor')
local SH = BSC.require('engine/shop')
local O = BSC.require('engine/outlook')
local SY = BSC.require('engine/synergy')
local A = BSC.require('engine/advice')
local Sched = BSC.require('core/scheduler')

local Player = {}
Player.__index = Player

function Player.new(cfg, opts)
    local p = setmetatable({}, Player)
    p.cfg = cfg
    p.opts = opts or {}
    p.anomalies = {}
    p.decisions = {}
    p.timing = { hand = 0, shop = 0, pack = 0, blind_select = 0 }
    return p
end

function Player:anomaly(g, what, detail)
    self.anomalies[#self.anomalies + 1] = { ante = g.ante, round = g.round, what = what, detail = detail }
end

-- Analyses, as the controller runs them (game/controller.lua, game/register_strategy.lua)
function Player:analyse(phase, st)
    local c = self.cfg.compute
    local t0 = os.clock()
    local res
    if phase == 'hand' then
        res = HA.analyse(st, { rollouts = c.rollouts, max_branches = c.max_branches, samples = c.samples })
        local ok, ord = pcall(function()
            local plays = {}
            for i = 1, math.min(6, #(res.plays or {})) do
                local pl = res.plays[i]
                if (pl.hidden_n or 0) == 0 then plays[#plays + 1] = { played = pl.cards, held = HA.minus(st.hand_cards or {}, pl.cards) } end
            end
            if #plays == 0 then return nil end
            return SY.best_order(st, { plays = plays })
        end)
        if ok then res.order = ord end
    elseif phase == 'shop' then
        res = SH.analyse(st, { n = math.max(24, math.floor((c.shop_samples or 120) / 2.5)) })
    elseif phase == 'pack' then
        res = SH.analyse(st, { n = 32, pack_items = (st.pack and st.pack.cards) or {} })
    elseif phase == 'blind_select' then
        res = O.analyse(st, { samples = math.floor((c.shop_samples or 120) / 2), rollouts = math.max(24, math.floor((c.rollouts or 64) * 0.75)),
            cfg = self.cfg })
    end
    self.timing[phase] = self.timing[phase] + (os.clock() - t0)
    return res
end

function Player:step(phase, st, res)
    local step, err = A.step(phase, st, res, self.cfg, false)
    return step, err
end

-- the player follows the joker order numbers
function Player:follow_order(g, st, res)
    local om = res and res.order and A.order_marks(st, res.order, self.cfg)
    if not om then return false end
    local uids = {}
    table.sort(om.marks, function(a, b) return a.pos < b.pos end)
    for i, m in ipairs(om.marks) do uids[i] = m.uid end
    if g:reorder(uids) then
        self:decision(g, 'reorder', { gain = om.gain })
        return true
    end
    return false
end

function Player:decision(g, kind, data)
    data = data or {}
    data.kind, data.ante, data.round = kind, g.ante, g.round
    self.decisions[#self.decisions + 1] = data
end

-- One blind: the copilot plays it to the end. Returns 'won' | 'lost'.
function Player:play_blind(g)
    local reorders = 0
    for _ = 1, 80 do
        local b = g.blind
        if b.scored >= b.chips then return 'won' end
        if b.hands_left <= 0 then
            if g:check_loss() then return 'lost' end
            return 'won'
        end
        local st = g:snapshot('hand')
        local res = self:analyse('hand', st)
        if reorders < 2 and self:follow_order(g, st, res) then
            reorders = reorders + 1
            st = g:snapshot('hand')
            res = self:analyse('hand', st)
        end
        local step = self:step('hand', st, res)
        local done = false
        if step then
            if step.action == 'play' then
                if os.getenv('BSC_TRAIN_VERBOSE') then
                    local Fm = BSC.require('ui/format')
                    local cards = {}
                    for _, c in ipairs(st.hand_cards) do cards[#cards + 1] = Fm.card_label(c) .. (c.debuff and '(x)' or '') end
                    io.stderr:write(string.format('[a%d r%d %s] %d/%d h%d d%d hand: %s | play %s (mean %s, p %s)\n', g.ante, g.round,
                        g.blind.key, math.floor(g.blind.scored), g.blind.chips, g.blind.hands_left, g.blind.discards_left,
                        table.concat(cards, ' '), table.concat((function() local t = {} for i, c in ipairs(step.cards or (step.targets or {})) do t[i] = type(c) == 'table' and Fm.card_label(c) or tostring(c) end return t end)(), ' '),
                        tostring(step.score and step.score.mean or (res.recommendation and res.recommendation.ref and res.recommendation.ref.mean)),
                        tostring(step.p)))
                end
                local s = g:play(step.targets)
                if os.getenv('BSC_TRAIN_VERBOSE') then io.stderr:write('   -> scored ' .. tostring(s) .. '\n') end
                done = s ~= nil
                if done then self:decision(g, 'play', { p = step.p, score = s }) end
            elseif step.action == 'discard' then
                if os.getenv('BSC_TRAIN_VERBOSE') then
                    local Fm = BSC.require('ui/format')
                    local cards = {}
                    for _, c in ipairs(st.hand_cards) do cards[#cards + 1] = Fm.card_label(c) end
                    io.stderr:write(string.format('[a%d r%d %s] %d/%d h%d d%d hand: %s | DISCARD %d cards (p %s)\n', g.ante, g.round,
                        g.blind.key, math.floor(g.blind.scored), g.blind.chips, g.blind.hands_left, g.blind.discards_left,
                        table.concat(cards, ' '), #step.targets, tostring(step.p)))
                end
                done = g:discard(step.targets) ~= nil
                if done then self:decision(g, 'discard', { p = step.p }) end
            elseif step.action == 'use' then
                done = g:use(step.targets[1], step.use_on) ~= nil
                if done then self:decision(g, 'use', { key = step.key or step.text }) end
            elseif step.action == 'sell' then
                done = g:sell(step.targets[1]) ~= nil
                if done then self:decision(g, 'sell', { text = step.text }) end
            end
        end
        if not done then
            -- no usable step: play the best play of the analysis
            self:anomaly(g, 'hand_fallback', step and (step.action .. ' ' .. tostring(step.text)) or 'no step')
            local bp = res and res.best_play
            local uids = {}
            if bp then for i, c in ipairs(bp.cards) do uids[i] = c.uid end
            else for i = 1, math.min(5, #b.hand) do uids[i] = b.hand[i].uid end end
            if not g:play(uids) then
                uids = {}
                for i = 1, math.min(5, #b.hand) do uids[i] = b.hand[i].uid end
                g:play(uids)
            end
        end
    end
    self:anomaly(g, 'blind_loop', g.blind.key)
    return 'lost'
end

-- An open pack: take / sell / skip as advised
function Player:play_pack(g)
    for _ = 1, 12 do
        if not g.pack then return end
        local st = g:snapshot('pack')
        local res = self:analyse('pack', st)
        local step = self:step('pack', st, res)
        local ok = false
        if step then
            if step.action == 'take' then
                ok = g:take(step.targets[1], step.use_on) ~= nil
                if ok then self:decision(g, 'take', { name = step.text, note = step.note }) end
            elseif step.action == 'sell' then
                ok = g:sell(step.targets[1]) ~= nil
                if ok then self:decision(g, 'sell', { text = step.text, where = 'pack' }) end
            elseif step.action == 'skip_pack' then
                ok = g:skip_pack()
                self:decision(g, 'skip_pack', {})
            end
        end
        if not ok then
            self:anomaly(g, 'pack_fallback', step and (step.action .. ' ' .. tostring(step.text)) or 'no step')
            g:skip_pack()
        end
    end
    if g.pack then self:anomaly(g, 'pack_loop', g.pack.kind); g:skip_pack() end
end

-- what the mod's recorder keeps at each shop (learning/recorder.lua): the review reads it
function Player:record_build(g, st, res)
    self.power = self.power or {}
    self.builds = self.builds or {}
    local med = res.base and res.base.median
    local last = self.power[#self.power]
    if med then
        if not last or last.ante ~= g.ante then self.power[#self.power + 1] = { ante = g.ante, round = g.round, median = med }
        else last.median = med end
    end
    local pl = res.plan
    if pl then
        local main = pl.main_hand and st.hands[pl.main_hand]
        self.builds[#self.builds + 1] = { ante = g.ante, round = g.round, dollars = g.dollars, cap = g.interest_cap,
            xmult = pl.xmult, xmult_target = pl.xmult_target, gap_xmult = pl.gaps.xmult and true or nil,
            gap_power = pl.gaps.power and true or nil, main_hand = pl.main_hand, main_level = main and main.level,
            jokers = #g.jokers, slots = g.joker_slots, p_boss = res.base and res.base.p_boss, p_win = res.base and res.base.p_win,
            median = med, falling_behind = pl.falling_behind, offers = {} }
        -- what the shop offered (for the analysis of the training runs)
        local b = self.builds[#self.builds]
        for i = 1, math.min(5, #(res.options or {})) do
            local o = res.options[i]
            b.offers[i] = { name = o.name or o.key, kind = o.kind, note = o.note, cost = o.cost }
        end
    end
end

function Player:play_shop(g)
    g:open_shop()
    local recorded = false
    for _ = 1, 40 do
        local st = g:snapshot('shop')
        local res = self:analyse('shop', st)
        if not recorded then self:record_build(g, st, res); recorded = true end
        self:follow_order(g, st, res)
        local step = self:step('shop', st, res)
        if not step then self:anomaly(g, 'shop_no_step'); break end
        local ok, why = true, nil
        if step.action == 'buy' then
            ok, why = g:buy(step.targets[1])
            if ok then self:decision(g, 'buy', { name = step.text, note = step.note, why = step.why }) end
            if ok and g.pack then self:play_pack(g) end
        elseif step.action == 'sell' then
            ok, why = g:sell(step.targets[1])
            if ok then self:decision(g, 'sell', { text = step.text, why = step.why }) end
        elseif step.action == 'use' then
            local c = g.consumables and (function() for _, x in ipairs(g.consumables) do if tostring(x.uid) == tostring(step.targets[1]) then return x end end end)()
            ok, why = g:use(step.targets[1], step.use_on)
            if ok then self:decision(g, 'use', { text = step.text, key = c and c.key }) end
        elseif step.action == 'reroll' then
            ok, why = g:reroll()
            if ok then self:decision(g, 'reroll', { why = step.why }) end
        elseif step.action == 'next_round' then
            self:decision(g, 'next_round', { why = step.why, dollars = g.dollars })
            break
        else
            ok, why = nil, 'unknown action ' .. tostring(step.action)
        end
        if not ok then
            self:anomaly(g, 'shop_invalid', step.action .. ' ' .. tostring(step.text) .. ' : ' .. tostring(why))
            break
        end
    end
    g.shop = nil
end

-- A whole run. Returns a summary.
function Player:play_run(g)
    for _ = 1, 200 do
        if g.won or g.lost then break end
        -- blind selection
        local st = g:snapshot('blind_select')
        local res = self:analyse('blind_select', st)
        local step = self:step('blind_select', st, res)
        local cur = g:current_blind_entry()
        if step and step.action == 'skip_blind' and cur and not cur.boss then
            self:decision(g, 'skip', { tag = g.blind_tags[cur.slot], p = step.p })
            g:skip_blind()
            if g.pending_pack then
                local pk = g.pending_pack
                g.pending_pack = nil
                g:open_pack(pk)
                self:play_pack(g)
            end
        else
            if not step then self:anomaly(g, 'blind_no_step') end
            g:start_blind()
            g.blind.p_pred = res and res.p_current and res.p_current.p
            local out = self:play_blind(g)
            if out == 'lost' then
                g.lost = true
                g.lost_to = { key = g.blind.key, name = g.blind.name, ante = g.ante, required = g.blind.chips, scored = g.blind.scored,
                    p_pred = g.blind.p_pred }
                g:end_round(false)
                break
            end
            g:end_round(true)
            if g.won then break end
            self:play_shop(g)
        end
    end
    return {
        seed = g.seed, won = g.won, ante = g.ante, lost_to = g.lost_to, dollars = g.dollars,
        jokers = (function() local t = {} for i, j in ipairs(g.jokers) do t[i] = j.key .. (j.edition and ('/' .. j.edition) or '') end return t end)(),
        hands = (function()
            local t = {}
            for name, h in pairs(g.hands) do if h.level > 1 or (h.played or 0) > 0 then t[name] = { level = h.level, played = h.played } end end
            return t
        end)(),
        deck_size = #g.cards, vouchers = g.vouchers, history = g.history, decisions = self.decisions, anomalies = self.anomalies,
        power = self.power, builds = self.builds,
        timing = self.timing, stats = g.stats,
    }
end

return Player
