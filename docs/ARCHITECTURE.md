# Étape B — Architecture et cahier des charges technique

## 1. Principes

1. **Lecture seule sur la partie.** Le seul code qui lit le jeu est `game/state_reader.lua` ;
   il produit un *instantané* (tables Lua pures, copiées). Aucun module d'analyse ne voit `G`.
   Le mod n'appelle jamais une fonction qui joue, achète, vend, relance, sélectionne ou défausse.
2. **Modules purs et testables.** Moteurs de règles, probabilités, score, stratégie,
   apprentissage et persistance sont des fonctions pures sur des tables, testées hors jeu
   avec LuaJIT et Lua 5.1.
3. **Honnêteté des chiffres.** Chaque résultat porte une *méthode* (`exact`, `enumeration`,
   `monte_carlo`, `heuristic`, `learned`) et une *couverture* (éléments non pris en compte).
   Un score n'est « exact » que si toutes les interactions sont modélisées et déterministes.
4. **Dégradation contrôlée.** Toute interaction avec le jeu est protégée par `pcall` ; une
   erreur dans un module désactive ce module, pas le jeu ni le reste du mod.
5. **Aucune dépendance externe.** Ni réseau, ni bibliothèque tierce : JSON, PRNG et
   statistiques sont implémentés dans le mod.

## 2. Arborescence

```
BalatroStrategicCopilot/              <- dossier à copier dans %AppData%/Balatro/Mods/
  BalatroStrategicCopilot.json        métadonnées Steamodded
  main.lua                            point d'entrée : chargement des modules, branchements
  config.lua                          configuration par défaut
  src/core/      util, json, log (DebugManager), i18n, rng, scheduler (calcul découpé)
  src/model/     cards, hands, jokers_db, blinds_db, items_db (tarots/planètes/spectrales/bons/paquets)
  src/engine/    poker_eval (RulesEngine), score (ScoreEvaluator), probability (ProbabilityEngine),
                 hand_advisor, synergy (JokerSynergyAnalyzer), economy, outlook (blindes à venir),
                 shop (ShopAnalyzer), strategy (StrategyEngine)
  src/learning/  recorder (journal), learning (LearningEngine), calibration, review (bilans)
  src/io/        persistence (PersistenceManager)
  src/game/      state_reader (GameStateReader), compat (CompatibilityManager), hooks, controller
  src/ui/        format (textes/couleurs, pur), ui_manager (UIManager, rendu LÖVE)
tests/           suite de tests (LuaJIT / Lua 5.1), simulateur de `G` pour l'intégration
standalone/      amorce du mode autonome (main.lua à copier dans %AppData%\Balatro) et son LISEZ-MOI
installer/       installateur-diagnostic Windows (INSTALLER_COPILOT.bat, DIAGNOSTIC_COPILOT.bat,
                 outils/installer_copilot.ps1), livré à la racine de l'archive
tools/           script de paquet (zip), harnais LÖVE (tests de persistance réelle),
                 vérification avec le vrai chargeur de Steamodded (smods_loader_check.lua)
docs/            documentation
```

## 3. Flux de données

```
             Game:update (chaque image)                     événements SMODS (mod.calculate)
                    │                                                  │
                    ▼                                                  ▼
  ┌──────────── controller ─────────────┐                     recorder (journal)
  │ 1. détecte un changement d'état      │                            │
  │    (signature légère : phase, mains, │                            ▼
  │    cartes, argent, boutique…)        │            learning / calibration ──► persistence
  │ 2. state_reader → instantané        │                            ▲
  │ 3. lance une tâche d'analyse         │                            │
  │    (scheduler, budget ms/image)      │──── prédictions ───────────┘
  └──────────────────────────────────────┘
                    │ résultats (progressifs)
                    ▼
           ui_manager (Game:draw, overlay)  ◄── format (pur)
```

* L'analyse n'est relancée que si la **signature** de l'état pertinent change
  (pas de recalcul par image). Une analyse en cours est **abandonnée** si l'état change.
