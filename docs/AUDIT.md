# Étape A — Audit de l'environnement

Date de l'audit : 2026-10-13. Ce document décrit ce qui a été **réellement observé**
dans l'environnement de développement, et ce qui ne l'a pas été.

## 1. Système et dossier de travail

| Élément | Constat |
|---|---|
| Système de développement | Linux x86_64 (Ubuntu 24.04, conteneur cloud éphémère) — **pas Windows** |
| Dossier de travail | `/home/user/Balatro-strategic-copilot`, dépôt git `flo-br/Balatro-strategic-copilot` |
| Projet existant | Aucun : dépôt vide (aucun commit, aucun fichier). Rien à préserver. |
| Données utilisateur jointes | `/mnt/user-data/uploads` vide |

## 2. Balatro, Steamodded, Lovely

| Composant | Présent dans l'environnement ? | Conséquence |
|---|---|---|
| Balatro (jeu) | **Non** (aucun `Balatro.exe`, `.love`, dossier Steam) | Le jeu ne peut pas être lancé ici ; aucun test « en conditions réelles » n'est possible. |
| Steamodded (SMODS) | Non installé ; **sources clonées en référence** (scratchpad, non livrées) | API vérifiées dans le code source (voir §4). |
| Lovely injector | Non installé ; sources clonées en référence | Le mod n'utilise **aucun patch Lovely** (pas de dépendance au code source du jeu par motif textuel). |
| Autres mods | Aucun | Compatibilité testée uniquement par conception + détection à l'exécution. |

Versions de référence consultées :

* Steamodded : commit `991b73a` (2026-10-10), `manifest.json` version `26.1002.0`,
  `version.lua` `26.1009.0~dev-a`. Dépendance déclarée par SMODS : Lovely `0.9.0`.
* Lovely : commit `073060e` (2026-09-23), crate `lovely-core` `0.10.0` (tags `v0.9.0`, `v0.10.0`).
* Balatro : version **non vérifiable** ici. Cible : la version stable 1.0.1 (série `1.0.1x`),
  lue à l'exécution via `G.VERSION` quand elle existe.

> Remarque sur la règle « ressources locales uniquement » : aucune documentation n'était
> présente localement. Pour éviter de supposer des API, les dépôts open source de Steamodded
> (GPL-3) et Lovely ont été clonés **dans le dossier temporaire de travail**, comme
> documentation locale de référence. Ils ne font pas partie du mod, ne sont pas redistribués
> et ne sont pas nécessaires à l'exécution. Le mod fonctionne entièrement hors ligne.

## 3. Lua / LuaJIT

* Balatro tourne sur **LÖVE 11.x avec LuaJIT 2.1** (sémantique Lua 5.1 : pas d'opérateurs
  `//`, `&`, pas de `utf8` standard hors LÖVE, `unpack` global, `goto` disponible).
* Installés ici pour les tests : `LuaJIT 2.1.1703358377`, `Lua 5.1.5`, `LÖVE 11.5`.
* Tout le code du mod est écrit en Lua 5.1 portable (testé sous LuaJIT **et** Lua 5.1).

## 4. API vérifiées dans les sources (et non supposées)

