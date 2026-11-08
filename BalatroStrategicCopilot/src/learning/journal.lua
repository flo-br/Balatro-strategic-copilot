-- Balatro Strategic Copilot - learning/journal.lua  (1.1.1)
-- Journal of each run, written while it is played, in a plain text file the player can read
-- or send (BSC/journal_parties.txt): the blinds offered (and the tags), what each shop offered
-- with the copilot's notes and advice, what the player bought, sold, rerolled, took in the packs
-- or left, the blinds skipped, the consumables used and what they changed (cards, money, levels,
-- jokers), every hand played or discarded with its cards and score, the end of each blind and of
-- the run. It is what the copilot needs to learn from winning runs (the moves of the player,
-- not only the ones that differed from its advice).
-- Only game data. It only READS the game state; nothing is ever done in the game.

local BSC = BSCopilot
local I = BSC.require('core/i18n')

local JN = { FILE = 'journal_parties.txt', OLD = 'journal_parties.old.txt', MAX_BYTES = 3 * 1024 * 1024 }
JN.__index = JN

local RANKS = { [11] = 'V', [12] = 'D', [13] = 'R', [14] = 'A' }
local SUITS = { Spades = '♠', Hearts = '♥', Diamonds = '♦', Clubs = '♣' }
local RARITY = { 'commun', 'peu commun', 'rare', 'légendaire' }
local SLOT = { Small = 'Small Blind', Big = 'Big Blind', Boss = 'Boss' }

-- writer(line): appends one line; opts.now: clock (tests)
function JN.new(writer, opts)
    opts = opts or {}
    local self = setmetatable({}, JN)
    self.write = writer
    self.now = opts.now or os.time
    self.ident = nil
    return self
end

local function short(key)
    local t = I.T('mod_short')
    return (type(t) == 'table' and t[key]) or tostring(key):gsub('^[me]_', '')
end