* Le `scheduler` exécute les analyses dans des coroutines avec un budget configurable
  (défaut 4 ms par image) : l'affichage reste fluide, les résultats s'affinent.

## 4. Interfaces des modules (contrats)

### 4.1 Instantané (`state_reader.snapshot()`)
```lua
{
  phase = 'hand'|'shop'|'blind_select'|'pack'|'round_eval'|'game_over'|'menu'|'other',
  run   = { ante, round, win_ante, stake, deck_key, challenge, seed_known=bool, won=bool },
  econ  = { dollars, interest_cap, interest_amount, reroll_cost, free_rerolls, rates = {...} },
  blind = { key, name, boss, chips_required, chips_scored, disabled, flags },
  round = { hands_left, discards_left, hand_size, hands_played, discards_used },
  hands = { [nom] = { level, chips, mult, l_chips, l_mult, played, played_this_round, visible } },
  jokers = { {key, name, rarity, edition, ability, sell_cost, debuff, face_down, blueprint_compat, ...}, ... },
  joker_slots, consumables = {...}, consumable_slots, vouchers = { [key]=true },
  hand_cards = { carte, ... },  deck = { carte, ... } (composition connue, ordre inconnu),
  full_deck_stats = { size, steel, stone, gold, enhanced, starting_size },
  shop = { jokers = {...}, vouchers = {...}, boosters = {...} },
  targets = { ancient_suit, idol = {rank, suit}, castle_suit, mail_rank, most_played_hand },
  probabilities_normal, flags = { plasma, ... },
  knowledge = { known = {...}, inferred = {...}, unknown = {...} },
  compat = { unknown_jokers = {...}, unknown_enhancements = {...}, modded_hands = {...} },
}
```
Carte : `{ uid, id(2..14 | nil pierre), rank, suit, nominal, enhancement, edition, seal,
bonus, perma_bonus, perma_mult, perma_x_mult, debuff, face_down, forced, played_this_ante }`.

### 4.2 RulesEngine — `engine/poker_eval.lua`
`classify(cards, rules) -> { name, scoring = {indices}, contains = {[nom]=true} }`
Règles : Four Fingers, Shortcut, Smeared, Wild, Pierre, Splash, cartes affaiblies.

### 4.3 ScoreEvaluator — `engine/score.lua`
`evaluate(state, played, held, opts) -> result` avec
`result = { hand, scoring, method, exact, mean, min, max, dist = {{score,p}...},
p_at_least(x), dollars, coverage = {unsupported = {...}, notes = {...}}, trace = {...} }`.
Les événements aléatoires (Lucky, Bloodstone, Misprint, Space Joker…) sont des *points de choix* :
énumération exacte jusqu'à `max_branches`, sinon Monte-Carlo reproductible.

### 4.4 ProbabilityEngine — `engine/probability.lua`
Hypergéométrique exacte, probabilité de compléter une main cible après pioche (énumération
exacte des multiensembles de pioche par classes de cartes), Monte-Carlo avec budget et
intervalle de Wilson.

### 4.5 HandAdvisor — `engine/hand_advisor.lua`
`analyse(state, budget) -> { plays = [...], discards = [...], round = { p_clear, method, n, ci } }`.
Politique future explicite (documentée dans `docs/MATHS.md`).

### 4.6 JokerSynergyAnalyzer — `engine/synergy.lua`
Contributions marginales mesurées par le ScoreEvaluator (avec/sans chaque joker), synergies
actives par règles, ordre optimal des jokers (permutations ≤ 6, sinon recherche locale).

### 4.7 ShopAnalyzer / StrategyEngine — `engine/shop.lua`, `engine/strategy.lua`
`evaluate_shop(state, model) -> options[]` : note /100, Δ probabilité estimée, coût, raisons,
risques, confiance. Ventes, remplacements, relance (espérance par Monte-Carlo sur le pool réel).
`StrategyEngine` agrège : puissance du build, besoins des prochaines blindes, posture de risque.

