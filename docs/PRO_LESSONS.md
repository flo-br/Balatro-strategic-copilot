# Leçons des meilleurs joueurs appliquées par le copilote

Synthèse des règles que le copilote applique (version 1.0.9), tirées de recherches sourcées sur
les guides, le wiki officiel (balatrowiki.org) et les forums de joueurs expérimentés. Les recherches
complètes, en anglais, avec l'adresse de chaque source et les désaccords entre sources, sont dans
[PRO_LESSONS_SOURCES.md](PRO_LESSONS_SOURCES.md) (les numéros § y renvoient),
[PRO_SKIPS_SOURCES.md](PRO_SKIPS_SOURCES.md) (blindes passées, 1.0.8) et
[PRO_SYNERGIES_SOURCES.md](PRO_SYNERGIES_SOURCES.md) (synergies des builds, 1.0.8).

Point de départ, partagé par les meilleurs joueurs : **toute partie est jouable**. Une défaite
s'explique presque toujours par un build qui a pris du retard ; le copilote cherche donc où,
avant de parler de variance (§0, §10.2).

## 1. Repères de santé d'une partie

| Repère | Règle appliquée | Où dans le code |
|---|---|---|
| Une main typique doit marquer la **mise de base de l'ante** (le boss, ×2, passe alors en 2 mains) (§1.5) | La main typique du copilote est mesurée sans défausse, ce qui la divise environ par 2 : sous **0,5 × la mise de base**, « en retard », le score passe avant les intérêts (seuil calibré sur les parties simulées : au-dessus, le boss de l'ante passe 87 à 100 % du temps, sous 0,3 seulement 55 %) | `engine/plan.lua` (`falling_behind`), `engine/advice.lua` |
| Fin d'ante 2 : le score doit avoir progressé (§1.6) | Signalé dans le bilan | `learning/review.lua` |
| 4 à 5 jokers au début de l'ante 3 ; au début, n'importe quel joker vaut mieux qu'un emplacement vide (§1.8, §3.3) | Antes 1-2 : les 3 premiers jokers sont pris dès 54/100, épargne ou non | `advice.lua` (`first_jokers`) |
| **×Mult** : en chercher dès l'ante 3-4, au moins 1 à l'ante 5, 2 à 3 aux antes 7-8 (§1.9) | Objectif par ante, avec une ante d'avance ; bonus de note aux ×Mult quand il en manque | `plan.lua` (`XMULT_TARGET`, `joker_bonus`) |
| Les blindes grandissent ×2,5 par ante ; +Jetons et +Mult ne suivent pas (§1.4, §3.8) | Malus de note aux jokers purement additifs à partir de l'ante 6 ; bonus aux jokers qui grandissent tôt | `plan.lua` |
| Une main principale, montée par les planètes (§1.12, §5.1) | Bonus aux planètes de la main principale ; bilan si moins de 70 % des planètes y vont | `shop.lua`, `review.lua` |

## 2. Économie

* Intérêts : 1 $ par tranche de 5 $, plafond 5 $ à 25 $ détenus (§2.1). Garder 25 $ à partir de
  l'ante 2 quand la suite est sûre ; **survivre passe avant** (§2.4).
* **Au-delà du plafond, l'argent ne rapporte plus rien** (« don't get rich ») : un achat qui laisse
  encore 25 $ + 5 $ est fait dès qu'il améliore le jeu (54/100) ; au-delà de 25 $ + 20 $, on relance
  pour trouver mieux (§2.15). Aux antes 1-3 : une relance par boutique au plus, sauf Chaos the Clown
  (§2.15, annexe A6).
* Dernière ante : les intérêts ne remboursent plus rien, l'argent devient du score (§11.7).
* **The Ox** : jouer sa main la plus jouée met l'argent à 0 → le copilote joue une autre main si les
  chances sont presque les mêmes, et dépense avant ce boss (§8.8).
