-- Balatro Strategic Copilot - engine/advice.lua  (next step)
-- Turns the analyses into ONE action to do now, so that the player is never lost: after each of
-- the player's actions the state changes, everything is recomputed and the next step appears.
-- A step names what to act on (cards, jokers, consumables, shop items: by uid; game buttons: by
-- kind) and the label shown above it. The player always performs the action: nothing here
-- touches the game.
--
-- step = { action, label, targets = {uid...}, use_on = {uid...}, button = kind|nil,
--          text, why, p = probability|nil, p_text, cls = 'good'|'mid'|'bad' }

local BSC = BSCopilot
local I = BSC.require('core/i18n')
local IT = BSC.require('model/items_db')
local E = BSC.require('engine/economy')

local A = {}

A.DEFAULTS = {
    buy_note = 56,                 -- shop / pack: an item is worth taking from this note (/100, 50 = neutral)
    sell_note = 60,                -- pure sale: from this note, and only if the joker brings almost nothing
    sell_max_contribution = 0.03,  -- ... at most 3 % of the score
    order_min_gain = 0.01,         -- joker order shown only if the right order scores 1 % more
    luchador_below = 0.80,         -- sell Luchador against a boss when the chances are below 80 %
}

local function settings(cfg)
    local a = (cfg and cfg.advice) or {}
    local out = {}
    for k, v in pairs(A.DEFAULTS) do out[k] = (a[k] ~= nil) and a[k] or v end
    return out
end
A.settings = settings

local function T(k, ...) return I.T(k, ...) end
local function dollars(state) return (state.econ and state.econ.dollars) or 0 end
local function floor_money(state) return (state.econ and state.econ.bankrupt_at) or 0 end

local function card_value(c)
    local v = (c.nominal or 0) + (c.bonus or 0) + (c.perma_bonus or 0) + 6 * ((c.mult or 0) + (c.perma_mult or 0))
    if (c.x_mult or 1) > 1 then v = v + 40 * (c.x_mult - 1) end
    if c.enh then v = v + 5 end
    return v
end

local function uids(list)
    local out = {}
    for i, c in ipairs(list or {}) do out[i] = c.uid end
    return out
end

local function contains(list, x)
    for _, v in ipairs(list or {}) do if v == x then return true end end
    return false
end

