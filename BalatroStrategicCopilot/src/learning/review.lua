-- Balatro Strategic Copilot - learning/review.lua
-- Post-run review. Decisions are judged ONLY by the estimates available when they were made
-- (chosen option vs best option at that time); outcomes are used to report predictions and
-- probable luck, never to label a decision as a mistake.

local BSC = BSCopilot
local I = BSC.require('core/i18n')
local LE = BSC.require('learning/learning')

local RV = {}

local function pct(p) return I.pct(p) end

function RV.build(run, profile)
    local rv = { result = run.won and 'win' or (run.end_reason == 'abandoned' and 'abandoned' or 'loss'),
        ante = run.final_ante, won_at_ante = run.won_at_ante, lost_to = run.lost_to,
        major = {}, mistakes = {}, successes = {}, bad_luck = {}, tips = {} }
    local categories = {}

    -- decisions
    local bad_rerolls = 0
    for _, d in ipairs(run.decisions or {}) do
        if d.kind == 'buying_card' then
            rv.major[#rv.major + 1] = string.format('Ante %d : achat %s (%s/100)', d.ante or 0, tostring(d.chosen_name or d.key), tostring(d.chosen_note or '?'))
            if d.best_note and d.chosen_note and d.best_note - d.chosen_note >= 15 and d.best_key ~= d.key then
                rv.mistakes[#rv.mistakes + 1] = string.format('Ante %d : achat noté %d/100 alors qu\'une option était estimée à %d/100 (%s).',
                    d.ante or 0, d.chosen_note, d.best_note, tostring(d.best_key))
                categories.shop = (categories.shop or 0) + 1
            end
        elseif d.kind == 'selling_card' then
            rv.major[#rv.major + 1] = string.format('Ante %d : vente %s', d.ante or 0, tostring(d.key))
            if d.contribution and d.contribution > 0.15 and (d.chosen_note or 50) < 45 then
                rv.mistakes[#rv.mistakes + 1] = string.format('Ante %d : vente d\'un joker qui apportait ~%s du score (estimation au moment de la vente).',
                    d.ante or 0, pct(d.contribution))
                categories.sell = (categories.sell or 0) + 1
            end
        elseif d.kind == 'reroll_shop' and d.followed == false then
            bad_rerolls = bad_rerolls + 1
        elseif d.kind == 'skip_blind' then
            rv.major[#rv.major + 1] = string.format('Ante %d : blinde passée', d.ante or 0)
            if d.followed == false then
                rv.mistakes[#rv.mistakes + 1] = string.format('Ante %d : blinde passée alors que l\'analyse le déconseillait.', d.ante or 0)
                categories.skip = (categories.skip or 0) + 1
            end
        elseif (d.kind == 'before' or d.kind == 'pre_discard') and d.p_best and d.p_chosen then
            if d.p_best - d.p_chosen >= 0.15 then
                rv.mistakes[#rv.mistakes + 1] = string.format('Ante %d : %s estimé(e) à %s de réussite alors que la recommandation donnait %s.',
                    d.ante or 0, d.kind == 'before' and 'main jouée' or 'défausse', pct(d.p_chosen), pct(d.p_best))
                categories.play = (categories.play or 0) + 1
            end
        end
    end
    if bad_rerolls >= 2 then
        rv.mistakes[#rv.mistakes + 1] = string.format('%d relances estimées peu rentables au moment de les faire.', bad_rerolls)
        categories.reroll = bad_rerolls
    end

    -- economy
    local low = 0
    for _, e in ipairs(run.economy or {}) do
        if (e.ante or 0) >= 3 and (e.dollars or 0) < 5 then low = low + 1 end
    end
    if low >= 3 then
        rv.mistakes[#rv.mistakes + 1] = string.format('Économie : %d manches sous 5 $ après l\'ante 2 (aucun intérêt perçu).', low)
        categories.econ = low
    end

    -- predictions and luck
    local correct, total = 0, 0
    for _, b in ipairs(run.blinds or {}) do
        if b.p_pred and b.cleared ~= nil then
            total = total + 1
            if (b.p_pred >= 0.5) == b.cleared then correct = correct + 1 end
            if not b.cleared and b.p_pred >= 0.8 then
                rv.bad_luck[#rv.bad_luck + 1] = string.format('%s perdue alors que la victoire était estimée à %s : probablement de la malchance, pas une erreur.',
                    tostring(b.name or b.key), pct(b.p_pred))
            end
            if b.cleared and b.p_pred <= 0.35 then
                rv.successes[#rv.successes + 1] = string.format('%s remportée malgré une estimation de %s.', tostring(b.name or b.key), pct(b.p_pred))
            end
        end
    end
    rv.predictions = { correct = correct, total = total, brier = LE.run_brier(run) }

    -- risky decisions that paid off (estimate lower than the recommendation, blind still won)
    for _, d in ipairs(run.decisions or {}) do
        if d.kind == 'before' and d.p_best and d.p_chosen and d.p_best - d.p_chosen >= 0.15 then
            local h
            for _, hh in ipairs(run.hands or {}) do if hh.round == d.round then h = hh end end
            if h and h.blind_cleared then
                rv.successes[#rv.successes + 1] = string.format('Ante %d : choix plus risqué que la recommandation, réussi (ne prouve pas qu\'il était meilleur).', d.ante or 0)
            end
        end
    end

    -- decisive jokers (measured shares in this run)
    local agg = {}
    for _, h in ipairs(run.hands or {}) do
        for k, share in pairs(h.contributions or {}) do
            local a = agg[k] or { n = 0, sum = 0 }
            a.n = a.n + 1; a.sum = a.sum + share
            agg[k] = a
        end
    end
    local DB = BSC.require('model/jokers_db')
    local best = {}
    for k, a in pairs(agg) do if a.n >= 3 then best[#best + 1] = { k = k, share = a.sum / a.n } end end
    table.sort(best, function(a, b) return a.share > b.share end)
    for i = 1, math.min(3, #best) do
        local d = DB.get(best[i].k)
        rv.successes[#rv.successes + 1] = string.format('%s : ~%s du score des mains jouées.', d and d.name or best[i].k, pct(best[i].share))
    end

    -- tips
    if categories.shop then rv.tips[#rv.tips + 1] = 'En boutique, un écart de note de plus de 15 points est un signal fort.' end
    if categories.reroll then rv.tips[#rv.tips + 1] = 'Garder l\'argent plutôt que relancer quand la relance est jugée peu rentable préserve les intérêts.' end
    if categories.econ then rv.tips[#rv.tips + 1] = 'Viser les paliers de 5 $ (jusqu\'à 25 $) quand le danger est faible.' end
    if categories.play then rv.tips[#rv.tips + 1] = 'Comparer la probabilité de réussite des options avant de jouer quand l\'écart est important.' end
    if categories.skip then rv.tips[#rv.tips + 1] = 'Ne passer une blinde que si la suivante reste largement maîtrisée.' end
    if #rv.tips == 0 then rv.tips[#rv.tips + 1] = 'Aucune erreur probable détectée par les estimations : le résultat dépend surtout du hasard et des options proposées.' end
    rv.learning = LE.summary(profile)
    return rv
end

-- Panel lines for the game-over phase.
function RV.panel(state, rv, detail)
    local function seg(t, c) return { t = t, c = c or 'text' } end
    local lines = {}
    if not rv then lines[#lines + 1] = { seg(I.T('computing'), 'dim') }; return lines end
    local title = rv.result == 'win' and I.T('review_result_win') or I.T('review_result_loss')
    lines[#lines + 1] = { seg(title, rv.result == 'win' and 'good' or 'bad'), seg('  ' .. I.T('review_ante', rv.ante or '?'), 'text') }
    if rv.predictions and rv.predictions.total > 0 then
        lines[#lines + 1] = { seg(I.T('review_predictions', rv.predictions.correct, rv.predictions.total), 'dim') }
    end
    local function section(title_key, list, colour, max)
        if #list == 0 then return end
        lines[#lines + 1] = { seg(I.T(title_key), 'title') }
        for i = 1, math.min(max or 4, #list) do lines[#lines + 1] = { seg('- ' .. list[i], colour) } end
    end
    section('review_mistakes', rv.mistakes, 'mid', detail and 6 or 3)
    section('review_good', rv.successes, 'good', detail and 5 or 3)
    if #rv.bad_luck > 0 then
        lines[#lines + 1] = { seg(I.T('review_luck', ''), 'title') }
        for i = 1, math.min(3, #rv.bad_luck) do lines[#lines + 1] = { seg('- ' .. rv.bad_luck[i], 'dim') } end
    end
    if detail then section('review_decisions', rv.major, 'text', 6) end
    section('review_tips', rv.tips, 'accent', 3)
    local l = rv.learning
    if l and l.runs and l.runs > 0 then
        local cal = l.calibration or {}
        lines[#lines + 1] = { seg(I.T('learning_status', l.runs, cal.enabled and 'active' or ('inactive (' .. tostring(cal.reason or '-') .. ')')), 'dim') }
        if l.score and l.score.exact_n and l.score.exact_n > 0 then
            lines[#lines + 1] = { seg(string.format('Scores exacts vérifiés : %d/%d conformes', l.score.exact_n - l.score.exact_mismatch, l.score.exact_n), 'dim') }
        end
    end
    return lines
end

return RV
