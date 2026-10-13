-- Balatro Strategic Copilot - game/event_fallback.lua
-- Older Steamodded versions (e.g. 1.0.0~BETA-0509c, verified in its sources) do not call
-- mod.calculate, so the copilot receives no game events there. This module rebuilds the
-- events the decision log needs by comparing consecutive stable snapshots (and by capturing
-- the played cards while the game is in HAND_PLAYED). It is only used in 'polling' mode, so
-- events are never counted twice. Read-only, like everything else.

local BSC = BSCopilot

local EF = { pending_play = nil, captured_key = nil }

-- 'native' when Steamodded dispatches contexts to mods (SMODS.get_mods_scoring_targets exists).
function EF.detect()
    local SMODS = rawget(_G, 'SMODS')
    if type(SMODS) == 'table' and type(SMODS.get_mods_scoring_targets) == 'function' then return 'native' end
    return 'polling'
end

-- Called at every poll (also during animations): remember the cards being scored.
function EF.capture()
    local G = rawget(_G, 'G')
    if not (G and G.STATES and G.GAME and G.play and type(G.play.cards) == 'table') then return end
    if G.STATE ~= G.STATES.HAND_PLAYED or #G.play.cards == 0 then return end
    local cr = G.GAME.current_round or {}
    local key = tostring(G.GAME.round) .. ':' .. tostring(cr.hands_left) .. ':' .. tostring(G.play.cards[1].sort_id)
    if EF.captured_key == key then return end
    EF.captured_key = key
    local uids = {}
    for i, c in ipairs(G.play.cards) do uids[i] = tostring(c.sort_id) end
    EF.pending_play = { uids = uids }
end

local function uid_set(list)
    local t = {}
    for _, c in ipairs(list or {}) do t[tostring(c.uid)] = c end
    return t
end

