# Entraînement du copilote sur des parties simulées

`tools/trainer/` fait jouer des **parties complètes** au copilote : à chaque instant, l'analyse du
mod tourne sur l'état simulé, le moteur « À FAIRE » (`engine/advice.lua`) donne l'étape, et un
« joueur » l'exécute exactement (jouer, défausser, utiliser avec ses cibles, acheter, vendre,
relancer, blinde suivante, prendre ou passer une carte de paquet, jouer ou passer une blinde,
ranger les jokers selon les numéros). On mesure ainsi ce que donnent **les conseils eux-mêmes**,
partie après partie, et on retrouve où ils échouent. Rien de cet outil n'est chargé par le mod.

**Ce n'est pas le vrai jeu.** Le score des mains vient du moteur exact du mod ; tout le reste
(pioche, blindes, boss, argent, boutiques, paquets, consommables, bons, tags, événements des
jokers) est réécrit d'après les règles vanilla 1.0.1, avec les simplifications ci-dessous. Les
résultats servent à comparer des versions du copilote entre elles, pas à prédire un taux de
victoire réel.

## Utilisation

```
luajit tools/trainer/run.lua <première_graine> <nombre> <sortie.jsonl> [réglage=valeur ...]
luajit tools/trainer/report.lua sortie.jsonl [autre.jsonl ...]
```

* Réglages : `rollouts=32` et `shop_samples=80` par défaut (le mod utilise 64 et 120 : plus lent),
  `deck=b_red` (15 decks, ci-dessous), `stake=1` à `8` (1.0.9), et tout réglage de la section
  `advice` de `config.lua` (ex. `buy_note=58`).
* `learn=1` (1.0.9) : les parties de la série partagent **un profil**, comme les parties du joueur
  dans le jeu : après chaque partie, le bilan du mod trouve les causes, les leçons nourrissent le
  plan et le copilote recalcule ses réglages (`learning/adapt.lua`) pour la partie suivante ; la
  ligne JSON contient alors `adapt` (changements) et `adapt_deltas` (écarts cumulés).
  `learn=lessons` ou `learn=adapt` : un seul des deux mécanismes (leçons du plan, réglages).
* `BSC_MOD_ROOT=<dossier>` : évaluer une autre version du mod (ex. une copie de la 1.0.6).
* `BSC_TRAIN_VERBOSE=1` : chaque main jouée ou défaussée est affichée.
* **Bifurcations** (1.0.11, Linux) : `luajit tools/trainer/branch.lua <graine> <nombre> <sortie.jsonl>
  antes=2-4 points=first K=4 alts=3 H=3 jobs=3 [réglages]`. Au premier pas de la boutique choisie,
  le processus est dupliqué (`fork()` par la FFI de LuaJIT) : une copie par alternative (le pas du
  copilote, acheter un autre objet, partir, relancer) et par futur (`K` graines de futur, **les mêmes
  pour toutes les alternatives**) ; chaque copie joue la suite avec le copilote, jusqu'à `H` antes
  plus loin (0 : fin de partie). Une ligne JSON par point : l'état, le pas du copilote et les `K`
  scores de chaque alternative. Les alternatives partent du **même état** : on mesure une décision
  sans le bruit des parties qui divergent dès le premier choix différent.
* Options des essais 1.0.10 (mises élevées ; valeur par défaut entre parenthèses, voir
  « Résultats 1.0.10 ») : `hs_rules` (1 : règles des mises élevées), `hs_safe_next` / `hs_safe_boss`
  (0,95 / 0,85), `track_scale` (0), `future_blend` (0), `main_focus` (0), `pack_penalty` (0),
  `prior_cal` (0), `pack_free` (0), `sample_growth` (0), `hidden_discards` (0), `hs_power` (0),
  `xmult_hunt` (0) ; 1.0.11 : `replace_growth` (0), `xmult_extra` (0).
* Une ligne JSON par partie : résultat, ante atteinte, blinde perdue, historique des manches,
  décisions, plateau, niveaux, et les anomalies (étape absente ou impossible à exécuter).
