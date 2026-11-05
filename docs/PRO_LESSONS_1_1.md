# Leçons des joueurs, recherche de la 1.1 (2026-11-05)

Recherche en ligne faite pour la 1.1 (« remettre en question tout ce qui a été appris »). Les
sources sont surtout des guides communautaires et des discussions de joueurs : des avis, pas des
mesures. Chaque piste a donc été **mesurée sur le simulateur** avant d'entrer dans le copilote
(voir [TRAINING.md](TRAINING.md), « Résultats 1.1 »). Les leçons des versions précédentes sont dans
[PRO_LESSONS.md](PRO_LESSONS.md).

## Ce que disent les sources

| Leçon | Sources |
|---|---|
| Acheter un joker qui marque dès la première ou la deuxième boutique (de préférence un +Mult) ; épargner ensuite vers 25 $. Ne pas acheter de joker au départ est « trop gourmand ». | [Steam : I need some tips](https://steamcommunity.com/app/2379780/discussions/0/4348864383403308040/), [guide débutant](https://game.lb-product.com/en/games/balatro/guides/balatro_beginner-guide) |
| Atteindre le plafond de 25 $ le plus tôt possible et y rester ; exception : les premières boutiques sont la meilleure occasion d'acheter des paquets. | [Mancunion, guide mise or](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/), [Steam](https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782) |
| Gagner les premières blindes en une main : chaque main restante rapporte 1 $. | [Substack, tier list 1.0](https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum) |
| Garder 15 à 20 $ en fin de boutique pour pouvoir acheter plusieurs paquets ou relancer ; les relances sont raisonnables avec un objectif précis ; 0-1 relance tôt, 1-3 en milieu de partie. | [Substack](https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum), [casualgameguides](https://casualgameguides.com/walkthroughs/balatro/money-interest-reroll-strategy) |
| Le moteur ×Mult doit être en place vers l'ante 4-5 ; les victoires ont souvent 2-3 sources de ×Mult. Monter la main principale avec les planètes. | [Steam](https://steamcommunity.com/app/2379780/discussions/0/604143386282207519), [Mobalytics](https://mobalytics.gg/blog/tier-lists/best-balatro-jokers/) |
| Paquets : Arcane et Spectral bien placés, Céleste pour monter les mains, Bouffon surtout au début (« n'importe quel joker vaut mieux que pas de joker »), Standard en dernier. | [Steam](https://steamcommunity.com/app/2379780/discussions/0/4201363889242704640), [dood.gg](https://dood.gg/it/balatro/guides/booster-guide) |
| Bons : Overstock en tête (plus de cartes en boutique), Grabber et Paint Brush tôt, Wasteful et Clearance Sale ensuite. | [games.gg](https://games.gg/balatro/guides/balatro-vouchers-tier-list/), [dood.gg](https://dood.gg/en/balatro/guides/voucher-guide) |
| Passer une blinde : presque jamais, sauf le tag Investissement à l'ante 1. Pas de joker loué tant que l'économie n'est pas faite. | [Mancunion](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/) |
| Taux de chances des cartes de boutique : jokers 20, tarots 4, planètes 4 (Tarot / Planet Merchant : 9,6 ; Tycoon : 32). | [gameplay.tips, RNG guide](https://gameplay.tips/guides/balatro-rng-mechanics-guide.html) |

## Ce que les parties du joueur ont montré (dossier BSC, 5 novembre)

* Prédictions bien calibrées dans le vrai jeu : sur 107 blindes annoncées à 90-100 %, 105 gagnées.
* Défaites en mise orange aux antes 4 à 6, faute de puissance ; une défaite à la petite blinde de
  l'ante 1 (malchance : sur 1 105 parties simulées, 4 défaites sur 1 102 annoncées à 100 %).
* En mode « Je joue, tu apprends » (mise blanche) : le joueur achète beaucoup de paquets et de bons
  et relance souvent quand il est riche, là où le copilote gardait l'argent ; dans un paquet
  Bouffon avec des emplacements vides, il prend le joker plutôt que de passer.

## Ce que le simulateur a montré

À la mise noire (60 parties de la 1.0.12), 80 % des parties atteignent l'ante 5 mais 43 %
seulement l'ante 6. À l'entrée de l'ante 5, les survivants ont 1,2 ×Mult (0,7 chez ceux qui
meurent) et une puissance médiane de 9 400 (6 200) ; la main principale n'est qu'au niveau 2,6
dans les deux groupes. Un joker ×Mult n'apparaît parmi les offres que **1,2 fois par partie** sur
les antes 1 à 5 : le copilote voit trop peu de jokers (il garde ses 25 $ et ne relance qu'au-delà
de 35 $).

## Ce qui a été gardé (mesuré)

Les guides disent d'acheter d'abord un joker qui marque plutôt que d'épargner dès l'ante 1 ; le
simulateur va dans le même sens : sans « 25 $ d'abord », sur 72 parties (mises blanche, noire et
orange, mêmes graines), 9 victoires au lieu de 4, +0,80 ± 0,66 blinde par partie. Le joker gratuit
d'un paquet pour un emplacement vide (l'habitude du joueur) est pris ; il ne change rien de mesurable
mais ne coûte rien. Relancer pour chercher un ×Mult, recommandé par plusieurs guides, a été
mesuré nettement plus mauvais à la mise orange (−0,67 ± 0,23) : l'argent y manque. Détails :
[TRAINING.md](TRAINING.md), « Résultats 1.1 ».
