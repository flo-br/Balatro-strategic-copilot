-- Balatro Strategic Copilot - core/i18n.lua
-- Translation tables. French is the default; add a language by adding a table with the
-- same keys (missing keys fall back to French, then to the key itself).
-- Placeholders: {1}, {2}, ... replaced by the arguments.

local I = {}

I.lang = 'fr'

I.strings = {
    fr = {
        title = 'Copilote stratégique',
        phase_hand = 'Main en cours', phase_shop = 'Boutique', phase_blind_select = 'Choix de la blinde',
        phase_pack = 'Paquet ouvert', phase_round_eval = 'Fin de manche', phase_game_over = 'Partie terminée',
        phase_menu = 'Menu', phase_busy = 'Animation…', phase_none = 'Jeu non détecté',
        computing = 'Analyse en cours…',
        no_analysis = 'Aucune analyse disponible',
        win_blind = 'Victoire blinde : {1}',
        win_run = 'Victoire partie : {1}',
        strategic = 'Potentiel stratégique : {1}/100',
        confidence = 'Confiance du calcul : {1}',
        conf_high = 'élevée', conf_medium = 'moyenne', conf_low = 'limitée', conf_none = 'indisponible',
        best_alt = 'Meilleure alternative : {1}',
        remaining = 'Reste à marquer : {1}',
        hands_discards = 'Mains : {1}   Défausses : {2}',
        rec_play = 'Jouer : {1}',
        rec_discard = 'Défausser : {1}',
        rec_play_short = 'JOUER', rec_discard_short = 'DÉFAUSSER',
        score_exact = '{1} (exact)',
        score_range = '{1} (de {2} à {3})',
        score_partial = '≈ {1} (partiel)',
        method_exact = 'calcul exact', method_enumeration = 'énumération exacte des aléas',
        method_monte_carlo = 'simulation (n={1})', method_heuristic = 'heuristique', method_learned = 'modèle appris',
        p_now = 'gagne tout de suite : {1}',
        target_flush = 'Couleur {1} : {2}/{3}', target_straight = 'Suite : {1}/{2}',
        target_rank = '{1} de {2}', target_full = 'Full', target_keep = 'garder la meilleure main',
        p_complete = 'prob. de compléter : {1}',
        alternatives = 'Alternatives',
        reasons = 'Pourquoi',
        risks = 'Risques',
        synergies = 'Synergies',
        coverage_partial = 'Compatibilité partielle : {1} non analysé(s)',
        hidden_cards = 'Cartes face cachée : non prises en compte',
        unknown_values = 'Certaines valeurs ne sont pas calculables de façon fiable',
        shop_title = 'Options de boutique',
        shop_buy = 'Acheter {1} ({2} $)',
        shop_note = '{1}/100',
        shop_keep_money = 'Garder l\'argent',
        shop_reroll = 'Relancer ({1} $) : {2}',
        reroll_ok = 'probablement rentable', reroll_ko = 'probablement peu rentable', reroll_unknown = 'intérêt incertain',
        sell = 'Vendre {1} (+{2} $)',
        interest = 'Intérêts : +{1} $ (seuil suivant à {2} $)',
        econ_warning = 'Attention : cet achat fait perdre {1} $ d\'intérêts',
        next_blind = 'Prochaine blinde : {1} ({2})',
        boss_upcoming = 'Boss : {1}',
        build_power = 'Puissance estimée : {1} par main',
        needed_per_hand = 'Requis : ~{1} par main',
        skip_advice = 'Passer la blinde : {1}',
        alert_danger = 'Danger : {1} de perdre la prochaine blinde',
        alert_great_buy = 'Achat très intéressant : {1}',
        alert_joker_order = 'Réordonner les jokers : +{1} % de score',
        alert_compat = 'Analyse incomplète : élément non reconnu',
        alert_economy = 'Cette dépense compromet l\'économie',
        alert_bad_reroll = 'Relance probablement peu rentable',
        review_title = 'Bilan de partie',
        review_result_win = 'Victoire', review_result_loss = 'Défaite',
        review_ante = 'Ante maximale : {1}',
        review_decisions = 'Décisions majeures',
        review_mistakes = 'Erreurs probables (à examiner)',
        review_good = 'Réussites remarquables',
        review_predictions = 'Prédictions : {1} correctes / {2}',
        review_luck = 'Malchance probable : {1}',
        review_tips = 'Pistes d\'amélioration',
        learning_status = 'Apprentissage : {1} parties, calibration {2}',
        learning_none = 'Apprentissage : pas encore de données',
        keys_help = '[{1}] panneau  [{2}] détail  [{3}] badges',
        disabled_module = 'Module désactivé après erreurs : {1}',
        yes = 'oui', no = 'non',
        play_label = 'Jouer', discard_label = 'Défausser', buy_label = 'Acheter', skip_label = 'Passer',
        pack_pick = 'Prendre : {1}', pack_skip = 'Passer le paquet',
        joker_order_suggest = 'Ordre conseillé : {1}',
        not_available = 'indisponible',
        percent = '{1} %',
        hand_names = {
            ['Flush Five'] = 'Couleur quinte', ['Flush House'] = 'Full couleur', ['Five of a Kind'] = 'Quinte',
            ['Straight Flush'] = 'Quinte flush', ['Four of a Kind'] = 'Carré', ['Full House'] = 'Full',
            ['Flush'] = 'Couleur', ['Straight'] = 'Suite', ['Three of a Kind'] = 'Brelan',
            ['Two Pair'] = 'Double paire', ['Pair'] = 'Paire', ['High Card'] = 'Carte haute', ['Royal Flush'] = 'Quinte flush royale',
        },
        suits = { Spades = 'Pique', Hearts = 'Cœur', Clubs = 'Trèfle', Diamonds = 'Carreau' },
        suit_letters = { Spades = 'P', Hearts = 'C', Clubs = 'T', Diamonds = 'K' },
        ranks = { [11] = 'V', [12] = 'D', [13] = 'R', [14] = 'A' },
    },
    en = {
        title = 'Strategic Copilot',
        computing = 'Analysing…', no_analysis = 'No analysis available',
        win_blind = 'Blind win: {1}', win_run = 'Run win: {1}', strategic = 'Strategic potential: {1}/100',
        confidence = 'Confidence: {1}', conf_high = 'high', conf_medium = 'medium', conf_low = 'limited', conf_none = 'unavailable',
        best_alt = 'Best alternative: {1}', remaining = 'Left to score: {1}', hands_discards = 'Hands: {1}   Discards: {2}',
        rec_play = 'Play: {1}', rec_discard = 'Discard: {1}', rec_play_short = 'PLAY', rec_discard_short = 'DISCARD',
        score_exact = '{1} (exact)', score_range = '{1} ({2} to {3})', score_partial = '≈ {1} (partial)',
        method_exact = 'exact computation', method_enumeration = 'exact enumeration of random events',
        method_monte_carlo = 'simulation (n={1})', method_heuristic = 'heuristic', method_learned = 'learned model',
        p_now = 'wins immediately: {1}', target_flush = 'Flush {1}: {2}/{3}', target_straight = 'Straight: {1}/{2}',
        target_rank = '{1} of {2}', target_full = 'Full House', target_keep = 'keep the best hand',
        p_complete = 'completion chance: {1}', alternatives = 'Alternatives', reasons = 'Why', risks = 'Risks',
        synergies = 'Synergies', coverage_partial = 'Partial compatibility: {1} not analysed',
        hidden_cards = 'Face-down cards: not taken into account', shop_title = 'Shop options',
        shop_buy = 'Buy {1} (${2})', shop_note = '{1}/100', shop_keep_money = 'Keep the money',
        shop_reroll = 'Reroll (${1}): {2}', reroll_ok = 'probably worth it', reroll_ko = 'probably not worth it',
        reroll_unknown = 'uncertain', sell = 'Sell {1} (+${2})', interest = 'Interest: +${1} (next step at ${2})',
        econ_warning = 'Warning: this purchase costs ${1} of interest', next_blind = 'Next blind: {1} ({2})',
        boss_upcoming = 'Boss: {1}', build_power = 'Estimated power: {1} per hand', needed_per_hand = 'Needed: ~{1} per hand',
        skip_advice = 'Skip blind: {1}', alert_danger = 'Danger: {1} to lose the next blind',
        alert_great_buy = 'Great buy: {1}', alert_joker_order = 'Reorder jokers: +{1}% score',
        alert_compat = 'Incomplete analysis: unknown element', alert_economy = 'This spending hurts the economy',
        alert_bad_reroll = 'Reroll probably not worth it', review_title = 'Run review',
        review_result_win = 'Win', review_result_loss = 'Loss', review_ante = 'Best ante: {1}',
        review_decisions = 'Key decisions', review_mistakes = 'Probable mistakes (to review)',
        review_good = 'Notable successes', review_predictions = 'Predictions: {1} correct / {2}',
        review_luck = 'Probable bad luck: {1}', review_tips = 'Ideas to improve',
        learning_status = 'Learning: {1} runs, calibration {2}', learning_none = 'Learning: no data yet',
        keys_help = '[{1}] panel  [{2}] detail  [{3}] badges', disabled_module = 'Module disabled after errors: {1}',
        yes = 'yes', no = 'no', play_label = 'Play', discard_label = 'Discard', buy_label = 'Buy', skip_label = 'Skip',
        pack_pick = 'Take: {1}', pack_skip = 'Skip the pack', joker_order_suggest = 'Suggested order: {1}',
        not_available = 'unavailable', percent = '{1}%',
        hand_names = {}, suits = { Spades = 'Spades', Hearts = 'Hearts', Clubs = 'Clubs', Diamonds = 'Diamonds' },
        suit_letters = { Spades = 'S', Hearts = 'H', Clubs = 'C', Diamonds = 'D' },
        ranks = { [11] = 'J', [12] = 'Q', [13] = 'K', [14] = 'A' },
    },
}

function I.set_lang(lang)
    if I.strings[lang] then I.lang = lang end
end

local function lookup(key)
    local t = I.strings[I.lang]
    local v = t and t[key]
    if v == nil then v = I.strings.fr[key] end
    return v
end

function I.T(key, ...)
    local v = lookup(key)
    if v == nil then return key end
    if type(v) ~= 'string' then return v end
    local args = { ... }
    if #args == 0 then return v end
    return (v:gsub('{(%d+)}', function(n)
        local a = args[tonumber(n)]
        if a == nil then return '' end
        return tostring(a)
    end))
end

function I.hand_name(name)
    local t = lookup('hand_names') or {}
    return t[name] or name
end

function I.suit_name(s)
    local t = lookup('suits') or {}
    return t[s] or s
end

function I.pct(p)
    if p == nil or p ~= p then return I.T('not_available') end
    local v = math.floor(p * 100 + 0.5)
    if p > 0 and v == 0 then return '<1 %' end
    if p < 1 and v == 100 then return '>99 %' end
    return I.T('percent', v)
end

return I