* `report.lua` applique à chaque défaite **le bilan de partie du mod** (`learning/review.lua`) et
  compte les causes trouvées.

## Règles simulées

* Mise blanche, deck rouge par défaut (+1 défausse), 4 mains, taille de main 8, 5 jokers,
  2 consommables, 4 $ au départ ; tailles de blindes vanilla, boss tirés selon leur ante minimale,
  sans répétition avant d'avoir tout vu, boss final à l'ante 8.
* **Mises** (1.0.9, cumulatives) : 2 rouge, Small Blind sans récompense ; 3 verte, blindes plus
  grosses (échelle 2) ; 4 noire, jokers de boutique et de paquet **éternels** (30 %) ; 5 bleue,
  une défausse de moins ; 6 violette, échelle 3 ; 7 orange, **périssables** (30 %, 5 manches) ;
  8 or, **location** (30 %, 1 $ à l'achat, 3 $ par manche, l'argent peut devenir négatif).
* **Decks** (1.0.9) : rouge (+1 défausse), bleu (+1 main), jaune (+10 $), vert (2 $ par main et
  1 $ par défausse restantes, pas d'intérêts), noir (+1 joker, −1 main), magique (Crystal Ball,
  2 The Fool), nébuleuse (Telescope, −1 consommable), fantôme (spectrales en boutique, Hex),
  abandonné (40 cartes, sans figures), damier (26 Piques, 26 Cœurs), zodiaque (Tarot Merchant,
  Planet Merchant, Overstock), peint (+2 taille de main, −1 joker), anaglyphe (Double Tag après
  chaque boss), plasma (jetons et multi équilibrés, blindes ×2), erratique (rangs et couleurs au
  hasard).
* Effets de boss simulés : couleurs et figures affaiblies, The Pillar, The Needle, The Water,
  The Manacle, The Psychic, The Eye, The Mouth (via le moteur de score), The Hook, The Arm, The Ox,
  The Tooth, The Serpent, The Flint, cartes face cachée (The House, The Wheel, The Mark, The Fish),
  Verdant Leaf, Crimson Heart, Cerulean Bell (1.0.8 : la carte imposée part avec chaque jeu et
  chaque défausse, une nouvelle est imposée après chaque pioche), Amber Acorn (mélange), Violet
  Vessel, The Wall. Comme dans le jeu (`Blind:set_blind`), toutes les cartes sont affaiblies dès
  le début de la blinde, pioche comprise (1.0.8 ; avant, celles de la pioche ne l'étaient qu'une
  fois piochées : The Pillar paraissait sûr à 100 %), cartes Joker (Wild) et Smeared Joker compris
  contre les boss de couleur, Pareidolia contre The Plant.
* Argent : récompense 3 / 4 / 5 $, 1 $ par main restante, intérêts calculés avant les gains
  (1 $ par 5 $, plafond 25 $), cartes Or et sceaux bleus en fin de manche, revenus des jokers
  (Golden, Cloud 9, Rocket, Satellite, Delayed Gratification, Egg, Gift Card), location.
* Boutique : 2 cartes (joker 20, tarot 4, planète 4), rareté 70 / 25 / 5 %, éditions aux taux
  vanilla, prix des jokers + coût d'édition, 2 paquets aux poids du wiki (le premier magasin a
  toujours un paquet Bouffon), 1 bon par ante, relance 5 $ +1 $, Chaos the Clown, tags.
* Paquets : Bouffon, Arcane (avec une main tirée pour cibler), Céleste (Telescope), Standard
  (amélioration 40 %, sceau 20 %, éditions), Spectral ; The Soul et Black Hole 0,3 %.
* Tous les tarots, planètes et spectrales ; les bons qui changent le jeu (mains, défausses, taille
  de main, emplacements, remises, éditions, relances, intérêts, taux) ; les tags principaux.
  Tags de boutique comme dans le jeu (1.0.8) : Uncommon / Rare remplacent la première carte de la
  boutique par un joker gratuit, un tag d'édition rend gratuit et édité le prochain joker sans
  édition qui apparaît (relances comprises) ; la main de l'Orbital Tag est affichée avant le
  passage.