-- Consumables -------------------------------------------------------------------------------
-- Planets level a hand up for good: use them, unless Observatory makes holding them better.
-- Money tarots: The Hermit (doubles money, max +20 $), Temperance (sum of joker sell values).
-- Card tarots (enhancement or suit) are only advised in hand / Arcana pack, where the cards
-- they apply to are in hand; their targets follow the hand recommendation.
function A.card_targets(info, hand, play_cards, discard_cards)
    local sim = info and info.sim
    if not sim then return nil end
    local n = sim.n or 1
    local visible = {}
    for _, c in ipairs(hand or {}) do if not c.face_down and not c.debuff then visible[#visible + 1] = c end end
    if #visible == 0 then return nil end
    local function top(list, k)
        table.sort(list, function(a, b)
            local va, vb = card_value(a), card_value(b)
            if va ~= vb then return va > vb end
            return tostring(a.uid) < tostring(b.uid)
        end)
        local out = {}
        for i = 1, math.min(k, #list) do out[i] = list[i] end
        return out
    end
    if sim.enhance == 'm_steel' or sim.enhance == 'm_gold' then
        -- held-in-hand effects: a card that stays in hand
        local held = {}
        for _, c in ipairs(visible) do if not contains(play_cards, c) and not c.enh then held[#held + 1] = c end end
        local t = top(held, n)
        return #t > 0 and t or nil
    end
    if sim.enhance == 'm_stone' then return nil end -- no clear general use: left to the player
    if sim.enhance then
        -- scoring effects: cards about to be played (or kept for the next play when discarding)
        local pool = {}
        local src = play_cards and #play_cards > 0 and play_cards or nil
        for _, c in ipairs(src or visible) do
            if not c.face_down and not c.enh and not (discard_cards and contains(discard_cards, c)) then pool[#pool + 1] = c end
        end
        local t = top(pool, n)
        return #t > 0 and t or nil
    end
    if sim.suit then
        -- suit change: only toward a suit the deck already favours (flush building)
        local counts = {}
        for _, c in ipairs(visible) do if c.suit then counts[c.suit] = (counts[c.suit] or 0) + 1 end end
        local best, best_n = nil, -1
        for s, k in pairs(counts) do if k > best_n then best, best_n = s, k end end
        if best ~= sim.suit or best_n < 2 then return nil end
        local others = {}
        for _, c in ipairs(visible) do if c.suit ~= sim.suit and not (c.enh == 'm_wild') then others[#others + 1] = c end end
        local t = top(others, n)
        return #t > 0 and t or nil
    end
    return nil
end

function A.consumable_step(state, phase, ctx)
    ctx = ctx or {}
    local observatory = state.vouchers and state.vouchers.v_observatory
    for _, c in ipairs(state.consumables or {}) do
        if not c.debuff then
            if c.set == 'Planet' and not observatory then
                return { action = 'use', label = T('lbl_use'), targets = { c.uid },
                    text = T('step_use_planet', c.name or c.key or '?', I.hand_name(c.hand_type or '?')),
                    why = T('why_planet'), cls = 'good' }
            end
            if c.key == 'c_black_hole' then
                return { action = 'use', label = T('lbl_use'), targets = { c.uid },
                    text = T('step_use', c.name or 'Black Hole'), why = T('why_black_hole'), cls = 'good' }
            end
            local info = IT.consumable(c.key)
            if info and info.money == 'double' and dollars(state) >= 4 then
                return { action = 'use', label = T('lbl_use'), targets = { c.uid },
                    text = T('step_use', c.name or c.key), why = T('why_hermit', math.min(20, dollars(state))), cls = 'good' }
            end
            if info and info.money == 'sell_values' then
                local sv = 0
                for _, j in ipairs(state.jokers or {}) do sv = sv + (j.sell_cost or 0) end
                if sv >= 3 then
                    return { action = 'use', label = T('lbl_use'), targets = { c.uid },
                        text = T('step_use', c.name or c.key), why = T('why_temperance', math.min(50, sv)), cls = 'good' }
                end
            end
            if (phase == 'hand') and info and info.sim and (info.sim.enhance or info.sim.suit) then
                local t = A.card_targets(info, state.hand_cards, ctx.play_cards, ctx.discard_cards)
                if t then
                    local names = {}
                    for i, card in ipairs(t) do names[i] = card end
                    return { action = 'use', label = T('lbl_use'), targets = { c.uid }, use_on = uids(t), use_cards = names,
                        text = T('step_use_on', c.name or c.key), why = T('why_tarot_cards'), cls = 'good' }
                end
            end
        end
    end
    return nil
end

-- Hand -----------------------------------------------------------------------------------------
local function owned(state, key)
    for k, j in ipairs(state.jokers or {}) do if j.key == key and not j.debuff then return j, k end end
end

function A.hand_step(state, r, cfg)
    local S = settings(cfg)
    if not r or r.empty then return nil end
    local rec = r.recommendation
    local play = rec and rec.type == 'play' and (rec.ref and rec.ref.cards or rec.cards) or nil
    local disc = rec and rec.type == 'discard' and rec.cards or nil
    -- Luchador: selling it disables the boss effect for this round
    local blind = state.blind or {}
    local lu = owned(state, 'j_luchador')
    if lu and blind.boss and not blind.disabled and r.round and r.round.p_clear and r.round.p_clear < S.luchador_below then
        return { action = 'sell', label = T('lbl_sell'), targets = { lu.uid }, text = T('step_sell', lu.name or 'Luchador'),
            why = T('why_luchador'), p = r.round.p_clear, p_text = T('p_blind_now'), cls = 'mid' }
    end
    local use = A.consumable_step(state, 'hand', { play_cards = play, discard_cards = disc })
    if use then return use end
    if not rec then return nil end
    local p = r.round and r.round.p_clear
    local approx = r.coverage and r.coverage.unsupported and #r.coverage.unsupported > 0 or nil
    if rec.type == 'play' and play then
        return { action = 'play', label = T('lbl_play'), targets = uids(play), cards = play, text = T('step_play'),
            hand = rec.ref and rec.ref.hand, score = rec.ref, p = p, p_text = T('p_blind'), cls = 'good', approx = approx,
            lo = r.round and r.round.lo, hi = r.round and r.round.hi, method = r.round and r.round.method }
    elseif rec.type == 'discard' and disc then
        return { action = 'discard', label = T('lbl_discard'), targets = uids(disc), cards = disc, text = T('step_discard'),
            target = rec.ref and rec.ref.target, p_complete = rec.ref and rec.ref.p_complete, p = p, p_text = T('p_blind'),
            cls = 'mid', approx = approx, lo = r.round and r.round.lo, hi = r.round and r.round.hi, method = r.round and r.round.method }
    end
    return nil
end

-- Shop -----------------------------------------------------------------------------------------
local function weakest_consumable(state)
    local worst, worst_v
    for _, c in ipairs(state.consumables or {}) do
        local info = IT.consumable(c.key)
        local v = (c.set == 'Planet') and 4 or ((info and info.v) or 3)
        if not worst or v < worst_v then worst, worst_v = c, v end
    end
    return worst
end

local function is_consumable(o)
    return o.kind == 'planet' or o.kind == 'tarot' or o.kind == 'spectral'
end

function A.shop_step(state, r, cfg, partial)
    local S = settings(cfg)
    if not r or partial or not r.options then return nil end
    local money, floor = dollars(state), floor_money(state)
    -- 1. consumables worth using now (planets, money tarots)
    local use = A.consumable_step(state, 'shop')
    if use then return use end
    -- 2. Invisible Joker ready: selling it duplicates a random joker
    for _, j in ipairs(state.jokers or {}) do
        if j.key == 'j_invisible' and not j.debuff then
            local ab = j.ability or {}
            local need = (type(ab.extra) == 'number' and ab.extra) or 2
            if type(ab.invis_rounds) == 'number' and ab.invis_rounds >= need and #(state.jokers or {}) >= 2 then
                return { action = 'sell', label = T('lbl_sell'), targets = { j.uid }, text = T('step_sell', j.name or 'Invisible Joker'),
                    why = T('why_invisible'), cls = 'good' }
            end
        end
    end
    -- 3. the best purchase worth making (replacement first needs a sale)
    local best
    for _, o in ipairs(r.options) do
        if (o.note or 0) >= S.buy_note and not o.blocked then
            local cost = o.cost or 0
            if o.kind == 'replace' then
                -- o.cost is already net of the sale of the replaced joker
                local old = state.jokers and state.jokers[o.replace_index]
                if old and money - cost >= floor then best = o; break end
            elseif money - cost >= floor then
                best = o; break
            end
        end
    end
    if best then
        local p, p_text = nil, nil
        if best.d_boss and r.boss then p, p_text = best.p_boss, T('p_boss_after') elseif best.d_next then p, p_text = best.p_next, T('p_next_after') end
        if best.kind == 'replace' then
            local old = state.jokers[best.replace_index]
            return { action = 'sell', label = T('lbl_sell'), targets = { old.uid }, text = T('step_sell_for', old.name or '?', best.name or '?'),
                why = T('why_replace', best.note or 0), p = p, p_text = p_text, cls = 'mid', note = best.note }
        end
        if is_consumable(best) and #(state.consumables or {}) >= (state.consumable_slots or 2) then
            local weak = weakest_consumable(state)
            if weak then
                return { action = 'sell', label = T('lbl_sell'), targets = { weak.uid }, text = T('step_sell_room', weak.name or '?', best.name or '?'),
                    why = T('why_room'), cls = 'mid' }
            end
        end
        return { action = 'buy', label = T('lbl_take'), targets = { best.uid }, text = T('step_buy', best.name or best.key or '?', best.cost or 0),
            why = (best.reasons and best.reasons[1]) or T('why_note', best.note or 0), note = best.note, p = p, p_text = p_text,
            cls = 'good' }
    end
    -- 4. a joker that brings (almost) nothing: its sale is pure money
    local s = r.sells and r.sells[1]
    if s and (s.note or 0) >= S.sell_note and (s.contribution or 1) <= S.sell_max_contribution and (s.sell or 0) > 0 then
        return { action = 'sell', label = T('lbl_sell'), targets = { s.uid }, text = T('step_sell', s.name or '?'),
            why = T('why_useless', math.floor(math.max(0, s.contribution or 0) * 100 + 0.5), s.sell or 0), cls = 'mid', note = s.note }
    end
    -- 5. reroll if a better shop is likely enough
    local rr = r.reroll
    if rr and rr.worth and money - (rr.cost or 0) >= floor then
        return { action = 'reroll', label = T('lbl_reroll'), button = 'reroll', text = T('step_reroll', rr.cost or 0),
            why = T('why_reroll', I.pct(rr.p_improve or 0)), p = rr.p_improve, p_text = T('p_improve'), cls = 'mid' }
    end
    -- 6. nothing left worth doing: next blind
    local p = r.base and r.base.p_next
    return { action = 'next_round', label = T('lbl_next_round'), button = 'next_round', text = T('step_next_round'),
        why = T('why_keep_money', E.interest(money, state.econ)), p = p, p_text = T('p_next_blind'), cls = 'good' }
end

-- Booster pack ---------------------------------------------------------------------------------
function A.pack_step(state, r, cfg, partial)
    local S = settings(cfg)
    if not r or partial or not r.options then return nil end
    local best = r.options[1]
    if best and (best.note or 0) >= math.min(S.buy_note, 50) and not best.blocked then
        if best.kind == 'replace' then
            local old = state.jokers and state.jokers[best.replace_index]
            if old then
                return { action = 'sell', label = T('lbl_sell'), targets = { old.uid }, text = T('step_sell_for', old.name or '?', best.name or '?'),
                    why = T('why_replace', best.note or 0), cls = 'mid' }
            end
        end
        local step = { action = 'take', label = T('lbl_take'), targets = { best.uid }, text = T('step_take', best.name or best.key or '?'),
            why = (best.reasons and best.reasons[1]) or T('why_note', best.note or 0), note = best.note, cls = 'good' }
        -- tarot / spectral of an Arcana or Spectral pack: used at once on cards of the pack hand
        local info = IT.consumable(best.key)
        if info and info.sim and (best.kind == 'tarot' or best.kind == 'spectral') then
            local t = A.card_targets(info, state.hand_cards, nil, nil)
            if t then step.use_on = uids(t); step.use_cards = t; step.text = T('step_take_use', best.name or best.key or '?') end
        end
        return step
    end
    return { action = 'skip_pack', label = T('lbl_skip'), button = 'skip_pack', text = T('step_skip_pack'), why = T('why_pack_weak'), cls = 'mid' }
end

-- Blind selection ------------------------------------------------------------------------------
function A.blind_step(state, r, cfg, partial)
    if not r or not r.current then return nil end
    local pc = r.p_current
    if r.skip and r.skip.recommended and not partial then
        local tag = r.skip.tag and tostring(r.skip.tag):gsub('^tag_', ''):gsub('_', ' ') or '?'
        return { action = 'skip_blind', label = T('lbl_skip'), button = 'skip_blind', text = T('step_skip_blind', r.current.name or '?'),
            why = T('why_skip', tag, r.skip.tag_value or 0, r.skip.lost or 0), p = r.skip.p_following, p_text = T('p_following'), cls = 'mid' }
    end
    return { action = 'select_blind', label = T('lbl_play_blind'), button = 'select_blind', text = T('step_play_blind', r.current.name or '?'),
        why = r.current.boss and T('why_boss') or (r.skip and T('why_no_skip', r.skip.tag_value or 0, r.skip.lost or 0)) or T('why_play'),
        p = pc and pc.p, p_text = T('p_blind'), lo = pc and pc.lo, hi = pc and pc.hi, method = 'monte_carlo', cls = 'good' }
end

-- Joker order ------------------------------------------------------------------------------------
-- Numbers to show on the jokers, only when the current order is not the right one.
function A.order_marks(state, order, cfg)
    local S = settings(cfg)
    if not order or not order.order or (order.gain or 0) < S.order_min_gain then return nil end
    local jokers = state.jokers or {}
    local same = true
    for i, k in ipairs(order.order) do if k ~= i then same = false end end
    if same then return nil end
    local marks = {}
    for pos, k in ipairs(order.order) do
        local j = jokers[k]
        if j then marks[#marks + 1] = { uid = j.uid, pos = pos, name = j.name, moved = (k ~= pos) } end
    end
    return { marks = marks, gain = order.gain, names = order.names }
end

-- Entry point ----------------------------------------------------------------------------------
function A.step(phase, state, r, cfg, partial)
    if not state then return nil end
    local ok, step = pcall(function()
        if phase == 'hand' then return A.hand_step(state, r, cfg)
        elseif phase == 'shop' then return A.shop_step(state, r, cfg, partial)
        elseif phase == 'pack' then return A.pack_step(state, r, cfg, partial)
        elseif phase == 'blind_select' then return A.blind_step(state, r, cfg, partial)
        end
    end)
    if ok then return step end
    return nil, step
end

return A
