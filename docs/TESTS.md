# Tests

## Exécution

```bash
luajit tests/run.lua          # suite complète sous LuaJIT 2.1 (runtime de Balatro/LÖVE)
lua5.1 tests/run.lua          # même suite sous Lua 5.1 (portabilité stricte)
luajit tests/run.lua shop     # filtre sur le nom du fichier
```

Sous Windows : installer LuaJIT, puis `luajit tests\run.lua` depuis la racine du dépôt.
Aucune dépendance de test : `tests/testlib.lua` fournit assertions, exécution et rapport.

## Inventaire

| Fichier | Tests | Couvre |
|---|---|---|
| `unit/test_util`, `test_json`, `test_rng`, `test_scheduler` | 22 | utilitaires, JSON sûr (jamais exécuté), PRNG isolé du jeu, découpage/annulation des calculs |
| `unit/test_poker_eval` | 11 | toutes les mains, As bas/haut sans boucle, Four Fingers, Shortcut, Smeared, Wild (affaiblie ou non), Pierre, Splash, ordre de jeu |
| `unit/test_score_reference` | 36 | **tests de référence** : scores calculés à la main d'après les règles (voir ci-dessous) |
| `unit/test_jokers` | 12 | 150 jokers présents ; jokers de rang, couleur, type de main, état, progression ; Loyalty Card ; argent ; Lucky Cat ; Bloodstone ; **fuzzing** des 150 jokers sur 40 mains aléatoires |
| `unit/test_probability` | 4 | hypergéométrique, inclusion-exclusion, « au moins r groupes » **comparés à l'énumération brute** ; Wilson |
| `unit/test_hand_advisor` | 8 | 218 jeux, défausse de couleur exacte, cas impossibles/faciles, monotonie en nombre de mains, carte imposée, The Psychic, cartes face cachée, quintes Four Fingers |
| `unit/test_economy`, `test_strategy`, `test_synergy`, `test_shop` | 20 | intérêts, puissance reproductible, bootstrap monotone, effets de boss, blindes futures, a priori de croissance, danger continu, ordre des jokers, contributions, adéquation, classement boutique, remplacement, planètes, variantes, relance, poids selon le danger |
| `unit/test_persistence` | 8 | aller-retour, **écriture interrompue** (A/B), corruption détectée par somme de contrôle, migration avec sauvegarde, schéma futur jamais écrasé, export/import, rotation des logs, fichiers jamais exécutés |
| `unit/test_learning` | 12 | **scénarios synthétiques à vérité connue** (voir ci-dessous) |
| `unit/test_recorder` | 3 | manche complète journalisée, fin de partie, abandon détecté |
| `unit/test_format` | 6 | pourcentages, classes + symboles, méthode et confiance affichées, couverture partielle, panneau boutique, traduction anglaise |
| `integration/test_mod_load` | 8 | `main.lua` réellement chargé via un faux Steamodded : accroches, touches, onglet de config, **première recommandation réelle**, rendu, sélection notée exactement, `calculate` renvoie toujours `nil`, robustesse à un état cassé, **aucune action de jeu appelée** (fonctions piégées), rafraîchissement du panneau |
| `integration/test_state_reader` | 6 | lecture complète, **ordre du deck non divulgué**, cartes face cachée masquées, améliorations/éditions/sceaux, jokers et boutique, erreurs confinées par section |
| `integration/test_compat` | 5 | mods détectés, nombres Talisman, contrôle croisé avec le jeu, dégradation des scores « exacts », multiplicateur appris |
| `integration/test_full_flow` | 2 | partie complète (main → défaite → bilan → fichiers → **redémarrage avec profil conservé**), boutique de bout en bout avec badges |
| `unit/test_performance` | 6 | mesures (ci-dessous) |
| **Total** | **169** | |

### Tests de référence (scores)

