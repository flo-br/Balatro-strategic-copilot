-- Balatro Strategic Copilot - core/i18n.lua
-- Translation tables. French is the default; add a language by adding a table with the
-- same keys (missing keys fall back to French, then to the key itself).
-- Placeholders: {1}, {2}, ... replaced by the arguments.

local I = {}

I.lang = 'fr'

I.strings = {
    fr = {
        -- next step (engine/advice.lua)
        todo = 'À FAIRE : ', todo_wait = 'À FAIRE : analyse en cours…',
        lbl_play = 'JOUER', lbl_discard = 'DÉFAUSSER', lbl_take = 'À PRENDRE', lbl_sell = 'À VENDRE',
        lbl_reroll = 'RELANCER', lbl_next_round = 'BLINDE SUIVANTE', lbl_play_blind = 'JOUER', lbl_skip = 'PASSER',
        lbl_use = 'UTILISER', lbl_target = 'CIBLE',
        step_play = 'Jouer ', step_discard = 'Défausser ',
        step_use_planet = 'Utiliser {1} (+1 niveau : {2})', step_use = 'Utiliser {1}', step_use_on = 'Utiliser {1} sur : ',
        step_sell = 'Vendre {1}', step_sell_for = 'Vendre {1} pour le remplacer par {2}', step_sell_room = 'Vendre {1} pour faire de la place à {2}',
        step_buy = 'Acheter {1} ({2} $)', step_take = 'Prendre {1}', step_take_use = 'Prendre {1} et l\'utiliser sur : ',
        step_reroll = 'Relancer la boutique ({1} $)', step_next_round = 'Passer à la blinde suivante',
        step_skip_pack = 'Passer ce paquet', step_skip_blind = 'Passer la blinde {1}', step_play_blind = 'Jouer la blinde {1}',
        why_planet = 'monte le niveau de la main pour toute la partie', why_black_hole = '+1 niveau à toutes les mains',
        why_hermit = 'double votre argent : +{1} $', why_temperance = 'rapporte la valeur de revente des jokers : +{1} $',
        why_tarot_cards = 'sélectionnez ces cartes, puis Utiliser', why_luchador = 'le vendre désactive l\'effet du boss',
        why_invisible = 'le vendre duplique un de vos jokers au hasard', why_replace = 'le nouveau est meilleur ({1}/100)',
        why_room = 'emplacements de consommables pleins', why_note = 'note {1}/100',
        why_useless = 'n\'apporte que {1} % du score : +{2} $', why_reroll = '{1} de chances de trouver mieux',
        why_keep_money = 'rien de rentable à acheter : intérêts {1} $ en fin de manche', why_pack_weak = 'aucune carte n\'améliore votre jeu',
        why_skip = 'tag {1} (~{2} $) > gains de la blinde (~{3} $)', why_no_skip = 'tag (~{1} $) < gains de la blinde (~{2} $)',
        why_boss = 'le boss ne peut pas être passé', why_play = 'jouer rapporte plus que passer',
        p_blind = 'victoire de la blinde', p_blind_now = 'victoire de la blinde (sans le vendre)', p_boss_after = 'victoire du boss après achat',
        p_next_after = 'victoire de la blinde suivante après achat', p_improve = 'meilleure boutique', p_next_blind = 'victoire de la blinde suivante',
        p_following = 'victoire de la blinde d\'après sans boutique',
        order_title = 'Ordre des jokers à changer (+{1} %) : ', order_hint = 'glissez les jokers pour suivre les numéros',
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
        score_partial = '≈ {1} (partiel)', score_avg = '≈ {1} en moyenne',
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
        hidden_cards = 'Cartes face cachée : conseil calculé sur les cartes possibles (reste du deck)',
        hidden_one = '1 carte cachée', hidden_n = '{1} cartes cachées (n\'importe lesquelles)',
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
        boss_effects = {
            discard_2_random = 'défausse 2 cartes au hasard à chaque main', most_played_money = 'argent à 0 si vous jouez votre main la plus jouée',
            first_hand_face_down = 'première main face cachée', big = 'blinde très grande', face_down_1_in_7 = '1 carte sur 7 face cachée',
            level_down = 'baisse le niveau de la main jouée', debuff_suit = 'une couleur est affaiblie', face_down_after_play = 'cartes face cachée après chaque main',
            five_cards = 'il faut jouer 5 cartes', no_discards = 'aucune défausse', hand_size_minus = '-1 taille de main',
            no_repeat_hand = 'pas deux fois le même type de main', one_hand_type = 'un seul type de main autorisé', debuff_face = 'figures affaiblies',
            draw_3 = 'pioche toujours 3 cartes', debuff_played_ante = 'cartes déjà jouées dans l\'ante affaiblies', hands_1 = 'une seule main',
            money_per_card = '-1 $ par carte jouée', halve_base = 'jetons et multiplicateur de base divisés par 2', faces_face_down = 'figures face cachée',
            jokers_hidden = 'jokers retournés et mélangés', debuff_all = 'toutes les cartes affaiblies jusqu\'à la vente d\'un joker',
            random_joker_disabled = 'un joker désactivé à chaque main', forced_card = 'une carte imposée dans chaque main',
        },
        ranks = { [11] = 'V', [12] = 'D', [13] = 'R', [14] = 'A' },
    },
    en = {
        todo = 'TO DO: ', todo_wait = 'TO DO: computing…',
        lbl_play = 'PLAY', lbl_discard = 'DISCARD', lbl_take = 'TAKE', lbl_sell = 'SELL', lbl_reroll = 'REROLL',
        lbl_next_round = 'NEXT BLIND', lbl_play_blind = 'PLAY', lbl_skip = 'SKIP', lbl_use = 'USE', lbl_target = 'TARGET',
        step_play = 'Play ', step_discard = 'Discard ', step_use_planet = 'Use {1} (+1 level: {2})', step_use = 'Use {1}',
        step_use_on = 'Use {1} on: ', step_sell = 'Sell {1}', step_sell_for = 'Sell {1} to replace it with {2}',
        step_sell_room = 'Sell {1} to make room for {2}', step_buy = 'Buy {1} ({2} $)', step_take = 'Take {1}',
        step_take_use = 'Take {1} and use it on: ', step_reroll = 'Reroll the shop ({1} $)', step_next_round = 'Go to the next blind',
        step_skip_pack = 'Skip this pack', step_skip_blind = 'Skip the {1}', step_play_blind = 'Play the {1}',
        why_planet = 'levels the hand up for the whole run', why_black_hole = '+1 level to every hand', why_hermit = 'doubles your money: +{1} $',
        why_temperance = 'gives the jokers sell value: +{1} $', why_tarot_cards = 'select these cards, then Use',
        why_luchador = 'selling it disables the boss effect', why_invisible = 'selling it duplicates one of your jokers',
        why_replace = 'the new one is better ({1}/100)', why_room = 'consumable slots are full', why_note = 'score {1}/100',
        why_useless = 'brings only {1} % of the score: +{2} $', why_reroll = '{1} chance of a better shop',
        why_keep_money = 'nothing worth buying: {1} $ interest at the end of the round', why_pack_weak = 'no card improves your build',
        why_skip = 'tag {1} (~{2} $) > blind rewards (~{3} $)', why_no_skip = 'tag (~{1} $) < blind rewards (~{2} $)',
        why_boss = 'the boss cannot be skipped', why_play = 'playing pays more than skipping',
        p_blind = 'blind won', p_blind_now = 'blind won (without selling)', p_boss_after = 'boss won after buying',
        p_next_after = 'next blind won after buying', p_improve = 'better shop', p_next_blind = 'next blind won',
        p_following = 'following blind won without shop', order_title = 'Change the joker order (+{1} %): ',
        order_hint = 'drag the jokers to follow the numbers',
        title = 'Strategic Copilot',
        computing = 'Analysing…', no_analysis = 'No analysis available',
        win_blind = 'Blind win: {1}', win_run = 'Run win: {1}', strategic = 'Strategic potential: {1}/100',
        confidence = 'Confidence: {1}', conf_high = 'high', conf_medium = 'medium', conf_low = 'limited', conf_none = 'unavailable',
        best_alt = 'Best alternative: {1}', remaining = 'Left to score: {1}', hands_discards = 'Hands: {1}   Discards: {2}',
        rec_play = 'Play: {1}', rec_discard = 'Discard: {1}', rec_play_short = 'PLAY', rec_discard_short = 'DISCARD',
        score_exact = '{1} (exact)', score_range = '{1} ({2} to {3})', score_partial = '≈ {1} (partial)', score_avg = '≈ {1} on average',
        method_exact = 'exact computation', method_enumeration = 'exact enumeration of random events',
        method_monte_carlo = 'simulation (n={1})', method_heuristic = 'heuristic', method_learned = 'learned model',
        p_now = 'wins immediately: {1}', target_flush = 'Flush {1}: {2}/{3}', target_straight = 'Straight: {1}/{2}',
        target_rank = '{1} of {2}', target_full = 'Full House', target_keep = 'keep the best hand',
        p_complete = 'completion chance: {1}', alternatives = 'Alternatives', reasons = 'Why', risks = 'Risks',
        synergies = 'Synergies', coverage_partial = 'Partial compatibility: {1} not analysed',
        hidden_cards = 'Face-down cards: advice computed over the possible cards (rest of the deck)',
        hidden_one = '1 hidden card', hidden_n = '{1} hidden cards (any of them)', shop_title = 'Shop options',
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