* The Hermit : utilisé à partir de 20 $ (il double jusqu'à +20 $), ou à la dernière ante (§2.13).
* Relancer avec une cible et un budget (§2.15) : en danger, 2 relances au plus par boutique.
* Remplacer un joker seulement pour un gain net (§3.9) : note ≥ 60, pas de va-et-vient.
* Seed Money : intéressant à partir de 40 $ (§2.12). Wheel of Fortune : ne vaut pas son prix (§7.13).
* Location : −3 $ par manche, compté dans l'économie et la note (§2.17).

## 3. Boutique et paquets

* Paquets évalués par leur contenu (jokers simulés pour Bouffon, planètes des mains jouées pour
  Céleste, cartes notées comme en boutique pour Arcane / Spectral) (§3.12-3.13).
* Judgement, Wraith, The Soul avec les jokers pleins : vendre d'abord le joker le plus faible si un
  joker aléatoire a de bonnes chances d'être meilleur ; The Soul : toujours (§7.1-7.4).
* Autocollants : Éternel jamais vendu ; Périssable compté selon les manches restantes, vendu une
  fois expiré ; Location coûte 3 $ par manche (§6.4-6.8).
* Cartes à jouer (boutique, paquet Standard) notées selon leurs améliorations, éditions et sceaux ;
  une carte sans effet dilue le deck (§5.16-5.20).

## 4. Blindes passées (recalculé en 1.0.8)

La règle de la 1.0.6-1.0.7 (« les pros ne passent presque jamais ») venait surtout de messages
écrits **avant le patch 1.0.1f (mai 2024)**. Ce patch a rendu **gratuits** les jokers des tags
Uncommon, Rare, Foil, Holographic, Polychrome et Negative (avant, les tags d'édition en
augmentaient le prix) et porté Investment de 15 $ à 25 $. Le copilote compare maintenant, à chaque
blinde, la valeur du tag au coût réel du passage (`engine/skip.lua`).

**Ce que coûte un passage** (tout est affiché) : récompense de la blinde (**0 $ pour la Small
Blind à partir de la mise rouge**), 1 $ par main restante, intérêts de la manche, argent des
jokers de la manche (une **location** coûte 3 $ par manche : le passage l'**économise**), la
**boutique** qui suit la blinde (≈ 4 $ à l'ante 1, 6 $ à l'ante 2, 10 $ aux antes 3-6, 14 $ aux
antes 7-8 ; plus quand il manque des jokers ou un ×Mult, moins sans argent à dépenser, ×1,3 pour la
boutique d'avant le boss), un tour de croissance des jokers qui grandissent et des jokers « quand
la blinde est choisie » (Cartomancer, Madness…), moins ce que le passage préserve (jokers qui
s'usent, Throwback, cartes non affaiblies contre The Pillar).

**Ce que vaut le tag**, selon la situation (classement des pros) :

| Tag | Valeur retenue |
|---|---|
| Investment | 25 $ (antes 1-3 ; ensuite surtout si l'argent manque) — S |
| Coupon | ≈ 12 $ aux antes 1-2 (boutique gratuite quand l'argent manque), moins ensuite — S |
| Polychrome / Holographic / Negative | joker de base gratuit + édition (Poly fort jusqu'à l'ante 4, Holo surtout antes 1-2, Negative = une place) — A |
| Economy, Speed, Handy, Garbage | le montant que le tag affiche (Economy : votre argent, 40 $ au plus ; Speed : 5 $ par passage) |
| Orbital | ≈ 3 planètes **seulement sur la main principale** (plus avant The Arm / The Flint), sinon rien |
| Boss | seulement contre un boss qui contre le jeu (comparé à un boss ordinaire de même taille) |
| Uncommon / Rare / Foil, Buffoon, Top-up | B : surtout comme premiers jokers, avec de la place |
| Charm, Ethereal, Meteor, Standard | C : rarement (Meteor avec Constellation, Standard avec Hologram) |
| Voucher, Juggle, D6, Double | presque jamais seuls (Double : vaut le tag suivant s'il est fort ; Juggle : avant The Manacle / The Psychic) |

À partir de la mise noire, un joker de tag peut porter un autocollant : sa valeur baisse (×0,7,
×0,6 à la mise or).

**Condition de sécurité** : la blinde qui suit doit être battue **sans** la boutique sautée, avec le
deck actuel : la Big Blind (≥ 90 %) après une Small Blind passée, **le boss** (≥ 90 %) après une Big
Blind passée — les passages de Big Blind restent donc rares, comme chez les pros. Ces chances
viennent d'une simulation complète de la manche (avec défausses) : l'ancienne estimation rapide,
sans défausses, annonçait 70 à 80 % pour une Big Blind d'ante 1 sans joker que le copilote a
gagnée 60 fois sur 60 en simulation.

En pratique (graines simulées) : la première Small Blind est passée pour Investment, Coupon,
Polychrome, Holographic (sans joker), Rare ; Investment, Negative, Orbital sur la main principale
ou Economy avec de l'argent plus tard ; presque jamais pour Voucher, Juggle, D6.

## 5. Pendant la main

* Cartes **Acier**, **Or** et **sceau bleu** : gardées en main ; jamais jouées comme cartes
  d'accompagnement quand la main gagne déjà (§5.11-5.12).
* Carte de **verre** : jouée seulement si elle est utile (1 chance sur 4 de se briser) ; carte
  **chance** : jouée de préférence comme accompagnement (§5.13-5.14).
* Sceau **violet** : défaussé de préférence (il crée un tarot) (§5.12).
* Pas de score inutile : une fois la blinde gagnée, chaque main non jouée vaut 1 $ (§5.9).
* Les meilleures options sont souvent à quelques pourcents les unes des autres : le copilote les
  départage par une seconde série de simulations, puis par le nombre de mains utilisées.
* **Verdant Leaf** : vendre le joker qui marque le moins (économie d'abord) pour lever l'effet (§8.8).

## 6. Bilan d'une défaite

Le bilan applique la liste de vérification des meilleurs joueurs (§10.2) : main typique sous la
mise de base (ante du décrochage), pas d'amélioration à la fin de l'ante 2, trop peu de jokers à
l'ante 3, ×Mult manquants, argent dormant au-delà du plafond, planètes dispersées, main principale
peu montée, préparation du boss, marge insuffisante avant une blinde décisive. Il ne conclut jamais
par « malchance » : une victoire estimée à 85 % laisse 15 % de risque, à réduire avant.

Les causes des défaites sont retenues (10 dernières) : quand la même revient, le plan lui donne plus
de poids (×1 à ×1,5), par exemple l'urgence des ×Mult.

## 7. Synergies des builds qui terminent les parties (1.0.8)

La base `model/builds_db.lua` reprend les builds que les meilleurs joueurs citent pour gagner
l'ante 8 et au-delà (détail, chiffres du wiki et sources : PRO_SYNERGIES_SOURCES.md) :

| Build | Pièces | Main | À construire avec |
|---|---|---|---|
| Rois tenus (Baron + Mime) | Baron, Mime, Rois d'acier à sceau rouge, Blueprint / Brainstorm | Carte haute, Paire | Chariot et Déjà Vu sur les Rois, Death (copier le meilleur Roi), Strength (Dame → Roi) |
| Figures en tête (Photograph + Hanging Chad) | Photograph, Hanging Chad, Sock and Buskin | Carte haute, Paire | figure jouée en premier, sceau rouge et verre sur un Roi |
| Triboulet + Sock and Buskin | Triboulet, Sock and Buskin | Full, Couleur | Strength et Death vers Rois et Dames |
| Canio | Canio, Pareidolia, Glass Joker | toutes | Hanged Man **sur les figures** |
| Petites cartes (Hack) | Hack, Wee Joker, Fibonacci, The Idol | Carré, Full | Hanged Man sur les figures, Death sur un 2 ou un 5 |
| Couleur | jokers de couleur, Smeared Joker, Ancient, Bloodstone (+ Oops!) | Couleur | tarots de couleur vers la couleur des jokers |
| Chance, verre, acier | Lucky Cat + Oops!, Glass Joker, Steel Joker + Mime | — | Magician, Justice, Chariot |
| Cartes ajoutées, Vampire, planètes, Perkeo | Hologram + DNA, Vampire + Midas Mask, Constellation, Perkeo + Observatory | — | — |
| Paires portées par les jokers | Card Sharp, The Duo / Trio / Family, Spare Trousers | Paire, Double paire | Mercury / Uranus, puis une source exponentielle |
| Défausses | Yorick, Hit the Road | — | bons et jokers de défausses |

Ce que le copilote en fait :
* **Boutique** : en plus du gain mesuré tout de suite, un joker reçoit un bonus pour ses
  synergies avec les jokers déjà là (≈ 110 paires notées S / A / B / C, et les anti-synergies :
  Vampire et les cartes chance, Stuntman et Baron, Ride the Bus et les figures…) et avec le deck
  (Steel Joker et des cartes d'acier, Baron et beaucoup de Rois…) ; « synergie : … » s'affiche.
  Aux antes 1-2, ce bonus compte moins : les pros ne forcent pas un build avant que la boutique
  en ait proposé les pièces.
* **Vente et remplacement** : une pièce d'un build garde la valeur de ses synergies.
* **Tarots** : les cibles suivent le build (Chariot et Strength vers les Rois avec Baron, Hanged
  Man sur les figures avec Canio, tarots de couleur vers la couleur des jokers).
* **Plan** : « Build en cours : … », les pièces à chercher et comment l'assembler.

Règles générales retenues : une base de jetons et de +Mult d'abord, puis des ×Mult pour les antes
7-8 ; une ou deux mains, montées par les planètes ; ne pas forcer un build tôt ; les effets de
cartes tenues demandent des cartes en main (pas de Stuntman avec Baron).

## 8. Ajouts 1.0.9 : ordre des cartes et erreurs trouvées en simulation

* **Ordre des cartes** (règle du jeu : cartes comptées de gauche à droite) : numéros JOUER 1, 2… et
  GARDER 1, 2… quand l'ordre change le score (Photograph et Hanging Chad sur la bonne carte, +Mult
  avant les cartes ×Mult, Dames de Shoot the Moon à gauche des Rois de Baron).
* Les règles suivantes ne viennent **pas** des sources ci-dessus mais des défaites du copilote
  sur le simulateur, à toutes les mises (TRAINING.md) : un joker loué se paie 3 $ à chaque manche
  et se revend dès qu'il n'est plus nécessaire ; un joker qui grandit se juge sur ce qu'il
  deviendra ; on ne remplace pas le seul ×Mult attendu à l'ante suivante par des jetons ; en
  danger critique, l'argent gardé ne sert à rien ; un bon est permanent et vaut plus tôt dans la
  partie.

## 9. Mises élevées (1.0.10, mise verte et au-delà)

Sources : [PRO_HIGH_STAKES_SOURCES.md](PRO_HIGH_STAKES_SOURCES.md) (forum Steam, wiki, patch 1.0.1 ;
Reddit et les vidéos n'ont pas pu être lus). Chaque règle a été **mesurée** sur le simulateur avant
d'être gardée (TRAINING.md, « Résultats 1.0.10 ») ; celles qui n'ont rien apporté restent
coupées et sont listées plus bas.

Gardées (ensemble, sur 60 parties simulées à la mise noire jamais utilisées pour les choisir et 40 qui l'ont été : voir TRAINING.md, « Résultats 1.0.10 ») :
* **Presque jamais passer une blinde** à partir de la mise verte : la boutique et la récompense
  perdues coûtent plus que presque tous les tags quand les blindes grandissent ×2,5 par ante.
  Exceptions : le tag Investissement aux antes 1-2, le tag Boss quand le boss à venir contre le
  jeu. C'est la règle qui pèse le plus (17 passages sur 20 parties avant, 4 après).
* **Pas de ×Mult en entrant à l'ante 5** (« ne rattrape presque jamais ») : l'argent n'est plus
  gardé pour les intérêts, tout va à la puissance.
* **L'épargne demande un plateau vraiment sûr** : l'argent n'est gardé pour les intérêts que si la
  prochaine blinde est gagnée à 95 % et le boss à 85 % (85 % / 70 % aux mises blanche et rouge). Mesuré à
  part : +0,18 ± 0,26 blinde par partie sur 60 parties, dans le bruit (épargner davantage faisait
  −0,57) ; plus strict encore (99 % / 95 %) n'apporte rien.
* **Locations** (mise or) : une seule avant l'ante 6, et seulement pour un joker qui porte le score
  (×Mult, joker qui grandit) ; le loyer passe avant les intérêts (plafond relevé de 3 $ par
  location).
* **Éternels** (mise noire et plus) : à partir de l'ante 3, un joker éternel qui n'est ni ×Mult ni
  croissant est noté plus risqué (il bloque un emplacement pour toute la partie).
* **Bons** qui n'ajoutent pas de score tout de suite (Overstock, Clearance Sale, Reroll Surplus…) :
  achetés seulement quand le plateau est sûr.
* Un premier joker de plus est pris sans regarder les intérêts aux antes 1-2.

Essayées et **non gardées** (aucun gain mesuré, voir TRAINING.md) : suivre la « trajectoire » de
puissance des parties gagnantes ; mêler l'estimation des antes futures à la note ; planètes
centrées sur la main principale (−0,6 ± 0,7 : le niveau de la main principale à l'ante 4 ne
prédit pas l'issue des parties simulées, la puissance médiane du plateau, si : corrélation 0,49).

## 10. Ce qui n'est pas (encore) appliqué

* Préparation explicite d'un boss connu à l'avance (garder Justice / Chariot pour The Needle ou The
  Eye, Luchador, Director's Cut) : seulement à travers la probabilité de battre le boss.
* Choix de la main principale selon la mise (paire / carte haute aux mises élevées) : essayé en
  1.0.10 par les planètes, sans gain mesuré.
* Placement de Blueprint / Brainstorm au-delà du calcul d'ordre existant.
