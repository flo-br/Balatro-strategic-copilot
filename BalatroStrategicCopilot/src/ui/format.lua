-- Balatro Strategic Copilot - ui/format.lua
-- Pure presentation logic: turns analysis results into lines of coloured text segments.
-- No LÖVE calls here (testable). A line is { {t=text, c=colour_name}, ... }.
-- Colour names: text, dim, good, mid, bad, title, chips, mult, money, accent, Spades, Hearts, Clubs, Diamonds.

local BSC = BSCopilot
local U = BSC.require('core/util')
local I = BSC.require('core/i18n')
local C = BSC.require('model/cards')
local EF = BSC.require('model/effects_db')

local F = {}
local T = I.T

F.symbols = { good = '+', mid = '~', bad = '-', suits = nil } -- UI may upgrade to glyphs

-- classification (never colour alone: a symbol is always attached) ---------------------------
function F.class_prob(p, cfg)
    cfg = cfg or {}
    if p == nil then return 'dim' end
    if p >= (cfg.good or 0.8) then return 'good' end
    if p >= (cfg.mid or 0.5) then return 'mid' end
    return 'bad'
end

function F.class_note(n, cfg)
    cfg = cfg or {}
    if n == nil then return 'dim' end
    if n >= (cfg.good or 70) then return 'good' end
    if n >= (cfg.mid or 45) then return 'mid' end
    return 'bad'
end

function F.mark(class)
    return F.symbols[class] or ''
end

function F.card_label(c)
    if not c then return '?' end
    if c.face_down then return '??' end
    if c.no_rank then return 'Pierre' end
    local ranks = I.T('ranks')
    local r = (type(ranks) == 'table' and ranks[c.id]) or tostring(c.id)
    local s
    if F.symbols.suits then s = F.symbols.suits[c.suit] end
    if not s then
        local letters = I.T('suit_letters')
        s = type(letters) == 'table' and letters[c.suit] or (c.suit or '?'):sub(1, 1)
    end
    return r .. s
end

