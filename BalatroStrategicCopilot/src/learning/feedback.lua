-- Balatro Strategic Copilot - learning/feedback.lua  (player corrections, "Mon choix")
-- The player selects in the game, with the mouse, what THEY would do (cards in hand, a shop
-- item, a joker, a consumable, a pack card), presses the "my choice" key and says why. The
-- copilot never acts in the game: it only READS what the player highlighted.
-- What is kept (profile.feedback, local, bounded):
--   entries : the last corrections (context, advice, choice, reason, free text <= 200 chars);
--   items   : note adjustment per item key (the item chosen +4, the item advised instead -4),
--             bounded to +-15 note points;
--   kinds   : the same per kind of item (x Mult joker, Buffoon Pack, planet...), +-8;
--   reasons : how many times each reason was given; each reason moves one setting a little
--             (bounded): synergies weigh more, x Mult wanted earlier, interest kept or spent...
-- Everything is shown (panel, review) and can be reset. No effect at all without corrections.
-- Pure functions of their arguments (the input box lives in game/feedback_input.lua).

local BSC = BSCopilot
local U = BSC.require('core/util')
local DB = BSC.require('model/jokers_db')
local PL = BSC.require('engine/plan')

local FB = {}

FB.MAX_ENTRIES = 300
FB.MAX_TEXT = 200
FB.ITEM_STEP, FB.ITEM_CAP = 4, 15
FB.KIND_STEP, FB.KIND_CAP = 2, 8

-- reasons: key, label, the setting it moves (see FB.nudges)
FB.REASONS = {
    { key = 'synergy', label = 'synergie avec mes jokers / mon deck' },
    { key = 'xmult', label = 'il me faut du ×Mult' },
    { key = 'economy', label = 'garder l\'argent (intérêts)' },
    { key = 'spend', label = 'la puissance d\'abord (dépenser)' },
    { key = 'hand', label = 'ma main principale' },
    { key = 'boss', label = 'préparer le boss' },
    { key = 'future', label = 'pour la suite (il va grandir)' },
    { key = 'risk', label = 'trop risqué' },
    { key = 'other', label = 'autre raison' },
}
FB.REASON_LABEL = {}
for _, r in ipairs(FB.REASONS) do FB.REASON_LABEL[r.key] = r.label end

local function new_data() return { entries = {}, items = {}, kinds = {}, reasons = {}, count = 0 } end

function FB.data(profile)
    if not profile then return nil end
    if type(profile.feedback) ~= 'table' then profile.feedback = new_data() end
    local d = profile.feedback
    d.entries = d.entries or {}; d.items = d.items or {}; d.kinds = d.kinds or {}; d.reasons = d.reasons or {}
    d.count = d.count or #d.entries
    return d
end

function FB.reset(profile)
    if profile then profile.feedback = new_data() end
end

-- Kind of an item, for the preferences: 'joker:xmult', 'pack:Buffoon', 'planet', 'tarot'...
-- Works on items of the state (shop / pack / owned) and on the options of engine/shop.lua.
function FB.kind_of(x)
    if not x then return nil end
    local set = x.set
    if set == 'Joker' or x.joker or x.joker_kind or (x.key and tostring(x.key):match('^j_')) then
        local k = x.joker_kind or PL.joker_kind(DB.get(x.key, x.name))
        return 'joker:' .. tostring(k or 'unknown')
    end
    if set == 'Booster' or x.pack_kind or (x.key and tostring(x.key):match('^p_')) then
        return 'pack:' .. tostring(x.pack_kind or (x.kind ~= 'booster' and x.kind) or 'pack')
    end
    if set == 'Planet' then return 'planet' end
    if set == 'Tarot' then return 'tarot' end
    if set == 'Spectral' then return 'spectral' end
    if set == 'Voucher' then return 'voucher' end
    if set == 'Default' or set == 'Enhanced' then return 'card' end
    return nil
end

FB.KIND_LABEL = {
    ['joker:xmult'] = 'jokers ×Mult', ['joker:additive'] = 'jokers +Mult / +Jetons', ['joker:scaling'] = 'jokers qui grandissent',
    ['joker:retrigger'] = 'jokers qui redéclenchent', ['joker:econ'] = 'jokers d\'argent', ['joker:utility'] = 'jokers utilitaires',
    ['pack:Buffoon'] = 'paquets Bouffon', ['pack:Arcana'] = 'paquets Arcane', ['pack:Celestial'] = 'paquets Céleste',
    ['pack:Spectral'] = 'paquets Spectral', ['pack:Standard'] = 'paquets Standard', planet = 'planètes', tarot = 'tarots',
    spectral = 'spectrales', voucher = 'bons', card = 'cartes à jouer',
}

