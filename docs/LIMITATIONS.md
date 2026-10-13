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

## Règles et modèle

* Jokers, améliorations, éditions, sceaux, mains et boss **moddés** : non simulés ; résultats
  marqués « partiel » ; un joker moddé reçoit au mieux un multiplicateur appris (après 3 mains).
* Cartes **face cachée** (The House, The Wheel, The Mark, The Fish) : jamais lues ; elles sont
  exclues des jeux proposés et leurs effets tenus ignorés (signalé).
* Défis (challenges) aux règles spéciales (ex. plafond de jetons) : non modélisés.
* Loyalty Card : hypothèse sur le moment où `hands_played` augmente (cohérente avec la description
  « toutes les 6 mains » ; l'écart éventuel serait détecté par le contrôle de score).
* Simulations de manche : politique simple et non optimale ; The Fish/The Wheel supposés
  transparents, Crimson Heart ignoré au-delà de la main courante, destruction des cartes de verre
  non simulée en cours de manche.
* Victoire à long terme : modèle de progression (croissance géométrique apprise, blindes
  indépendantes, boss inconnus ~15 % plus durs) → **confiance limitée** par construction.
* Tarots, spectrales, paquets, tags : simulés seulement pour les améliorations / changements de
  couleur / niveaux ; le reste est heuristique (affiché comme tel).
* Pas de réglage automatique des poids de la note (choix délibéré, voir LEARNING.md).

## Interface

* Overlay dessiné par-dessus le jeu (pas d'objets UI Balatro) : pas de survol à la souris ;
  touches `C`, `V`, `B` (modifiables dans `config.lua`, redémarrage requis).
* Si la police du jeu ne contient pas certains caractères (≈, …, symboles de couleur), ils sont
  remplacés automatiquement (`~`, `...`, lettres P/C/T/K).

## Performances

* Analyse de main complète ≈ 0,3 s CPU, boutique ≈ 0,6 s CPU (mesurées sous LuaJIT, voir
  TESTS.md), réparties par tranches de 4 ms par image : les résultats apparaissent
  progressivement (« Analyse en cours… »).
