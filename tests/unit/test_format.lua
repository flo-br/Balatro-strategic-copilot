local T = ...
local S = {}

local function text_of(lines)
    local out = {}
    for _, l in ipairs(lines) do
        local parts = {}
        for _, s in ipairs(l) do parts[#parts + 1] = s.t end
        out[#out + 1] = table.concat(parts)
    end
    return table.concat(out, '\n')
end

function S.percent_format(T)
    local I = BSCopilot.require('core/i18n')
    T.eq(I.pct(0.874), '87 %')
    T.eq(I.pct(1), '100 %')
    T.eq(I.pct(0.001), '<1 %')
    T.eq(I.pct(0.999), '>99 %')
    T.eq(I.pct(nil), 'indisponible')
end

function S.classes_and_symbols(T)
    local Fmt = BSCopilot.require('ui/format')
    T.eq(Fmt.class_prob(0.9), 'good'); T.eq(Fmt.class_prob(0.6), 'mid'); T.eq(Fmt.class_prob(0.2), 'bad')
    T.eq(Fmt.class_note(80), 'good'); T.eq(Fmt.class_note(50), 'mid'); T.eq(Fmt.class_note(10), 'bad')
    -- never colour alone: a symbol is attached to every class
    T.ok(Fmt.mark('good') ~= '' and Fmt.mark('mid') ~= '' and Fmt.mark('bad') ~= '')
    T.ok(Fmt.mark('good') ~= Fmt.mark('bad'))
end

function S.hand_panel_shows_method_and_confidence(T)
    local Fmt = BSCopilot.require('ui/format')
    local C = BSCopilot.require('model/cards')
    local cards = C.parse_list('Ah Ad')
    local r = { remaining = 200, hands_left = 3, discards_left = 2, coverage = { unsupported = {} },
        round = { p_clear = 0.87, method = 'monte_carlo', n = 64, lo = 0.78, hi = 0.93 },
        recommendation = { type = 'play', ref = { cards = cards, hand = 'Pair', mean = 64, min = 64, max = 64, p_win = 0, complete = true } },
        plays = {}, notes = {} }
    local txt = text_of(Fmt.hand_panel({}, r, true))
    T.ok(txt:find('simulation %(n=64%)'), 'method shown')
    T.ok(txt:find('Confiance du calcul'), 'confidence shown')
    T.ok(not txt:find('JOUER'), 'the recommendation is the step line, not repeated')
    T.eq(Fmt.score_text(r.recommendation.ref), '64 (exact)', 'exact score labelled')
    T.eq(Fmt.score_text({ mean = 22, hidden_n = 5, complete = true }), '≈ 22 en moyenne', 'hidden cards: an average')
end

function S.partial_coverage_is_visible(T)
    local Fmt = BSCopilot.require('ui/format')
    local r = { remaining = 200, hands_left = 3, discards_left = 2, coverage = { unsupported = { 'Mod Joker' } },
        round = { p_clear = 0.5, method = 'monte_carlo', n = 64, lo = 0.4, hi = 0.6 }, plays = {}, notes = {} }
    local txt = text_of(Fmt.hand_panel({}, r, false))
    T.ok(txt:find('Compatibilité partielle'), txt)
    T.ok(txt:find('limitée') or txt:find('faible'), 'confidence lowered')
    local A = BSCopilot.require('engine/advice')
    r.recommendation = { type = 'play', ref = { cards = {} } }
    T.ok(A.hand_step({ jokers = {}, consumables = {}, blind = {} }, r).approx, 'approximate marker on the step probability')
end

function S.shop_panel_content(T)
    local FS = BSCopilot.require('ui/format_strategy')
    local r = { base = { p_next = 0.9, p_boss = 0.55, p_win = 0.2, growth = 2, growth_source = 'prior', median = 500 },
        next_blind = { chips = 800 }, boss = { name = 'The Hook', chips = 1600 }, danger = 0.3,
        options = { { name = 'The Duo', note = 82, cost = 8, affordable = true, d_boss = 0.2, ratio = 1.8, reasons = { 'joue souvent Pair' }, risks = {} } },
        reroll = { cost = 5, worth = false, p_improve = 0.2, n = 10 }, interest = { now = 2, next_step = 15 }, sells = {} }
    local txt = text_of(FS.shop_panel({}, r, true))
    T.ok(txt:find('82/100'), txt)
    T.ok(txt:find('Acheter The Duo'))
    T.ok(txt:find('boss %+20 pts'))
    T.ok(txt:find('peu rentable'))
    T.ok(txt:find('confiance limitée') or txt:find('limitée'), 'run probability flagged as low confidence')
    T.ok(txt:find('Intérêts'))
end

function S.english_translation_available(T)
    local I = BSCopilot.require('core/i18n')
    I.set_lang('en')
    T.eq(I.T('win_blind', '87 %'), 'Blind win: 87 %')
    T.eq(I.T('review_title'), 'Run review')
    -- missing key falls back to French then to the key
    T.eq(I.T('phase_shop'), 'Boutique')
    T.eq(I.T('no_such_key'), 'no_such_key')
    I.set_lang('fr')
end

-- The player sees which effects the copilot takes into account.
function S.card_effects_are_shown(T)
    local Fmt = BSCopilot.require('ui/format')
    local C = BSCopilot.require('model/cards')
    local steel, holo = C.parse('Ks'), C.parse('Ah')
    C.set_enhancement(steel, 'm_steel'); holo.edition = 'e_holo'; holo.seal = 'Red'
    local txt = text_of({ Fmt.cards_segments({ steel, holo }) })
    T.ok(txt:find('acier', 1, true) and txt:find('holo', 1, true) and txt:find('sceau rouge', 1, true), txt)
    local lines = Fmt.effects_lines({ hand_cards = { steel, holo, C.parse('2c') },
        jokers = { { name = 'Joker', eternal = true }, { name = 'Gros Michel', perishable = true, perish_tally = 2 } } })
    local all = text_of(lines)
    T.ok(all:find('×1,5 multi tant qu', 1, true) and all:find('à garder en main', 1, true), all)
    T.ok(all:find('éternel', 1, true) and all:find('2 manche', 1, true), all)
    T.ok(not all:find('2♣', 1, true) and not all:find('2T', 1, true), 'plain cards not listed')
end

return S
