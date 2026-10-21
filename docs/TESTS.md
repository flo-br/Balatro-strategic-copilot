# Tests

## Exécution

```bash
luajit tests/run.lua          # suite complète sous LuaJIT 2.1 (runtime de Balatro/LÖVE)
lua5.1 tests/run.lua          # même suite sous Lua 5.1 (portabilité stricte)
luajit tests/run.lua shop     # filtre sur le nom du fichier
```

Sous Windows : installer LuaJIT, puis `luajit tests\run.lua` depuis la racine du dépôt.
Aucune dépendance de test : `tests/testlib.lua` fournit assertions, exécution et rapport.

```bash
python3 tools/build.py                                    # paquet dist/…zip
pwsh -NoProfile -File tests/installer/test_installer.ps1 -Zip dist/BalatroStrategicCopilot-1.0.10-installateur.zip [-Smods <sources Steamodded>]
tests/standalone/run_love_standalone.sh dist/BalatroStrategicCopilot-1.0.10.zip [dossier]      # mode autonome, vrai LÖVE
luajit tools/smods_loader_check.lua <sources Steamodded> <dossier Mods>   # vrai chargeur Steamodded
```

## Inventaire

| Fichier | Tests | Couvre |
|---|---|---|
| `unit/test_util`, `test_json`, `test_rng`, `test_scheduler` | 23 | utilitaires, JSON sûr (jamais exécuté), PRNG isolé du jeu, découpage/annulation des calculs, protection d'erreur compatible avec la suspension des calculs (Lua 5.1) |
| `unit/test_poker_eval` | 11 | toutes les mains, As bas/haut sans boucle, Four Fingers, Shortcut, Smeared, Wild (affaiblie ou non), Pierre, Splash, ordre de jeu |
| `unit/test_score_reference` | 36 | **tests de référence** : scores calculés à la main d'après les règles (voir ci-dessous) |
| `unit/test_jokers` | 12 | 150 jokers présents ; jokers de rang, couleur, type de main, état, progression ; Loyalty Card ; argent ; Lucky Cat ; Bloodstone ; **fuzzing** des 150 jokers sur 40 mains aléatoires |
| `unit/test_probability` | 4 | hypergéométrique, inclusion-exclusion, « au moins r groupes » **comparés à l'énumération brute** ; Wilson |
| `unit/test_hand_advisor` | 17 | **1.0.10** : cartes face cachée (The Wheel) : les cartes d'un jeu mêlant cartes cachées et visibles peuvent être défaussées au lieu d'être jouées (option coupée par défaut, mesurée neutre), aucun candidat en double ; **1.0.9** : **ordre des cartes** (Photograph + Hanging Chad : un Roi en tête ; carte Multi avant une carte de verre ; Dames gardées à gauche des Rois avec Shoot the Moon + Baron ; pas de numéros quand l'ordre ne change rien), jeu évalué dans son meilleur ordre (la Double paire qui ne gagne qu'avec un Roi en tête est trouvée) ; **1.0.8** : **Cerulean Bell** (la carte imposée part avec chaque défausse, 4 autres cartes au plus, la défausser seule est une option ; fin de manche simulée avec une nouvelle carte imposée après chaque pioche : chances proches du même jeu sans boss), boss qui changent d'une main à l'autre (The Eye, The Mouth, The Arm, Crimson Heart) ; **1.0.7** : cartes Or et sceau bleu gardées en main sur une main gagnante, valeur des cartes selon leurs effets (acier, or, violet, chance, verre) ; 218 jeux, défausse de couleur exacte, cas impossibles/faciles, monotonie en nombre de mains, carte imposée, The Psychic, carte cachée inutile quand la paire visible gagne, **toutes les cartes cachées (The House)** : conseil non vide, positions interchangeables, même conseil quelle que soit l'identité réelle des cartes, quintes Four Fingers |
| `unit/test_advice` | 35 | **1.0.9** : numéros JOUER 1, 2… / GARDER 1, 2… et IMPOSÉE n sur les cartes ; joker loué acheté seulement s'il est fort ou en danger, revendu quand la suite reste sûre sans lui ; danger critique : relances sans limite de nombre ; **prochaine étape** : achat du meilleur objet abordable, remplacement (vendre d'abord), consommables pleins (faire de la place), vente d'un joker inutile seulement, relance puis blinde suivante, attente de l'analyse complète, planètes (sauf Observatory), tarots d'argent, jouer / défausser, tarot sur les cartes à jouer, Luchador contre un boss dangereux, Invisible Joker prêt, paquets (prendre / passer, cibles d'Arcana), passer ou jouer une blinde (boss toujours joué), numéros d'ordre seulement quand l'ordre est faux ; **1.0.6** : Death (DEVIENT à gauche, MODÈLE à droite, consigne de glissement), Strength, Hanged Man, sceaux, Magician, Chariot, consommables qui créent des cartes, Death pris dans un paquet, blinde : choix définitif seulement, paquets achetés dès 52/100, épargne des intérêts à partir de l'ante 2 (sauf objet fort ou danger), intérêts pesés à l'ante 1, une relance par boutique / relance gratuite ; **1.0.7** : éternel jamais vendu, périssable expiré vendu, Judgement avec jokers pleins (vendre d'abord le plus faible, en boutique et en paquet), règles des pros (en retard → acheter, dernière ante et The Ox → pas d'épargne, relances avec l'argent dormant, une seule relance aux antes 1-3), Verdant Leaf (une seule vente), excédent d'argent investi |
| `unit/test_economy`, `test_strategy`, `test_synergy`, `test_shop` | 29 | **1.0.10** : un joker tiré d'un paquet Bouffon est gratuit (option coupée par défaut, mesurée neutre) ; **1.0.9** : location comptée sur la durée (note bien plus basse que le même joker sans location), paquet Bouffon moins bien noté à la mise or (autocollants), revente d'un joker qui grandit comptée avec sa croissance ; intérêts, puissance reproductible, bootstrap monotone, effets de boss, blindes futures, a priori de croissance, danger continu, **1.0.8 : blindes passées comme les pros** (première Small Blind passée pour Investment, Coupon, Polychrome si la Big Blind reste sûre ; jamais pour Voucher, Juggle, D6, Double seuls ; jamais si la blinde suivante n'est pas sûre), ordre des jokers, contributions, adéquation, classement boutique, remplacement, planètes, variantes, relance, poids selon le danger, **paquets évalués par leur contenu** ; **1.0.7** : location −3 $/manche, cartes à jouer notées selon leurs effets, Judgement mesuré comme un remplacement, Hex / Ankh mesurés sur le plateau qu'ils laissent, relance utile même avec 5 jokers |
| `unit/test_skip` | 6 | **1.0.8** : coût d'un passage (récompense, mains, intérêts, boutique ; Small Blind gratuite dès la mise rouge ; location économisée), tags d'argent selon le montant affiché, Orbital seulement sur la main principale, Big Blind passée seulement avec un boss sûr, Double selon le tag suivant, Boss Tag seulement contre un boss qui contre le jeu |
| `unit/test_high_stakes` | 9 | **1.0.10** (mises verte et au-delà) : seuils « sûr » plus stricts (95 % / 85 % : mêmes chances, épargne gardée à la mise blanche, achat à la mise noire) ; presque jamais passer une blinde (tag Investissement aux antes 1-2, tag Boss contre un boss qui contre le jeu) ; pas de ×Mult à l'ante 4 → plus d'épargne ; trajectoire des parties gagnées (option coupée) ; une seule location avant l'ante 6 et seulement pour un ×Mult ou un joker qui grandit, éternels non ×Mult plus risqués ; bons sans score attendus sur un plateau sûr ; calibrage a priori des chances de la boutique (option coupée) ; planètes de la main principale (option coupée) ; jokers que le jeu ne rend jamais éternels / périssables (listes du wiki, identiques dans le mod et le simulateur) |
| `unit/test_builds` | 5 | **1.0.8** : synergies des builds (Baron + Mime, réduites aux antes 1-2), anti-synergie (Vampire et cartes chance), Steel Joker et cartes d'acier, Blueprint qui veut un ×Mult à copier, build en cours et cartes voulues, cibles des tarots selon le build (Strength Dame → Roi avec Baron, Hanged Man sur les figures avec Canio, The Sun vers les Cœurs avec Bloodstone) |
| `unit/test_plan` | 5 | **1.0.9** : remplacer le seul ×Mult attendu à l'ante suivante par un joker sans ×Mult est pénalisé ; plan de partie : types de jokers, sources de ×Mult (Polychrome comprise), objectifs par ante, « en retard », bonus selon la phase, affichage en boutique |
| `unit/test_persistence` | 8 | aller-retour, **écriture interrompue** (A/B), corruption détectée par somme de contrôle, migration avec sauvegarde, schéma futur jamais écrasé, export/import, rotation des logs, fichiers jamais exécutés |
| `unit/test_adapt` | 4 | **1.0.9** : un changement n'est essayé qu'après une cause qui revient (pas après une seule défaite, jamais pour « main sous la mise » / « décrochage », 3 parties enregistrées), un seul essai à la fois, partie comptée une fois, partie abandonnée ignorée ; essai gardé si les 3 parties suivantes ne sont pas moins bonnes, annulé sinon (retour à `config.lua`, cause mise de côté) ; bornes ; réglages appliqués aux conseils, aux passages et à l'urgence des ×Mult du plan ; texte du bilan avec le verdict |
| `unit/test_learning` | 13 | **scénarios synthétiques à vérité connue** (voir ci-dessous) ; **1.0.7** : bilan sans « malchance », causes d'une défaite (déficit, décrochage, ×Mult, argent dormant, boss, marge), causes retenues pour le plan |
| `unit/test_recorder` | 3 | manche complète journalisée, fin de partie, abandon détecté |
| `unit/test_format` | 7 | pourcentages, classes + symboles, méthode et confiance affichées, couverture partielle, panneau boutique, traduction anglaise, **effets des cartes et autocollants affichés** |
| `integration/test_mod_load` | 8 | `main.lua` réellement chargé via un faux Steamodded : accroches, touches, onglet de config, **première recommandation réelle**, rendu, sélection notée exactement, `calculate` renvoie toujours `nil`, robustesse à un état cassé, **aucune action de jeu appelée** (fonctions piégées), rafraîchissement du panneau |
| `integration/test_state_reader` | 6 | lecture complète, **ordre du deck non divulgué**, cartes face cachée masquées, améliorations/éditions/sceaux, jokers et boutique, erreurs confinées par section |
| `integration/test_compat` | 5 | mods détectés, nombres Talisman, contrôle croisé avec le jeu, dégradation des scores « exacts », multiplicateur appris |
| `integration/test_old_smods` | 6 | Steamodded sans événements de mod (1.0.0~BETA-0509c) : mode de repli, **1.0.9 : toutes les cartes jouées capturées alors qu'elles arrivent une à une** (avant : la première seulement, scores prévus faux), main/défausse/achat/vente/relance reconstruits, bandeau actif, **bandeau encore visible au menu après l'intro**, **bandeau d'erreur au démarrage**, retour au mode natif sans double comptage |
| `integration/test_standalone` | 7 | mode autonome : démarrage sans Steamodded (modules et `config.lua` via `love.filesystem`), bandeau, touches lues au clavier (bascule, pas de répétition, ignorées pendant une saisie ou avec Ctrl, touche déjà enfoncée au démarrage ignorée), amorce : `main.lua` d'origine exécuté une seule fois, ordre de recherche rétabli, démarrage à la 1re image, Steamodded laissé seul s'il a chargé le copilote, dossier du mod absent sans bloquer le jeu, arrêt clair si le `main.lua` d'origine est introuvable |
| `integration/test_steps_ui` | 5 | étiquette sur le bouton « blinde suivante », bouton absent : étape gardée en texte et boutons vus écrits au journal, étiquette « passer » sur la colonne de la blinde en cours, numéros d'ordre sous les jokers puis disparition une fois l'ordre corrigé, **The House** toutes cartes cachées (plus de « Aucune analyse disponible ») |
| `integration/test_full_flow` | 2 | partie complète (main → défaite → bilan → fichiers → **redémarrage avec profil conservé**), boutique de bout en bout avec badges |
| `unit/test_performance` | 6 | mesures (ci-dessous) |
| **Total** | **272** | |

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
* vraies erreurs (écart de note de 38, main à 50 % au lieu de 90 %, relances inutiles) :
  détectées même si la partie est gagnée ;
* 2 succès : intervalle de confiance > 50 points, aucune tendance déclarée ;
* défaite à p = 0,85 : **aucune erreur inventée et aucune « malchance »** : le bilan nomme la marge
  trop faible et les exigences du boss ;
* idempotence, croissance, contributions, multiplicateur inconnu à peine modifié par 1 observation ;
* profil sauvegardé puis rechargé par une nouvelle instance (« redémarrage ») : statistiques intactes.

## Résultats obtenus (2026-10-19)

| Environnement | Résultat |
|---|---|
| LuaJIT 2.1.1703358377 | **249 réussis, 0 échec** |
| Lua 5.1.5 | **249 réussis, 0 échec** |
| Mode autonome sur le **vrai LÖVE 11.5**, exécutable fusionné comme `Balatro.exe` (ci-dessous) | **5 scénarios conformes** |
| Installateur extrait de `…-1.0.8-installateur.zip`, PowerShell 7.4 (Linux) | **9 scénarios, 53 vérifications réussies** |
| Installateur, analyse statique de compatibilité Windows PowerShell 5.1 (PSScriptAnalyzer 1.25, profil Windows 10 / PS 5.1) | **0 erreur de syntaxe, 0 incompatibilité** |

### Mode autonome sur le vrai LÖVE (`tests/standalone/run_love_standalone.sh`)

Le script construit un **exécutable fusionné** (binaire LÖVE 11.5 + archive d'un Balatro simulé
contenant `conf.lua` et `main.lua`), exactement comme `Balatro.exe`, puis le lance sous Xvfb avec
différents dossiers de sauvegarde (l'équivalent de `%AppData%\Balatro`) remplis depuis l'archive
`BalatroStrategicCopilot-1.0.10.zip`. Résultats (2026-10-18) :

| Scénario | Résultat |
|---|---|
| amorce + mod copiés | l'amorce est lue **à la place** du `main.lua` du jeu ; le `main.lua` d'origine est exécuté **une seule fois** ; copilote démarré en mode autonome (« 1.0.8 actif … mode autonome ») ; touche C : panneau ouvert ; C pendant une saisie : ignorée ; analyse terminée (image 311) ; panneau et badges « JOUER » affichés (capture) |
| mod seul, sans amorce | jeu normal, pas de copilote (témoin) |
| amorce sans le dossier du mod | jeu normal jusqu'au bout ; bandeau rouge « dossier introuvable » ; erreur dans `amorce.log` |
| Steamodded a déjà chargé le copilote | l'amorce se retire (« Steamodded gère déjà le copilote »), pas de double chargement |
| jeu demandant `appendidentity = true` | amorce non lue, jeu normal (la seule configuration où le mode autonome ne peut pas fonctionner) |

Avec Lovely, l'amorce serait elle aussi modifiée (même nom que le `main.lua` du jeu) : entourée
du code que Steamodded 0509c et 26.x ajoutent (`crash_handler.lua` avant, `core.lua` après), elle
**compile** et le code ajouté après `do return end` **ne s'exécute pas** (vérifié avec LuaJIT).

### Installateur-diagnostic (`tests/installer/test_installer.ps1`)

Chaque scénario construit une fausse arborescence Windows (racine Steam, bibliothèques,
`appmanifest`, dossiers du jeu, `%AppData%\Balatro\Mods`, Téléchargements, journaux de Lovely),
exécute l'installateur **extrait de l'archive réelle**, puis contrôle le résultat :

| Scénario | Ce qui est vérifié |
|---|---|
| S1 jeu réinstallé dans une autre bibliothèque | bonne installation choisie (celle déclarée à Steam), Lovely absent détecté puis copié depuis l'ancienne installation, Steamodded et autres mods listés, ancienne copie imbriquée + zip déplacés hors de `Mods` (rien supprimé), une seule copie installée, ancien journal signalé comme antérieur aux corrections |
| S2 diagnostic seul après un lancement réussi | Lovely, Steamodded (nombre de patchs) et « copilote prêt » lus dans le journal ; **aucune modification** |
| S3 Steamodded rangé trop bas + doublon désactivé, `version.dll` avec `winmm.dll`, `--vanilla` | Steamodded remonté, doublon déplacé, ancien fichier renommé, option `--vanilla` du bon jeu signalée comme bloquante |
| S4 Lovely et Steamodded absents, archives officielles dans Téléchargements | `winmm.dll` extrait de l'archive Lovely, Steamodded extrait directement dans `Mods\smods`, copilote installé |
| S5 paquet extrait **dans** `Mods` et lancé de là | une seule copie au bon endroit, programme en cours non déplacé, utilisateur prévenu |
| S6 journaux | Steamodded non chargé, copilote absent, erreur au démarrage du copilote, mode vanilla, plantage, autre dossier `Mods` |
| S7 lancement puis attente | journal écrit pendant l'attente détecté, arrêt dès que le copilote est prêt |
| S8 paquet incomplet | message « extraire toute l'archive » |
| S9 copilote désactivé (`Mods\lovely\blacklist.txt`) | ligne retirée, autres lignes conservées, copie de sécurité |

Les dossiers `Mods` produits par S1, S4, S5, S7 et S9 sont ensuite passés aux **deux vrais
chargeurs** de Steamodded (ci-dessous) : copilote trouvé, activé, bandeau « 1.0.3 actif » dans
chaque cas.

### Performances mesurées (LuaJIT, conteneur Linux, plusieurs exécutions)

| Calcul | Mesure |
|---|---|
| Score exact d'une main, 8 jokers | 0,03–0,04 ms |
| Lecture de l'état (instantané) | 0,17–0,19 ms |
| Analyse de main complète (218 jeux + simulations, 64 manches/candidat) | 290–420 ms de CPU, en 60–80 tranches |
| Analyse de boutique complète | 630–810 ms de CPU |
| Plus longue tranche de calcul par image (budget 4 ms) | 6–10 ms |
| Sauvegarde du profil (2 000 observations) | ≈ 4 ms |

### Vrais chargeurs de Steamodded (`tools/smods_loader_check.lua`)

Exécute **le code réel** du chargeur de Steamodded — `loadMods()` de `1.0.0~BETA-0509c` (mai 2025)
et `loadMods()` + `load_mods()` de `26.1009.0` (récent) ; sources non incluses dans le projet,
licence GPL-3.0 — sur un dossier `Mods`, le jeu étant simulé par
`tests/integration/fake_game.lua`. Le dossier `Mods` n'est jamais modifié (les écritures de
Steamodded sont seulement affichées). Résultats avec 0509c (2026-10-13, paquet 1.0.2 ; identiques
avec le chargeur récent sauf mention) :

| Disposition dans `Mods` | Trouvé | Bandeau |
|---|---|---|
| `BalatroStrategicCopilot\` (archive extraite) | oui | « 1.0.2 actif » |
| `BalatroStrategicCopilot-1.0.2.zip` déposé tel quel | **non** | aucun |
| dépôt GitHub entier `balatro-strategic-copilot-…\` | oui | « 1.0.2 actif » |
| dépôt GitHub extrait deux fois `X\X\BalatroStrategicCopilot\` | **non** | aucun |
| `BalatroStrategicCopilot-1.0.2\BalatroStrategicCopilot\` (« Extraire tout ») | oui | « 1.0.2 actif » |
| dépôt entier renommé `BalatroStrategicCopilot\BalatroStrategicCopilot\` | oui | « 1.0.2 actif » |
| dossier du mod + dépôt entier (doublon) | oui (1 copie, l'autre rejetée `dupe`) ; **récent : écrit `BalatroStrategicCopilot` dans `blacklist.txt`** | « 1.0.2 actif » |
| `BalatroStrategicCopilot` listé dans `Mods\lovely\blacklist.txt` (récent) | oui, **désactivé** | aucun |
| `BalatroStrategicCopilot\BalatroStrategicCopilot-1.0.2\BalatroStrategicCopilot\` | **non** | aucun |

Cause des « non » dans le code de Steamodded : les fichiers `.json` ne sont cherchés qu'à 1 ou 2
dossiers sous `Mods` (`depth > 3` arrête l'exploration) et une archive `.zip` n'est ni un dossier ni
un `.json` (seul le chargeur récent, `src/preflight/loader.lua`, monte les zips ; non simulé ici
car il faut LÖVE). La documentation 1.0.0/1.0.1 affirmait à tort qu'un zip déposé tel quel
fonctionnait : corrigé en 1.0.2. Le chargeur récent désactive durablement un mod en double via
`blacklist.txt` : pris en charge par l'installateur en 1.0.3.

### Parties complètes simulées (`tools/trainer`, 1.0.9 : mises 1 à 8, 15 decks)

Le copilote joue seul des parties complètes dans un Balatro simplifié (voir
[TRAINING.md](TRAINING.md)) : chaque décision est l'étape « À FAIRE » du mod. Résultats et
défauts trouvés : TRAINING.md. Ce n'est pas le vrai jeu : ces parties servent à comparer des
versions du copilote et à trouver ses faiblesses.

### Runtime LÖVE réel (harnais `tools/love_harness`)

Exécuté avec **LÖVE 11.5** sous Xvfb : le vrai `love.graphics`, `love.filesystem` et
`love.timer`, avec l'état de Balatro simulé. Scénarios main (ordre des jokers), boutique, choix
de blinde, The House (cartes face cachée), Death dans la zone des consommables (1.0.6 : cartes
DEVIENT / MODÈLE étiquetées, consigne de glissement, panneau placé sous la zone) et effets (1.0.7 :
cartes acier / or / holo / sceaux affichées avec leur rôle, jokers éternel et périssable) et Cerulean
Bell (1.0.8 : étiquette IMPOSÉE sur la carte sélectionnée d'office, explication dans le panneau) et
ordre des cartes (1.0.9 : Photograph + Hanging Chad, JOUER 1 sur le Roi, les étiquettes voisines
décalées d'une rangée pour rester lisibles, « +335 % » dans le panneau) : accroches
installées, analyses terminées (28–298 images), sauvegarde/rechargement réels dans le dossier de
sauvegarde LÖVE, **0 erreur**. Captures : `docs/img/overlay_*.png`.

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
* Steamodded complet dans le jeu : seuls ses **chargeurs** ont été exécutés (deux versions) ; le
  reste (API, interface, injection des objets) est remplacé par un faux respectant les signatures
  vérifiées.
* Le mode autonome avec le **vrai Balatro** : le `conf.lua` du jeu n'a pas pu être lu ; s'il
  demandait `appendidentity = true`, l'amorce ne serait pas lue (rien ne se passerait, jeu normal).
  `BSC\amorce.log` le montre dès le premier lancement.
* L'installateur sous **Windows réel** : il a été exécuté avec PowerShell 7 sous Linux et analysé
  pour Windows PowerShell 5.1, mais ni `cmd.exe` (fichiers `.bat`), ni le registre, ni Steam
  (`steam://`), ni la détection du processus du jeu, ni un antivirus n'ont pu être exercés.
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
