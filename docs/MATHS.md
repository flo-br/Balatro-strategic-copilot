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

Boss dont l'effet change d'une main à l'autre, appliqués dans la fin de manche simulée (1.0.8) :
* **Cerulean Bell** : la carte imposée est toujours sélectionnée, donc jouée **et défaussée** avec
  les autres (4 autres cartes au plus) ; après chaque pioche, une carte de la nouvelle main est
  imposée au hasard (`Blind:drawn_to_hand`). Les défausses proposées contiennent donc toujours la
  carte imposée, et « défausser la seule carte imposée » est une option ;
* **The Eye** : un type de main déjà joué dans la manche ne marque plus ; **The Mouth** : seul le
  premier type joué marque ; **The Arm** : la main jouée perd un niveau, pour les mains suivantes
  aussi ;
* **The Hook** : 2 cartes tenues au hasard sont défaussées à chaque main jouée ;
* **Crimson Heart** : un autre joker au hasard (parmi ceux qui ne l'étaient pas) est désactivé
  à chaque main ;
* **The Fish** (cartes piochées après une main), **The Wheel** (1 sur 7), **The Mark** (figures) :
  les cartes piochées face cachée restent inconnues de la politique (légèrement pessimiste).

Prévision des boss à venir (choix de blinde) : mêmes règles, et les cartes affaiblies le sont comme
dans le jeu (`Blind:debuff_card`) : cartes Joker (Wild) et, avec Smeared Joker, les deux couleurs
rouges ou noires contre les boss de couleur ; toutes les cartes contre The Plant avec Pareidolia ;
cartes déjà jouées dans l'ante contre The Pillar.

Limites : politique non optimale (une meilleure stratégie peut faire mieux), destruction des
cartes de verre non simulée en cours de manche, The House non appliqué aux prévisions (main de
départ supposée visible), Verdant Leaf supposé levé sans perte de joker dans les prévisions.

### Cartes face cachée (The House, The Mark, The Wheel, The Fish)

Le joueur ne voit ni la valeur ni la couleur d'une carte cachée, mais il sait **parmi quelles
cartes** elles se trouvent : la vue du deck montre la pioche restante, donc les cartes cachées
viennent de `deck complet − pioche − cartes visibles en main` (ce lot contient aussi la défausse :
jamais d'information que le joueur n'a pas, et l'identité d'une carte cachée précise n'est jamais
lue). Les positions cachées sont donc **interchangeables** : une action candidate est « ces cartes
visibles + N cartes cachées ». Candidats : les meilleures mains visibles, `N = 1…5` cartes cachées
jouées ou défaussées, et les meilleures mains visibles complétées de cartes cachées ; défausses
ciblées sur les cartes visibles.
* Valeur immédiate d'un jeu : moyenne sur 24 tirages des identités cachées (« ≈ x en moyenne »).
* Probabilité de battre la blinde : fin de manche simulée en deux temps (16 parties pour tous les
  candidats, puis 64 pour les 6 meilleurs), mêmes tirages pour tous les candidats. Seules les
  cartes cachées utilisées par la première action reçoivent une identité ; celles qui restent en
  main **restent inconnues** pour la suite simulée (la politique ne peut pas s'appuyer dessus et
  tend à les défausser, comme le joueur) : estimation légèrement pessimiste si elles sont jouées
  plus tard à l'aveugle.
* À chances égales : moins de cartes cachées jouées (une carte au hasard peut changer le type de
  main, ce que certains boss punissent).

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

**Synergies (builds 1.0.8, grande liste 1.0.12 : `engine/builds.lua`, [SYNERGIES.md](SYNERGIES.md)).**
Un joker reçoit, dans `potentiel`, la somme des forces de ses synergies avec le plateau
(S 0,4 ; A 0,28 ; B 0,16 ; C 0,07 ; X −0,25 ; paires des deux listes, règles générales, deck,
bons achetés et cartes tenues, builds), bornée à [−0,5 ; 0,6] et ×0,7 aux antes 1-2. Une
carte, un bon ou un paquet reçoit de même la somme des synergies avec les jokers possédés, bornée
à [−0,4 ; 0,5] ; pour un paquet, dont la note vient du contenu simulé, elle s'ajoute en points :
`note + 45·w_potentiel·bonus`. Règles générales : même main (B, A avec un ×Mult), une main qui
en contient une autre (C), même couleur payée (B, A avec un ×Mult), un joker de couleur et un
joker de Couleur (C), deux couleurs différentes (−0,07 ; B avec Smeared Joker et deux couleurs de
même teinte), copies (A) d'un ×Mult compatible Blueprint. Une paire nommée remplace la règle
générale pour les mêmes jokers.

**Vos corrections (« Mon choix », 1.0.12, [LEARNING.md](LEARNING.md) §4 bis)** ajoutent aux notes
la préférence apprise (±15 points pour un objet, ±8 pour son type) et multiplient, dans des
bornes, quelques poids (`w_synergie`, `w_potentiel`, `w_risque`, `w_impact`, poids des intérêts).

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

**Paquets (boosters)**, évalués par leur **contenu** : espérance de la meilleure carte parmi les
`k` cartes montrées (tirage sans remise, bootstrap 400), plus la moitié de l'avance de la
2e meilleure quand on en choisit 2, puis `note = 50 + (valeur − 10·coût − 50)·fiabilité` :
* Buffon : les 10 jokers tirés ci-dessus (mêmes notes simulées que pour la relance), fiabilité 0,9 ;
* Céleste : `50 + 30·min(1, 1,5·part_de_la_main)` par main de base (Telescope : la main la plus
  jouée seulement) ;
* Arcane / Spectral : chaque carte notée comme la même carte en boutique, mais **gratuite**
  (`note(économie = valeur/10, fiabilité 0,6)`, +1 $ si elle améliore le deck ; The Soul et
  Black Hole exclus, trop rares) ;
* Standard : 46 (cartes à jouer, rarement utiles sans plan précis).
Fiabilité 0,7 hors Buffon. Ordre de grandeur (ante 1, deck de départ) : Buffon 60–83, Arcane
55–58, Céleste 55–56, Standard 45–46.

## 8. Prochaine étape (« À FAIRE »)

Une seule action est proposée ; après chaque action du joueur l'état change, tout est recalculé et
l'étape suivante apparaît. Règles (`engine/advice.lua`, seuils réglables dans `config.lua`,
section `advice`) :