| API / donnée | Vérification | Usage dans le mod |
|---|---|---|
| Métadonnées JSON de mod (`id`, `name`, `author[]`, `description`, `prefix`, `main_file`, `version`, `dependencies`, `priority`, `badge_colour`) | `src/preflight/loader.lua` (`json_spec`) | `BalatroStrategicCopilot.json` |
| `SMODS.load_file(path)` → chunk | `src/preflight/loader.lua:874` | chargement des modules |
| `SMODS.current_mod`, `mod.config` (depuis `config.lua`), `SMODS.save_mod_config(mod)` | `src/ui.lua:1655-1700` | configuration |
| `mod.config_tab` (UI `create_toggle{label, ref_table, ref_value}`) | `src/ui.lua:556`, `1944` | onglet de configuration |
| `mod.calculate(self, context)` appelé pour **chaque** `SMODS.calculate_context` | `src/utils.lua:2429` (`get_mods_scoring_targets`) + `get_card_areas('individual')` | observation non intrusive des événements (achat, vente, relance, main, défausse, fin de manche, `game_over`) — retourne toujours `nil` |
| Contextes : `setting_blind`, `end_of_round{game_over}`, `buying_card`, `selling_card`, `reroll_shop`, `open_booster`, `skip_blind`, `using_consumeable`, `pre_discard`, `before`, `after`, `ending_shop`, `starting_shop`, `first_hand_drawn` | patchs `lovely/*.toml` | journal des décisions |
| `SMODS.Keybind{key_pressed, event, action}` | `src/game_object.lua:3850` ; touches déjà prises : `m` (maintien), `alt+f5`, `f2` | ouverture du panneau |
| `Game.update` / `Game.draw` (méthodes de `Game`), accroche par enveloppe | `src/ui.lua:463` (SMODS fait de même) ; `Game:draw` termine en dessinant à l'écran (`lovely/screenshader_rendering.toml`) | rafraîchissement et overlay |
| Transformation unités → pixels : `px = (T + G.ROOM.T) * G.TILESCALE * G.TILESIZE` | `SMODS.pixels_to_unit`, `card_draw.lua:147`, `ui_elements.toml:324` | badges sur les cartes |
| `G.FUNCS.get_poker_hand_info(cards)` (sans effet de bord hors contexte « getter ») ; `evaluate_poker_hand` ; règles Flush House / Full House / Two Pair | `src/overrides.lua:1575`, `src/game_object.lua:3014-3090` | contrôle croisé de l'identification des mains |
| Ordre exact du score (avant → cartes jouées : `playing_card`{chips, mult, x_mult, p_dollars} puis `edition` puis effets « individual » des jokers → cartes tenues → jokers : édition avant, `joker_main`, `other_joker`, édition après → `final_scoring_step` → `floor(chips × mult)`) | `lovely/better_calc.toml`, `src/utils.lua:1512-1600, 2229-2300` | `ScoreEvaluator` |
| `G.STATES.{SELECTING_HAND, SHOP, HAND_PLAYED, DRAW_TO_HAND, GAME_OVER, TAROT_PACK, PLANET_PACK, SPECTRAL_PACK, STANDARD_PACK, BUFFOON_PACK, SMODS_BOOSTER_OPENED}`, `G.GAME.won` | patchs et `src/utils.lua` | détection de phase |
| Journalisation `sendDebugMessage/sendInfoMessage/sendWarnMessage/sendErrorMessage(msg, logger)` | `src/preflight/logging.lua` | `DebugManager` |

## 5. Constat technique majeur : le score natif n'est pas simulable à blanc

Le pipeline natif (`G.FUNCS.evaluate_play` / `SMODS.calculate_context`) **modifie l'état** pendant
le calcul : Green Joker, Ride the Bus, Square Joker, Runner, Obelisk incrémentent leurs
compteurs en contexte `before` ; Vampire et Midas Mask changent l'amélioration des cartes ;
Hiker modifie les cartes ; des événements d'animation et d'argent sont empilés. L'appeler pour
« prévoir » un score modifierait la partie réelle. **Décision** : le moteur de règles du mod
réimplémente fidèlement les règles vanilla sur un instantané en tables pures, en lisant les
**valeurs** (`card.ability`, niveaux de mains, etc.) directement depuis le jeu. Le natif sert
de contrôle croisé (identification de main) et de vérité terrain *a posteriori* (score réel
obtenu après chaque main, comparé à la prédiction).

## 6. Risques de compatibilité

1. Mods ajoutant des jokers/améliorations/mains : leurs effets ne sont pas connus du moteur →
   le résultat est marqué **« partiel »** (jamais « exact »), avec la liste des éléments ignorés.
2. Changements d'API Steamodded : accès au jeu isolés dans `GameStateReader` / `hooks`, tous
   protégés (`pcall`) ; en cas d'échec, dégradation contrôlée (le panneau affiche l'erreur).
3. Positionnement des badges sur les cartes : formule vérifiée dans les sources mais **non
   observée à l'écran** ; désactivable, et toutes les informations figurent aussi dans le panneau.
4. Balatro mobile / autres plateformes : non ciblé.

## 7. Inconnues restantes

* Comportement visuel réel en jeu (aucun lancement possible ici).
* Version exacte de Balatro chez l'utilisateur (lue à l'exécution).
* Certaines constantes vanilla non présentes dans SMODS (ex. tables de probabilité de boutique)
  sont **lues dans `G.GAME` à l'exécution** quand c'est possible, sinon issues de la connaissance
  des règles vanilla et signalées comme hypothèses dans `docs/LIMITATIONS.md`.

## 8. Installation / désinstallation prévues

* Installation : copier le dossier `BalatroStrategicCopilot/` dans `%AppData%\Balatro\Mods\`
  (Steamodded + Lovely installés au préalable). Aucun fichier du jeu n'est modifié.
* Données du mod : `%AppData%\Balatro\BSC\` (via `love.filesystem`), séparées des sauvegardes du jeu.
* Désinstallation : supprimer le dossier du mod (et, si souhaité, `%AppData%\Balatro\BSC\`).