-- Card label for the texts (no ui module here: rank + suit letter)
local SUIT_L = { Spades = 'P', Hearts = 'C', Clubs = 'T', Diamonds = 'K' }
local RANK_L = { [14] = 'A', [13] = 'R', [12] = 'D', [11] = 'V' }
local function card_label(c)
    if not c then return '?' end
    if c.face_down then return '??' end
    local r = RANK_L[c.id] or tostring(c.id or '?')
    return r .. (SUIT_L[c.suit] or '')
end
FB.card_label = card_label

local function item_brief(x, area)
    return { key = x.key, name = x.name or (x.joker and x.joker.name) or x.key, area = area, set = x.set or (x.joker and 'Joker'),
        cost = x.cost, sell = x.sell_cost, kind = FB.kind_of(x), uid = x.uid }
end

-- What the advice says, in a few fields (the step of engine/advice.lua)
local function advice_brief(step, state)
    if not step then return nil end
    local a = { action = step.action, label = step.label, text = step.text, why = step.why }
    local t = step.targets and step.targets[1]
    if t ~= nil then
        local function find(list, area)
            for _, x in ipairs(list or {}) do if tostring(x.uid) == tostring(t) then return item_brief(x, area) end end
        end
        local shop = state and state.shop or {}
        a.item = find(shop.jokers, 'shop') or find(shop.vouchers, 'voucher') or find(shop.boosters, 'booster')
            or find(state and state.pack and state.pack.cards, 'pack') or find(state and state.jokers, 'joker')
            or find(state and state.consumables, 'consumable')
    end
    if step.cards then
        local t2 = {}
        for i, c in ipairs(step.cards) do t2[i] = card_label(c) end
        a.cards = t2
    end
    return a
end