| Phase | Ordre de priorité |
|---|---|
| Main | 1. Verdant Leaf : vendre le joker qui marque le moins (économie d'abord, jamais un éternel) ; 2. vendre Luchador (s'il n'est pas éternel) si boss actif et victoire < 80 % ; 3. utiliser une planète (sauf avec Observatory : la garder donne ×1,5), Black Hole, The Hermit (≥ 20 $, ou dernière ante), Temperance (≥ 3 $ de revente), Judgement / Wraith (≤ 10 $) / The Soul s'il y a la place, un tarot d'amélioration ou de couleur sur les cartes qui vont jouer ; 4. jouer / défausser selon la simulation de manche |
| Boutique | 1. consommables comme ci-dessus (+ ceux qui créent des cartes quand il y a la place : High Priestess, Emperor, Wheel of Fortune ; Judgement / Wraith / The Soul avec les jokers pleins : vendre d'abord le joker le plus faible si un joker aléatoire a ≥ 50 % de chances d'être meilleur et un gain moyen ≥ 5 %, mesuré comme un remplacement) ; 2. vendre Invisible Joker quand il est prêt, un joker périssable expiré ; 3. meilleur achat abordable dont la note atteint le **seuil exigé** (ci-dessous) — remplacement : vendre d'abord le joker remplacé ; consommables pleins : vendre d'abord le plus faible ; 4. vendre un joker qui apporte ≤ 3 % du score (note de vente ≥ 60) ; 5. relancer : gratuite, ou rentable, ou **une fois par boutique** (ci-dessous) ; 6. blinde suivante |
| Paquet | prendre la meilleure carte (note ≥ 50) — tarot ou spectrale : avec ses cartes cibles (dans la main du paquet) — sinon passer |
| Choix de blinde | (à partir de la mise verte, 1.0.10 : jouer, sauf tag Investissement aux antes 1-2 ou tag Boss contre un boss qui contre le jeu) passer si le tag vaut au moins 1 $ de plus que ce que coûte le passage (récompense, mains, intérêts, jokers, boutique, croissance) et que la blinde qui suit reste ≥ 90 % sans la boutique (§9), sinon jouer ; un boss se joue toujours. Seul le choix **définitif** est affiché (pas pendant que l'analyse se termine) |

**Discipline d'argent inspirée des meilleurs joueurs** (seulement quand la suite est « sûre » :
prochaine blinde ≥ 85 % et boss ≥ 70 % ; **à partir de la mise verte, 95 % et 85 %** (1.0.10) ;
sinon la puissance passe d'abord et seul le seuil de base compte) :
* seuil de base : 56/100, **52/100 pour un paquet** (les meilleurs joueurs en achètent très
  souvent) ;
* à partir de l'ante 2 : garder le plafond d'intérêts (25 $) et ne dépenser que l'excédent ; un
  achat qui fait passer sous 25 $ exige une note ≥ 75 ;
* ante 1 : chaque dollar d'intérêts perdu relève le seuil de 3 points ;
* un objet noté ≥ 75 est toujours acheté (s'il est abordable) ;
* **l'argent au-delà du plafond ne rapporte rien** : si l'achat laisse encore 25 $ + 5 $, tout
  objet noté ≥ 54 est acheté ; antes 1-2 : les 3 premiers jokers sont pris dès 54, épargne ou non
  (« n'importe quel joker vaut mieux qu'un emplacement vide ») ;
* **remplacer un joker** (vendre puis acheter) exige une note ≥ 60 : on perd sa valeur de revente
  et sa progression, pas de va-et-vient pour un gain minime ;
* « en retard » (une main typique, estimée sans défausse, sous 0,5 × la mise de base de l'ante,
  `engine/plan.lua`, seuil calibré sur les parties simulées) : la suite
  n'est pas sûre, l'épargne est levée ; dernière ante et boss The Ox à venir : pas d'épargne ;
* relance : gratuite → toujours ; rentable (§7) → si elle respecte l'épargne ; argent ≥ plafond +
  10 $ et un ×Mult ou de la puissance manque au plan → relancer ; blindes à venir en danger → au
  plus 2 relances par boutique en gardant 10 $ ; argent ≥ plafond + 20 $ → relancer
  pour trouver mieux ; aux antes 1-3, une seule relance par boutique (sauf Chaos the Clown / Flash
  Card) ; sinon **une seule relance par boutique** avant de partir, si elle respecte l'épargne
  (ante 1 : au plus 1 $ d'intérêts perdu) et si la meilleure boutique a ≥ 15 % de chances. Le
  nombre de relances déjà faites se déduit du prix (+1 $ par relance ; prix de départ du tag D6 lu
  s'il existe).
Tous ces seuils sont dans `config.lua` (section `advice`).

**Plan de partie** (`engine/plan.lua`, leçons des meilleurs joueurs, [PRO_LESSONS.md](PRO_LESSONS.md)) :
* sources de ×Mult : jokers ×Mult (et Blueprint / Brainstorm), jokers Polychrome, 3 cartes
  Acier / Verre ou plus ; attendues : 0, 0, 0, 1, 1, 2, 2, 3 aux antes 1 à 8, recherchées une ante
  à l'avance ;
* main principale : la plus jouée (à égalité, la plus haute en niveau) ;
* bonus de note (composante « potentiel ») : ×Mult `0,1 + 0,07·(ante − 2)`, +0,3 quand il en manque
  (×1 à ×1,5 selon les défaites passées) ; jokers qui grandissent +0,2 avant l'ante 6 ; jokers
  additifs −0,25 à partir de l'ante 6, +0,2 aux antes 1-2 tant qu'il y a moins de 2 jokers de score ;
  économie +0,15 aux antes 1-2, −0,2 à partir de l'ante 6 ; planète de la main principale +0,2 ;
* remplacement : bonus du nouveau joker moins celui du joker remplacé.

**Valeur d'une main au-delà de la blinde** (`HA.side_value`, en $) : argent gagné en jouant (sceau
or, chance), cartes Or (+3 $) et sceaux bleus (planète ≈ 3 $) gardés en main si la manche se termine,
carte de verre jouée (−6 $ × 1/4), sceau violet défaussé (tarot ≈ 3 $). Elle départage deux options
de mêmes chances (une main gagnée d'avance n'utilise pas ses cartes Or comme accompagnement), et
l'emporte quand les chances diffèrent de moins de 3 points mais la valeur de plus de 5 $ (The Ox :
jouer la main la plus jouée met l'argent à 0).

**Précision des simulations de manche** : chaque option reçoit 64 simulations ; les 3 meilleures
(à moins de 10 points de la meilleure) en reçoivent 64 de plus ; un écart d'une simulation ou moins
n'est pas un écart : les mains utilisées départagent.

**Valeur d'une carte** (`model/effects_db.lua`, `EF.card_value`, sert à ranger les cartes à
garder, défausser, copier) : jetons de la carte + bonus + 6 × multi (carte chance : multi ÷ 5 et
3 × gain ÷ 15) + 40 × (×Mult − 1) + 60 × (×Mult tenu − 1) (acier) + 4 × argent tenu (or) + 12 si
joker (wild) + édition (brillant 15, holo 25, poly 30) + sceau (or 8, rouge 15, bleu 10, violet −15).

**Cibles des tarots et spectrales** (heuristique explicable ; « utilité » d'une carte = valeur
ci-dessus + 2 × (exemplaires de son rang dans le deck − 4) + 6 si couleur dominante du deck) :

| Effet | Cartes indiquées |
|---|---|
| Mult, Bonus, Verre, Chance (comptent au jeu) | les meilleures cartes de la main recommandée (sinon de la main), jamais une carte défaussée |
| Acier (effet en main) | la carte de plus haut rang gardée en main |
| Or | la carte gardée la moins utile |
| Pierre (Tower) | la carte la moins utile (pas proposé pendant une main) |
| Joker / Wild (Lovers) | la meilleure carte d'une couleur non dominante |
| Couleur (Star, Moon, Sun, World) | vers la couleur dominante du deck : les cartes d'autres couleurs, les meilleures d'abord ; vers une autre couleur : seulement depuis un paquet, sur les cartes les moins utiles |
| Strength (+1 rang) | les cartes dont le rang suivant est plus fréquent dans le deck |
| Hanged Man (détruire) | les cartes simples les moins utiles, jamais sous 20 cartes |
| **Death** (gauche devient droite) | MODÈLE = la carte la plus utile, DEVIENT = la moins utile (écart ≥ 6) ; si DEVIENT est à droite du MODÈLE, le copilote demande d'abord de la glisser à gauche |
| Sceaux : Talisman (or), Déjà Vu (rouge), Trance (bleu), Medium (violet) | or : la meilleure carte jouée ; rouge : la meilleure carte (améliorée de préférence) ; bleu : la moins utile, à garder en main ; violet : la moins utile, à défausser |
| Aura (édition) | la meilleure carte sans édition |
| Cryptid (2 copies) | la meilleure carte |

Chaque carte visée reçoit son étiquette (CIBLE, DEVIENT (gauche), MODÈLE (droite), À DÉTRUIRE).
Pendant une main, un tarot n'est proposé que si la cible est clairement utile.

**Ordre des jokers** : calculé aussi pendant une main (sur les meilleurs jeux de la main), affiché
seulement si l'ordre actuel n'est pas le bon et que le bon ordre marque ≥ 1 % de plus ; chaque
ordre calculé est lié à la disposition exacte des jokers pour laquelle il a été calculé.

**Ordre des cartes (1.0.9)** : le jeu compte les cartes jouées de gauche à droite, puis les
cartes gardées en main de gauche à droite. L'ordre change le score quand une carte donne un ×Mult
(verre, polychrome, Photograph sur la première figure, Triboulet, The Idol, Ancient Joker,
Bloodstone : les +Mult comptés **avant** elle sont multipliés) ou avec Hanging Chad (la première
carte est redéclenchée), et en main avec Shoot the Moon + Baron (les Dames à gauche des Rois).
* Pendant l'énumération des 218 jeux, quand le plateau a l'un de ces effets, chaque jeu est évalué
  dans le meilleur de ses ordres utiles (l'ordre actuel, chaque carte placée en premier, chaque
  carte placée en dernier : 9 ordres au plus pour 5 cartes) ; avant 1.0.9 il l'était dans l'ordre
  de l'écran, et une Double paire gagnante seulement avec un Roi en tête (1 184 contre 272) était
  écartée. La politique de la fin de manche fait de même sur ses deux meilleurs jeux.
* Pour le jeu conseillé, tous les ordres des cartes jouées sont essayés (120 pour 5 cartes) et les
  cartes gardées sont rangées « effets additifs, puis neutres, puis multiplicatifs » ; les numéros
  JOUER 1, 2… / GARDER 1, 2… ne s'affichent que si le bon ordre marque au moins 0,5 % de plus que
  l'ordre actuel.

**Mises (1.0.9)** :
* **location** (mise or) : 1 $ à l'achat puis 3 $ à chaque fin de manche. Le coût compté dans la
  note est `prix + 3 $ × 6 manches` (deux antes de détention), sans les raccourcis « premier
  joker » ni « dépenser l'excédent » : un joker loué n'est pris que s'il est fort (note ≥ 75) ou si
  la suite est en danger. Un joker loué est **revendu** dès que la prochaine blinde et le boss
  restent sûrs sans lui (seuils de sécurité ci-dessus), s'il apporte au plus 15 % du score ou,
  quel que soit son apport, quand il reste moins de 10 $ (le loyer bloque alors tout achat : sur le
  simulateur, Raised Fist loué a coûté 3 $ par manche pendant 11 manches, argent à 0 $). Les paquets
  Bouffon et les relances sont estimés avec les autocollants que leurs jokers peuvent porter
  (éternel 30 % dès la mise noire, sinon périssable 30 % dès la mise orange ; location 30 % à la
  mise or). Sur le simulateur, deux locations prises à
  l'ante 1 (Mad Joker, Lusty Joker à 1 $) avaient vidé l'argent de toute la partie (−5 $ à la fin) ;
* **danger critique** : prochaine blinde ou boss sous 50 % et un ×Mult ou de la puissance manque
  au plan → relancer sans limite de nombre tant qu'il reste 4 $ (l'argent gardé ne vaut rien après
  une défaite ; parties simulées perdues aux antes 6-7 avec 50 à 75 $ en poche) ; danger simple :
  2 relances au plus en gardant 10 $ ;
* **revente d'un joker qui grandit** : sa contribution compte aussi ce qu'il deviendra en 3 manches
  (`GROWTH`) ; avant 1.0.9, Runner, Hologram ou Glass Joker étaient achetés « pour leur
  croissance » puis revendus dans la même boutique comme « n'apportant que 0 % » ;
* **remplacer un ×Mult** par un joker qui n'en est pas un, quand il manquerait alors un ×Mult à
  l'ante suivante : perte de « potentiel » de 0,3 (×1 à ×1,5 selon les défaites passées) ;
* **bons** : un bon est permanent ; ceux qui ne se simulent pas valent `valeur par ante × antes
  restantes` (Overstock 3 $, Clearance Sale 4 $, Reroll Surplus 2,5 $, Telescope 2,5 $, Hone 1,5 $,
  Crystal Ball 1,5 $, Director's Cut 1,2 $, Planet Merchant 1,2 $…) ; avant 1.0.9 une valeur fixe
  de 3 à 9 $, toujours sous le prix de 10 $, les faisait presque toujours refuser. Les bons simulés
  (+1 main, +1 défausse, +1 taille de main) reçoivent en plus `0,3 × min(1, antes restantes / 4)`
  de potentiel ;
* blindes plus grosses (mises verte et violette) : les ×Mult sont attendus une ou deux antes plus
  tôt (`PL.stake_shift`) ; Small Blind sans récompense (lue dans le jeu) ; tags qui donnent un joker
  moins sûrs avec les autocollants (×0,7 / ×0,6).

## 9. Heuristiques documentées

Utilisées seulement quand la simulation est impossible, toujours affichées « heuristique » et
ramenées vers 50 (fiabilité 0,5–0,6) :
* valeurs en dollars des tarots, spectrales, bons non simulables, paquets (`model/items_db.lua`) ;
* croissance future des jokers évolutifs (`GROWTH` dans `engine/shop.lua`) ;
* passer une blinde (`engine/skip.lua`, 1.0.8, sources : PRO_SKIPS_SOURCES.md) : conseillé si
  `valeur_tag − coût_passage ≥ 1 $` et si la blinde qui suit reste battue **sans** la boutique
  sautée (Big Blind ≥ 90 % après une Small Blind passée ; boss ≥ 90 % après une Big Blind passée),
  probabilité tirée d'une **simulation complète de la manche** avec le deck actuel.
  `coût_passage = récompense (0 $ pour la Small Blind dès la mise rouge) + 1 $ × mains restantes
  attendues + intérêts de la manche + argent des jokers de la manche (location : −3 $) + boutique
  + croissance perdue − ce que le passage préserve`. Mains restantes : `mains − ⌈taille / (1,5 ×
  main typique)⌉`. Boutique : 4 $ (ante 1), 6 $ (ante 2), 10 $ (antes 3-6), 14 $ (antes 7-8),
  ×1,25 s'il manque des jokers / un ×Mult / de la puissance, ×0,6 avec moins de 5 $ à dépenser,
  ×0,8 jokers pleins sans manque, ×1,3 pour la boutique d'avant le boss (Big Blind), ×1,3 si le
  boss est sous 70 %, ×1,2 dès la mise violette. Croissance : 2 à 3 $ par joker qui grandit, 2 $
  par joker « quand la blinde est choisie », −1 $ par joker qui s'use ; Throwback −6 $ ; The
  Pillar −3 $. Valeur des tags : tableau de PRO_LESSONS.md §4 (montant affiché pour Economy,
  Speed, Handy, Garbage ; Orbital sur la main principale seulement ; Boss : `60 × (P(boss
  ordinaire) − P(ce boss))` ; Double : 0,6 × le tag suivant s'il vaut ≥ 12 $ ; jokers de tag ×0,7
  dès la mise noire, ×0,6 à la mise or).
* synergies des builds (`engine/builds.lua`, `model/builds_db.lua`) : bonus de « potentiel »
  dans la note de boutique, somme des paires présentes (S 0,40, A 0,28, B 0,16, C 0,07,
  anti-synergie −0,25), bornée à [−0,5 ; 0,6], ×0,7 aux antes 1-2.
Les tarots qui améliorent ou changent la couleur de cartes sont **simulés** sur des cibles
probables (les meilleures cartes non améliorées / les cartes de plus faible valeur), d'où la
mention « simulation approchée ».

## 10. Recalcul du développement après chaque partie (1.0.9)

`learning/adapt.lua`. Après chaque partie, le bilan (`learning/review.lua`) donne les causes ; le
profil compte chaque cause dans les **défaites** et les **victoires** du joueur, et garde le
résultat des 20 dernières parties (ante atteinte, une victoire compte 9).

**Un essai, puis un verdict.** Après une défaite, et si aucun essai n'est en cours, le copilote
essaie **un** changement : celui que demande la cause la plus fréquente de vos défaites, à
condition qu'elle les distingue des victoires (vue dans 2 défaites au moins et
`P(cause | défaite) − P(cause | victoire) ≥ 0,2`, estimations de Laplace ; sans victoire
enregistrée, `P(cause | victoire)` part de 1/2) et qu'au moins 3 parties soient enregistrées.
Le changement est joué pendant **3 parties**, puis jugé : moyenne des 3 parties ≥ moyenne des
parties enregistrées avant l'essai → **gardé** ; sinon **annulé**, et la même cause n'est plus
essayée pendant 10 parties. Chaque étape (à l'essai, gardé, annulé, avec les deux moyennes) est
écrite dans le bilan.

| Cause | Changement essayé (un pas, dans des bornes fixes) |
|---|---|
| ×Mult manquants | urgence des ×Mult en boutique +0,25 (bonus de potentiel ×1,25, au plus ×1,5), seuil de remplacement −2 |
| main principale peu montée | poids des planètes de la main principale +0,25 (au plus ×1,5) |
| argent dormant | seuil « dépenser l'excédent » −2, réserve au-delà du plafond −2, réserve avant relance −4 |
| trop peu de jokers | +1 joker pris d'office aux antes 1-2, seuil d'achat −1 |
| aucune amélioration à l'ante 2 | seuil « dépenser l'excédent » −2, seuil d'achat −1 |
| économie | seuil d'achat +1, épargne une ante plus tôt |
| marge, boss | sécurité exigée et sécurité d'un passage +1 pas |
| défaite juste après un passage | marge d'un passage +2 $, sécurité d'un passage +0,02 |

« Main typique sous la mise » et « puissance qui décroche » n'ont pas de règle : elles sont dans
**toutes** les défaites. Une partie abandonnée n'est pas comptée.

**Mesures qui ont imposé cette forme** (TRAINING.md, mise blanche, mêmes graines 201-220, sans
recalcul : 9 victoires sur 20, ante moyenne 7,0) :
* version 1 (toutes les causes de chaque défaite, appliquées tout de suite) : réglages à leurs
  bornes en 5 parties, 1 victoire sur 10 (graines 201-210, contre 4 sans recalcul) ;
* version 2 (seulement les causes qui distinguent les défaites, appliquées tout de suite) :
  6 sur 20 ; chaque mécanisme seul (réglages : 7 sur 20 ; leçons de la 1.0.7 qui pesaient
  directement sur le plan : 7 sur 20) fait moins bien que sans recalcul, jamais mieux ;
* d'où la version livrée : un changement n'est **gardé que si les parties suivantes ne sont pas
  moins bonnes**. Les leçons de la 1.0.7 (×Mult, planètes) passent par les mêmes essais au lieu de
  peser d'office sur le plan. Mesurée sur les mêmes graines : 7 sur 20 (ante 6,8) ; l'essai qui
  faisait moins bien (urgence des ×Mult) a été annulé ; pas de progrès démontré sur 20 parties.
  `learning.adapt = false` coupe les essais.

Les valeurs ajustées s'appliquent par dessus `config.lua` dans `engine/advice.lua`,
`engine/skip.lua` et `engine/plan.lua`.
