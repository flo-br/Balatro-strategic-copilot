# Limites connues

## Validation

* **Le mod n'a pas été lancé dans Balatro réel.** L'environnement de développement (Linux, sans
  Balatro) ne le permettait pas. Ont été vérifiés : les API Steamodded/Lovely dans leurs sources,
  le code vanilla cité par les patchs Steamodded, un environnement Balatro/Steamodded simulé, et le
  vrai runtime LÖVE 11.5 (rendu et fichiers). Restent **à confirmer en jeu** : position exacte des
  badges (formule unités → pixels vérifiée dans les sources mais non observée à l'écran), police
  du jeu, ressenti des alertes, et l'ensemble des règles vanilla de score sur des cas réels
  (le contrôle automatique « prédiction exacte = score réel » le signalera dès les premières mains).
* Les valeurs par défaut des jokers (`config` dans `jokers_db.lua`) ne servent qu'en repli ; en
  jeu, les valeurs réelles sont lues dans `card.ability`.

## Étiquettes sur les boutons du jeu

* Les boutons sont repérés par la fonction qu'ils déclenchent (`config.button`). Seul l'identifiant
  `next_round_button` (bouton pour quitter la boutique) est vérifié dans des sources ; les noms
  `reroll_shop`, `select_blind`, `skip_blind`, `skip_booster` ne le sont pas (code du jeu non
  disponible). Si un bouton n'est pas trouvé, l'étape reste écrite dans le résumé et la liste des
  boutons réellement présents est écrite **une fois** dans `BSC\logs\bsc.log`
  (`button … not found … buttons seen`) : à envoyer pour corriger les noms.
* Cibles des tarots et spectrales, seuils d'achat et de vente, discipline d'intérêts, relance
  unique, Luchador : heuristiques documentées (docs/MATHS.md §7–8), réglables dans `config.lua`
  (section `advice`). Elles s'inspirent des habitudes des meilleurs joueurs mais **n'ont pas été
  calibrées sur des parties réelles**.
* Le nombre de relances déjà faites dans une boutique se déduit du prix de la relance (+1 $ à
  chaque fois) ; avec le tag D6, le prix de départ est lu dans `round_resets.temp_reroll_cost`
  s'il existe (champ non vérifié dans des sources ; sans lui, quelques relances bon marché de
  plus peuvent être proposées).
* La zone des consommables est lue dans `G.consumeables` pour y placer le panneau en dessous ;
  la position observée en jeu reste à confirmer.
* Plan de partie et leçons des meilleurs joueurs (docs/PRO_LESSONS.md) : règles de pratique,
  réglées sur des parties **simulées** (docs/TRAINING.md), pas sur des parties réelles. Le
  simulateur n'est pas le vrai jeu : ses résultats servent à comparer des versions du copilote.
* Autocollants : le nombre de manches restantes d'un joker périssable est lu dans
  `ability.perish_tally` s'il existe (non vérifié dans des sources) ; sinon 5 manches sont supposées.
* Préparation explicite d'un boss connu (garder Justice / Chariot, Director's Cut) : seulement à
  travers la probabilité de battre le boss.

## Mode autonome (sans Lovely ni Steamodded)

* Repose sur l'ordre de recherche de LÖVE 11 (dossier de sauvegarde avant le jeu pour `main.lua`,
  vérifié dans `boot.lua` de LÖVE 11.3 à 11.5 et sur le vrai LÖVE 11.5 avec un exécutable fusionné).
  Il ne fonctionne pas si `conf.lua` de Balatro demande `appendidentity = true`, ce qui n'a pas pu
  être vérifié sans le jeu ; dans ce cas rien ne se passe et le jeu reste normal.
* Pas d'onglet de configuration (il est fourni par Steamodded) : réglages dans `config.lua`.
* Pas d'événements de Steamodded : les actions sont reconstruites en comparant les états (comme
  avec les anciens Steamodded).
* Si Lovely est installé en même temps, il modifie aussi l'amorce (comme le `main.lua` du jeu) ;
  l'amorce reste valide et ne fait rien en double (vérifié en compilant l'amorce entourée du code
  de Steamodded 0509c et 26.x), mais elle est alors inutile.

## Règles et modèle

* Jokers, améliorations, éditions, sceaux, mains et boss **moddés** : non simulés ; résultats
  marqués « partiel » ; un joker moddé reçoit au mieux un multiplicateur appris (après 3 mains).
* Cartes **face cachée** (The House, The Wheel, The Mark, The Fish) : jamais lues ; elles sont
  exclues des jeux proposés et leurs effets tenus ignorés (signalé).
* Défis (challenges) aux règles spéciales (ex. plafond de jetons) : non modélisés.
* Loyalty Card : hypothèse sur le moment où `hands_played` augmente (cohérente avec la description
  « toutes les 6 mains » ; l'écart éventuel serait détecté par le contrôle de score).
* Simulations de manche : politique simple et non optimale ; destruction des cartes de verre
  non simulée en cours de manche ; dans les prévisions de boss, The House (main de départ
  supposée visible) et Verdant Leaf (supposé levé sans perte de joker) sont optimistes.
* Victoire à long terme : modèle de progression (croissance géométrique apprise, blindes
  indépendantes, boss inconnus ~15 % plus durs) → **confiance limitée** par construction.
* Tarots, spectrales, paquets, tags : simulés seulement pour les améliorations / changements de
  couleur / niveaux ; le reste est heuristique (affiché comme tel).
* Pas de réglage automatique des poids de la note (choix délibéré, voir LEARNING.md).
* Blindes passées : valeurs des tags et de la boutique sautée **estimées** (synthèse des avis des
  meilleurs joueurs, PRO_SKIPS_SOURCES.md), pas mesurées ; le joker qu'un tag donnera est inconnu.
* Synergies des builds : bonus estimés (paires notées S / A / B / C), ajoutés au gain mesuré ;
  l'ordre des cartes tenues en main (Dames avant Rois avec Shoot the Moon et Baron) n'est pas
  conseillé.

## Interface

* Overlay dessiné par-dessus le jeu (pas d'objets UI Balatro) : pas de survol à la souris ;
  touches `C`, `V`, `B` (modifiables dans `config.lua`, redémarrage requis).
* Si la police du jeu ne contient pas certains caractères (≈, …, symboles de couleur), ils sont
  remplacés automatiquement (`~`, `...`, lettres P/C/T/K).

## Performances

* Analyse de main complète ≈ 0,3 s CPU, boutique ≈ 0,6 s CPU (mesurées sous LuaJIT, voir
  TESTS.md), réparties par tranches de 4 ms par image : les résultats apparaissent
  progressivement (« Analyse en cours… »).
