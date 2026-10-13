-- Balatro Strategic Copilot - ui/format.lua
-- Pure presentation logic: turns analysis results into lines of coloured text segments.
-- No LÖVE calls here (testable). A line is { {t=text, c=colour_name}, ... }.
-- Colour names: text, dim, good, mid, bad, title, chips, mult, money, accent, Spades, Hearts, Clubs, Diamonds.

local BSC = BSCopilot
local U = BSC.require('core/util')
local I = BSC.require('core/i18n')
local C = BSC.require('model/cards')

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
    for i, c in ipairs(cards or {}) do
        segs[#segs + 1] = { t = F.card_label(c), c = c.suit or 'text' }
        if i < #cards then segs[#segs + 1] = { t = ' ', c = 'text' } end
    end
    return segs
end

function F.cards_text(cards)
    local parts = {}
    for i, c in ipairs(cards or {}) do parts[i] = F.card_label(c) end
    return table.concat(parts, ' ')
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

function F.score_text(play)
    if not play then return T('not_available') end
    if play.complete == false then return T('score_partial', U.fmt_num(play.mean)) end
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
    -- headline probability
    if r.round then
        local cls = F.class_prob(r.round.p_clear)
        local conf = F.confidence(r.round.method, r.round.lo, r.round.hi, r.coverage and #r.coverage.unsupported == 0)
        local ptxt = I.pct(r.round.p_clear)
        if conf == 'low' and r.coverage and #r.coverage.unsupported > 0 then ptxt = '≈ ' .. ptxt end
        lines[#lines + 1] = line(seg(F.mark(cls) .. ' ', cls), seg(T('win_blind', ptxt), cls))
        lines[#lines + 1] = line(seg(T('confidence', T('conf_' .. conf)) .. ' — ' .. F.method_text(r.round.method, r.round.n), 'dim'))
    else
        lines[#lines + 1] = line(seg(T('computing'), 'dim'))
    end
    -- recommendation
    local rec = r.recommendation
    if rec and rec.type == 'play' and rec.ref then
        local l = line(seg(T('rec_play_short') .. ' ', 'good'))
        append(l, F.cards_segments(rec.ref.cards))
        lines[#lines + 1] = l
        lines[#lines + 1] = line(seg('  ' .. I.hand_name(rec.ref.hand or '?') .. ' — ' .. F.score_text(rec.ref), 'chips'))
        if r.remaining > 0 then
            lines[#lines + 1] = line(seg('  ' .. T('p_now', I.pct(rec.ref.p_win)), F.class_prob(rec.ref.p_win)))
        end
    elseif rec and rec.type == 'discard' then
        local l = line(seg(T('rec_discard_short') .. ' ', 'mid'))
        append(l, F.cards_segments(rec.cards))
        lines[#lines + 1] = l
        if rec.ref and rec.ref.target then
            local txt = '  ' .. F.target_text(rec.ref.target)
            if rec.ref.p_complete then txt = txt .. ' — ' .. T('p_complete', I.pct(rec.ref.p_complete)) end
            lines[#lines + 1] = line(seg(txt, 'accent'))
        end
    elseif r.best_play then
        local l = line(seg(T('rec_play_short') .. ' ', 'good'))
        append(l, F.cards_segments(r.best_play.cards))
        lines[#lines + 1] = l
        lines[#lines + 1] = line(seg('  ' .. I.hand_name(r.best_play.hand or '?') .. ' — ' .. F.score_text(r.best_play), 'chips'))
    end
    -- alternatives
    if detail and r.candidates and #r.candidates > 1 then
        lines[#lines + 1] = line(seg(T('alternatives'), 'title'))
        for i = 2, math.min(4, #r.candidates) do
            local c = r.candidates[i]
            local l = line(seg((c.type == 'play' and T('play_label') or T('discard_label')) .. ' ', 'dim'))
            append(l, F.cards_segments(c.cards))
            l[#l + 1] = seg('  ' .. I.pct(c.p_clear), F.class_prob(c.p_clear))
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