### 4.8 LearningEngine — `learning/*.lua`
Données brutes (journal par partie) séparées des statistiques apprises (profil).
Bêta-binomiale, régression logistique bayésienne en ligne (capacité → réussite de blinde),
calibration par classes avec validation temporelle, contributions des jokers avec rétrécissement
vers l'a priori.

### 4.9 PersistenceManager — `io/persistence.lua`
JSON versionné ; double emplacement A/B avec numéro de séquence et somme de contrôle
(écriture résistante aux interruptions, `love.filesystem` n'ayant pas de renommage atomique) ;
migrations avec sauvegarde préalable ; export / import / réinitialisation ; mise en quarantaine
des fichiers corrompus.

### 4.10 UIManager — `ui/ui_manager.lua`
Overlay `love.graphics` dessiné après `Game:draw` : panneau (touche configurable), badges
compacts (valeur + type + couleur + symbole pour daltoniens), alertes dédupliquées, bilan de partie.

### 4.11 CompatibilityManager — `game/compat.lua`
Détection des mods chargés, des objets inconnus du moteur, contrôle croisé de l'identification
des mains avec le natif, suivi de l'écart prédiction/score réel ; publie un niveau de
compatibilité (`complete`, `partielle`, `dégradée`).

### 4.12 DebugManager — `core/log.lua`
Niveaux (`error`, `warn`, `info`, `debug`, `trace`), tampon circulaire, fichier local
`BSC/logs/bsc.log` borné, relais vers la console Steamodded.

## 5. Stockage

```
%AppData%/Balatro/BSC/
  profile.a.json / profile.b.json     statistiques apprises (schéma versionné)
  runs/run_<horodatage>.a|b.json      journal brut d'une partie
  runs/index.a|b.json                 index des parties (bornage du volume)
  backups/                            copies avant migration / import
  corrupt/                            fichiers invalides mis en quarantaine
  export/                             exports
  import/                             fichiers à importer (déposés par l'utilisateur)
  logs/bsc.log
```

## 6. Objectifs de performance (mesurés en tests, LuaJIT)

| Calcul | Objectif |
|---|---|
| Lecture d'instantané | < 2 ms |
| Évaluation exacte d'une main (8 jokers) | < 0,2 ms |
| Meilleure main jouable (≤ 218 sous-ensembles, 8 cartes) | < 60 ms (découpé) |
| Analyse complète de manche (Monte-Carlo, budget) | < 1,5 s cumulée, ≤ 4 ms/image |
| Analyse boutique | < 300 ms cumulés |
| Sauvegarde du profil | < 20 ms |

## 7. Stratégie de tests

* `tests/run.lua` : exécuteur minimal sans dépendance (assertions, rapport, code de sortie).
* Unitaires : JSON, PRNG, combinatoire, classification de mains, score, jokers, économie,
  boutique, apprentissage, calibration, persistance (système de fichiers simulé).
* Référence : scénarios de score dont le résultat est calculé à la main à partir des règles
  vanilla (documentés dans `tests/test_score_reference.lua`), probabilités exactes vérifiées
  par énumération brute.
* Apprentissage : scénarios synthétiques à vérité connue (pas de certitude après peu d'essais,
  défaites non assimilées à de mauvaises décisions, calibration mesurable, persistance).
* Intégration : simulateur de `G` + faux `SMODS` qui charge réellement `main.lua`, exerce
  les accroches, le lecteur d'état, l'UI (avec un faux `love.graphics`) et la persistance.
* LÖVE réel : harnais `tools/love_harness` exécuté avec LÖVE 11.5 pour la persistance réelle
  (`love.filesystem`) et le rendu de l'overlay (capture d'écran sous Xvfb si disponible).
* Performance : chronométrage des calculs représentatifs.
* **Non réalisable ici** : tests dans Balatro réel (documentés dans `docs/TESTS.md`).