Chaque cas de `test_score_reference.lua` documente son calcul, par exemple :
* Paire d'As niveau 1 : `(10 + 11 + 11) × 2 = 64` ;
* Carte de verre holographique : `16 × ((1 × 2) + 10) = 192` (le verre s'applique **avant**
  l'édition de la carte) ;
* Roi d'acier tenu + Baron + Mime : `14 × 2 × 1,5⁴ = 141` ;
* Joker polychrome suivi d'un Joker : `32 × ((2 + 4) × 1,5 + 4) = 416` ;
* Photograph + Hanging Chad sur une paire de Rois : `50 × 16 = 800` ;
* The Flint, Plasma, The Arm, The Psychic, Observatory, Vampire, Midas Mask, Hiker + sceau rouge,
  Wee Joker, Obelisk, Card Sharp, Supernova, Dusk, Acrobat, Stencil, Flower Pot, Seeing Double,
  Lucky Card (distribution 16 / 336, moyenne 80), Misprint (énumération des 24 issues),
  Space Joker (83,25), repli Monte-Carlo, joker inconnu → non exact.

Ces références dérivent des règles vanilla/Steamodded vérifiées (AUDIT.md) ; elles n'ont **pas**
été comparées à des parties réelles. En jeu, chaque main jouée est automatiquement comparée à la
prédiction (journal + diagnostic de compatibilité).

### Tests d'apprentissage (vérité connue)

* 3 défaites à p = 0,9 : la valeur calibrée reste > 0,6 et la calibration n'est pas activée ;
* prédicteur surconfiant (vérité = p/2, 1 500 observations) : calibration activée par la
  validation temporelle, Brier amélioré sur l'échantillon récent, `0,8 → ≈ 0,4`, monotone ;
* prédicteur bien calibré : ECE < 0,05, carte quasi identité ;
* défaite à p = 0,85 avec décisions conformes : **aucune erreur inventée**, malchance signalée ;
* vraies erreurs (écart de note de 38, main à 50 % au lieu de 90 %, relances inutiles) :
  détectées même si la partie est gagnée ;
* 2 succès : intervalle de confiance > 50 points, aucune tendance déclarée ;
* idempotence, croissance, contributions, multiplicateur inconnu à peine modifié par 1 observation ;
* profil sauvegardé puis rechargé par une nouvelle instance (« redémarrage ») : statistiques intactes.

## Résultats obtenus (2026-10-13)

| Environnement | Résultat |
|---|---|
| LuaJIT 2.1.1703358377 | **169 réussis, 0 échec** |
| Lua 5.1.5 | **169 réussis, 0 échec** |
| Paquet `dist/BalatroStrategicCopilot-1.0.0.zip` extrait, puis tests d'intégration sur cette copie | 9 réussis, 0 échec (paquet complet) |

### Performances mesurées (LuaJIT, conteneur Linux, plusieurs exécutions)

| Calcul | Mesure |
|---|---|
| Score exact d'une main, 8 jokers | 0,03–0,04 ms |
| Lecture de l'état (instantané) | 0,17–0,19 ms |
| Analyse de main complète (218 jeux + simulations, 64 manches/candidat) | 290–420 ms de CPU, en 60–80 tranches |
| Analyse de boutique complète | 630–810 ms de CPU |
| Plus longue tranche de calcul par image (budget 4 ms) | 6–10 ms |
| Sauvegarde du profil (2 000 observations) | ≈ 4 ms |

### Runtime LÖVE réel (harnais `tools/love_harness`)

Exécuté avec **LÖVE 11.5** sous Xvfb : le vrai `love.graphics`, `love.filesystem` et
`love.timer`, avec l'état de Balatro simulé. Scénarios main, boutique et choix de blinde :
accroches installées, analyses terminées (68–254 images), sauvegarde/rechargement réels dans le
dossier de sauvegarde LÖVE, **0 erreur**. Captures : `docs/img/overlay_*.png`.

## Défauts trouvés et corrigés pendant la validation

* `goto` introduit dans `shop.lua` (non supporté par Lua 5.1) → réécrit.
* Ordre inversé des lignes « Sélection » dans le panneau (vu sur capture).
* Départage arbitraire entre actions de même probabilité → préférence pour gagner avec moins de
  mains (plus d'argent), puis pour jouer plutôt que défausser.
* « 100 % » affiché pour un résultat simulé → borne de confiance (`≥ 94 %`).
* Lignes coupées dans le panneau → retour à la ligne par mot.
* Libellé trompeur « rapporte ~1 $/manche » pour Credit Card → « permet de s'endetter ».
* Panneau bloqué sur « Analyse en cours… » (cache des lignes et résultat complété sur place)
  → compteur de version + test de non-régression.

## Ce qui n'a PAS pu être testé

* **Balatro réel** : non installé dans l'environnement (Linux, conteneur). Aucun test en jeu n'a
  été réalisé ; aucun n'est revendiqué.
* Le vrai chargeur Steamodded (remplacé par un faux respectant les signatures vérifiées).
* La position réelle des badges sur les cartes (formule vérifiée dans les sources, cohérente
  dans le harnais, non observée dans le jeu).
* La police du jeu (`m6x11plus`) : non disponible ; le remplacement des glyphes manquants est
  prévu et testé avec la police par défaut de LÖVE.
* Les interactions avec d'autres mods réels (seules leurs traces — registre, Talisman, mains
  inconnues — sont simulées).
* Windows (chemins `%AppData%`) : `love.filesystem` gère l'emplacement ; non exécuté sous Windows.
* Manette, très longues sessions (mémoire), toutes les combinaisons de boss rares.

### Vérifications à faire lors du premier lancement réel

1. *Mods* affiche le mod sans avertissement ; `bsc.log` contient
   `ready (update=true draw=true events=true keys=true)`.
2. En main, `C` ouvre le panneau ; les badges « JOUER » sont au-dessus des bonnes cartes.
3. Sélectionner une main : la ligne « Sélection » donne le score ; le jouer : le journal ne doit
   pas contenir `exact score mismatch`.
4. Boutique : notes au-dessus des articles ; fin de partie : bilan affiché, fichiers dans `BSC\`.
