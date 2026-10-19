# Description des modules

Tous les fichiers sont dans `BalatroStrategicCopilot/`. Seuls `game/state_reader.lua`,
`game/hooks.lua`, `game/controller.lua`, `game/compat.lua`, `game/config_ui.lua`,
`game/ui_targets.lua` et `ui/ui_manager.lua` touchent le jeu ou LÖVE ; tout le reste est pur et testé hors jeu.

| Fichier | Responsabilité (cahier des charges) |
|---|---|
| `main.lua` | point d'entrée Steamodded, chargeur de modules (`SMODS.load_file`) |
| `config.lua` | configuration par défaut (touches, interface, alertes, seuils, budgets de calcul, apprentissage, logs) |
| `src/core/util.lua` | utilitaires purs (copies sûres, combinatoire, tri stable, formats) |
| `src/core/json.lua` | JSON sûr (jamais exécuté) |
| `src/core/rng.lua` | générateur pseudo-aléatoire indépendant de celui du jeu |
| `src/core/log.lua` | **DebugManager** : niveaux, tampon, fichier borné, chronométrages |
| `src/core/i18n.lua` | traductions (français par défaut, anglais) |
| `src/core/scheduler.lua` | calculs découpés par image, annulables, résultats partiels |
| `src/model/cards.lua` | modèle normalisé des cartes (rangs, couleurs, améliorations, éditions) |
| `src/model/hands.lua` | mains de poker vanilla, niveaux, planètes |
| `src/model/jokers_db.lua` | logique des 150 jokers vanilla, étiquettes de synergie, économie, risques |
| `src/model/blinds_db.lua` | blindes et boss, formule de taille vanilla |
| `src/model/items_db.lua` | tarots, planètes, spectrales, bons, paquets (simulables ou heuristiques) |
| `src/model/builds_db.lua` | builds des meilleurs joueurs (pièces, anti-synergies, main, cartes voulues, comment les assembler), paires de jokers notées S / A / B / C / anti, synergies joker + deck |
| `src/model/effects_db.lua` | améliorations, éditions, sceaux, autocollants des jokers : rôle (jouer, garder, défausser, prudence), valeur d'une carte |
| `src/engine/poker_eval.lua` | **RulesEngine** : identification des mains (Four Fingers, Shortcut, Smeared, Wild, Pierre, Splash) |
| `src/engine/score.lua` | **ScoreEvaluator** : pipeline de score complet, aléas énumérés / Monte-Carlo, couverture |
| `src/engine/probability.lua` | **ProbabilityEngine** : hypergéométrique, inclusion-exclusion, Wilson |
| `src/engine/hand_advisor.lua` | **HandAdvisor** : jeux (évalués dans leur meilleur ordre quand l'ordre compte), défausses, simulation de manche, recommandation, **ordre des cartes** jouées et gardées (`HA.best_order`) |
| `src/engine/synergy.lua` | **JokerSynergyAnalyzer** : thèmes, synergies, contributions, ordre des jokers |
| `src/engine/economy.lua` | intérêts, revenus, coût d'opportunité |
| `src/engine/strategy.lua` | **StrategyEngine** : puissance, P(blinde), perspectives de victoire, danger |
| `src/engine/shop.lua` | **ShopAnalyzer** : options, notes, ventes, remplacements, relance |
| `src/engine/outlook.lua` | choix de blinde : prochaine blinde, boss (simulés), passer ou jouer (via `engine/skip.lua`) |
| `src/engine/skip.lua` | passer ou jouer une blinde : valeur de chaque tag selon la situation contre le coût réel du passage, condition de sécurité |
| `src/engine/builds.lua` | synergies d'un joker avec le plateau et le deck, builds en cours et pièces manquantes, cartes voulues par le build (cibles des tarots) |
| `src/engine/plan.lua` | plan de partie (leçons des meilleurs joueurs) : main principale, ×Mult attendus par ante, « en retard », manques, bonus de note par type de joker |
| `src/engine/advice.lua` | **prochaine étape** : UNE action à faire maintenant (jouer, défausser, acheter, vendre, relancer, blinde suivante, utiliser, prendre ou passer un paquet, jouer ou passer une blinde) et numéros d'ordre des jokers |
| `src/learning/recorder.lua` | journal brut des parties |
| `src/learning/calibration.lua` | calibration et métriques (Brier, log-loss, ECE) |
| `src/learning/learning.lua` | **LearningEngine** : profil appris |
| `src/learning/review.lua` | bilan de partie : erreurs au moment de la décision et causes de la défaite (toute partie est jouable) ; affiche les réglages recalculés |
| `src/learning/adapt.lua` | recalcul des réglages après chaque partie : causes du bilan → pas bornés sur les seuils d'achat, d'épargne, de sécurité et de passage ; retour vers la base après une victoire |
| `src/learning/runtime.lua` | liaison enregistreur / apprentissage / stockage, export, import, réinitialisation |
| `src/io/persistence.lua` | **PersistenceManager** : JSON versionné A/B, sommes de contrôle, migrations, quarantaine |
| `src/game/state_reader.lua` | **GameStateReader** : seul lecteur de `G` (connu / déduit / inconnu) |
| `src/game/compat.lua` | **CompatibilityManager** : mods détectés, contrôle croisé, Talisman, dégradation |
| `src/game/controller.lua` | détection des changements, ordonnancement, événements, alertes, modèle d'interface |
| `src/game/hooks.lua` | accroches `Game.update`, `Game.draw`, `mod.calculate`, `SMODS.Keybind` |
| `src/game/boot.lua` | assemblage au démarrage |
| `src/game/register_strategy.lua` | analyses de boutique, blinde, paquet, fin de manche ; alertes |
| `src/game/config_ui.lua` | onglet de configuration Steamodded (export, import, réinitialisation) |
| `src/game/ui_targets.lua` | repère les boutons du jeu (relance, blinde suivante, sélectionner / passer la blinde, passer le paquet) pour y poser l'étiquette ; lecture seule |
| `src/ui/format.lua`, `src/ui/format_strategy.lua` | présentation pure (lignes, couleurs, symboles) |
| `src/ui/ui_manager.lua` | **UIManager** : rendu LÖVE (panneau, badges, alertes) |

## Interfaces principales

Voir [ARCHITECTURE.md](ARCHITECTURE.md#4-interfaces-des-modules-contrats) pour les formats
d'instantané et de résultats. Points d'extension :

* `Controller.register(phase, analyseur, formateur, badges)` ajoute une analyse par phase ;
* `Controller.on(écouteur)` reçoit `state`, `event`, `analysis` (utilisé par l'apprentissage) ;
* `jokers_db` : ajouter une entrée `def(clé, {...})` avec les fonctions de phase
  (`before`, `indiv`, `rep`, `held`, `main`, `other`) pour prendre en charge un joker moddé ;
* `i18n.strings.<langue>` : ajouter une langue sans toucher à l'interface.

Outils hors du mod (non chargés en jeu) :

| Fichier | Rôle |
|---|---|
| `tools/trainer/rules.lua`, `sim.lua` | Balatro simplifié pour l'entraînement (docs/TRAINING.md) |
| `tools/trainer/player.lua` | joueur qui suit exactement l'étape « À FAIRE » du copilote |
| `tools/trainer/run.lua`, `report.lua` | parties simulées en série (`stake=1..8`, `deck=…`, `learn=1` : profil partagé et réglages recalculés après chaque partie), rapport avec le bilan du mod |
| `tools/trainer/bridge.lua` | convertit une partie simulée en journal de partie du mod (pour le bilan et le recalcul des réglages) |
| `tools/love_harness/` | rendu réel du panneau avec LÖVE 11.5 sur un état simulé |
