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
    -- money discipline of top players (only while the next blinds are safe)
    booster_note = 52,             -- boosters: bought from this note (top players buy them very often)
    strong_note = 75,              -- an item this strong is bought even if it breaks the savings
    save_from_ante = 2,            -- from this ante, keep the interest cap ($25) and spend only the excess
    interest_weight = 3,           -- before that, each $ of interest lost raises the required note by 3
    safe_next = 0.85,              -- "safe": next blind won with at least 85 % ...
    safe_boss = 0.70,              -- ... and the boss with at least 70 %
    reroll_once = true,            -- nothing worth buying: one reroll per shop before leaving
    reroll_once_max_loss = 1,      -- ... if it costs at most 1 $ of interest (before the savings ante)
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
-- Cards that need a SELECTION in hand (tarots / spectrals with a target, see items_db) are
-- advised in hand and in Arcana / Spectral packs, with the exact cards to select, their role
-- and, for Death, their order (the LEFT selected card becomes a copy of the RIGHT one).

-- deck context: how often each rank / suit appears in the full deck
local function deck_stats(state)
    local st = { rank = {}, suit = {}, n = 0 }
    for _, c in ipairs(state and state.full_deck or {}) do
        st.n = st.n + 1
        if c.id and c.id > 0 then st.rank[c.id] = (st.rank[c.id] or 0) + 1 end
        if c.suit then st.suit[c.suit] = (st.suit[c.suit] or 0) + 1 end
    end
    local best, bn = nil, -1
    for s2, k in pairs(st.suit) do if k > bn or (k == bn and tostring(s2) < tostring(best)) then best, bn = s2, k end end
    st.dom_suit = best
    return st
end
A.deck_stats = deck_stats

-- how much a card is worth keeping / playing in this deck (explainable, documented)
local function usefulness(c, st)
    local u = card_value(c)
    if c.id and st.rank[c.id] then u = u + 2 * (st.rank[c.id] - 4) end
    if st.dom_suit and c.suit == st.dom_suit then u = u + 6 end
    if c.enh then u = u + 10 end
    if c.edition then u = u + 12 end
    if c.seal then u = u + 6 end
    return u
end
A.usefulness = usefulness

local function plain(c) return not c.enh and not c.edition and not c.seal end

local function sorted(list, key, desc)
    local t = {}
    for i, c in ipairs(list) do t[i] = c end
    table.sort(t, function(a, b)
        local ka, kb = key(a), key(b)
        if ka ~= kb then if desc then return ka > kb end return ka < kb end
        return tostring(a.uid) < tostring(b.uid)
    end)
    return t
end