function F.cards_segments(cards)
    local segs = {}
    local hidden = 0
    local visible = {}
    for _, c in ipairs(cards or {}) do
        if c.face_down then hidden = hidden + 1 else visible[#visible + 1] = c end
    end
    for i, c in ipairs(visible) do
        segs[#segs + 1] = { t = F.card_label(c), c = c.suit or 'text' }
        local mods = F.modifiers_text(c)
        if mods ~= '' then segs[#segs + 1] = { t = '(' .. mods .. ')', c = 'dim' } end
        if i < #visible then segs[#segs + 1] = { t = ' ', c = 'text' } end
    end
    if hidden > 0 then
        -- hidden positions are interchangeable (see engine/hand_advisor.lua)
        local txt = (hidden == 1) and T('hidden_one') or T('hidden_n', hidden)
        segs[#segs + 1] = { t = (#visible > 0 and ' + ' or '') .. txt, c = 'mid' }
    end
    return segs
end

-- Short names of a card's modifiers ("acier, holo"), as the player reads them in the game.
function F.modifiers_text(c)
    local names = I.T('mod_short')
    local out = {}
    for _, k in ipairs(EF.modifiers(c)) do
        -- a Stone card is already labelled "Pierre"
        if k ~= 'm_stone' then out[#out + 1] = (type(names) == 'table' and names[k]) or k end
    end
    return table.concat(out, ', ')
end

function F.cards_text(cards)
    local parts = {}
    for i, c in ipairs(cards or {}) do parts[i] = F.card_label(c) end
    return table.concat(parts, ' ')
end

-- Probability text that never hides uncertainty: a simulated 100 % (or 0 %) is shown as
-- its confidence bound (">= 94 %"), only exact computations may display 100 %.
function F.prob_text(p, method, lo, hi)
    if p == nil then return T('not_available') end
    if method ~= 'exact' and method ~= 'enumeration' then
        if p >= 1 and lo then return '≥ ' .. I.pct(lo) end
        if p <= 0 and hi then return '≤ ' .. I.pct(hi) end
    end
    return I.pct(p)
end

function F.method_text(method, n)
    if method == 'monte_carlo' then return T('method_monte_carlo', n or '?') end
    return T('method_' .. tostring(method))
end

function F.confidence(method, lo, hi, complete)
    if complete == false then return 'low' end
    if method == 'exact' or method == 'enumeration' then return 'high' end
    if lo and hi then
        local half = (hi - lo) / 2
        if half <= 0.04 then return 'high' end
        if half <= 0.10 then return 'medium' end
        return 'low'
    end
    return 'low'
end

local function trust_exact()
    local CM = BSC.modules and BSC.modules['game/compat']
    return not CM or CM.trust_exact()
end

function F.score_text(play)
    if not play then return T('not_available') end
    if (play.hidden_n or 0) > 0 then return T('score_avg', U.fmt_num(play.mean)) end -- depends on the hidden cards
    if play.complete == false or not trust_exact() then return T('score_partial', U.fmt_num(play.mean)) end
    if play.min == play.max then return T('score_exact', U.fmt_num(play.mean)) end
    return T('score_range', U.fmt_num(play.mean), U.fmt_num(play.min), U.fmt_num(play.max))
end

local function line(...) return { ... } end
local function seg(t, c) return { t = t, c = c or 'text' } end

local function append(dst, segs) for _, s in ipairs(segs) do dst[#dst + 1] = s end return dst end

function F.target_text(t)
    if not t then return '' end
    if t.name == 'Flush' then return T('target_flush', I.suit_name(t.suit), t.have, t.need) end
    if t.name == 'Straight' then return T('target_straight', t.have, t.need) end
    if t.name == 'Full House' then return T('target_full') end
    if t.name == 'Keep' then return T('target_keep') end
    if t.rank then
        local ranks = I.T('ranks')
        local r = (type(ranks) == 'table' and ranks[t.rank]) or tostring(t.rank)
        return T('target_rank', I.hand_name(t.name), r)
    end
    return I.hand_name(t.name)
end

-- Cards in hand whose modifiers change what to do with them (keep, discard, play with care),
-- and the jokers' stickers: shows the player what the copilot takes into account.
function F.effects_lines(state, max)
    local lines = {}
    local desc, hint = I.T('mod_desc'), I.T('role_hint')
    local listed = {}
    for _, c in ipairs((state and state.hand_cards) or {}) do
        local mods = EF.modifiers(c)
        if #mods > 0 then listed[#listed + 1] = { c = c, mods = mods } end
    end
    if #listed > 0 then
        lines[#lines + 1] = line(seg(T('effects_title'), 'title'))
        for i = 1, math.min(max or 4, #listed) do
            local e = listed[i]
            local parts = {}
            for _, k in ipairs(e.mods) do parts[#parts + 1] = (type(desc) == 'table' and desc[k]) or k end
            local l = line(seg('  ', 'text'))
            append(l, F.cards_segments({ e.c }))
            l[#l + 1] = seg(' : ' .. table.concat(parts, ' ; '), 'dim')
            local role = EF.role(e.c)
            if role ~= 'play' and type(hint) == 'table' and hint[role] then l[#l + 1] = seg(' → ' .. hint[role], 'accent') end
            lines[#lines + 1] = l
        end
    end
    local st = {}
    for _, j in ipairs((state and state.jokers) or {}) do
        local ks = EF.stickers(j)
        if #ks > 0 then
            local names = I.T('mod_short')
            local parts = {}
            for _, k in ipairs(ks) do
                local t = (type(names) == 'table' and names[k]) or k
                if k == 'perishable' then t = t .. ' : ' .. T('perish_left', EF.perish_left(j)) end
                parts[#parts + 1] = t
            end
            st[#st + 1] = (j.name or '?') .. ' (' .. table.concat(parts, ', ') .. ')'
        end
    end
    if #st > 0 then lines[#lines + 1] = line(seg(T('jokers_stickers') .. table.concat(st, ' · '), 'dim')) end
    return lines
end

-- Hand phase panel ----------------------------------------------------------------------
function F.hand_panel(state, r, detail)
    local lines = {}
    if not r then
        lines[#lines + 1] = line(seg(T('computing'), 'dim'))
        return lines
    end
    if r.empty then
        lines[#lines + 1] = line(seg(T('no_analysis'), 'dim'))
        return lines
    end
    lines[#lines + 1] = line(seg(T('remaining', U.fmt_num(r.remaining)), 'text'))
    lines[#lines + 1] = line(seg(T('hands_discards', r.hands_left, r.discards_left), 'dim'))
    -- how reliable the probability shown on the step line is
    if r.round then
        local conf = F.confidence(r.round.method, r.round.lo, r.round.hi, r.coverage and #r.coverage.unsupported == 0)
        lines[#lines + 1] = line(seg(T('confidence', T('conf_' .. conf)) .. ' — ' .. F.method_text(r.round.method, r.round.n), 'dim'))
    end
    -- (the recommendation itself is the "À FAIRE" step line, engine/advice.lua)
    append(lines, F.effects_lines(state, detail and 8 or 4))
    -- alternatives
    if detail and r.candidates and #r.candidates > 1 then
        lines[#lines + 1] = line(seg(T('alternatives'), 'title'))
        for i = 2, math.min(4, #r.candidates) do
            local c = r.candidates[i]
            local l = line(seg((c.type == 'play' and T('play_label') or T('discard_label')) .. ' ', 'dim'))
            append(l, F.cards_segments(c.cards))
            l[#l + 1] = seg('  ' .. F.prob_text(c.p_clear, 'monte_carlo', c.lo, c.hi), F.class_prob(c.p_clear))
            lines[#lines + 1] = l
        end
    elseif detail and r.plays and #r.plays > 1 then
        lines[#lines + 1] = line(seg(T('alternatives'), 'title'))
        for i = 2, math.min(4, #r.plays) do
            local p = r.plays[i]
            local l = line()
            append(l, F.cards_segments(p.cards))
            l[#l + 1] = seg('  ' .. I.hand_name(p.hand or '?') .. ' ' .. U.fmt_num(p.mean), 'dim')
            lines[#lines + 1] = l
        end
    end
    -- coverage / honesty notes
    if r.coverage and #r.coverage.unsupported > 0 then
        lines[#lines + 1] = line(seg(T('coverage_partial', table.concat(r.coverage.unsupported, ', ')), 'bad'))
    end
    for _, n in ipairs(r.notes or {}) do
        if n == 'hidden_cards' then lines[#lines + 1] = line(seg(T('hidden_cards'), 'mid')) end
    end
    return lines
end

-- Badge descriptor for a card (UI draws it above the card) --------------------------------
-- returns { text, class, kind } or nil
function F.hand_badges(r)
    local out = {}
    if not r or not r.recommendation then return out end
    local rec = r.recommendation
    if rec.type == 'play' and rec.ref then
        for _, c in ipairs(rec.ref.cards) do out[c.uid] = { text = T('rec_play_short'), class = 'good', kind = 'play' } end
    elseif rec.type == 'discard' then
        for _, c in ipairs(rec.cards or {}) do out[c.uid] = { text = T('rec_discard_short'), class = 'bad', kind = 'discard' } end
    end
    return out
end

return F