local function mods_of(x)
    local out = {}
    if x.enh and x.enh ~= 'c_base' then out[#out + 1] = short(x.enh) end
    if x.edition then out[#out + 1] = short(x.edition) end
    if x.seal then out[#out + 1] = short('seal_' .. tostring(x.seal)) end
    if x.eternal then out[#out + 1] = short('eternal') end
    if x.perishable then
        local left = x.perish_tally
        out[#out + 1] = short('perishable') .. (left and (' ' .. tostring(left)) or '')
    end
    if x.rental then out[#out + 1] = short('rental') end
    return out
end

function JN.card(c)
    if not c then return '?' end
    if c.face_down then return '??' end
    local base
    if c.enh == 'm_stone' then base = 'Pierre'
    else base = (RANKS[c.id] or tostring(c.id or '?')) .. (SUITS[c.suit] or (c.suit and c.suit:sub(1, 1)) or '') end
    local m = {}
    for _, k in ipairs(mods_of(c)) do if k ~= short('m_stone') then m[#m + 1] = k end end
    if #m > 0 then base = base .. '(' .. table.concat(m, ', ') .. ')' end
    return base
end

function JN.cards(list)
    local out = {}
    for i, c in ipairs(list or {}) do out[i] = JN.card(c) end
    return table.concat(out, ' ')
end

function JN.joker(j)
    if not j then return '?' end
    local m = mods_of(j)
    return tostring(j.name or j.key or '?') .. (#m > 0 and (' (' .. table.concat(m, ', ') .. ')') or '')
end

function JN.jokers(list)
    local out = {}
    for i, j in ipairs(list or {}) do out[i] = JN.joker(j) end
    return #out > 0 and table.concat(out, ', ') or 'aucun'
end

-- a shop or pack item, with the copilot's note when known
function JN.item(it, note)
    if not it then return '?' end
    local parts = {}
    if it.joker then
        local j = it.joker
        local m = mods_of(j)
        if j.edition == nil and it.edition then m[#m + 1] = short(it.edition) end
        parts[1] = tostring(j.name or it.name or it.key)
        local rar = RARITY[tonumber(j.rarity or 0)]
        local d = {}
        if rar then d[#d + 1] = rar end
        for _, k in ipairs(m) do d[#d + 1] = k end
        if #d > 0 then parts[1] = parts[1] .. ' (' .. table.concat(d, ', ') .. ')' end
    elseif it.card then
        parts[1] = 'carte ' .. JN.card(it.card)
    else
        parts[1] = tostring(it.name or it.key or '?')
        if it.set == 'Planet' and it.hand_type then parts[1] = parts[1] .. ' (' .. I.hand_name(it.hand_type) .. ')' end
        if it.edition then parts[1] = parts[1] .. ' (' .. short(it.edition) .. ')' end
    end
    if it.cost and it.cost > 0 then parts[#parts + 1] = tostring(it.cost) .. ' $' end
    if note then parts[#parts + 1] = 'note ' .. tostring(math.floor(note + 0.5)) end
    return table.concat(parts, ', ')
end

local function shop_items(s)
    local sh = s and s.shop or {}
    local out = {}
    for _, area in ipairs({ sh.jokers or {}, sh.boosters or {}, sh.vouchers or {} }) do
        for _, it in ipairs(area) do out[#out + 1] = it end
    end
    return out
end

local function find(list, uid)
    for _, x in ipairs(list or {}) do if tostring(x.uid) == tostring(uid) then return x end end
end

local function sig(list)
    local t = {}
    for i, x in ipairs(list or {}) do t[i] = tostring(x.uid) end
    return table.concat(t, ',')
end

local function levels(s)
    local out = {}
    for _, name in ipairs(BSC.require('model/hands').ORDER or {}) do
        local h = s.hands and s.hands[name]
        if h and (h.level or 1) > 1 then out[#out + 1] = I.hand_name(name) .. ' ' .. tostring(h.level) end
    end
    return #out > 0 and table.concat(out, ', ') or 'tous au niveau 1'
end

local function hand_name(cards, s)
    local ok, PE = pcall(BSC.require, 'engine/poker_eval')
    if not ok then return nil end
    local ok2, ev = pcall(PE.evaluate, cards, s.rules or {})
    if ok2 and ev and ev.name then return I.hand_name(PE.display_name(ev)) end
end

-- the copilot's advice for that state, in a few words
function JN.advice_text(step)
    if not step then return nil end
    local t = step.text or step.label
    if not t then return nil end
    if step.cards and #step.cards > 0 then t = t .. ' : ' .. JN.cards(step.cards)
    elseif step.use_cards and #step.use_cards > 0 then t = t .. ' sur ' .. JN.cards(step.use_cards) end
    return t
end

local function money(s) return s and s.econ and s.econ.dollars end

function JN:line(s, text)
    local r = s and s.run or {}
    local d = money(s)
    self.write(string.format('A%s M%s %s| %s', tostring(r.ante or '?'), tostring(r.round or '?'),
        d and (tostring(d) .. ' $ ') or '', text))
end

local function identity(s)
    local r = s.run or {}
    return table.concat({ tostring(r.seed), tostring(r.deck_key), tostring(r.stake), tostring(r.challenge) }, '|')
end

-- what a consumable (or a pack card) changed: cards, money, levels, jokers
local function changes(before, after)
    local out = {}
    -- the whole deck when both states have it (cards in hand, in the draw pile, played), else
    -- the hand, only within the same phase (a pack closing empties the hand)
    local b, a = before.full_deck, after.full_deck
    if not (b and a and #b > 0 and #a > 0) then
        b, a = nil, nil
        if before.phase == after.phase then b, a = before.hand_cards, after.hand_cards end
    end
    local old, new = {}, {}
    for _, c in ipairs(b or {}) do old[tostring(c.uid)] = c end
    for _, c in ipairs(a or {}) do new[tostring(c.uid)] = c end
    for _, c in ipairs(b or {}) do
        local n = new[tostring(c.uid)]
        if not n then out[#out + 1] = JN.card(c) .. ' détruite'
        elseif JN.card(n) ~= JN.card(c) then out[#out + 1] = JN.card(c) .. ' → ' .. JN.card(n) end
    end
    for _, c in ipairs(a or {}) do
        if not old[tostring(c.uid)] then out[#out + 1] = 'nouvelle carte ' .. JN.card(c) end
    end
    local oj = {}
    for _, j in ipairs(before.jokers or {}) do oj[tostring(j.uid)] = j end
    local nj = {}
    for _, j in ipairs(after.jokers or {}) do
        nj[tostring(j.uid)] = true
        local o = oj[tostring(j.uid)]
        if not o then out[#out + 1] = 'nouveau joker ' .. JN.joker(j)
        elseif JN.joker(o) ~= JN.joker(j) then out[#out + 1] = JN.joker(o) .. ' → ' .. JN.joker(j) end
    end
    for _, j in ipairs(before.jokers or {}) do
        if not nj[tostring(j.uid)] then out[#out + 1] = 'joker perdu ' .. JN.joker(j) end
    end
    for name, h in pairs(after.hands or {}) do
        local o = before.hands and before.hands[name]
        if o and (h.level or 1) ~= (o.level or 1) then out[#out + 1] = I.hand_name(name) .. ' niveau ' .. tostring(h.level) end
    end
    local d0, d1 = money(before), money(after)
    if d0 and d1 and d1 ~= d0 then out[#out + 1] = string.format('%+d $', d1 - d0) end
    return out
end

-- every stable state of the game (prev: the previous one); observing: "Je joue, tu apprends" on
function JN:on_state(prev, s, observing)
    if not s or not s.run or s.phase == 'menu' or s.phase == 'none' then return end
    local id = identity(s)
    if id ~= self.ident then
        self.ident = id
        self.blind_round, self.shop_sig, self.last_avis, self.pack_sig = nil, nil, nil, nil
        self.pending_play, self.pending_use, self.won_logged, self.select_round = nil, nil, nil, nil
        local r = s.run
        self.write('')
        self.write(string.format('=== Partie du %s : deck %s, mise %s, graine %s%s — %s ===',
            os.date('%Y-%m-%d %H:%M', self.now()), tostring(r.deck_name or r.deck_key or '?'), tostring(r.stake or '?'),
            tostring(r.seed or '?'), r.challenge and (', défi ' .. tostring(r.challenge)) or '',
            observing and 'vous jouez seul (O)' or 'conseils affichés'))
        self.obs = observing and true or false
    end
    -- the mode changed during the run (key O)
    if (observing and true or false) ~= self.obs then
        self.obs = observing and true or false
        self:line(s, 'mode : ' .. (observing and 'vous jouez seul (O), aucun conseil affiché' or 'conseils affichés'))
    end
    -- the score of the last hand played
    local pp = self.pending_play
    if pp and s.blind and s.blind.chips_scored ~= nil then
        local scored = s.blind.chips_scored
        if s.phase == 'hand' or s.phase == 'round_eval' or s.phase == 'shop' or s.phase == 'game_over' then
            local delta = pp.before and (scored - pp.before)
            if delta and delta >= 0 then
                self:line(s, string.format('   → %d jetons (total %d / %s)', math.floor(delta + 0.5), math.floor(scored + 0.5), tostring(pp.required or '?')))
            end
            self.pending_play = nil
        end
    end
    -- what the last consumable / pack card changed
    if self.pending_use and s.phase ~= 'busy' then
        local ch = changes(self.pending_use, s)
        if #ch > 0 then self:line(s, '   effet : ' .. table.concat(ch, ' ; ')) end
        self.pending_use = nil
    end
    local pphase = prev and prev.phase
    -- left the shop
    if pphase == 'shop' and s.phase ~= 'shop' and s.phase ~= 'pack' then
        local a = self:advice_for(prev)
        self:line(prev, 'quitte la boutique' .. (a and (' [conseil : ' .. a .. ']') or ''))
    end
    -- a pack left without taking anything
    if pphase == 'pack' and s.phase ~= 'pack' and not self.pack_taken then
        self:line(prev, 'passe le paquet')
    end
    if s.phase ~= 'pack' then self.pack_sig = nil end
    -- blind selection: the three blinds and the tags
    if s.phase == 'blind_select' and self.select_round ~= (s.run.ante or 0) * 100 + (s.run.round or 0) then
        self.select_round = (s.run.ante or 0) * 100 + (s.run.round or 0)
        local parts = {}
        for _, b in ipairs(s.upcoming or {}) do
            local tag = s.blind_tag_names and s.blind_tag_names[b.slot]
            local st = (b.state == 'Defeated' and ', gagnée') or (b.state == 'Skipped' and ', passée') or ''
            parts[#parts + 1] = string.format('%s %s jetons%s%s', b.boss and tostring(b.name) or (SLOT[b.slot] or b.slot),
                tostring(b.chips), tag and (' (tag ' .. tostring(tag) .. ')') or '', st)
        end
        if #parts > 0 then self:line(s, 'CHOIX DE BLINDE : ' .. table.concat(parts, ' · ')) end
    end
    -- a blind starts: its size, the board, the levels
    if s.phase == 'hand' and s.blind and self.blind_round ~= s.run.round then
        self.blind_round = s.run.round
        local b = s.blind
        local rd = s.round or {}
        self:line(s, string.format('BLINDE %s : %s jetons, %s mains, %s défausses', tostring(b.name or b.key or '?'),
            tostring(b.chips_required or '?'), tostring(rd.hands_left or '?'), tostring(rd.discards_left or '?')))
        self:line(s, '   jokers : ' .. JN.jokers(s.jokers) .. ' | niveaux : ' .. levels(s))
        if s.consumables and #s.consumables > 0 then
            local c = {}
            for i, x in ipairs(s.consumables) do c[i] = tostring(x.name or x.key) end
            self:line(s, '   consommables : ' .. table.concat(c, ', '))
        end
        self.blind_info = { name = b.name or b.key, required = b.chips_required }
    end
    -- a blind ends
    if (pphase == 'hand') and (s.phase == 'round_eval' or s.phase == 'shop') and self.blind_info then
        local scored = (s.blind and s.blind.chips_scored ~= 0 and s.blind.chips_scored) or (prev.blind and prev.blind.chips_scored)
        self:line(s, string.format('blinde gagnée : %s (%s / %s jetons)', tostring(self.blind_info.name),
            tostring(scored or '?'), tostring(self.blind_info.required or '?')))
        self.blind_info = nil
    end
    -- a new shop (arrival or reroll): its offers
    if s.phase == 'shop' then
        local items = shop_items(s)
        local sg = sig(items)
        -- written again only when new offers appear (arrival, reroll), not after a purchase or
        -- a pack opened from the shop
        local arrival = self.shop_sig == nil
        local fresh = arrival
        if not fresh and sg ~= self.shop_sig then
            local was = {}
            for u in tostring(self.shop_sig):gmatch('[^,]+') do was[u] = true end
            for _, it in ipairs(items) do if not was[tostring(it.uid)] then fresh = true end end
        end
        self.shop_sig = sg
        if fresh then
            if arrival then
                self:line(s, '   jokers : ' .. JN.jokers(s.jokers) .. ' | niveaux : ' .. levels(s))
            end
            self.last_avis = nil
            local t = {}
            for i, it in ipairs(items) do t[i] = JN.item(it) end
            self:line(s, 'BOUTIQUE : ' .. (#t > 0 and table.concat(t, ' ; ') or 'vide')
                .. (s.econ and s.econ.reroll_cost and (' | relance ' .. tostring(s.econ.reroll_cost) .. ' $') or ''))
        end
    elseif s.phase ~= 'pack' then
        self.shop_sig = nil
    end
    -- a pack opened: its cards (and the hand dealt for Arcana / Spectral packs)
    if s.phase == 'pack' and s.pack then
        local sg = sig(s.pack.cards)
        if sg ~= self.pack_sig then
            if self.pack_sig == nil then self.pack_taken = nil end
            self.pack_sig = sg
            local t = {}
            for i, it in ipairs(s.pack.cards or {}) do t[i] = JN.item(it) end
            self:line(s, string.format('PAQUET %s : %s (choix restants : %s)', tostring(self.pack_name or ''),
                #t > 0 and table.concat(t, ' ; ') or 'vide', tostring(s.pack.choices_left or '?')))
            if s.hand_cards and #s.hand_cards > 0 then self:line(s, '   main : ' .. JN.cards(s.hand_cards)) end
        end
    end
    -- end of the run
    if s.run.won and not self.won_logged then
        self.won_logged = true
        self:line(s, string.format('=== VICTOIRE (ante %s) ===', tostring(s.run.ante)))
    end
    if s.phase == 'game_over' and pphase ~= 'game_over' then
        local b = self.blind_info or (prev and prev.blind and { name = prev.blind.name, required = prev.blind.chips_required })
        local scored = (s.blind and s.blind.chips_scored) or (prev and prev.blind and prev.blind.chips_scored)
        self:line(s, string.format('=== FIN : %s à l\'ante %s contre %s (%s / %s jetons) ===', s.run.won and 'partie terminée' or 'défaite',
            tostring(s.run.ante), tostring(b and b.name or '?'), tostring(scored or '?'), tostring(b and b.required or '?')))
        self.blind_info = nil
    end
end

-- the copilot's note of a shop or pack item (from the analysis of that state)
local function note_of(result, uid)
    for _, o in ipairs(result and result.options or {}) do
        if tostring(o.uid) == tostring(uid) then return o.note end
    end
end

-- analysis finished for a state: the copilot's view of the shop / pack (step = its advice)
function JN:on_analysis(phase, result, s, step)
    self.advice = self.advice or {}
    self.advice[phase] = { step = step, state = s }
    self.results = self.results or {}
    self.results[phase] = result
    if phase == 'shop' and s and s.phase == 'shop' then
        local t = {}
        for _, o in ipairs(result and result.options or {}) do
            if o.note and #t < 6 then t[#t + 1] = tostring(o.name or o.key) .. ' ' .. tostring(math.floor(o.note + 0.5)) end
        end
        local text = '   avis du copilote : ' .. (JN.advice_text(step) or '?') .. (#t > 0 and (' | notes : ' .. table.concat(t, ', ')) or '')
        -- written when it changes (after a purchase the next step may be another one)
        if text ~= self.last_avis then
            self.last_avis = text
            self:line(s, text)
        end
    end
end

-- the advice computed for exactly that state (nil when its analysis had not finished)
function JN:advice_for(s)
    local a = s and self.advice and self.advice[s.phase]
    if a and a.state == s then return JN.advice_text(a.step) end
end

-- an action of the player, from the state it was taken in
function JN:on_event(ev, s)
    if not ev or not s or not s.run then return end
    local k = ev.kind
    local function with_advice(text)
        local a = self:advice_for(s)
        return a and (text .. ' [conseil : ' .. a .. ']') or text
    end
    if k == 'before' then
        local played, held, set = {}, {}, {}
        for _, u in ipairs(ev.uids or {}) do
            local c = find(s.hand_cards, u)
            if c then played[#played + 1] = c; set[c] = true end
        end
        for _, c in ipairs(s.hand_cards or {}) do if not set[c] then held[#held + 1] = c end end
        local name = (ev.scoring_name and I.hand_name(ev.scoring_name)) or hand_name(played, s) or 'main'
        self:line(s, with_advice(string.format('joue %s : %s%s', name, JN.cards(played),
            #held > 0 and (' | garde : ' .. JN.cards(held)) or '')))
        self.pending_play = { before = ev.chips_before or (s.blind and s.blind.chips_scored), required = s.blind and s.blind.chips_required }
    elseif k == 'pre_discard' then
        local cards = {}
        for _, u in ipairs(ev.uids or {}) do local c = find(s.hand_cards, u); if c then cards[#cards + 1] = c end end
        self:line(s, with_advice('défausse : ' .. JN.cards(cards)))
    elseif k == 'buying_card' then
        if s.phase == 'pack' then
            local it = find(s.pack and s.pack.cards, ev.uid)
            local sel = {}
            for _, c in ipairs(s.hand_cards or {}) do if c.highlighted then sel[#sel + 1] = c end end
            self:line(s, with_advice('prend ' .. JN.item(it or { name = ev.key }, note_of(self.results and self.results.pack, ev.uid))
                .. (#sel > 0 and (' sur ' .. JN.cards(sel)) or '')))
            self.pack_taken = true
            self.pending_use = s
        else
            local it = find(shop_items(s), ev.uid)
            self:line(s, with_advice('achète ' .. JN.item(it or { name = ev.key, cost = ev.cost }, note_of(self.results and self.results.shop, ev.uid))))
        end
    elseif k == 'open_booster' then
        local it = find(shop_items(s), ev.uid)
        self.pack_name = (it and it.name) or ev.key
        self.pack_sig = nil
        self:line(s, with_advice('ouvre ' .. JN.item(it or { name = ev.key }, note_of(self.results and self.results.shop, ev.uid))))
    elseif k == 'selling_card' then
        local j = find(s.jokers, ev.uid) or find(s.consumables, ev.uid)
        self:line(s, with_advice(string.format('vend %s (+%s $)', j and (j.set and tostring(j.name or j.key) or JN.joker(j)) or tostring(ev.key),
            tostring(ev.sell_cost or (j and j.sell_cost) or '?'))))
    elseif k == 'reroll_shop' then
        self:line(s, with_advice('relance la boutique' .. (s.econ and s.econ.reroll_cost and (' (' .. tostring(s.econ.reroll_cost) .. ' $)') or '')))
    elseif k == 'using_consumeable' then
        local c = find(s.consumables, ev.uid)
        local sel = {}
        for _, x in ipairs(s.hand_cards or {}) do if x.highlighted then sel[#sel + 1] = x end end
        self:line(s, with_advice('utilise ' .. tostring(c and (c.name or c.key) or ev.key or '?') .. (#sel > 0 and (' sur ' .. JN.cards(sel)) or '')))
        self.pending_use = s
    elseif k == 'skip_blind' then
        local slot
        for _, b in ipairs(s.upcoming or {}) do if b.state == 'Select' then slot = b.slot; break end end
        local tag = slot and s.blind_tag_names and s.blind_tag_names[slot]
        self:line(s, with_advice(string.format('passe la %s%s', SLOT[slot] or 'blinde', tag and (' → tag ' .. tostring(tag)) or '')))
    end
end

-- Writer appending to BSC/journal_parties.txt through the store backend, with a size cap
-- (the previous file is kept as journal_parties.old.txt).
function JN.file_writer(store, max_bytes)
    if not (store and store.be and store.be.append) then return function() end end
    local path = store:path(JN.FILE)
    local cap = max_bytes or JN.MAX_BYTES
    local checked = 0
    return function(line)
        pcall(function()
            checked = checked + 1
            if checked % 50 == 1 and store.be.size and store.be.size(path) > cap then
                store.be.write(store:path(JN.OLD), store.be.read(path) or '')
                store.be.write(path, '')
            end
            store.be.append(path, line .. '\n')
        end)
    end
end

return JN