local function first(list, n)
    local out = {}
    for i = 1, math.min(n, #list) do out[i] = list[i] end
    return out
end

local function filter(list, pred)
    local out = {}
    for _, c in ipairs(list) do if pred(c) then out[#out + 1] = c end end
    return out
end

-- Target description of a consumable (items_db `target`, or `sim` enhance / suit)
local function target_of(info)
    if not info then return nil end
    if info.target then return info.target end
    local sim = info.sim
    if sim and sim.enhance then return { kind = 'enhance', enhance = sim.enhance, n = sim.n or 1 } end
    if sim and sim.suit then return { kind = 'suit', suit = sim.suit, n = sim.n or 1 } end
    return nil
end
A.target_of = target_of

-- Cards to select for a consumable: { cards = {...} (in selection order), roles = {...},
-- hint = text|nil } or nil when no selection is clearly worth it.
-- ctx: play_cards / discard_cards (hand recommendation), strict (hand phase: only clear gains)
function A.targets(info, state, hand, ctx)
    ctx = ctx or {}
    local tg = target_of(info)
    if not tg then return nil end
    local st = deck_stats(state)
    local n = tg.n or 1
    local visible = filter(hand or {}, function(c) return not c.face_down end)
    if #visible == 0 then return nil end
    local U_ = function(c) return usefulness(c, st) end
    local play = ctx.play_cards
    local function in_play(c) return play and contains(play, c) end
    local function role_all(cards, role) local r = {} for i = 1, #cards do r[i] = role end return r end
    local picked, roles, hint

    if tg.kind == 'enhance' then
        local e = tg.enhance
        if e == 'm_steel' then
            -- x1.5 while HELD: a strong card that stays in hand
            picked = first(sorted(filter(visible, function(c) return not c.enh and not in_play(c) end),
                function(c) return (c.id or 0) * 100 + U_(c) end, true), n)
            roles = role_all(picked, T('role_held'))
        elseif e == 'm_gold' then
            picked = first(sorted(filter(visible, function(c) return not c.enh and not in_play(c) end), U_, false), n)
            roles = role_all(picked, T('role_held'))
        elseif e == 'm_stone' then
            if ctx.strict then return nil end
            picked = first(sorted(filter(visible, function(c) return not c.enh end), U_, false), n)
            roles = role_all(picked, T('role_weak'))
        elseif e == 'm_wild' then
            picked = first(sorted(filter(visible, function(c) return not c.enh and c.suit ~= st.dom_suit end), U_, true), n)
            roles = role_all(picked, T('role_flush'))
        else
            -- Mult / Bonus / Glass / Lucky: on the cards that will score
            local src = (play and #play > 0) and play or visible
            picked = first(sorted(filter(src, function(c) return not c.face_down and not c.enh
                and not (ctx.discard_cards and contains(ctx.discard_cards, c)) end), U_, true), n)
            roles = role_all(picked, T('role_scoring'))
        end
    elseif tg.kind == 'suit' then
        local others = filter(visible, function(c) return c.suit ~= tg.suit and c.enh ~= 'm_wild' and c.enh ~= 'm_stone' end)
        if tg.suit == st.dom_suit then
            picked = first(sorted(others, U_, true), n)
        else
            if ctx.strict then return nil end -- not toward the deck's main suit: only when taken from a pack
            picked = first(sorted(others, U_, false), n)
        end
        roles = role_all(picked, T('role_suit'))
    elseif tg.kind == 'rank_up' then
        -- +1 rank: where the next rank is more common in the deck (more pairs / sets)
        local cands = filter(visible, function(c) return c.id and c.id >= 2 and c.id < 14 and c.enh ~= 'm_stone' end)
        local function gain(c) return (st.rank[c.id + 1] or 0) - (st.rank[c.id] or 0) end
        picked = first(sorted(cands, function(c) return gain(c) * 100 - U_(c) end, true), n)
        if ctx.strict and #picked > 0 and gain(picked[1]) <= 0 then return nil end
        roles = role_all(picked, T('role_rank_up'))
    elseif tg.kind == 'destroy' then
        -- deck thinning: the least useful plain cards, never below 20 cards
        if st.n > 0 and st.n - n < 20 then return nil end
        picked = first(sorted(filter(visible, plain), U_, false), n)
        roles = role_all(picked, T('role_destroy'))
    elseif tg.kind == 'copy' then
        local by_u = sorted(visible, U_, true)
        local model = by_u[1]
        local victims = sorted(filter(visible, function(c) return c ~= model and plain(c) end), U_, false)
        local victim = victims[1]
        if not model or not victim then return nil end
        if U_(model) - U_(victim) < 6 then return nil end
        picked = { victim, model }
        roles = { T('role_becomes'), T('role_model') }
        local vx, mx = victim.pos_x, model.pos_x
        if vx == nil or mx == nil then
            for i, c in ipairs(hand or {}) do
                if c == victim then vx = i end
                if c == model then mx = i end
            end
        end
        if vx and mx and vx > mx then hint = T('hint_drag_left') end
    elseif tg.kind == 'seal' then
        local free = filter(visible, function(c) return not c.seal end)
        if tg.seal == 'Gold' then
            local src = filter((play and #play > 0) and play or free, function(c) return not c.seal and not c.face_down end)
            picked = first(sorted(src, U_, true), n); roles = role_all(picked, T('role_played'))
        elseif tg.seal == 'Red' then
            picked = first(sorted(free, function(c) return U_(c) + (c.enh and 10 or 0) end, true), n); roles = role_all(picked, T('role_scoring'))
        elseif tg.seal == 'Blue' then
            picked = first(sorted(free, U_, false), n); roles = role_all(picked, T('role_keep_end'))
        else
            picked = first(sorted(free, U_, false), n); roles = role_all(picked, T('role_to_discard'))
        end
    elseif tg.kind == 'edition' then
        picked = first(sorted(filter(visible, function(c) return not c.edition end), U_, true), n)
        roles = role_all(picked, T('role_scoring'))
    elseif tg.kind == 'duplicate' then
        picked = first(sorted(visible, U_, true), n)
        roles = role_all(picked, T('role_best'))
    end
    if not picked or #picked == 0 then return nil end
    return { cards = picked, roles = roles, hint = hint, kind = tg.kind }
end

-- Free consumables (no selection, no downside) worth using now
local function free_use(info, state)
    if not info or not info.free then return nil end
    if info.free == 'consumables' then
        local room = (state.consumable_slots or 2) - (#(state.consumables or {}) - 1)
        if room >= 1 then return T('why_creates_cards') end
    elseif info.free == 'joker_slot' then
        if #(state.jokers or {}) < (state.joker_slots or 5) then return T('why_creates_joker') end
    elseif info.free == 'joker_edition' then
        for _, j in ipairs(state.jokers or {}) do if not j.edition then return T('why_wheel') end end
    end
    return nil
end

local function use_step(c, t, text_key)
    local step = { action = 'use', label = T('lbl_use'), targets = { c.uid },
        text = T(text_key or 'step_use_on', c.name or c.key or '?'), cls = 'good', why = T('why_tarot_cards') }
    if t then
        step.use_on, step.use_cards, step.use_roles, step.hint = uids(t.cards), t.cards, t.roles, t.hint
        step.use_labels = {}
        for i, card in ipairs(t.cards) do
            local lbl = T('lbl_target')
            if t.kind == 'copy' then lbl = (i == 1) and T('lbl_becomes') or T('lbl_model')
            elseif t.kind == 'destroy' then lbl = T('lbl_destroy') end
            step.use_labels[card.uid] = lbl
        end
    end
    return step
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
            local why_free = free_use(info, state)
            if why_free then
                return { action = 'use', label = T('lbl_use'), targets = { c.uid }, text = T('step_use', c.name or c.key),
                    why = why_free, cls = 'good' }
            end
            if phase == 'hand' and target_of(info) then
                local t = A.targets(info, state, state.hand_cards, { play_cards = ctx.play_cards,
                    discard_cards = ctx.discard_cards, strict = true })
                if t then return use_step(c, t) end
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

-- Money discipline: below the interest cap, keep the money unless the item is strong; when the
-- next blinds are in danger, power comes first and the discipline is lifted.
local function money_policy(state, r, S)
    local econ = state.econ or {}
    local ante = (state.run and state.run.ante) or 1
    local b = r.base or {}
    local safe = (b.p_next or 0) >= S.safe_next and (b.p_boss or b.p_next or 0) >= S.safe_boss
    local cap = econ.no_interest and 0 or (econ.interest_cap or 25)
    return { safe = safe, ante = ante, target = (safe and ante >= S.save_from_ante) and cap or 0 }
end

local function required_note(o, money, pol, S)
    local base = (o.kind == 'booster') and S.booster_note or S.buy_note
    if not pol.safe or (o.note or 0) >= S.strong_note then return base end
    if pol.target > 0 and money - (o.cost or 0) < pol.target then return S.strong_note end
    return base + S.interest_weight * (o.interest_loss or 0)
end

-- Rerolls already paid in this shop (the price goes up by 1 $ after each one).
local function rerolls_done(econ)
    local base = (type(econ.temp_reroll_cost) == 'number') and econ.temp_reroll_cost or (econ.base_reroll_cost or 5)
    return math.max(0, (econ.reroll_cost or base) - base)
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
    local pol = money_policy(state, r, S)
    local best, saved
    for _, o in ipairs(r.options) do
        local base = (o.kind == 'booster') and S.booster_note or S.buy_note
        if (o.note or 0) >= base and not o.blocked then
            -- o.cost of a replacement is already net of the sale of the replaced joker
            local cost = o.cost or 0
            local old = (o.kind ~= 'replace') or (state.jokers and state.jokers[o.replace_index])
            if old and money - cost >= floor then
                if (o.note or 0) >= required_note(o, money, pol, S) then best = o; break end
                saved = saved or o
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
    -- 5. reroll: free, likely better, or once per shop before leaving (top players' habit)
    local econ = state.econ or {}
    local rr = r.reroll
    local rcost = (rr and rr.cost) or econ.reroll_cost or 5
    local function reroll(why, p)
        return { action = 'reroll', label = T('lbl_reroll'), button = 'reroll', text = T('step_reroll', rcost), why = why,
            p = p, p_text = p and T('p_improve') or nil, cls = 'mid' }
    end
    if (econ.free_rerolls or 0) > 0 then return reroll(T('why_reroll_free')) end
    local keep = math.max(floor, pol.target)
    if rr and rr.worth and money - rcost >= floor and money - rcost >= pol.target then
        return reroll(T('why_reroll', I.pct(rr.p_improve or 0)), rr.p_improve)
    end
    if S.reroll_once and not saved and rerolls_done(econ) == 0 and money - rcost >= keep
        and (pol.target > 0 or E.interest_loss(money, rcost, econ) <= S.reroll_once_max_loss)
        and (not rr or (rr.p_improve or 0) >= 0.15) then
        return reroll(T('why_reroll_once'), rr and rr.p_improve)
    end
    -- 6. nothing left worth doing: next blind
    local p = r.base and r.base.p_next
    local why = T('why_keep_money', E.interest(money, econ))
    if saved then why = T('why_save', E.interest(money, econ), saved.name or saved.key or '?', saved.note or 0) end
    return { action = 'next_round', label = T('lbl_next_round'), button = 'next_round', text = T('step_next_round'),
        why = why, p = p, p_text = T('p_next_blind'), cls = 'good' }
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
        if info and (best.kind == 'tarot' or best.kind == 'spectral') and target_of(info) then
            local t = A.targets(info, state, state.hand_cards, {})
            if t then
                local u = use_step({ uid = best.uid, name = best.name, key = best.key }, t, 'step_take_use')
                u.action, u.label, u.note, u.why = 'take', T('lbl_take'), best.note, step.why
                return u
            end
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
    -- only the FINAL decision is shown: a partial analysis could still change its mind
    -- (e.g. "play" then "skip" once the skip advice is computed)
    if not state or partial then return nil end
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
