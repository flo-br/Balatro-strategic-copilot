# Leçons des meilleurs joueurs appliquées par le copilote

Synthèse des règles que le copilote applique (version 1.0.7), tirées d'une recherche sourcée sur
les guides, le wiki officiel (balatrowiki.org) et les forums de joueurs expérimentés. La recherche
complète, en anglais, avec l'adresse de chaque source et les désaccords entre sources, est dans
[PRO_LESSONS_SOURCES.md](PRO_LESSONS_SOURCES.md) (les numéros § y renvoient).

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

## 4. Blindes passées

Les meilleurs joueurs ne passent presque jamais (§4.2) : passer coûte la récompense, l'argent des
mains, les intérêts **et la boutique**. Le copilote ne conseille de passer que si le tag vaut plus
que tout cela et que la blinde suivante reste ≥ 95 % ; en pratique Investment ou Economy (§4.3-4.5).

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

## 7. Ce qui n'est pas (encore) appliqué

* Préparation explicite d'un boss connu à l'avance (garder Justice / Chariot pour The Needle ou The
  Eye, Luchador, Director's Cut) : seulement à travers la probabilité de battre le boss.
* Choix de la main principale selon la mise (paire / carte haute aux mises élevées) et
  « affinage » du deck (Hanged Man) au-delà des cibles de tarot.
* Placement de Blueprint / Brainstorm au-delà du calcul d'ordre existant.
