# Les pourcentages et notes affichés

Le copilote distingue trois types de valeurs. Elles ne sont **jamais** interchangeables.

## 1. Probabilité de réussite (objectif proche)

Exemples : `Victoire blinde : 87 %`, `Victoire boss The Hook : 64 %`,
`gagne tout de suite : 35 %`, `prob. de compléter : 38 %`.

| Indicateur | Objectif | Méthode | Confiance typique |
|---|---|---|---|
| *gagne tout de suite* | la main jouée atteint le score restant | calcul exact, ou énumération exacte des aléas | élevée |
| *prob. de compléter* | une défausse complète la main visée à la prochaine pioche | combinatoire exacte (hypergéométrique, inclusion-exclusion) sur la composition connue du deck | élevée |
| *Victoire blinde* (en main) | battre la blinde avant la fin des mains | simulation de la fin de manche (n affiché) avec une **politique explicite** | élevée à moyenne |
| *Victoire blinde / boss* (avant la blinde) | battre la prochaine blinde / le boss avec le deck complet | simulation de manches fraîches, effets du boss inclus | moyenne |
| *Victoire prochaine blinde / boss* (boutique) | idem, utilisé pour comparer les achats | rééchantillonnage (bootstrap) des mains simulées | moyenne |

Règles d'affichage :
* la **méthode** est toujours indiquée (`calcul exact`, `énumération exacte des aléas`,
  `simulation (n=64)`, `heuristique`) ;
* une simulation qui donne 100 % ou 0 % affiche sa borne de confiance à 95 % (`≥ 94 %`) ;
* `≈` signale qu'un élément n'a pas pu être analysé (joker moddé, carte face cachée…) ;
* si un calcul n'est pas fiable, la valeur est `indisponible` plutôt qu'inventée.

La politique supposée pour la suite de la manche (simulations) est décrite dans
[MATHS.md](MATHS.md#politique-de-jeu-simulée). Ce n'est pas « la meilleure façon de jouer » :
c'est un modèle simple, explicite et reproductible ; une meilleure stratégie peut faire mieux.

## 2. Probabilité de victoire à long terme

Exemple : `Victoire partie : 23 % (confiance limitée, croissance ×2.0/ante a priori)`.

Elle combine la puissance actuelle du build, la taille de toutes les blindes jusqu'à l'ante
gagnante, et un **modèle de progression** (croissance de la puissance par ante) appris sur vos
parties et ramené vers un a priori tant que les données sont rares. Elle suppose les blindes
indépendantes et les boss inconnus ~15 % plus difficiles. **C'est une estimation de modèle, à
confiance limitée** : elle n'est jamais affichée comme certaine (bornée entre `<1 %` et `>99 %`).
En mode Infini, elle est remplacée par la progression attendue (nombre de blindes).

## 3. Note stratégique sur 100

Exemple : `▲ 82/100 Acheter The Duo (8 $)`.

Elle **classe** les options ; ce n'est **pas** une probabilité. 50 = neutre (équivalent à garder
l'argent), au-dessus = recommandé, en dessous = déconseillé. Elle combine :

| Composante | Mesure |
|---|---|
| impact | variation simulée de P(prochaine blinde), P(boss) et de l'estimation de victoire |
| puissance | rapport de puissance par main (simulé) |
| potentiel | gain futur des jokers qui progressent (simulation après croissance, heuristique) |
| synergies | adéquation au build réellement joué (mains jouées, couleurs du deck…) |
| économie | revenus ou valeur en argent |
| coût | prix + intérêts perdus, rapporté à l'argent disponible |
| risque | destruction possible, périssable, location, effets négatifs |
| fiabilité | ramène la note vers 50 si l'option n'a pas pu être simulée |

Les poids dépendent **continûment** du danger : quand la prochaine blinde est menacée,
l'impact immédiat pèse plus et l'économie moins. Formule exacte : [MATHS.md](MATHS.md#note-stratégique).

## Couleurs et symboles

| Classe | Probabilité | Note | Couleur | Symbole |
|---|---|---|---|---|
| favorable | ≥ 80 % | ≥ 70 | vert | `+` (ou `▲`) |
| intermédiaire | 50–80 % | 45–70 | orange | `~` (ou `●`) |
| défavorable | < 50 % | < 45 | rouge | `-` (ou `▼`) |

Les seuils sont configurables (`config.lua`, section `thresholds`).

## Confiance du calcul

* **élevée** : calcul exact, énumération exacte, ou simulation dont l'intervalle de confiance
  à 95 % fait moins de ±4 points ;
* **moyenne** : simulation à ±4–10 points ;
* **limitée** : intervalle plus large, modèle à long terme, ou analyse partielle.