* Événements de jokers hors score : défausse (Green Joker, Ramen, Castle, Hit the Road, Mail-In
  Rebate, Faceless, Trading Card, Yorick, Burnt), fin de manche (Popcorn, Turtle Bean, Ice Cream,
  Seltzer, Campfire, Invisible Joker, Gros Michel, Cavendish, périssable), vente (Campfire,
  Luchador, Invisible Joker), cartes jouées (Hiker, Midas Mask, Vampire, DNA, Space Joker, verre
  brisé et Glass Joker), Chicot, Mr. Bones.

## Simplifications connues

* Pas de déblocages ni de « portes » d'apparition des jokers (le pool vient de la base du mod),
  pas d'exclusion des cartes déjà vues dans les paquets ; autocollants tirés indépendamment (30 %)
  et non selon les règles exactes du jeu.
* Madness et Ceremonial Dagger détruisent désormais un joker au choix de la blinde (1.0.9).
* Jokers dont les effets hors score ne sont pas simulés : Fortune Teller (compte des tarots),
  Hologram (cartes ajoutées), Riff-raff, Cartomancer, 8 Ball,
  Superposition, Séance, Sixth Sense, Certificate, Marble Joker, Vagabond, Matador, Hallucination,
  Perkeo, To Do List, Obelisk / Card Sharp hors de la main jouée, et quelques autres.
* Tags non simulés : ceux qui ne figurent pas dans `rules.lua` ne sont pas proposés.
* Générateur aléatoire différent de celui du jeu : une graine du simulateur ne correspond à aucune
  graine réelle.

## Résultats (2026-10-18, deck rouge, mise blanche, réglages par défaut du simulateur)

Étapes intermédiaires, 20 graines :

