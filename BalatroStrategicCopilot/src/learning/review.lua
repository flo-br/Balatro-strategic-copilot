-- Balatro Strategic Copilot - learning/review.lua
-- Post-run review, with the mindset of top players: EVERY SEED IS PLAYABLE. A loss is never
-- explained by luck alone: the review looks for what made the build fall short, when it
-- happened and what to do differently, including when the player followed the copilot (the
-- copilot's own plan can be wrong: it says so). Two kinds of findings:
--   * mistakes: decisions that differed from the best option AT THE TIME (judged only with the
--     estimates available then, never with the outcome);
--   * causes: why the build was not strong enough (power that stopped following the blinds,
--     multipliers missing, money left idle, main hand not levelled, boss not prepared, a
--     margin too thin). They come from the run trajectory, compared with the plan
--     (engine/plan.lua) and with the lessons of top players (docs/PRO_LESSONS.md).

local BSC = BSCopilot
local I = BSC.require('core/i18n')
local LE = BSC.require('learning/learning')
local BL = BSC.require('model/blinds_db')
local H = BSC.require('model/hands')

local RV = {}

local function pct(p) return I.pct(p) end

-- what each boss demands, and how top players prepare for it (model/blinds_db.lua)
RV.BOSS_PREP = BL.PREP

-- Trajectory of the build vs the blinds (top players' health check): at each ante, a typical
-- hand must reach the ante's base chips, i.e. the boss (2x base) in two hands. The copilot's
-- typical hand is measured without discards: threshold engine/plan.lua PL.BEHIND_RATIO.
-- Returns the first ante where it fell below, and the ratios.
local function trajectory(run)
    local PL = BSC.require('engine/plan')
    local ratios = {}
    local drop
    for _, p in ipairs(run.power or {}) do
        local base = BL.base_amount(p.ante or 1, run.scaling or 1)
        if base > 0 and p.median then
            local r = p.median / base
            ratios[#ratios + 1] = { ante = p.ante, ratio = r }
            if not drop and r < PL.BEHIND_RATIO then drop = p.ante end
        end
    end
    return drop, ratios
end

function RV.build(run, profile)
    local rv = { result = run.won and 'win' or (run.end_reason == 'abandoned' and 'abandoned' or 'loss'),
        ante = run.final_ante, won_at_ante = run.won_at_ante, lost_to = run.lost_to,
        major = {}, mistakes = {}, causes = {}, successes = {}, bad_luck = {}, tips = {}, lessons = {} }
    local categories = {}

    -- decisions (judged at decision time) ------------------------------------------------------
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
        rv.mistakes[#rv.mistakes + 1] = string.format('%d relances faites alors que l\'étape conseillée n\'était pas de relancer.', bad_rerolls)
        categories.reroll = bad_rerolls
    end

    -- causes: why the build fell short (the trajectory, never the outcome alone) ---------------
    local lost = rv.result == 'loss'
    local lost_blind
    for _, b in ipairs(run.blinds or {}) do if b.cleared == false then lost_blind = b end end
    if lost and lost_blind then
        local bname = (BL.get(lost_blind.key) or {}).name or lost_blind.name or lost_blind.key
        if lost_blind.score and lost_blind.chips and lost_blind.chips > 0 then
            local short = 1 - lost_blind.score / lost_blind.chips
            rv.causes[#rv.causes + 1] = { key = 'deficit', text = string.format('%s (ante %d) : %s marqués sur %s requis, il manquait %s du score.',
                tostring(bname), lost_blind.ante or 0, tostring(math.floor(lost_blind.score)), tostring(lost_blind.chips), pct(math.max(0, short))) }
        end
        local prep = RV.BOSS_PREP[lost_blind.key]
        if prep then rv.causes[#rv.causes + 1] = { key = 'boss', text = string.format('%s : %s.', tostring(bname), prep) } end
        if lost_blind.p_pred and lost_blind.p_pred >= 0.5 then
            -- not "bad luck": a risk that was accepted, the margin is built in the antes before
            rv.causes[#rv.causes + 1] = { key = 'margin', text = string.format(
                'La victoire était estimée à %s : %s de risque, c\'est trop pour une blinde décisive. Visez ≥ 95 %% en construisant de la marge dans les antes précédentes.',
                pct(lost_blind.p_pred), pct(1 - lost_blind.p_pred)) }
        end
    end
    local drop, ratios = trajectory(run)
    if drop and (lost or (run.final_ante or 0) <= drop + 2) then
        rv.causes[#rv.causes + 1] = { key = 'power_drop', text = string.format(
            'Dès l\'ante %d, la puissance a décroché : une main typique (estimée sans défausse) marquait moins de la moitié de la mise de base de l\'ante, le boss ne passait plus en 2 mains. C\'est dans les boutiques de cette ante que la partie s\'est jouée.', drop) }
    end
    -- end of ante 2: was there any scoring upgrade at all?
    local p1, p2
    for _, r in ipairs(ratios) do
        if r.ante == 1 then p1 = r end
        if r.ante == 2 then p2 = r end
    end
    if p1 and p2 and lost and (run.final_ante or 0) <= 4 then
        local g1 = p1.ratio * BL.base_amount(1, run.scaling or 1)
        local g2 = p2.ratio * BL.base_amount(2, run.scaling or 1)
        if g2 < g1 * 1.5 then
            rv.causes[#rv.causes + 1] = { key = 'no_upgrade', text = 'Fin de l\'ante 2 sans vraie amélioration du score (jokers, niveaux, cartes) : les blindes de l\'ante 3 deviennent hors de portée.' }
        end
    end
    -- jokers on the board and empty slots
    for _, b in ipairs(run.builds or {}) do
        if b.ante == 3 and (b.jokers or 0) < 3 then
            rv.causes[#rv.causes + 1] = { key = 'few_jokers', text = string.format(
                'Ante 3 avec seulement %d joker(s) : les meilleurs joueurs en ont 4 à 5 à ce stade (au début, n\'importe quel joker vaut mieux qu\'un emplacement vide).', b.jokers or 0) }
            break
        end
    end
    -- multipliers
    local short_x
    for _, b in ipairs(run.builds or {}) do
        if b.xmult_target and (b.xmult or 0) < b.xmult_target and (not short_x or b.ante > short_x.ante) then short_x = b end
    end
    if short_x and (lost or short_x.ante >= 4) then
        rv.causes[#rv.causes + 1] = { key = 'xmult', text = string.format(
            'Ante %d : %d multiplicateur(s) ×Mult sur %d attendus. Les blindes grandissent ×2,5 par ante, les +Mult et +Jetons ne suivent pas : il fallait acheter (ou relancer pour trouver) un ×Mult.',
            short_x.ante, short_x.xmult or 0, short_x.xmult_target) }
        categories.xmult = true
    end
    -- idle money
    local idle, idle_max = 0, 0
    for _, b in ipairs(run.builds or {}) do
        local cap = b.cap or 25
        if (b.dollars or 0) >= cap + 15 and (b.gap_xmult or b.gap_power) then
            idle = idle + 1
            if b.dollars > idle_max then idle_max = b.dollars end
        end
    end
    if idle >= 2 then
        rv.causes[#rv.causes + 1] = { key = 'idle_money', text = string.format(
            'Argent dormant : %d boutiques avec jusqu\'à %d $ alors que le build manquait de puissance. Au-delà du plafond d\'intérêts, l\'argent ne rapporte plus rien : il fallait relancer.',
            idle, idle_max) }
        categories.idle = true
    end
    -- main hand
    local last_build = (run.builds or {})[#(run.builds or {})]
    if last_build and last_build.ante and last_build.ante >= 5 and last_build.main_level and last_build.main_level < 4 then
        rv.causes[#rv.causes + 1] = { key = 'levels', text = string.format(
            'Main principale (%s) seulement niveau %d à l\'ante %d : les planètes (et paquets Céleste) de cette main font grandir le score à chaque niveau.',
            I.hand_name(last_build.main_hand or '?'), last_build.main_level, last_build.ante) }
        categories.levels = true
    end
    -- planets: focused on the main hand?
    local main = last_build and last_build.main_hand
    local planets, on_main = 0, 0
    for _, d in ipairs(run.decisions or {}) do
        local hand = d.key and H.PLANETS[d.key]
        if d.kind == 'using_consumeable' and hand then
            planets = planets + 1
            if hand == main then on_main = on_main + 1 end
        end
    end
    if main and planets >= 4 and on_main / planets < 0.7 then
        rv.causes[#rv.causes + 1] = { key = 'planets_spread', text = string.format(
            'Planètes dispersées : %d sur %d pour la main principale (%s). Les meilleurs joueurs en concentrent au moins 70 %% sur une main.',
            on_main, planets, I.hand_name(main)) }
        categories.levels = true
    end
    -- economy
    local low = 0
    for _, e in ipairs(run.economy or {}) do
        if (e.ante or 0) >= 3 and (e.dollars or 0) < 5 then low = low + 1 end
    end
    if low >= 3 then
        rv.causes[#rv.causes + 1] = { key = 'economy', text = string.format('Économie : %d manches sous 5 $ après l\'ante 2 (aucun intérêt perçu, aucune relance possible).', low) }
        categories.econ = low
    end
    if lost and #rv.causes == 0 then
        rv.causes[#rv.causes + 1] = { key = 'unknown', text = 'Pas assez de données enregistrées pour situer le décrochage : la prochaine partie sera suivie plus finement.' }
    end

    -- predictions (honesty of the estimates) and successes ---------------------------------
    local correct, total = 0, 0
    for _, b in ipairs(run.blinds or {}) do
        if b.p_pred and b.cleared ~= nil then
            total = total + 1
            if (b.p_pred >= 0.5) == b.cleared then correct = correct + 1 end
            if b.cleared and b.p_pred <= 0.35 then
                rv.successes[#rv.successes + 1] = string.format('%s remportée malgré une estimation de %s.', tostring(b.name or b.key), pct(b.p_pred))
            end
        end
    end
    rv.predictions = { correct = correct, total = total, brier = LE.run_brier(run) }

    for _, d in ipairs(run.decisions or {}) do
        if d.kind == 'before' and d.p_best and d.p_chosen and d.p_best - d.p_chosen >= 0.15 then
            local h
            for _, hh in ipairs(run.hands or {}) do if hh.round == d.round then h = hh end end
            if h and h.blind_cleared then
                rv.successes[#rv.successes + 1] = string.format('Ante %d : choix plus risqué que la recommandation, réussi (ne prouve pas qu\'il était meilleur).', d.ante or 0)
            end
        end
    end

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

    -- what to do next time --------------------------------------------------------------------
    if categories.xmult then rv.tips[#rv.tips + 1] = 'Viser un ×Mult dès l\'ante 3, deux à l\'ante 5, trois pour l\'ante 8 (Polychrome et cartes Acier comptent).' end
    if categories.idle then rv.tips[#rv.tips + 1] = 'Garder 25 $ pour les intérêts, dépenser le reste en relances tant qu\'il manque une pièce au build.' end
    if categories.levels then rv.tips[#rv.tips + 1] = 'Concentrer les planètes sur la main principale ; un paquet Céleste vaut souvent mieux qu\'un joker moyen.' end
    if categories.shop then rv.tips[#rv.tips + 1] = 'En boutique, un écart de note de plus de 15 points est un signal fort.' end
    if categories.reroll then rv.tips[#rv.tips + 1] = 'Relancer quand le copilote l\'indique (une fois avant de partir, ou avec l\'argent en trop), pas au-delà.' end
    if categories.econ then rv.tips[#rv.tips + 1] = 'Viser les paliers de 5 $ (jusqu\'à 25 $) quand le danger est faible.' end
    if categories.play then rv.tips[#rv.tips + 1] = 'Comparer la probabilité de réussite des options avant de jouer quand l\'écart est important.' end
    if categories.skip then rv.tips[#rv.tips + 1] = 'Ne passer une blinde que si la suivante reste largement maîtrisée.' end
    for _, c in ipairs(rv.causes) do
        if c.key == 'boss' then rv.tips[#rv.tips + 1] = 'Le boss de l\'ante est connu dès son début : préparer le build en conséquence.'; break end
    end
    if #rv.tips == 0 and lost then rv.tips[#rv.tips + 1] = 'Construire plus de marge avant les boss (viser ≥ 95 % de victoire estimée).' end
    -- causes kept by the profile: the copilot adapts its plan when the same cause repeats
    for _, c in ipairs(rv.causes) do rv.lessons[#rv.lessons + 1] = c.key end
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
        for i = 1, math.min(max or 4, #list) do
            local item = list[i]
            lines[#lines + 1] = { seg('- ' .. (type(item) == 'table' and item.text or item), colour) }
        end
    end
    section('review_causes', rv.causes or {}, 'bad', detail and 7 or 4)
    section('review_mistakes', rv.mistakes, 'mid', detail and 6 or 3)
    section('review_tips', rv.tips, 'accent', 3)
    section('review_good', rv.successes, 'good', detail and 5 or 2)
    if detail then section('review_decisions', rv.major, 'text', 6) end
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
