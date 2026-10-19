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
  `deck=b_red`, et tout réglage de la section `advice` de `config.lua` (ex. `buy_note=58`).
* `BSC_MOD_ROOT=<dossier>` : évaluer une autre version du mod (ex. une copie de la 1.0.6).
* `BSC_TRAIN_VERBOSE=1` : chaque main jouée ou défaussée est affichée.
* Une ligne JSON par partie : résultat, ante atteinte, blinde perdue, historique des manches,
  décisions, plateau, niveaux, et les anomalies (étape absente ou impossible à exécuter).
* `report.lua` applique à chaque défaite **le bilan de partie du mod** (`learning/review.lua`) et
  compte les causes trouvées.

## Règles simulées

* Mise blanche, deck rouge par défaut (+1 défausse), 4 mains, taille de main 8, 5 jokers,
  2 consommables, 4 $ au départ ; tailles de blindes vanilla, boss tirés selon leur ante minimale,
  sans répétition avant d'avoir tout vu, boss final à l'ante 8.
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

* Pas d'autocollants (mises supérieures), pas de déblocages ni de « portes » d'apparition des
  jokers (le pool vient de la base du mod), pas d'exclusion des cartes déjà vues dans les paquets.
* Jokers dont les effets hors score ne sont pas simulés : Fortune Teller (compte des tarots),
  Hologram (cartes ajoutées), Madness, Ceremonial Dagger, Riff-raff, Cartomancer, 8 Ball,
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
