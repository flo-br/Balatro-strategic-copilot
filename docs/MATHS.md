# Méthodes mathématiques et limites des estimations

## 1. Score d'une main (ScoreEvaluator)

Le pipeline de Steamodded a été vérifié dans ses sources (voir [AUDIT.md](AUDIT.md)) et
réimplémenté sur un instantané en tables pures (le pipeline natif modifie l'état et ne peut pas
servir de simulation) :

1. Effets de boss avant le score : The Psychic (5 cartes), The Eye (pas deux fois la même main),
   The Mouth (une seule main), The Arm (niveau −1), The Ox (argent à 0), The Tooth (−1 $ par
   carte), The Hook (2 cartes tenues défaussées au hasard).
2. Contexte *before* des jokers, de gauche à droite (Space Joker, Ride the Bus, Green Joker,
   Runner, Square, Spare Trousers, Obelisk, Vampire, Midas Mask, To Do List…).
3. Jetons et multiplicateur de la main **après** ces effets ; The Flint divise par deux.
4. Cartes jouées dans l'ordre : jetons (rang + bonus + bonus permanent), mult, ×mult, argent,
   puis édition, puis effets *individual* des jokers ; redéclenchements (sceau rouge, Hack,
   Sock and Buskin, Hanging Chad, Dusk, Seltzer, copies Blueprint/Brainstorm).
5. Cartes tenues : Acier ×1,5, Baron, Shoot the Moon, Raised Fist ; redéclenchements (sceau
   rouge, Mime) seulement si la carte a produit un effet.
6. Jokers : édition (Foil/Holo) avant, effet principal, effets « joker sur joker »
   (Baseball Card), Polychrome après ; puis consommables (Observatory).
7. Étape finale du deck (Plasma : équilibrage) puis `floor(jetons × mult)`.

Les **valeurs** (multiplicateurs, compteurs, niveaux, probabilité `normal`) sont lues dans le
jeu ; la base des 150 jokers ne fournit que la logique de déclenchement.

**Aléas** (Lucky Card 1/5 et 1/15, Bloodstone, Misprint 0–23, Space Joker, Business Card,
Reserved Parking, The Hook) : chaque tirage est un *point de choix*. Les chemins sont énumérés
exactement (probabilité de chaque chemin = produit des probabilités) jusqu'à 48 chemins pour
l'analyse de main ; au-delà, Monte-Carlo reproductible (160 échantillons, graine fixe).
Le résultat est une **distribution** ; `P(score ≥ X)` en découle.

« exact » n'est affiché que si : un seul chemin, tous les jokers connus, aucune carte cachée,
aucune amélioration/édition/sceau inconnu, et aucune discordance observée avec le jeu pendant la
session.

## 2. Combinatoire exacte (ProbabilityEngine)

Le deck restant est connu en **composition** (visible dans le jeu), jamais en ordre.
* Hypergéométrique : `P(X = k) = C(K,k)·C(N−K,n−k)/C(N,n)` (couleurs, rangs).
* Suites : il faut au moins une carte de chaque rang manquant → inclusion-exclusion
  `P(tous touchés) = Σ_{S ⊆ manquants} (−1)^{|S|} C(N − n_S, n)/C(N, n)`.
* Four Fingers : « au moins r groupes parmi m » → somme sur les ensembles touchés, chacun par
  inclusion-exclusion. Vérifié contre l'énumération brute dans les tests.
* Intervalles : Wilson à 95 % pour toute proportion simulée.

## 3. Politique de jeu simulée

Pour estimer la probabilité de battre la blinde, la fin de manche est simulée avec un ordre
de pioche aléatoire (graines communes à toutes les actions comparées, pour réduire la variance).
À chaque décision simulée :

1. si une main atteint le score restant → la jouer ;
2. sinon, si `meilleur_score × mains_restantes ≥ restant` → jouer la meilleure main ;
3. sinon, s'il reste des défausses → défausser vers la cible au meilleur potentiel
   (probabilité exacte de complétion × score de la main complétée) ;
4. sinon → jouer la meilleure main.

Les mains candidates dans la simulation sont générées structurellement (groupes de rang,
doubles paires, full, couleurs, suites, carte haute, variantes complétées à 5 cartes) ; la
décision **réelle** proposée au joueur, elle, compare les 218 sous-ensembles exactement.
Les compteurs des jokers évoluent d'une main simulée à l'autre (Green Joker, Ice Cream…).

Limites : politique non optimale (une meilleure stratégie peut faire mieux), The Fish / The
Wheel / The House supposés sans cartes cachées dans les simulations, Crimson Heart ignoré au-delà
de la main courante, destruction des cartes de verre non simulée en cours de manche.