-- Context of a correction: what the player highlighted, what the copilot advises.
-- Returns ctx or nil, reason ('no_run', 'nothing_selected').
function FB.capture(state, phase, step)
    if not state or not state.run then return nil, 'no_run' end
    local ctx = { phase = phase, ante = state.run.ante, round = state.run.round, stake = state.run.stake, deck = state.run.deck_key,
        dollars = state.econ and state.econ.dollars, advice = advice_brief(step, state), selected = {} }
    local sel = ctx.selected
    local function pick(list, area)
        for _, x in ipairs(list or {}) do if x.highlighted then sel[#sel + 1] = item_brief(x, area) end end
    end
    if phase == 'hand' then
        local cards = {}
        for _, c in ipairs(state.hand_cards or {}) do if c.highlighted then cards[#cards + 1] = c end end
        if #cards > 0 then
            local labels = {}
            for i, c in ipairs(cards) do labels[i] = card_label(c) end
            ctx.cards = labels
        end
    end
    pick(state.jokers, 'joker')
    pick(state.consumables, 'consumable')
    if state.shop then
        pick(state.shop.jokers, 'shop'); pick(state.shop.vouchers, 'voucher'); pick(state.shop.boosters, 'booster')
    end
    if state.pack then pick(state.pack.cards, 'pack') end
    ctx.choices = FB.choices(ctx)
    if #ctx.choices == 0 then return nil, 'nothing_selected' end
    return ctx
end

-- The choices the player can confirm (first screen of the input box).
function FB.choices(ctx)
    local out = {}
    local function add(kind, label, item) out[#out + 1] = { kind = kind, label = label, item = item } end
    local ph = ctx.phase
    if ph == 'hand' then
        if ctx.cards then
            local l = table.concat(ctx.cards, ' ')
            add('play', 'Jouer ' .. l)
            add('discard', 'Défausser ' .. l)
        end
        for _, it in ipairs(ctx.selected) do
            if it.area == 'consumable' then add('use', 'Utiliser ' .. tostring(it.name), it) end
            if it.area == 'joker' then add('sell', 'Vendre ' .. tostring(it.name), it) end
        end
    elseif ph == 'shop' then
        for _, it in ipairs(ctx.selected) do
            if it.area == 'shop' or it.area == 'voucher' or it.area == 'booster' then
                add('buy', 'Acheter ' .. tostring(it.name) .. (it.cost and (' (' .. it.cost .. ' $)') or ''), it)
            elseif it.area == 'joker' then
                add('sell', 'Vendre ' .. tostring(it.name), it)
                add('keep', 'Garder ' .. tostring(it.name) .. ' (ne pas le vendre)', it)
            elseif it.area == 'consumable' then
                add('use', 'Utiliser ' .. tostring(it.name), it)
                add('sell', 'Vendre ' .. tostring(it.name), it)
            end
        end
        add('leave', 'Ne rien acheter : blinde suivante')
        add('reroll', 'Relancer la boutique')
    elseif ph == 'pack' then
        for _, it in ipairs(ctx.selected) do
            if it.area == 'pack' then add('take', 'Prendre ' .. tostring(it.name), it) end
            if it.area == 'joker' then add('sell', 'Vendre ' .. tostring(it.name), it) end
        end
        add('skip_pack', 'Passer le paquet')
    elseif ph == 'blind_select' then
        add('play_blind', 'Jouer la blinde')
        add('skip_blind', 'Passer la blinde (prendre le tag)')
        for _, it in ipairs(ctx.selected) do
            if it.area == 'joker' then add('sell', 'Vendre ' .. tostring(it.name), it) end
            if it.area == 'consumable' then add('use', 'Utiliser ' .. tostring(it.name), it) end
        end
    end
    return out
end

local function bump(t, key, step, cap)
    if not key then return 0 end
    local old = t[key] or 0
    local new = U.clamp(old + step, -cap, cap)
    t[key] = (new ~= 0) and new or nil
    return new - old
end

-- Records a correction and learns from it. entry = { ctx, choice (one of ctx.choices),
-- reason (key), text }. Returns the list of what changed (texts), and the entry kept.
function FB.record(profile, entry, now)
    local d = FB.data(profile)
    if not d or not entry or not entry.ctx or not entry.choice then return {}, nil end
    local ctx, ch = entry.ctx, entry.choice
    local text = tostring(entry.text or ''):gsub('[%c]', ' ')
    if #text > FB.MAX_TEXT then text = text:sub(1, FB.MAX_TEXT) end
    local reason = FB.REASON_LABEL[entry.reason or ''] and entry.reason or 'other'
    local kept = { t = now or os.time(), phase = ctx.phase, ante = ctx.ante, round = ctx.round, stake = ctx.stake, deck = ctx.deck,
        dollars = ctx.dollars, advice = ctx.advice, choice = { kind = ch.kind, label = ch.label, item = ch.item }, cards = ctx.cards,
        reason = reason, text = text }
    d.entries[#d.entries + 1] = kept
    while #d.entries > FB.MAX_ENTRIES do table.remove(d.entries, 1) end
    d.count = (d.count or 0) + 1
    d.reasons[reason] = (d.reasons[reason] or 0) + 1
    local changes = {}
    local function note_change(name, delta)
        if delta and delta ~= 0 then changes[#changes + 1] = string.format('%s %+d', tostring(name), delta) end
    end
    local adv = ctx.advice or {}
    local adv_item = adv.item
    local mine = ch.item
    local function prefer(it, sign)
        if not it or not it.key then return end
        note_change(it.name, bump(d.items, it.key, sign * FB.ITEM_STEP, FB.ITEM_CAP))
        if it.kind then bump(d.kinds, it.kind, sign * FB.KIND_STEP, FB.KIND_CAP) end
    end
    local buyish = { buy = true, take = true, keep = true }
    local advice_buys = adv.action == 'buy' or adv.action == 'take'
    if buyish[ch.kind] then
        -- the player wants this item more than the copilot did
        if not (advice_buys and adv_item and mine and adv_item.key == mine.key) then
            prefer(mine, 1)
            if advice_buys and adv_item then prefer(adv_item, -1) end
        end
    elseif ch.kind == 'sell' then
        prefer(mine, -1)
    elseif ch.kind == 'leave' or ch.kind == 'skip_pack' then
        -- the item advised was not worth it for the player
        if advice_buys and adv_item then prefer(adv_item, -1) end
    end
    if reason ~= 'other' then changes[#changes + 1] = FB.REASON_LABEL[reason] end
    return changes, kept
end

-- Note adjustment of an item (shop / pack option): points + text, or 0.
function FB.item_adjust(profile, x)
    local d = profile and profile.feedback
    if type(d) ~= 'table' or not x then return 0, nil end
    local v = 0
    local ik = x.key and d.items and d.items[x.key]
    if ik then v = v + ik end
    local kind = FB.kind_of(x)
    local kk = kind and d.kinds and d.kinds[kind]
    if kk then v = v + kk end
    v = U.clamp(v, -FB.ITEM_CAP - FB.KIND_CAP, FB.ITEM_CAP + FB.KIND_CAP)
    if v == 0 then return 0, nil end
    return v, string.format('vos choix : %+d', v)
end

-- Settings moved by the reasons given (each reason a little, bounded). Returns a table of
-- multipliers / deltas, empty without corrections:
--   synergy (x weight of synergies), potential (x weight of what a joker becomes), risk
--   (x weight of risks), impact (x weight of the next blinds), xmult (+ urgency of x Mult),
--   levels (+ weight of the main hand's levels), interest (+/- weight of interest lost).
function FB.nudges(profile)
    local d = profile and profile.feedback
    local r = (type(d) == 'table' and d.reasons) or {}
    local function n(k) return r[k] or 0 end
    local out = {}
    if n('synergy') > 0 then out.synergy = 1 + math.min(0.5, 0.1 * n('synergy')) end
    if n('future') > 0 then out.potential = 1 + math.min(0.5, 0.1 * n('future')) end
    if n('risk') > 0 then out.risk = 1 + math.min(0.6, 0.15 * n('risk')) end
    if n('boss') > 0 then out.impact = 1 + math.min(0.25, 0.05 * n('boss')) end
    if n('xmult') > 0 then out.xmult = math.min(0.5, 0.1 * n('xmult')) end
    if n('hand') > 0 then out.levels = math.min(0.5, 0.1 * n('hand')) end
    local money = U.clamp(0.5 * n('economy'), 0, 2) - U.clamp(0.5 * n('spend'), 0, 2)
    if money ~= 0 then out.interest = money end
    return out
end

-- Short summary for the panel: { lines of text }, newest preferences first.
function FB.summary(profile, max_items)
    local d = profile and profile.feedback
    if type(d) ~= 'table' or (d.count or 0) == 0 then return nil end
    local parts = {}
    local items = {}
    for k, v in pairs(d.items or {}) do items[#items + 1] = { k = k, v = v } end
    table.sort(items, function(a, b) if math.abs(a.v) ~= math.abs(b.v) then return math.abs(a.v) > math.abs(b.v) end return a.k < b.k end)
    for i = 1, math.min(max_items or 4, #items) do
        local def = DB.get(items[i].k)
        parts[#parts + 1] = string.format('%s %+d', (def and def.name) or items[i].k, items[i].v)
    end
    local kinds = {}
    for k, v in pairs(d.kinds or {}) do kinds[#kinds + 1] = { k = k, v = v } end
    table.sort(kinds, function(a, b) if math.abs(a.v) ~= math.abs(b.v) then return math.abs(a.v) > math.abs(b.v) end return a.k < b.k end)
    for i = 1, math.min(2, #kinds) do parts[#parts + 1] = string.format('%s %+d', FB.KIND_LABEL[kinds[i].k] or kinds[i].k, kinds[i].v) end
    local nd = FB.nudges(profile)
    if nd.synergy then parts[#parts + 1] = string.format('synergies ×%.1f', nd.synergy) end
    if nd.xmult then parts[#parts + 1] = string.format('×Mult +%.1f', nd.xmult) end
    if nd.interest then parts[#parts + 1] = (nd.interest > 0) and 'garder l\'argent' or 'dépenser plus tôt' end
    if nd.risk then parts[#parts + 1] = 'prudence' end
    if nd.potential then parts[#parts + 1] = 'jokers qui grandissent' end
    if nd.levels then parts[#parts + 1] = 'main principale' end
    if nd.impact then parts[#parts + 1] = 'boss' end
    return { count = d.count, text = table.concat(parts, ' · ') }
end

-- One line of the text file the player can read or send (BSC/mes_choix.txt).
function FB.export_line(e)
    if not e then return '' end
    local ph = ({ hand = 'main', shop = 'boutique', pack = 'paquet', blind_select = 'choix de blinde' })[e.phase] or tostring(e.phase)
    local adv = e.advice and (tostring(e.advice.label or '') .. ' ' .. tostring(e.advice.text or '')) or '-'
    if e.advice and e.advice.cards then adv = adv .. ' [' .. table.concat(e.advice.cards, ' ') .. ']' end
    return string.format('%s | mise %s, ante %s, %s, %s $ | conseil : %s | mon choix : %s | raison : %s | %s',
        os.date('%Y-%m-%d %H:%M', e.t or 0), tostring(e.stake or '?'), tostring(e.ante or '?'), ph, tostring(e.dollars or '?'),
        adv, tostring(e.choice and e.choice.label or '?'), FB.REASON_LABEL[e.reason] or tostring(e.reason), (e.text ~= '' and ('« ' .. e.text .. ' »') or ''))
end

-- Corrections of one run (for the review), oldest first.
function FB.run_entries(profile, since_t)
    local d = profile and profile.feedback
    local out = {}
    if type(d) ~= 'table' then return out end
    for _, e in ipairs(d.entries or {}) do if (e.t or 0) >= (since_t or 0) then out[#out + 1] = e end end
    return out
end

return FB