local function missing(prev_list, now_list)
    local now = uid_set(now_list)
    local out = {}
    for _, c in ipairs(prev_list or {}) do
        if not now[tostring(c.uid)] then out[#out + 1] = c end
    end
    return out
end

local function shop_items(s)
    local out = {}
    local sh = s and s.shop
    if not sh then return out end
    for _, area in ipairs({ sh.jokers or {}, sh.vouchers or {}, sh.boosters or {} }) do
        for _, it in ipairs(area) do out[#out + 1] = it end
    end
    return out
end

local function dollars(s) return (s and s.econ and s.econ.dollars) or 0 end

-- Synthetic events between two stable snapshots (prev = state before the action).
function EF.diff(prev, s)
    local evs = {}
    if not prev or not s or not prev.run or not s.run then return evs end
    local same_round = prev.run.round == s.run.round and prev.run.seed == s.run.seed

    -- hand played / cards discarded -----------------------------------------------------------
    if prev.phase == 'hand' then
        local pr, nr = prev.round or {}, s.round or {}
        if EF.pending_play then
            evs[#evs + 1] = { kind = 'before', uids = EF.pending_play.uids, chips_before = prev.blind and prev.blind.chips_scored,
                synthetic = true }
            EF.pending_play = nil
        elseif same_round and s.phase == 'hand' and (nr.hands_left or 0) < (pr.hands_left or 0) then
            local gone = missing(prev.hand_cards, s.hand_cards)
            local uids = {}
            for i, c in ipairs(gone) do uids[i] = tostring(c.uid) end
            if #uids > 0 then
                evs[#evs + 1] = { kind = 'before', uids = uids, chips_before = prev.blind and prev.blind.chips_scored, synthetic = true }
            end
        end
        if same_round and s.phase == 'hand' and (nr.discards_left or 0) < (pr.discards_left or 0)
            and (nr.hands_left or 0) == (pr.hands_left or 0) then
            local gone = missing(prev.hand_cards, s.hand_cards)
            local uids = {}
            for i, c in ipairs(gone) do uids[i] = tostring(c.uid) end
            evs[#evs + 1] = { kind = 'pre_discard', uids = uids, synthetic = true }
        end
    end

    -- shop / pack -------------------------------------------------------------------------------
    if prev.phase == 'shop' or prev.phase == 'pack' then
        local owned_now = {}
        for _, j in ipairs(s.jokers or {}) do owned_now[tostring(j.uid)] = j end
        for _, c in ipairs(s.consumables or {}) do owned_now[tostring(c.uid)] = c end
        local now_items = uid_set(shop_items(s))
        -- reroll first: every joker slot replaced while staying in the shop, money spent
        -- (or a free reroll used), and none of the old cards owned now
        local rerolled = false
        if prev.phase == 'shop' and s.phase == 'shop' then
            local pj, sj = (prev.shop and prev.shop.jokers) or {}, (s.shop and s.shop.jokers) or {}
            if #pj > 0 and #sj > 0 then
                local any_kept, any_owned = false, false
                local now = uid_set(sj)
                for _, it in ipairs(pj) do
                    if now[tostring(it.uid)] then any_kept = true end
                    if owned_now[tostring(it.uid)] then any_owned = true end
                end
                local free_used = ((prev.econ or {}).free_rerolls or 0) > ((s.econ or {}).free_rerolls or 0)
                if not any_kept and not any_owned and (dollars(s) < dollars(prev) or free_used) then
                    evs[#evs + 1] = { kind = 'reroll_shop', synthetic = true }
                    rerolled = true
                end
            end
        end
        local prev_jokers_area = {}
        for _, it in ipairs((prev.shop and prev.shop.jokers) or {}) do prev_jokers_area[tostring(it.uid)] = true end
        local slots_shrank = #((s.shop and s.shop.jokers) or {}) < #((prev.shop and prev.shop.jokers) or {})
        for _, it in ipairs(shop_items(prev)) do
            local uid = tostring(it.uid)
            local skip = rerolled and prev_jokers_area[uid]
            if not now_items[uid] and not skip then
                if owned_now[uid] or (it.set == 'Voucher' and s.vouchers and s.vouchers[it.key]) then
                    evs[#evs + 1] = { kind = 'buying_card', uid = uid, key = it.key, cost = it.cost, set = it.set, synthetic = true }
                elseif it.set == 'Booster' and s.phase == 'pack' then
                    evs[#evs + 1] = { kind = 'open_booster', uid = uid, key = it.key, synthetic = true }
                elseif (it.set == 'Tarot' or it.set == 'Planet' or it.set == 'Spectral') and slots_shrank and dollars(s) < dollars(prev) then
                    -- consumable bought and used directly from the shop
                    evs[#evs + 1] = { kind = 'buying_card', uid = uid, key = it.key, cost = it.cost, set = it.set, synthetic = true }
                end
            end
        end
        -- sold / used owned cards
        local gone = missing(prev.jokers, s.jokers)
        for _, c in ipairs(missing(prev.consumables, s.consumables)) do gone[#gone + 1] = c end
        for _, c in ipairs(gone) do
            if dollars(s) > dollars(prev) then
                evs[#evs + 1] = { kind = 'selling_card', uid = tostring(c.uid), key = c.key, sell_cost = c.sell_cost, synthetic = true }
            elseif c.set == 'Tarot' or c.set == 'Planet' or c.set == 'Spectral' then
                evs[#evs + 1] = { kind = 'using_consumeable', uid = tostring(c.uid), key = c.key, set = c.set, synthetic = true }
            end
        end
    end

    -- skipped blind -------------------------------------------------------------------------------
    if prev.phase == 'blind_select' then
        local before = {}
        for _, b in ipairs(prev.upcoming or {}) do before[b.slot] = b.state end
        for _, b in ipairs(s.upcoming or {}) do
            if b.state == 'Skipped' and before[b.slot] and before[b.slot] ~= 'Skipped' then
                evs[#evs + 1] = { kind = 'skip_blind', blind = b.key, synthetic = true }
            end
        end
    end
    return evs
end

return EF