| Version | Victoires | Ante moyenne | Remarques |
|---|---|---|---|
| 1.0.6 | 0 / 20 | 5,40 | 11 paquets mal gérés (étape impossible à exécuter) |
| 1.0.7, première étape (×Mult, The Ox, relances quand l'argent dort) | 3 / 20 | 5,65 | |

Évaluation finale, **les mêmes 40 graines** pour les deux versions :

| Version | Victoires | Ante moyenne | Ante 5 atteinte | Ante 6 | Ante 7 | Ante 8 | Étapes impossibles |
|---|---|---|---|---|---|---|---|
| 1.0.6 | 6 / 40 (15 %) | 5,58 | 80 % | 53 % | 33 % | 25 % | 31 |
| 1.0.7 | 11 / 40 (28 %) | 6,63 | 95 % | 78 % | 55 % | 43 % | 2 |

Graine par graine, la 1.0.7 va plus loin sur 22 graines, moins loin sur 8, aussi loin sur 10.
Les probabilités affichées restent bien calibrées : les blindes annoncées gagnées à 90-100 % l'ont
été 98 % du temps.

Ce que les défaites simulées ont montré, et qui a été corrigé en 1.0.7 :
* un plateau sans ×Mult perd à l'ante 5-6 ou contre Violet Vessel ;
* l'argent s'accumulait (50 à 110 $) au lieu de devenir de la puissance ;
* des emplacements de jokers restaient vides (3 jokers à l'ante 5 avec 80 $) ;
* contre The Ox, jouer la main la plus jouée a coûté 67 $ ;
* entre options presque certaines, le hasard de 32 simulations décidait ;
* Hex et Ankh détruisaient des plateaux entiers, Judgement était conseillé jokers pleins sans
  dire quoi vendre ;
* va-et-vient de jokers (acheter, revendre, racheter) et relances en série en position difficile.

Ce qui reste, d'après le bilan du mod sur les 29 défaites de la 1.0.7 (une défaite a souvent
plusieurs causes) : main typique sous la mise de base (29), puissance qui décroche à une ante (24),
×Mult manquants (24), boss mal préparé (24), argent dormant au-delà du plafond (20), planètes
dispersées (15), main principale peu montée (12). Ce sont les pistes des prochaines versions.

## Résultats 1.0.8 (2026-10-19, simulateur corrigé, mêmes 40 graines)

Le simulateur a été corrigé (Cerulean Bell, affaiblissements dès le début de la blinde, tags de
boutique) : les chiffres ne se comparent qu'entre versions jouées sur **ce** simulateur.

| Version | Victoires | Ante moyenne | Ante 6 atteinte | Ante 7 | Ante 8 | Blindes passées |
|---|---|---|---|---|---|---|
| 1.0.7 | 8 / 40 (20 %) | 6,78 | 85 % | 68 % | 58 % | 23 (Investment 16, Economy 7) |
| 1.0.8 | 16 / 40 (40 %) | 6,95 | 88 % | 73 % | 60 % | 38 (Economy 10, Investment 8, Polychrome 5, Holographic 3, Boss 3, Garbage 3, Rare 2, Coupon 2, Negative 1, Handy 1) |

Graine par graine, la 1.0.8 va plus loin sur 20 graines, moins loin sur 13, aussi loin sur 7. Les
blindes annoncées gagnées à 90-100 % l'ont été 721 fois sur 723. Une défaite suit directement un
passage : graine 24, The Manacle (ante 1) perdu à 268 / 600 alors qu'il était annoncé à 96 %.

**Mesure qui a changé le calcul des passages** : passer la première Small Blind, puis jouer la
Big Blind de l'ante 1 **sans aucun joker** avec les conseils du copilote : **60 victoires sur 60**.
L'ancienne estimation rapide (mains typiques sans défausses) l'annonçait à 70-81 % et interdisait
donc ce passage, que les meilleurs joueurs font couramment ; la blinde qui suit est désormais
estimée par une simulation complète de la manche (100 % ici).

Causes des 24 défaites de la 1.0.8 d'après le bilan du mod : main typique sous la mise de base
(24), puissance qui décroche (21), boss (21), ×Mult manquants (20), argent dormant (17), planètes
dispersées (13).

## Résultats 1.0.9 (2026-10-19, toutes les mises, 15 decks)

Réglages du simulateur : `rollouts=24 shop_samples=60` (plus rapide que le mod en jeu). « Avant » =
la version de travail du début de cette série (ordre des cartes affiché, capture des cartes jouées
corrigée, simulateur multi-mises), **avant** les corrections trouvées en faisant jouer le copilote à
toutes les mises ; « après » = 1.0.9 livrée. Mêmes graines des deux côtés.

| Deck rouge | Avant | Après |
|---|---|---|
| Mise blanche (1), graines 1-5 | 2 / 5 victoires, ante moyenne 7,8 | **3 / 5**, ante moyenne 7,4 |
| Mise bleue (5), graines 1-6 | 0 / 6, ante moyenne 5,33 | 0 / 6, ante moyenne 5,17 |
| Mise or (8), graines 1-10 | 0 / 10, ante moyenne 4,1 ; **312 $ de loyers** payés, argent négatif dans 4 parties | 0 / 10, ante moyenne 4,2 ; **128 $ de loyers**, jokers loués revendus |

**15 decks à la mise noire (4)**, graines 101-103, 1.0.9 livrée : **1 victoire sur 45** (deck
Zodiaque), ante moyenne 5,22 ; ante 5 atteinte 76 %, ante 6 31 %, ante 8 9 %.

| Deck | Victoires | Ante moyenne | | Deck | Victoires | Ante moyenne |
|---|---|---|---|---|---|---|
| Rouge | 0 / 3 | 5,00 | | Abandonné | 0 / 3 | 5,67 |
| Bleu | 0 / 3 | 6,00 | | Damier | 0 / 3 | 4,67 |
| Jaune | 0 / 3 | 4,33 | | Zodiaque | 1 / 3 | 5,33 |
| Vert | 0 / 3 | 5,33 | | Peint | 0 / 3 | 4,67 |
| Noir | 0 / 3 | 5,00 | | Anaglyphe | 0 / 3 | 6,00 |
| Magique | 0 / 3 | 4,67 | | Plasma | 0 / 3 | 6,00 |
| Nébuleuse | 0 / 3 | 5,67 | | Erratique | 0 / 3 | 5,00 |
| Fantôme | 0 / 3 | 5,00 | | | | |

Trois parties par deck ne suffisent pas à classer les decks entre eux ; ce tableau montre surtout
qu'aucun deck ne fait planter le copilote ni le simulateur (0 erreur sur 45 parties).

**Ce que ces parties ont fait trouver et corriger** (détails : MATHS.md §8, « Mises ») :
* deux jokers **loués** à 1 $ pris à l'ante 1 vidaient l'argent de toute la partie (location
  comptée comme 1 $) ;
* un paquet Bouffon acheté pour une « meilleure carte attendue 97/100 » à la mise or, puis tous ses
  jokers refusés (autocollants ignorés dans l'estimation) ;
* jokers qui grandissent achetés pour leur croissance puis revendus dans la même boutique
  (sur 22 parties, 33 jokers revendus dans la manche même de leur achat ou la suivante, toutes
  raisons confondues) ;
* Baron (seul ×Mult) vendu à l'ante 3 pour Crafty Joker ;
* 50 à 75 $ gardés aux antes 6-7 alors que le boss était perdu d'avance ;
* bons presque jamais achetés (3 en 22 parties) ;
* une Double paire gagnante seulement avec un Roi en tête écartée (jeux évalués dans l'ordre de
  l'écran).

**Ce qui reste** (bilan du mod sur les 44 défaites des 15 decks) : main typique sous la mise (44),
×Mult manquants (39), puissance qui décroche (32), boss (27), main principale peu montée (17),
planètes dispersées (15), marge (13). La plupart des parties s'arrêtent à l'ante 5 (20 sur 45) :
aux mises 3 et plus, les blindes de l'ante 5 (20 000 à 30 000) demandent un plateau à ×Mult que le
copilote ne réunit pas encore à temps. Les boss qui cachent des cartes (The House, The Fish,
The Mark) terminent 10 parties sur 44. Aux mises 5 et 8, le copilote ne gagne aucune partie
simulée : il n'est pas au niveau des meilleurs joueurs sur ces mises.

### Recalcul après chaque partie (`learn`), mise blanche, deck rouge, graines 201-220

Chaque série enchaîne les parties sur **un même profil**, comme un joueur : après chaque partie,
le bilan du mod, puis le recalcul. Comparaison avec les mêmes graines jouées sans recalcul.

| Version du recalcul | Graines 201-210 | Graines 211-220 | Total |
|---|---|---|---|
| Aucun recalcul | 4 / 10, ante 7,3 | 5 / 10, ante 6,7 | **9 / 20, ante 7,0** |
| v1 : toutes les causes, appliquées tout de suite (+ leçons 1.0.7) | 1 / 10, ante 6,4 | — | — |
| v2 : causes qui distinguent les défaites, appliquées tout de suite (+ leçons 1.0.7) | 3 / 10, ante 6,8 | 3 / 10, ante 6,5 | 6 / 20, ante 6,65 |
| leçons 1.0.7 seules (poids d'office sur le plan) | 2 / 10, ante 7,0 | 5 / 10, ante 6,7 | 7 / 20, ante 6,85 |
| v2 réglages seuls | 4 / 10, ante 7,1 | 3 / 10, ante 6,5 | 7 / 20, ante 6,8 |
| **v3 livrée : un essai de 3 parties, gardé seulement s'il ne fait pas moins bien** | 3 / 10, ante 7,0 | 4 / 10, ante 6,6 | 7 / 20, ante 6,8 (et une série de 20 parties d'affilée : 7 / 20, ante 6,8) |

Lecture honnête : **aucune version du recalcul ne fait mieux que pas de recalcul** sur ces 20
graines ; la v1 faisait nettement moins bien (les réglages atteignaient leurs bornes en 5 parties).
La v3 a fait ce pour quoi elle est conçue : l'urgence des ×Mult, essayée après 3 défaites, a donné
ante 6, victoire, ante 6 (moyenne 7,0) contre 8,0 avant : **annulée** ; les essais « plus de
sécurité » ont été annulés une fois puis gardés (sécurité exigée contre le boss +0,03 à +0,06), ce
qui reste dans le bruit. Avec 20 parties, un écart de 2 victoires n'est pas significatif
(écart-type ≈ 2,2 victoires) ; il ne montre pas non plus de progrès. Le recalcul reste donc
prudent (un essai à la fois, annulé s'il ne paie pas) et peut être coupé (`learning.adapt = false`).

## Résultats 1.0.10 (2026-10-21, mises élevées)

Demande : progresser aux mises élevées. Réglages du simulateur : `rollouts=24 shop_samples=60`,
deck rouge. **Mesure** : une victoire est rare à ces mises (0 à 2 sur 20 parties), on compte donc
les **blindes gagnées**, plus la fraction du score atteinte contre la blinde perdue (une victoire
compte 25). Chaque version joue **les mêmes graines** ; l'écart est calculé graine par graine
(moyenne ± erreur type). Avec 20 parties, l'écart type d'une différence est de 2 à 6 blindes :
seul un écart d'environ ±1,5 se détache du bruit, d'où la validation finale sur de **nouvelles
graines**, jamais utilisées pour choisir les réglages.

### Essais un par un (mise noire, graines 301-320)

| Essai | Blindes + fraction | Ante moyenne | Écart |
|---|---|---|---|
| 1.0.9 (référence) | 14,13 | 5,30 | — |
| E1 trajectoire des parties gagnantes | 14,11 | 5,30 | −0,02 ± 0,73 |
| E2 trajectoire + estimation des antes futures | 13,69 | — | −0,44 ± 0,68 |
| E3 règles des mises élevées + trajectoire | 15,59 | 5,60 | +1,46 ± 1,07 |
| **E4 règles des mises élevées** | **15,66** | **5,40** | **+1,53 ± 0,72** |
| E5 planètes centrées sur la main principale (comparé à E3) | 15,02 | 5,35 | −0,57 ± 0,71 |
| E6 calibrage a priori des chances (comparé à E3) | = E3 | = E3 | décisions identiques |
| E7 −8 points aux paquets Arcane / Standard / Spectral (comparé à E4) | 14,61 | 5,15 | −1,05 ± 1,31 |
| E8 relances pour chercher un ×Mult dès l'ante 3 (comparé à E4) | 15,66 | 5,55 | 0,00 ± 0,59 |
| E9 jokers d'un paquet Bouffon comptés gratuits (comparé à E4) | 15,52 | 5,45 | −0,15 ± 0,90 |
| E10 poids de la puissance du plateau ×1,5 (10 parties, arrêté) | 12,77 | 4,60 | −1,98 ± 1,23 |
| E11 E9 + croissance des jokers tirés | 15,40 | 5,45 | −0,27 ± 0,91 |
| E6b seuils « sûr » lus sur les chances calibrées (épargne plus) | 15,09 | 5,25 | −0,57 ± 0,54 |
| E12 E9 + E11 + défausses avec cartes cachées + E8 | 15,25 | 5,50 | −0,41 ± 0,93 |
| **E14 seuils « sûr » plus stricts aux mises élevées : 95 % / 85 % (épargne moins)** | **16,03** | **5,50** | **+0,37 ± 0,41** |
| E15 seuils encore plus stricts : 99 % / 95 % | 15,66 | 5,40 | 0,00 ± 0,87 |

### Validation sur de nouvelles graines (1.0.10 livrée = E4 + E14)

| Mise, graines | 1.0.9 | 1.0.10 | Écart graine par graine |
|---|---|---|---|
| Noire (4), 321-340 | 14,50 ; ante 5,40 ; 1 victoire | 15,69 ; ante 5,55 ; 1 victoire | +1,19 ± 0,96 |
| Noire (4), 341-360 | 13,54 ; ante 5,00 ; 1 victoire | 14,53 ; ante 5,10 ; 1 victoire | +0,99 ± 1,31 |
| Noire, 321-360 (graines jamais utilisées pour choisir) | 14,02 ; ante 5,20 ; 2 victoires | 15,11 ; ante 5,33 ; 2 victoires | +1,09 ± 0,80 |
| **Noire, 301-360 regroupées (60 parties)** | 14,06 ; ante 5,23 ; 2 victoires | 15,42 ; ante 5,38 ; 2 victoires | **+1,36 ± 0,59** |
| Or (8), 401-412 | 8,38 ; ante 3,25 ; 0 victoire | 9,99 ; ante 3,75 ; 0 victoire | +1,61 ± 0,81 |
| Blanche (1), 501-512 | 20,08 ; 4 victoires sur 12 | 20,08 ; 4 victoires sur 12 | identique (règles actives à partir de la mise verte) |

E14 seul (seuils plus stricts) contre E4 : +0,37 ± 0,41 (301-320), +0,52 ± 0,48 (321-340), puis
−0,33 ± 0,50 (341-360) : **+0,18 ± 0,26 sur 60 graines, dans le bruit**. Gardé parce que son effet
estimé reste positif et va dans le même sens que E6b (épargner davantage : −0,57) ; E15, plus
strict encore, n'apporte rien. Sans ces seuils, les seules règles des mises élevées font
+1,18 ± 0,56 sur les mêmes 60 graines : l'essentiel du progrès vient d'elles.

### Ce que le diagnostic a montré

* **Probabilités de la main** (fin de manche simulée) : bien calibrées, plutôt prudentes. Sur
  toutes les décisions des essais, annoncé 40-70 % → gagné 60-85 % ; annoncé 90-100 % → 100 %. Une
  défaite contre The Wheel rejouée en détail (graine 314, 5 200 à faire, quinte à 4 940 sur la
  manche précédente) était un pari juste, perdu.
* **Ce qui prédit l'issue d'une partie** (95 parties, plateau à l'entrée de l'ante 4) : la
  puissance médiane du plateau (corrélation 0,49) et la chance annoncée contre le boss (0,42) ;
  pas le niveau de la main principale (−0,04), ce qui explique l'échec de E5.
* **Morts** : surtout à l'ante 5 (20 000 à 40 000 à faire), par manque de puissance : 6 à 8
  défaites sur 20 contre une simple Big Blind ; un ×Mult proposé en boutique seulement 26 fois
  en 20 parties, presque toujours aux antes 1-3.
* **Erreurs trouvées et corrigées dans les deux modèles** (copilote et simulateur) : les jokers
  que le jeu ne rend jamais éternels ou périssables (listes du wiki : un joker qui grandit n'est
  jamais périssable) ; le simulateur les approchait par des étiquettes (Cavendish et Turtle Bean
  pouvaient y être éternels). Analyse des cartes cachées : candidats en double retirés.
* **Corrigées mais coupées** parce que la mesure ne montre aucun gain : le prix d'un joker tiré
  d'un paquet Bouffon était compté en plus du prix du paquet (E9 : 23 → 30 paquets Bouffon
  achetés, issue inchangée) ; la croissance des jokers tirés pour un paquet ou une relance (E11) ;
  avec des cartes cachées, défausser les cartes d'un jeu qui mêle cartes cachées et visibles
  (le jeu choisi à The Wheel jouait cinq cartes faibles pour 13 jetons avec quatre défausses ;
  la simulation donne 73,3 % pour la défausse contre 73,0 % pour ce jeu : écart négligeable).

**Lecture honnête.** Sur ces parties simulées, la 1.0.10 gagne en moyenne 1,1 à 1,4 blinde de plus
par partie à la mise noire (selon qu'on compte ou non les graines qui ont servi à choisir) et 1,6
à la mise or (12 parties), sans rien changer à la mise blanche ; elle ne gagne **pas plus de
parties** (2 sur 60 de part et d'autre à la mise noire, 0 sur 12 à la mise or). La plupart des
parties s'arrêtent toujours à l'ante 5 : le copilote reste loin du niveau des meilleurs joueurs à
ces mises. Rien n'a été vérifié dans le vrai jeu.