## 4. Puissance du build et P(blinde) hors manche

*Échantillons de puissance* : N mains fraîches tirées au hasard du deck complet ; pour chacune,
score de la meilleure main (politique structurelle) ; une main sur `h` est évaluée comme
« dernière main » (Dusk, Acrobat). Les variantes (acheter X, vendre Y, monter une main…) sont
évaluées **sur les mêmes mains** (nombres aléatoires communs).

*Bootstrap* : `P(total ≥ X)` où chaque main de la manche prend le maximum de `k` échantillons,
`k = 1 + défausses/mains` (part fractionnaire tirée au hasard) — modèle simple de l'apport des
défausses, utilisé pour **comparer** des options. Pour la prochaine blinde, la simulation
complète de la §3 est utilisée.

## 5. Victoire à long terme

`P(victoire) = Π_{blindes restantes} P(blinde_j)` avec, pour une blinde de l'ante `a`,
une puissance mise à l'échelle par `g^(a − a_actuelle)` :

* `g` (croissance par ante) = moyenne géométrique apprise sur vos parties, rétrécie vers
  l'a priori `g₀ = 2,0` avec un poids de 5 parties : `ln g = (5·ln g₀ + Σ ln gᵢ)/(5 + n)` ;
* boss inconnus : taille divisée par 0,85 (≈15 % plus difficiles, a priori) ;
* blindes supposées indépendantes, Small/Big supposées jouées.

C'est un modèle à **confiance limitée**, affiché comme tel.

## 6. Note stratégique

```
z = w_impact·impact + w_puissance·puissance + w_potentiel·potentiel + w_synergie·synergie
    + w_éco·économie − w_coût·coût − w_risque·risque
note = 50 + 50·tanh(z) ;  note = 50 + (note − 50)·fiabilité
```

* `impact = clamp(5·(0,35·ΔP_blinde + 0,35·ΔP_boss + 0,30·ΔP_victoire), −1,5, 1,5)`
* `puissance = clamp(log₂(ratio), −1, 1)` ; `potentiel = clamp(log₂(ratio_futur/ratio), 0, 1)`
* `coût = clamp((prix + 3·intérêts_perdus)/max(10, argent + 10), 0, 1,5)`
* danger `d = 1 − (0,6·P_prochaine + 0,4·P_boss)` ; poids :
  `w_impact = 1,4 + 1,6·d`, `w_potentiel = 0,9·(1 − d) + 0,1`, `w_éco = 0,8·(1 − d) + 0,1`,
  `w_coût = 0,7·(1 − d) + 0,3`, `w_puissance = 1`, `w_synergie = 0,5`, `w_risque = 0,6`.

Les poids ne sont **pas** modifiés automatiquement après une victoire ou une défaite. Leur
réglage automatique a été volontairement écarté : l'attribution d'un résultat de partie à un
achat est trop confondue avec le hasard pour les volumes de données d'un joueur (voir
[LEARNING.md](LEARNING.md)). Ils sont stockés dans le profil et versionnés.

## 7. Relance de boutique

Taux d'apparition lus dans le jeu (`joker_rate`, `tarot_rate`, `planet_rate`, `spectral_rate`,
`playing_card_rate`) ; rareté des jokers selon les constantes vanilla (70 % commun, 25 %
inhabituel, 5 % rare) ; pool réel lu dans le jeu (jokers débloqués, conditions d'apparition,
jokers possédés exclus sauf Showman). 10 jokers tirés selon cette distribution sont évalués par
simulation ; l'espérance de la meilleure note sur 2 emplacements est estimée par bootstrap et
comparée à la meilleure option actuelle et au coût. Un joker moddé du pool reçoit une note
neutre (50) et n'est jamais inventé.

## 8. Heuristiques documentées

Utilisées seulement quand la simulation est impossible, toujours affichées « heuristique » et
ramenées vers 50 (fiabilité 0,5–0,6) :
* valeurs en dollars des tarots, spectrales, bons non simulables, paquets (`model/items_db.lua`) ;
* croissance future des jokers évolutifs (`GROWTH` dans `engine/shop.lua`) ;
* valeurs des tags de blinde (`engine/outlook.lua`) et conseil de passer une blinde :
  conseillé seulement si `valeur_tag > récompense perdue + 2 $` et si la blinde suivante reste
  ≥ 85 % sans la boutique intermédiaire.
Les tarots qui améliorent ou changent la couleur de cartes sont **simulés** sur des cibles
probables (les meilleures cartes non améliorées / les cartes de plus faible valeur), d'où la
mention « simulation approchée ».
