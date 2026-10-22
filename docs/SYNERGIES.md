# Synergies des jokers

Fichier généré par `luajit tools/synergies_doc.lua docs/SYNERGIES.md` à partir de
`BalatroStrategicCopilot/src/model/builds_db.lua` et `BalatroStrategicCopilot/src/model/synergies_db.lua`
(ne pas modifier à la main : modifier les listes puis relancer l'outil).

**366 paires joker + joker, 111 synergies joker + carte / bon / paquet, 26 builds**, et des règles
générales pour ce qu'aucune liste ne peut énumérer. Tous les jokers du jeu de base (150) y figurent.

## Comment le copilote s'en sert

- **Boutique et paquets** : un joker qui forme une synergie avec vos jokers reçoit un bonus de « potentiel »
  (S +0,4, A +0,28, B +0,16, C +0,07, X −0,25, total borné entre −0,5 et +0,6 ; ×0,7 aux antes 1-2, où les pros
  ne forcent pas encore un build). La raison est affichée : « synergie : Baron, chaque Roi tenu compte deux fois ».
- **Cartes, bons et paquets** : The Chariot avec Steel Joker, les planètes avec Constellation, un paquet Standard
  avec Hologram, Wasteful avec Yorick… reçoivent le même bonus (borné entre −0,4 et +0,5).
- **Bons achetés et cartes tenues** comptent aussi pour un joker en boutique (Perkeo quand Observatory est acheté).
- **« Synergies à chercher »** (panneau de la boutique) : les pièces S et A qui manquent à vos jokers.
- Le moteur de score **mesure** toujours ce qu'un joker apporte maintenant ; ces listes ajoutent ce que le build
  deviendra. Vos corrections (touche « Mon choix », raison « synergie ») peuvent augmenter leur poids (×1,5 au plus).

## Règles générales (engine/builds.lua)

- Deux jokers de la **même main** (Jolly + Sly, Crazy + Devious, Four Fingers + Droll…) : B, A si l'un est un ×Mult.
- Une main qui en **contient** une autre (un Brelan contient une Paire : Zany + Jolly) : C.
- Deux jokers de la **même couleur** (Lusty + Bloodstone…) : B, A si l'un est un ×Mult ; Blackboard avec Pique ou Trèfle : B.
- Un joker de couleur et un joker de **Couleur** (la main) : C. Deux couleurs différentes : −C (deux decks à construire),
  sauf avec Smeared Joker et deux couleurs de même teinte : B.
- **Blueprint / Brainstorm** avec un ×Mult ou un redéclencheur compatible (le jeu l'indique sur la carte) : A ;
  le joker ×Mult acheté quand une copie est déjà là : B.
- Une paire nommée dans les listes remplace toujours la règle générale pour les deux mêmes jokers.

## Par joker

### 8 Ball

- **B** Fortune Teller — plus de tarots utilisés
- **B** Oops! All 6s — un tarot une fois sur deux par 8 joué
- **C** Campfire — des tarots à vendre

### Abstract Joker

- **B** Riff-raff — deux jokers de plus : +6 Mult
- **B** Antimatter — un emplacement de plus : un joker de plus (+3 Mult)
- **B** Ectoplasm — un emplacement de plus : un joker de plus (+3 Mult)
- **C** Joker — un joker de plus : +3 Mult
- **X** Joker Stencil — Stencil veut peu de jokers, Abstract beaucoup

### Acrobat

- **B** Blueprint — ×3 de plus en dernière main
- **B** Brainstorm — ×3 de plus en dernière main
- **B** Dusk — dernière main : redéclenchée et ×3

### Ancient Joker

- **A** Blueprint — ×1,5 de plus par carte de la couleur
- **A** Brainstorm — ×1,5 de plus par carte de la couleur
- **A** Smeared Joker — la couleur choisie couvre la moitié du deck
- **B** Dusk — dernière main : chaque carte de la couleur deux fois
- **B** Hanging Chad — première carte de la couleur : ×1,5 trois fois
- **B** Photograph — deux ×Mult par carte
- **B** Seltzer — 10 mains : chaque carte de la couleur deux fois
- **X** Flower Pot — Ancient Joker veut une couleur, Flower Pot les quatre
- **X** Four Fingers — moins de cartes de la couleur marquent

### Arrowhead

- **B** Wrathful Joker — Piques joués : +50 jetons et +3 Mult
- **B** The World — The World : des Piques

### Astronomer

- **A** Constellation — planètes gratuites : Constellation grandit
- **A** paquets Céleste — paquets Céleste gratuits
- **A** planètes — planètes gratuites
- **B** Satellite — planètes gratuites : Satellite rapporte plus

### Banner

- **B** Delayed Gratification — garder ses défausses : jetons et argent
- **B** Wasteful — une défausse de plus : +30 jetons
- **X** Burglar — plus de défausses du tout
- **X** Mystic Summit — Banner veut des défausses restantes, Mystic Summit aucune

### Baron

- **S** Blueprint — un ×1,5 de plus par Roi tenu
- **S** Brainstorm — un ×1,5 de plus par Roi tenu
- **S** Mime — chaque Roi tenu compte deux fois
- **A** Chicot — plus de The Plant contre les Rois
- **A** DNA — ajoute des Rois (avec leur acier et leur sceau)
- **A** Cryptid — deux copies du meilleur Roi
- **A** Deja Vu — sceau rouge sur un Roi tenu : compte deux fois
- **A** The Chariot — acier sur les Rois tenus : ×1,5 et ×1,5
- **B** Juggler — une carte tenue de plus : un Roi de plus en main
- **B** Shoot the Moon — Dames tenues (à gauche) puis Rois
- **B** Troubadour — +2 cartes tenues : plus de Rois en main
- **B** Turtle Bean — des cartes tenues de plus : plus de Rois en main
- **B** Death — Death : copier un Roi
- **B** Strength — Strength : Dame → Roi
- **C** Certificate — cartes à sceau ajoutées (parfois rouge)
- **C** Raised Fist — carte tenue la plus basse
- **X** Stuntman — moins de cartes tenues

### Baseball Card

- **A** Blueprint — ×1,5 de plus par joker inhabituel
- **A** Brainstorm — ×1,5 de plus par joker inhabituel

### Blackboard

- **A** Blueprint — ×3 de plus, main tenue toute noire
- **A** Brainstorm — ×3 de plus, main tenue toute noire
- **B** Stuntman — petite main : plus facile de ne tenir que du noir
- **B** The Moon — The Moon : des Trèfles (noirs)
- **B** The World — The World : des Piques (noirs)

### Bloodstone

- **A** Oops! All 6s — ×1,5 garanti par Cœur
- **A** The Sun — The Sun : des Cœurs
- **B** Blueprint — deux tirages ×1,5 par Cœur
- **B** Brainstorm — deux tirages ×1,5 par Cœur
- **B** Dusk — dernière main : deux tirages par Cœur
- **B** Hanging Chad — premier Cœur : trois tirages ×1,5
- **B** Smeared Joker — les Carreaux comptent aussi
- **C** Lusty Joker — +3 par Cœur avant le ×Mult
- **X** Four Fingers — moins de cartes de la couleur marquent

### Blue Joker

- **C** Marble Joker — deck plus grand : plus de jetons
- **C** paquets Standard — deck plus grand
- **X** Erosion — Blue Joker veut un grand deck, Erosion un petit

### Blueprint

- **S** Baron — un ×1,5 de plus par Roi tenu
- **S** Caino — ×Mult de Canio copié
- **S** Triboulet — ×4 par Roi ou Dame
- **S** Yorick — ×Mult de Yorick copié
- **A** Ancient Joker — ×1,5 de plus par carte de la couleur
- **A** Baseball Card — ×1,5 de plus par joker inhabituel
- **A** Blackboard — ×3 de plus, main tenue toute noire
- **A** Brainstorm — deux copies du même joker : Blueprint à sa gauche, la cible, Brainstorm n'importe où
- **A** Campfire — ×Mult de Campfire copié
- **A** Card Sharp — ×3 de plus sur la main rejouée
- **A** Cavendish — ×3 copié
- **A** Constellation — ×Mult des planètes copié
- **A** DNA — plusieurs copies par manche
- **A** Driver's License — ×3 de plus avec 16 cartes améliorées
- **A** Flower Pot — ×3 de plus sur quatre couleurs
- **A** Glass Joker — ×Mult du verre brisé copié
- **A** Hit the Road — ×Mult des Valets défaussés copié
- **A** Hologram — ×Mult de Hologram copié
- **A** Lucky Cat — ×Mult de Lucky Cat copié
- **A** Mime — un redéclenchement de plus des cartes tenues
- **A** Obelisk — ×Mult d'Obelisk copié
- **A** Perkeo — deux copies de planète par boutique
- **A** Photograph — deux ×2 sur la première figure
- **A** Seeing Double — ×2 de plus avec un Trèfle
- **A** Steel Joker — ×Mult de l'acier copié
- **A** The Duo — ×2 de plus sur chaque paire
- **A** The Family — ×4 de plus sur un carré
- **A** The Idol — ×2 de plus par carte cible
- **A** The Order — ×3 de plus sur une suite
- **A** The Tribe — ×2 de plus sur une couleur
- **A** The Trio — ×3 de plus sur un brelan
- **A** Vampire — ×Mult de Vampire copié
- **B** Acrobat — ×3 de plus en dernière main
- **B** Bloodstone — deux tirages ×1,5 par Cœur
- **B** Cartomancer — deux tarots par blinde
- **B** Dusk — dernière main redéclenchée une fois de plus
- **B** Hack — 2 à 5 redéclenchés une fois de plus
- **B** Hanging Chad — la première carte jouée deux fois de plus
- **B** Loyalty Card — ×4 de plus toutes les 6 mains
- **B** Madness — ×Mult de Madness copié
- **B** Mail-In Rebate — 5 $ devient 10 $ par défausse
- **B** Ramen — ×Mult de Ramen copié
- **B** Seltzer — redéclenchement copié
- **B** Sock and Buskin — figures redéclenchées une fois de plus
- **B** Stuntman — +250 jetons copiés sans perdre de cartes en main
- **B** Throwback — ×Mult des passages copié
- **C** Misprint — un second tirage de 0 à 23 Mult

### Bootstraps

- **B** Bull — l'argent devient du score
- **B** Golden Joker — 4 $ par manche : plus de Mult
- **B** Golden Ticket — 4 $ par carte or : plus de Mult
- **B** Rocket — l'argent devient du score
- **B** Rough Gem — 1 $ par Carreau : plus de Mult
- **B** To the Moon — plus d'intérêts : plus de Mult
- **B** Seed Money — plus d'argent gardé
- **B** The Hermit — The Hermit double l'argent
- **C** Cloud 9 — argent des 9 : plus de Mult
- **C** To Do List — 4 $ par main demandée : Bootstraps grandit
- **X** Credit Card — dettes : Bootstraps ne donne rien
- **X** Vagabond — Bootstraps veut beaucoup d'argent, Vagabond 4 $ au plus

### Brainstorm

- **S** Baron — un ×1,5 de plus par Roi tenu
- **S** Caino — ×Mult de Canio copié
- **S** Triboulet — ×4 par Roi ou Dame
- **S** Yorick — ×Mult de Yorick copié
- **A** Ancient Joker — ×1,5 de plus par carte de la couleur
- **A** Baseball Card — ×1,5 de plus par joker inhabituel
- **A** Blackboard — ×3 de plus, main tenue toute noire
- **A** Blueprint — deux copies du même joker : Blueprint à sa gauche, la cible, Brainstorm n'importe où
- **A** Campfire — ×Mult de Campfire copié
- **A** Card Sharp — ×3 de plus sur la main rejouée
- **A** Cavendish — ×3 copié
- **A** Constellation — ×Mult des planètes copié
- **A** DNA — plusieurs copies par manche
- **A** Driver's License — ×3 de plus avec 16 cartes améliorées
- **A** Flower Pot — ×3 de plus sur quatre couleurs
- **A** Glass Joker — ×Mult du verre brisé copié
- **A** Hit the Road — ×Mult des Valets défaussés copié
- **A** Hologram — ×Mult de Hologram copié
- **A** Lucky Cat — ×Mult de Lucky Cat copié
- **A** Mime — un redéclenchement de plus des cartes tenues
- **A** Obelisk — ×Mult d'Obelisk copié
- **A** Photograph — deux ×2 sur la première figure
- **A** Seeing Double — ×2 de plus avec un Trèfle
- **A** Steel Joker — ×Mult de l'acier copié
- **A** The Duo — ×2 de plus sur chaque paire
- **A** The Family — ×4 de plus sur un carré
- **A** The Idol — ×2 de plus par carte cible
- **A** The Order — ×3 de plus sur une suite
- **A** The Tribe — ×2 de plus sur une couleur
- **A** The Trio — ×3 de plus sur un brelan
- **A** Vampire — ×Mult de Vampire copié
- **B** Acrobat — ×3 de plus en dernière main
- **B** Bloodstone — deux tirages ×1,5 par Cœur
- **B** Dusk — dernière main redéclenchée une fois de plus
- **B** Hack — 2 à 5 redéclenchés une fois de plus
- **B** Hanging Chad — la première carte jouée deux fois de plus
- **B** Loyalty Card — ×4 de plus toutes les 6 mains
- **B** Madness — ×Mult de Madness copié
- **B** Ramen — ×Mult de Ramen copié
- **B** Sock and Buskin — figures redéclenchées une fois de plus
- **B** Throwback — ×Mult des passages copié

### Bull

- **B** Bootstraps — l'argent devient du score
- **B** Golden Joker — 4 $ par manche : plus de jetons
- **B** Golden Ticket — 4 $ par carte or : plus de jetons
- **B** Rocket — l'argent devient du score
- **B** Rough Gem — 1 $ par Carreau : plus de jetons
- **B** To the Moon — plus d'intérêts : plus de jetons
- **B** Seed Money — plus d'argent gardé
- **B** The Hermit — The Hermit double l'argent
- **C** Cloud 9 — argent des 9 : plus de jetons
- **C** To Do List — 4 $ par main demandée : Bull grandit
- **X** Credit Card — dettes : Bull ne donne rien
- **X** Vagabond — Bull veut beaucoup d'argent, Vagabond 4 $ au plus

### Burglar

- **B** Card Sharp — +3 mains : rejouer la même main plus souvent
- **B** Green Joker — plus de mains, plus de défausses perdues
- **B** Loyalty Card — +3 mains : ×4 plus souvent
- **B** Spare Trousers — plus de mains : grandit plus vite
- **B** Supernova — plus de mains : grandit plus vite
- **C** Runner — +3 mains : plus de suites
- **C** Troubadour — Burglar rend la main perdue
- **X** Banner — plus de défausses du tout
- **X** Burnt Joker — plus de défausses du tout
- **X** Castle — plus de défausses du tout
- **X** Delayed Gratification — plus de défausses du tout
- **X** Faceless Joker — plus de défausses du tout
- **X** Hit the Road — plus de défausses du tout
- **X** Ice Cream — +3 mains : Ice Cream fond plus vite
- **X** Mail-In Rebate — plus de défausses du tout
- **X** Obelisk — Obelisk veut changer de main
- **X** Trading Card — plus de défausses du tout
- **X** Yorick — plus de défausses du tout

### Burnt Joker

- **B** Space Joker — deux sources de niveaux
- **C** Drunkard — une défausse de plus
- **X** Burglar — plus de défausses du tout

### Business Card

- **C** Oops! All 6s — argent garanti
- **C** Sock and Buskin — figures redéclenchées : deux tirages à 2 $

### Caino

- **S** Blueprint — ×Mult de Canio copié
- **S** Brainstorm — ×Mult de Canio copié
- **A** Glass Joker — figures de verre brisées : les deux grandissent
- **A** Pareidolia — toute carte détruite compte
- **A** Trading Card — destruction contrôlée de figures
- **A** The Hanged Man — détruire deux figures : +×2
- **B** Erosion — figures détruites : ×1 pour Canio et +4 Mult pour Erosion
- **B** Invisible Joker — peut dupliquer Canio (moins de jokers, plus de chances)
- **B** Familiar — des figures à détruire ensuite
- **B** Immolate — figures détruites parmi les cinq

### Campfire

- **A** Blueprint — ×Mult de Campfire copié
- **A** Brainstorm — ×Mult de Campfire copié
- **B** Cartomancer — des cartes à vendre
- **B** Riff-raff — des jokers à vendre
- **C** 8 Ball — des tarots à vendre
- **C** Diet Cola — vendre Diet Cola : un Double Tag et +×0,25
- **C** Gift Card — les cartes vendues valent plus
- **C** Hallucination — des tarots à vendre
- **C** Ice Cream — vendre Ice Cream avant qu'il fonde : +×0,25
- **C** Popcorn — vendre Popcorn avant la fin : +×0,25
- **C** Superposition — des tarots à vendre
- **C** Vagabond — des tarots à vendre
- **C** planètes — des cartes à vendre
- **C** tarots — des cartes à vendre
- **X** Constellation — utiliser contre vendre
- **X** Throwback — passer remet Campfire à zéro plus tôt

### Card Sharp

- **A** Blueprint — ×3 de plus sur la main rejouée
- **A** Brainstorm — ×3 de plus sur la main rejouée
- **A** Chicot — plus de boss qui contrent la main répétée
- **B** Burglar — +3 mains : rejouer la même main plus souvent
- **B** Supernova — la même main rejouée : ×3 et Supernova grandit
- **C** paquets Céleste — monter la main rejouée
- **X** Obelisk — Card Sharp veut rejouer la main, Obelisk veut en changer

### Cartomancer

- **B** Blueprint — deux tarots par blinde
- **B** Campfire — des cartes à vendre
- **B** Fortune Teller — des tarots pour Fortune Teller
- **B** Perkeo — des tarots à copier en négatif
- **X** Throwback — passer contre jouer les manches

### Castle

- **B** Drunkard — plus de défausses : Castle grandit plus vite
- **B** Merry Andy — plus de défausses : Castle grandit plus vite
- **B** Wasteful — une défausse de plus
- **X** Burglar — plus de défausses du tout
- **X** Delayed Gratification — ne pas défausser contre défausser beaucoup
- **X** Ramen — Ramen perd ×0,01 par carte défaussée

### Cavendish

- **A** Blueprint — ×3 copié
- **A** Brainstorm — ×3 copié
- **B** Showman — doublons possibles

### Ceremonial Dagger

- **B** Riff-raff — Riff-raff fournit les jokers à sacrifier
- **C** Egg — plus de valeur de vente mangée
- **C** Gift Card — plus de valeur de vente mangée

### Certificate

- **A** Hologram — ×0,25 par carte ajoutée
- **C** Baron — cartes à sceau ajoutées (parfois rouge)
- **X** Erosion — Erosion veut un petit deck, Certificate ajoute des cartes

### Chaos the Clown

- **B** Flash Card — relance gratuite : Flash Card grandit sans payer
- **C** Reroll Surplus — relances moins chères

### Chicot

- **A** Baron — plus de The Plant contre les Rois
- **A** Card Sharp — plus de boss qui contrent la main répétée
- **A** Photograph — plus de The Plant contre les figures
- **X** Matador — Matador veut l'effet du boss, Chicot le supprime

### Clever Joker

- **B** Spare Trousers — double paire : +80 jetons et Spare Trousers grandit

### Cloud 9

- **C** Bootstraps — argent des 9 : plus de Mult
- **C** Bull — argent des 9 : plus de jetons
- **C** Death — Death : copier un 9

### Constellation

- **A** Astronomer — planètes gratuites : Constellation grandit
- **A** Blueprint — ×Mult des planètes copié
- **A** Brainstorm — ×Mult des planètes copié
- **A** paquets Céleste — des planètes à utiliser
- **A** planètes — chaque planète utilisée : +×0,1
- **B** Satellite — planètes différentes : de l'argent chaque manche
- **B** Planet Merchant — plus de planètes en boutique
- **B** Planet Tycoon — plus de planètes en boutique
- **B** Trance — sceau bleu : une planète à chaque fin de manche
- **X** Campfire — utiliser contre vendre
- **X** Red Card — utiliser contre passer les paquets
- **X** Throwback — jouer les manches contre les passer

### Crafty Joker

- **B** The Tribe — couleur : +80 jetons puis ×2
- **C** Four Fingers — plus de couleurs
- **C** Smeared Joker — plus de couleurs

### Crazy Joker

- **B** The Order — suite : +12 Mult puis ×3
- **C** Four Fingers — plus de suites
- **C** Shortcut — plus de suites

### Credit Card

- **B** Vagabond — dépenser sous 4 $ (jusqu'à −20 $) : des tarots à chaque main
- **X** Bootstraps — dettes : Bootstraps ne donne rien
- **X** Bull — dettes : Bull ne donne rien

### Delayed Gratification

- **B** Banner — garder ses défausses : jetons et argent
- **X** Burglar — plus de défausses du tout
- **X** Castle — ne pas défausser contre défausser beaucoup
- **X** Hit the Road — ne pas défausser contre défausser des Valets
- **X** Mail-In Rebate — ne pas défausser contre défausser beaucoup
- **X** Mystic Summit — ne pas défausser contre défausser tout
- **X** Yorick — ne pas défausser contre défausser beaucoup

### Devious Joker

- **B** The Order — suite : +100 jetons puis ×3
- **C** Four Fingers — plus de suites
- **C** Shortcut — plus de suites

### Diet Cola

- **C** Campfire — vendre Diet Cola : un Double Tag et +×0,25

### DNA

- **A** Baron — ajoute des Rois (avec leur acier et leur sceau)
- **A** Blueprint — plusieurs copies par manche
- **A** Brainstorm — plusieurs copies par manche
- **A** Hologram — ×0,25 par carte ajoutée
- **B** Sixth Sense — le 6 copié donne une spectrale
- **B** Steel Joker — copier une carte d'acier : Steel Joker monte
- **C** Glass Joker — copier une carte de verre
- **X** Erosion — Erosion veut un petit deck, DNA ajoute des cartes

### Driver's License

- **A** Blueprint — ×3 de plus avec 16 cartes améliorées
- **A** Brainstorm — ×3 de plus avec 16 cartes améliorées
- **B** Marble Joker — pierres ajoutées : 16 cartes améliorées plus vite
- **B** Midas Mask — figures changées en or : 16 cartes améliorées plus vite
- **B** Justice — cartes améliorées (verre)
- **B** The Chariot — cartes améliorées (acier)
- **B** The Devil — cartes améliorées (or)
- **B** The Empress — cartes améliorées (Mult)
- **B** The Hierophant — cartes améliorées (bonus)
- **B** The Lovers — cartes améliorées (joker)
- **B** The Magician — cartes améliorées (chance)
- **B** The Tower — cartes améliorées (pierre)
- **X** Vampire — Vampire mange les améliorations

### Droll Joker

- **B** The Tribe — couleur : +10 Mult puis ×2
- **C** Four Fingers — plus de couleurs
- **C** Smeared Joker — plus de couleurs

### Drunkard

- **A** Yorick — plus de défausses
- **B** Castle — plus de défausses : Castle grandit plus vite
- **B** Hit the Road — plus de défausses de Valets
- **C** Burnt Joker — une défausse de plus
- **C** Mail-In Rebate — plus de défausses payées

### Dusk

- **B** Acrobat — dernière main : redéclenchée et ×3
- **B** Ancient Joker — dernière main : chaque carte de la couleur deux fois
- **B** Bloodstone — dernière main : deux tirages par Cœur
- **B** Blueprint — dernière main redéclenchée une fois de plus
- **B** Brainstorm — dernière main redéclenchée une fois de plus
- **B** Hiker — dernière main : chaque carte gagne +5 jetons deux fois
- **B** Photograph — dernière main : ×2 de la figure deux fois
- **B** The Idol — dernière main : ×2 de la carte cible deux fois
- **B** Triboulet — dernière main : Rois et Dames ×2 deux fois

### Egg

- **B** Swashbuckler — valeur de vente d'Egg ajoutée au Mult
- **C** Ceremonial Dagger — plus de valeur de vente mangée

### Erosion

- **A** Immolate — cinq cartes détruites : +20 Mult et 20 $
- **A** The Hanged Man — détruire deux cartes : +8 Mult
- **B** Caino — figures détruites : ×1 pour Canio et +4 Mult pour Erosion
- **B** Trading Card — cartes détruites : le deck s'amincit, +4 Mult par carte
- **C** Glass Joker — verre brisé : le deck s'amincit
- **X** Blue Joker — Blue Joker veut un grand deck, Erosion un petit
- **X** Certificate — Erosion veut un petit deck, Certificate ajoute des cartes
- **X** DNA — Erosion veut un petit deck, DNA ajoute des cartes
- **X** Hologram — buts opposés (ajouter ou retirer des cartes)
- **X** Marble Joker — Erosion veut un petit deck, Marble ajoute des pierres
- **X** Cryptid — cartes ajoutées : Erosion baisse
- **X** paquets Standard — cartes ajoutées : Erosion baisse

### Even Steven

- **B** Hack — 2 et 4 redéclenchés : +4 Mult deux fois

### Faceless Joker

- **B** Pareidolia — toutes les cartes sont des figures : 5 $ à chaque défausse de 3 cartes
- **X** Burglar — plus de défausses du tout

### Fibonacci

- **B** Hack — 2, 3, 5 redéclenchés : +8 Mult deux fois
- **C** Hanging Chad — As, 2, 3, 5 ou 8 en tête trois fois
- **C** Wee Joker — les 2 jouent pour les deux

### Flash Card

- **B** Chaos the Clown — relance gratuite : Flash Card grandit sans payer
- **B** Reroll Glut — relances moins chères
- **B** Reroll Surplus — relances moins chères

### Flower Pot

- **A** Blueprint — ×3 de plus sur quatre couleurs
- **A** Brainstorm — ×3 de plus sur quatre couleurs
- **B** Seeing Double — ×6 sur une main de couleurs mêlées
- **B** Smeared Joker — Smeared : deux cartes couvrent les quatre couleurs
- **B** Splash — quatre couleurs avec peu de cartes
- **B** The Lovers — cartes joker : toutes les couleurs
- **X** Ancient Joker — Ancient Joker veut une couleur, Flower Pot les quatre

### Fortune Teller

- **A** paquets Arcane — des tarots à utiliser
- **A** tarots — +1 Mult par tarot utilisé
- **B** 8 Ball — plus de tarots utilisés
- **B** Cartomancer — des tarots pour Fortune Teller
- **B** Hallucination — plus de tarots utilisés
- **B** Superposition — plus de tarots utilisés
- **B** Vagabond — plus de tarots utilisés
- **B** Tarot Merchant — plus de tarots en boutique

### Four Fingers

- **A** The Order — suites de 4 cartes : ×3 bien plus souvent
- **A** The Tribe — couleurs de 4 cartes : ×2 bien plus souvent
- **B** Runner — plus de suites : Runner grandit plus vite
- **B** Seance — quintes flush plus faciles
- **B** Shortcut — suites et quintes flush faciles
- **B** Square Joker — couleurs et suites de 4 cartes : Square Joker grandit
- **C** Crafty Joker — plus de couleurs
- **C** Crazy Joker — plus de suites
- **C** Devious Joker — plus de suites
- **C** Droll Joker — plus de couleurs
- **X** Ancient Joker — moins de cartes de la couleur marquent
- **X** Bloodstone — moins de cartes de la couleur marquent

### Gift Card

- **A** Swashbuckler — valeur de vente de tous les jokers : Mult qui monte chaque manche
- **C** Campfire — les cartes vendues valent plus
- **C** Ceremonial Dagger — plus de valeur de vente mangée

### Glass Joker

- **A** Blueprint — ×Mult du verre brisé copié
- **A** Brainstorm — ×Mult du verre brisé copié
- **A** Caino — figures de verre brisées : les deux grandissent
- **A** Justice — Justice : des cartes de verre à briser
- **B** Oops! All 6s — le verre casse plus souvent : Glass Joker grandit vite
- **B** Deja Vu — sceau rouge sur le verre : ×2 deux fois
- **C** DNA — copier une carte de verre
- **C** Erosion — verre brisé : le deck s'amincit
- **X** Vampire — Vampire mange le verre

### Gluttonous Joker

- **B** Onyx Agate — Trèfles joués : +7 et +3 Mult
- **B** Seeing Double — Trèfles joués : +3 Mult et ×2
- **B** The Moon — The Moon : des Trèfles

### Golden Joker

- **B** Bootstraps — 4 $ par manche : plus de Mult
- **B** Bull — 4 $ par manche : plus de jetons

### Golden Ticket

- **A** Midas Mask — figures jouées changées en or : 4 $ chacune
- **A** The Devil — The Devil : des cartes or
- **B** Bootstraps — 4 $ par carte or : plus de Mult
- **B** Bull — 4 $ par carte or : plus de jetons
- **B** Hanging Chad — carte or en tête : 4 $ trois fois
- **X** Vampire — Vampire mange l'Or

### Greedy Joker

- **B** Rough Gem — Carreaux joués : +3 Mult et 1 $
- **B** The Star — The Star : des Carreaux

### Green Joker

- **B** Burglar — plus de mains, plus de défausses perdues
- **X** Hit the Road — Green Joker perd 1 Mult par défausse
- **X** Yorick — Green Joker perd 1 Mult par défausse

### Gros Michel

- **X** Oops! All 6s — Gros Michel détruit une fois sur trois

### Hack

- **A** The Idol — carte cible basse : ×2 deux fois
- **B** Blueprint — 2 à 5 redéclenchés une fois de plus
- **B** Brainstorm — 2 à 5 redéclenchés une fois de plus
- **B** Even Steven — 2 et 4 redéclenchés : +4 Mult deux fois
- **B** Fibonacci — 2, 3, 5 redéclenchés : +8 Mult deux fois
- **B** Odd Todd — 3 et 5 redéclenchés : +31 jetons deux fois
- **B** Ride the Bus — petites cartes sans figures : Ride the Bus grandit
- **B** Walkie Talkie — les 4 redéclenchés : +10 jetons et +4 Mult deux fois
- **B** Wee Joker — +16 jetons permanents par 2
- **C** Hiker — 2 à 5 redéclenchés : +5 jetons permanents deux fois

### Half Joker

- **B** The Duo — paire jouée seule (2-3 cartes) : +20 Mult puis ×2
- **C** Jolly Joker — paire jouée seule : +20 et +8 Mult
- **C** Sly Joker — paire jouée seule : +20 Mult et +50 jetons
- **X** Square Joker — Half Joker veut 3 cartes au plus, Square Joker exactement 4

### Hallucination

- **B** Fortune Teller — plus de tarots utilisés
- **B** Oops! All 6s — un tarot à chaque paquet ouvert
- **C** Campfire — des tarots à vendre

### Hanging Chad

- **A** Photograph — figure en tête jouée 3 fois : ×8
- **A** The Idol — carte cible en tête : ×2 trois fois
- **A** Triboulet — Roi ou Dame en tête : ×2 trois fois
- **B** Ancient Joker — première carte de la couleur : ×1,5 trois fois
- **B** Bloodstone — premier Cœur : trois tirages ×1,5
- **B** Blueprint — la première carte jouée deux fois de plus
- **B** Brainstorm — la première carte jouée deux fois de plus
- **B** Golden Ticket — carte or en tête : 4 $ trois fois
- **B** Hiker — +15 jetons permanents par main
- **B** Lucky Cat — trois tirages chance par main
- **B** Wee Joker — un 2 en tête : Wee Joker grandit trois fois
- **C** Fibonacci — As, 2, 3, 5 ou 8 en tête trois fois
- **C** Rough Gem — Carreau en tête : 1 $ trois fois
- **C** Scholar — As en tête : +20 jetons et +4 Mult trois fois
- **C** Walkie Talkie — 10 ou 4 en tête trois fois

### Hiker

- **B** Dusk — dernière main : chaque carte gagne +5 jetons deux fois
- **B** Hanging Chad — +15 jetons permanents par main
- **B** Seltzer — 10 mains : +5 jetons permanents deux fois par carte
- **B** Splash — toutes les cartes jouées comptent : +5 jetons permanents chacune
- **C** Hack — 2 à 5 redéclenchés : +5 jetons permanents deux fois
- **C** Sock and Buskin — figures redéclenchées : +5 jetons permanents deux fois

### Hit the Road

- **A** Blueprint — ×Mult des Valets défaussés copié
- **A** Brainstorm — ×Mult des Valets défaussés copié
- **A** Mail-In Rebate — Valets défaussés : ×0,5 et de l'argent
- **B** Drunkard — plus de défausses de Valets
- **B** Merry Andy — plus de défausses de Valets
- **B** Death — Death : copier un Valet
- **B** Recyclomancy — une défausse de plus par manche
- **B** Strength — Strength : 10 → Valet
- **B** Wasteful — une défausse de plus par manche
- **X** Burglar — plus de défausses du tout
- **X** Delayed Gratification — ne pas défausser contre défausser des Valets
- **X** Green Joker — Green Joker perd 1 Mult par défausse
- **X** Ramen — Ramen perd ×0,01 par carte défaussée

### Hologram

- **A** Blueprint — ×Mult de Hologram copié
- **A** Brainstorm — ×Mult de Hologram copié
- **A** Certificate — ×0,25 par carte ajoutée
- **A** DNA — ×0,25 par carte ajoutée
- **A** Marble Joker — ×0,25 par carte ajoutée
- **A** Cryptid — deux cartes ajoutées
- **A** Familiar — trois figures ajoutées
- **A** Incantation — quatre cartes ajoutées
- **A** paquets Standard — cartes ajoutées : +×0,25 chacune
- **B** Grim — deux As ajoutés
- **B** Illusion — cartes à jouer en boutique
- **B** Magic Trick — cartes à jouer en boutique
- **X** Erosion — buts opposés (ajouter ou retirer des cartes)
- **X** Throwback — passer contre jouer les manches

### Ice Cream

- **C** Campfire — vendre Ice Cream avant qu'il fonde : +×0,25
- **X** Burglar — +3 mains : Ice Cream fond plus vite

### Invisible Joker

- **B** Caino — peut dupliquer Canio (moins de jokers, plus de chances)
- **B** Perkeo — peut dupliquer Perkeo (moins de jokers, plus de chances)
- **B** Triboulet — peut dupliquer Triboulet (moins de jokers, plus de chances)
- **B** Yorick — peut dupliquer Yorick (moins de jokers, plus de chances)
- **X** Madness — Madness peut le détruire avant les deux manches

### Joker

- **C** Abstract Joker — un joker de plus : +3 Mult

### Joker Stencil

- **B** Antimatter — un emplacement vide de plus
- **B** Ectoplasm — joker négatif : pas d'emplacement pris
- **C** Blank — vers Antimatter
- **X** Abstract Joker — Stencil veut peu de jokers, Abstract beaucoup
- **X** Riff-raff — Joker Stencil veut des emplacements vides

### Jolly Joker

- **B** The Duo — paire : +8 Mult puis ×2
- **C** Half Joker — paire jouée seule : +20 et +8 Mult

### Juggler

- **B** Baron — une carte tenue de plus : un Roi de plus en main
- **B** Mime — une carte tenue de plus redéclenchée
- **B** Stuntman — compense la main réduite de Stuntman

### Loyalty Card

- **B** Blueprint — ×4 de plus toutes les 6 mains
- **B** Brainstorm — ×4 de plus toutes les 6 mains
- **B** Burglar — +3 mains : ×4 plus souvent

### Luchador

- **X** Matador — Matador veut l'effet du boss, Luchador le supprime

### Lucky Cat

- **A** Blueprint — ×Mult de Lucky Cat copié
- **A** Brainstorm — ×Mult de Lucky Cat copié
- **A** Oops! All 6s — deux fois plus de réussites
- **A** The Magician — The Magician : des cartes chance
- **B** Hanging Chad — trois tirages chance par main
- **B** Deja Vu — sceau rouge sur une carte chance : deux tirages
- **X** Vampire — Vampire mange les cartes chance

### Lusty Joker

- **B** The Sun — The Sun : des Cœurs
- **C** Bloodstone — +3 par Cœur avant le ×Mult

### Mad Joker

- **B** Spare Trousers — double paire : +10 Mult et Spare Trousers grandit

### Madness

- **B** Blueprint — ×Mult de Madness copié
- **B** Brainstorm — ×Mult de Madness copié
- **C** Riff-raff — Riff-raff fournit les jokers à détruire
- **X** Invisible Joker — Madness peut le détruire avant les deux manches
- **X** Mr. Bones — Madness peut détruire Mr. Bones

### Mail-In Rebate

- **A** Hit the Road — Valets défaussés : ×0,5 et de l'argent
- **B** Blueprint — 5 $ devient 10 $ par défausse
- **C** Drunkard — plus de défausses payées
- **C** Merry Andy — plus de défausses payées
- **C** Wasteful — une défausse de plus payée
- **X** Burglar — plus de défausses du tout
- **X** Delayed Gratification — ne pas défausser contre défausser beaucoup
- **X** Ramen — Ramen perd ×0,01 par carte défaussée

### Marble Joker

- **A** Hologram — ×0,25 par carte ajoutée
- **A** Stone Joker — une pierre de plus à chaque blinde : +25 jetons chacune
- **B** Driver's License — pierres ajoutées : 16 cartes améliorées plus vite
- **C** Blue Joker — deck plus grand : plus de jetons
- **X** Erosion — Erosion veut un petit deck, Marble ajoute des pierres

### Matador

- **X** Chicot — Matador veut l'effet du boss, Chicot le supprime
- **X** Luchador — Matador veut l'effet du boss, Luchador le supprime

### Merry Andy

- **A** Yorick — plus de défausses
- **B** Castle — plus de défausses : Castle grandit plus vite
- **B** Hit the Road — plus de défausses de Valets
- **C** Mail-In Rebate — plus de défausses payées

### Midas Mask

- **A** Golden Ticket — figures jouées changées en or : 4 $ chacune
- **A** Pareidolia — toutes les cartes jouées deviennent Or
- **B** Driver's License — figures changées en or : 16 cartes améliorées plus vite
- **B** Vampire — Vampire mange l'Or : grandit à chaque main
- **C** The Devil — plus de cartes or

### Mime

- **S** Baron — chaque Roi tenu compte deux fois
- **A** Blueprint — un redéclenchement de plus des cartes tenues
- **A** Brainstorm — un redéclenchement de plus des cartes tenues
- **A** Steel Joker — cartes d'acier tenues redéclenchées
- **B** Juggler — une carte tenue de plus redéclenchée
- **B** Raised Fist — la carte tenue la plus basse compte deux fois
- **B** Shoot the Moon — chaque Dame tenue : +13 Mult deux fois
- **B** The Chariot — cartes d'acier tenues redéclenchées
- **C** Reserved Parking — figures tenues : deux tirages à 1 $
- **X** Stuntman — moins de cartes tenues

### Misprint

- **C** Blueprint — un second tirage de 0 à 23 Mult

### Mr. Bones

- **X** Madness — Madness peut détruire Mr. Bones

### Mystic Summit

- **X** Banner — Banner veut des défausses restantes, Mystic Summit aucune
- **X** Delayed Gratification — ne pas défausser contre défausser tout

### Obelisk

- **A** Blueprint — ×Mult d'Obelisk copié
- **A** Brainstorm — ×Mult d'Obelisk copié
- **X** Burglar — Obelisk veut changer de main
- **X** Card Sharp — Card Sharp veut rejouer la main, Obelisk veut en changer
- **X** Supernova — Obelisk veut changer de main

### Odd Todd

- **B** Hack — 3 et 5 redéclenchés : +31 jetons deux fois
- **C** Ride the Bus — jouer sans figures

### Onyx Agate

- **B** Gluttonous Joker — Trèfles joués : +7 et +3 Mult
- **B** Seeing Double — Trèfles joués : +7 Mult et ×2
- **B** The Moon — The Moon : des Trèfles

### Oops! All 6s

- **A** Bloodstone — ×1,5 garanti par Cœur
- **A** Lucky Cat — deux fois plus de réussites
- **A** Space Joker — une chance sur deux de monter la main jouée
- **B** 8 Ball — un tarot une fois sur deux par 8 joué
- **B** Glass Joker — le verre casse plus souvent : Glass Joker grandit vite
- **B** Hallucination — un tarot à chaque paquet ouvert
- **C** Business Card — argent garanti
- **C** Reserved Parking — argent garanti
- **X** Gros Michel — Gros Michel détruit une fois sur trois

### Pareidolia

- **A** Caino — toute carte détruite compte
- **A** Midas Mask — toutes les cartes jouées deviennent Or
- **B** Faceless Joker — toutes les cartes sont des figures : 5 $ à chaque défausse de 3 cartes
- **B** Sock and Buskin — toutes les cartes redéclenchées
- **X** Ride the Bus — chaque main remet Ride the Bus à zéro

### Perkeo

- **S** Observatory — planètes copiées en négatif : ×1,5 chacune pour leur main
- **A** Blueprint — deux copies de planète par boutique
- **A** Black Hole — Black Hole copiée
- **A** planètes — une planète copiée à chaque boutique
- **B** Cartomancer — des tarots à copier en négatif
- **B** Invisible Joker — peut dupliquer Perkeo (moins de jokers, plus de chances)

### Photograph

- **A** Blueprint — deux ×2 sur la première figure
- **A** Brainstorm — deux ×2 sur la première figure
- **A** Chicot — plus de The Plant contre les figures
- **A** Hanging Chad — figure en tête jouée 3 fois : ×8
- **A** Sock and Buskin — la figure en tête redéclenchée
- **B** Ancient Joker — deux ×Mult par carte
- **B** Dusk — dernière main : ×2 de la figure deux fois
- **B** Seltzer — 10 mains : ×2 de la figure deux fois
- **B** Deja Vu — sceau rouge sur la figure de tête
- **X** Ride the Bus — les figures remettent Ride the Bus à zéro

### Popcorn

- **C** Campfire — vendre Popcorn avant la fin : +×0,25

### Raised Fist

- **B** Mime — la carte tenue la plus basse compte deux fois
- **C** Baron — carte tenue la plus basse

### Ramen

- **B** Blueprint — ×Mult de Ramen copié
- **B** Brainstorm — ×Mult de Ramen copié
- **X** Castle — Ramen perd ×0,01 par carte défaussée
- **X** Hit the Road — Ramen perd ×0,01 par carte défaussée
- **X** Mail-In Rebate — Ramen perd ×0,01 par carte défaussée
- **X** Yorick — Ramen perd ×0,01 par carte défaussée

### Red Card

- **X** Constellation — utiliser contre passer les paquets

### Reserved Parking

- **C** Mime — figures tenues : deux tirages à 1 $
- **C** Oops! All 6s — argent garanti

### Ride the Bus

- **B** Hack — petites cartes sans figures : Ride the Bus grandit
- **C** Odd Todd — jouer sans figures
- **X** Pareidolia — chaque main remet Ride the Bus à zéro
- **X** Photograph — les figures remettent Ride the Bus à zéro
- **X** Sock and Buskin — les figures remettent Ride the Bus à zéro

### Riff-raff

- **B** Abstract Joker — deux jokers de plus : +6 Mult
- **B** Campfire — des jokers à vendre
- **B** Ceremonial Dagger — Riff-raff fournit les jokers à sacrifier
- **C** Madness — Riff-raff fournit les jokers à détruire
- **X** Joker Stencil — Joker Stencil veut des emplacements vides

### Rocket

- **B** Bootstraps — l'argent devient du score
- **B** Bull — l'argent devient du score
- **X** Throwback — passer contre jouer les manches

### Rough Gem

- **B** Bootstraps — 1 $ par Carreau : plus de Mult
- **B** Bull — 1 $ par Carreau : plus de jetons
- **B** Greedy Joker — Carreaux joués : +3 Mult et 1 $
- **B** The Star — The Star : des Carreaux
- **C** Hanging Chad — Carreau en tête : 1 $ trois fois

### Runner

- **A** The Order — chaque suite : Runner grandit et ×3
- **B** Four Fingers — plus de suites : Runner grandit plus vite
- **B** Shortcut — plus de suites : Runner grandit plus vite
- **C** Burglar — +3 mains : plus de suites

### Satellite

- **B** Astronomer — planètes gratuites : Satellite rapporte plus
- **B** Constellation — planètes différentes : de l'argent chaque manche
- **B** paquets Céleste — des planètes différentes
- **B** planètes — 1 $ par planète différente utilisée

### Scary Face

- **B** Sock and Buskin — figures redéclenchées : +30 jetons deux fois

### Scholar

- **C** Hanging Chad — As en tête : +20 jetons et +4 Mult trois fois
- **C** Death — Death : copier un As

### Seance

- **B** Four Fingers — quintes flush plus faciles
- **B** Shortcut — quintes flush plus faciles
- **B** Smeared Joker — quintes flush plus faciles

### Seeing Double

- **A** Blueprint — ×2 de plus avec un Trèfle
- **A** Brainstorm — ×2 de plus avec un Trèfle
- **B** Flower Pot — ×6 sur une main de couleurs mêlées
- **B** Gluttonous Joker — Trèfles joués : +3 Mult et ×2
- **B** Onyx Agate — Trèfles joués : +7 Mult et ×2
- **B** Smeared Joker — tout Pique compte comme Trèfle
- **B** The Moon — The Moon : des Trèfles

### Seltzer

- **B** Ancient Joker — 10 mains : chaque carte de la couleur deux fois
- **B** Blueprint — redéclenchement copié
- **B** Hiker — 10 mains : +5 jetons permanents deux fois par carte
- **B** Photograph — 10 mains : ×2 de la figure deux fois
- **B** The Idol — 10 mains : carte cible deux fois
- **B** Triboulet — 10 mains : Rois et Dames ×2 deux fois

### Shoot the Moon

- **B** Baron — Dames tenues (à gauche) puis Rois
- **B** Mime — chaque Dame tenue : +13 Mult deux fois
- **B** Cryptid — deux Dames de plus
- **B** Death — Death : copier une Dame
- **B** Strength — Strength : Valet → Dame
- **X** Stuntman — moins de Dames tenues

### Shortcut

- **A** The Order — suites avec trous : ×3 bien plus souvent
- **B** Four Fingers — suites et quintes flush faciles
- **B** Runner — plus de suites : Runner grandit plus vite
- **B** Seance — quintes flush plus faciles
- **C** Crazy Joker — plus de suites
- **C** Devious Joker — plus de suites
- **C** Superposition — suites avec As

### Showman

- **B** Cavendish — doublons possibles

### Sixth Sense

- **B** DNA — le 6 copié donne une spectrale
- **C** Death — Death : copier un 6

### Sly Joker

- **B** The Duo — paire : +50 jetons puis ×2
- **C** Half Joker — paire jouée seule : +20 Mult et +50 jetons

### Smeared Joker

- **A** Ancient Joker — la couleur choisie couvre la moitié du deck
- **A** The Tribe — deux couleurs seulement : couleurs faciles, ×2
- **B** Bloodstone — les Carreaux comptent aussi
- **B** Flower Pot — Smeared : deux cartes couvrent les quatre couleurs
- **B** Seance — quintes flush plus faciles
- **B** Seeing Double — tout Pique compte comme Trèfle
- **C** Crafty Joker — plus de couleurs
- **C** Droll Joker — plus de couleurs

### Smiley Face

- **B** Sock and Buskin — figures redéclenchées : +5 Mult deux fois

### Sock and Buskin

- **S** Triboulet — Rois et Dames redéclenchés : ×4 chacun
- **A** Photograph — la figure en tête redéclenchée
- **A** The Idol — figure cible : ×2 deux fois
- **B** Blueprint — figures redéclenchées une fois de plus
- **B** Brainstorm — figures redéclenchées une fois de plus
- **B** Pareidolia — toutes les cartes redéclenchées
- **B** Scary Face — figures redéclenchées : +30 jetons deux fois
- **B** Smiley Face — figures redéclenchées : +5 Mult deux fois
- **C** Business Card — figures redéclenchées : deux tirages à 2 $
- **C** Hiker — figures redéclenchées : +5 jetons permanents deux fois
- **X** Ride the Bus — les figures remettent Ride the Bus à zéro

### Space Joker

- **A** Oops! All 6s — une chance sur deux de monter la main jouée
- **B** Burnt Joker — deux sources de niveaux
- **B** Supernova — une seule main montée

### Spare Trousers

- **B** Burglar — plus de mains : grandit plus vite
- **B** Clever Joker — double paire : +80 jetons et Spare Trousers grandit
- **B** Mad Joker — double paire : +10 Mult et Spare Trousers grandit
- **B** Square Joker — les deux grandissent avec la double paire à 4 cartes
- **C** Supernova — une seule main (double paire) : les deux grandissent

### Splash

- **B** Flower Pot — quatre couleurs avec peu de cartes
- **B** Hiker — toutes les cartes jouées comptent : +5 jetons permanents chacune

### Square Joker

- **B** Four Fingers — couleurs et suites de 4 cartes : Square Joker grandit
- **B** Spare Trousers — les deux grandissent avec la double paire à 4 cartes
- **X** Half Joker — Half Joker veut 3 cartes au plus, Square Joker exactement 4

### Steel Joker

- **A** Blueprint — ×Mult de l'acier copié
- **A** Brainstorm — ×Mult de l'acier copié
- **A** Mime — cartes d'acier tenues redéclenchées
- **A** The Chariot — The Chariot : une carte d'acier de plus (+×0,2)
- **B** DNA — copier une carte d'acier : Steel Joker monte
- **X** Stuntman — moins de cartes d'acier tenues
- **X** Vampire — Vampire mange l'acier

### Stone Joker

- **A** Marble Joker — une pierre de plus à chaque blinde : +25 jetons chacune
- **A** The Tower — The Tower : des cartes pierre (+25 jetons chacune)

### Stuntman

- **B** Blackboard — petite main : plus facile de ne tenir que du noir
- **B** Blueprint — +250 jetons copiés sans perdre de cartes en main
- **B** Juggler — compense la main réduite de Stuntman
- **B** Turtle Bean — compense la main réduite de Stuntman
- **X** Baron — moins de cartes tenues
- **X** Mime — moins de cartes tenues
- **X** Shoot the Moon — moins de Dames tenues
- **X** Steel Joker — moins de cartes d'acier tenues

### Supernova

- **B** Burglar — plus de mains : grandit plus vite
- **B** Card Sharp — la même main rejouée : ×3 et Supernova grandit
- **B** Space Joker — une seule main montée
- **C** Spare Trousers — une seule main (double paire) : les deux grandissent
- **X** Obelisk — Obelisk veut changer de main
- **X** Throwback — passer contre jouer les manches

### Superposition

- **B** Fortune Teller — plus de tarots utilisés
- **C** Campfire — des tarots à vendre
- **C** Shortcut — suites avec As

### Swashbuckler

- **A** Gift Card — valeur de vente de tous les jokers : Mult qui monte chaque manche
- **B** Egg — valeur de vente d'Egg ajoutée au Mult

### The Duo

- **A** Blueprint — ×2 de plus sur chaque paire
- **A** Brainstorm — ×2 de plus sur chaque paire
- **A** The Family — un carré contient une paire : ×4 et ×2
- **A** The Trio — Full ou brelan contient une paire : ×2 et ×3 ensemble
- **B** Half Joker — paire jouée seule (2-3 cartes) : +20 Mult puis ×2
- **B** Jolly Joker — paire : +8 Mult puis ×2
- **B** Sly Joker — paire : +50 jetons puis ×2

### The Family

- **A** Blueprint — ×4 de plus sur un carré
- **A** Brainstorm — ×4 de plus sur un carré
- **A** The Duo — un carré contient une paire : ×4 et ×2
- **A** The Trio — un carré contient un brelan : ×4 et ×3

### The Idol

- **A** Blueprint — ×2 de plus par carte cible
- **A** Brainstorm — ×2 de plus par carte cible
- **A** Hack — carte cible basse : ×2 deux fois
- **A** Hanging Chad — carte cible en tête : ×2 trois fois
- **A** Sock and Buskin — figure cible : ×2 deux fois
- **B** Dusk — dernière main : ×2 de la carte cible deux fois
- **B** Seltzer — 10 mains : carte cible deux fois

### The Order

- **A** Blueprint — ×3 de plus sur une suite
- **A** Brainstorm — ×3 de plus sur une suite
- **A** Four Fingers — suites de 4 cartes : ×3 bien plus souvent
- **A** Runner — chaque suite : Runner grandit et ×3
- **A** Shortcut — suites avec trous : ×3 bien plus souvent
- **B** Crazy Joker — suite : +12 Mult puis ×3
- **B** Devious Joker — suite : +100 jetons puis ×3

### The Tribe

- **A** Blueprint — ×2 de plus sur une couleur
- **A** Brainstorm — ×2 de plus sur une couleur
- **A** Four Fingers — couleurs de 4 cartes : ×2 bien plus souvent
- **A** Smeared Joker — deux couleurs seulement : couleurs faciles, ×2
- **A** Sigil — tout le deck d'une seule couleur
- **B** Crafty Joker — couleur : +80 jetons puis ×2
- **B** Droll Joker — couleur : +10 Mult puis ×2
- **B** The Moon — convertir vers une couleur
- **B** The Star — convertir vers une couleur
- **B** The Sun — convertir vers une couleur
- **B** The World — convertir vers une couleur

### The Trio

- **A** Blueprint — ×3 de plus sur un brelan
- **A** Brainstorm — ×3 de plus sur un brelan
- **A** The Duo — Full ou brelan contient une paire : ×2 et ×3 ensemble
- **A** The Family — un carré contient un brelan : ×4 et ×3
- **B** Wily Joker — brelan : +100 jetons puis ×3
- **B** Zany Joker — brelan : +12 Mult puis ×3

### Throwback

- **B** Blueprint — ×Mult des passages copié
- **B** Brainstorm — ×Mult des passages copié
- **X** Campfire — passer remet Campfire à zéro plus tôt
- **X** Cartomancer — passer contre jouer les manches
- **X** Constellation — jouer les manches contre les passer
- **X** Hologram — passer contre jouer les manches
- **X** Rocket — passer contre jouer les manches
- **X** Supernova — passer contre jouer les manches

### To Do List

- **C** Bootstraps — 4 $ par main demandée : Bootstraps grandit
- **C** Bull — 4 $ par main demandée : Bull grandit

### To the Moon

- **A** Money Tree — plafond d'intérêts 100 $
- **A** Seed Money — plafond d'intérêts 50 $ : To the Moon rapporte plus
- **B** Bootstraps — plus d'intérêts : plus de Mult
- **B** Bull — plus d'intérêts : plus de jetons
- **X** Vagabond — intérêts contre rester pauvre

### Trading Card

- **A** Caino — destruction contrôlée de figures
- **B** Erosion — cartes détruites : le deck s'amincit, +4 Mult par carte
- **X** Burglar — plus de défausses du tout

### Triboulet

- **S** Blueprint — ×4 par Roi ou Dame
- **S** Brainstorm — ×4 par Roi ou Dame
- **S** Sock and Buskin — Rois et Dames redéclenchés : ×4 chacun
- **A** Hanging Chad — Roi ou Dame en tête : ×2 trois fois
- **A** Cryptid — deux Rois ou Dames de plus
- **A** Death — Death : copier un Roi ou une Dame
- **A** Strength — Strength : Valet → Dame, Dame → Roi
- **B** Dusk — dernière main : Rois et Dames ×2 deux fois
- **B** Invisible Joker — peut dupliquer Triboulet (moins de jokers, plus de chances)
- **B** Seltzer — 10 mains : Rois et Dames ×2 deux fois

### Troubadour

- **B** Baron — +2 cartes tenues : plus de Rois en main
- **C** Burglar — Burglar rend la main perdue

### Turtle Bean

- **B** Baron — des cartes tenues de plus : plus de Rois en main
- **B** Stuntman — compense la main réduite de Stuntman

### Vagabond

- **B** Credit Card — dépenser sous 4 $ (jusqu'à −20 $) : des tarots à chaque main
- **B** Fortune Teller — plus de tarots utilisés
- **C** Campfire — des tarots à vendre
- **X** Bootstraps — Bootstraps veut beaucoup d'argent, Vagabond 4 $ au plus
- **X** Bull — Bull veut beaucoup d'argent, Vagabond 4 $ au plus
- **X** To the Moon — intérêts contre rester pauvre

### Vampire

- **A** Blueprint — ×Mult de Vampire copié
- **A** Brainstorm — ×Mult de Vampire copié
- **B** Midas Mask — Vampire mange l'Or : grandit à chaque main
- **B** The Devil — des améliorations à manger
- **B** The Empress — des améliorations à manger
- **B** The Hierophant — des améliorations à manger
- **B** The Magician — des améliorations à manger
- **X** Driver's License — Vampire mange les améliorations
- **X** Glass Joker — Vampire mange le verre
- **X** Golden Ticket — Vampire mange l'Or
- **X** Lucky Cat — Vampire mange les cartes chance
- **X** Steel Joker — Vampire mange l'acier

### Walkie Talkie

- **B** Hack — les 4 redéclenchés : +10 jetons et +4 Mult deux fois
- **C** Hanging Chad — 10 ou 4 en tête trois fois

### Wee Joker

- **B** Hack — +16 jetons permanents par 2
- **B** Hanging Chad — un 2 en tête : Wee Joker grandit trois fois
- **B** Cryptid — deux 2 de plus
- **B** Death — Death : copier un 2
- **C** Fibonacci — les 2 jouent pour les deux

### Wily Joker

- **B** The Trio — brelan : +100 jetons puis ×3

### Wrathful Joker

- **B** Arrowhead — Piques joués : +50 jetons et +3 Mult
- **B** The World — The World : des Piques

### Yorick

- **S** Blueprint — ×Mult de Yorick copié
- **S** Brainstorm — ×Mult de Yorick copié
- **A** Drunkard — plus de défausses
- **A** Merry Andy — plus de défausses
- **A** Recyclomancy — une défausse de plus : ×1 plus vite
- **A** Wasteful — une défausse de plus : ×1 plus vite
- **B** Invisible Joker — peut dupliquer Yorick (moins de jokers, plus de chances)
- **X** Burglar — plus de défausses du tout
- **X** Delayed Gratification — ne pas défausser contre défausser beaucoup
- **X** Green Joker — Green Joker perd 1 Mult par défausse
- **X** Ramen — Ramen perd ×0,01 par carte défaussée

### Zany Joker

- **B** The Trio — brelan : +12 Mult puis ×3

## Builds

### Rois tenus en main (Baron + Mime) — A (forte)

- Pièces centrales : Baron
- Soutiens : Mime, Blueprint, Brainstorm, Shoot the Moon, Raised Fist, Steel Joker, DNA, Juggler, Troubadour, Turtle Bean, Reserved Parking
- À éviter : Stuntman, Merry Andy, Vampire, Triboulet, Sock and Buskin, Photograph
- Conseil : Chariot (acier) et Déjà Vu (sceau rouge) sur les Rois, Death pour copier le meilleur Roi, Strength : Dame → Roi ; garder les Rois en main, ne pas les jouer

### Figures en tête (Photograph + Hanging Chad) — A (forte)

- Pièces centrales : Photograph, Hanging Chad
- Soutiens : Sock and Buskin, Smiley Face, Scary Face, Business Card, Midas Mask, Pareidolia, Hiker, Dusk, Seltzer, Blueprint, Brainstorm
- À éviter : Ride the Bus, Caino, Faceless Joker
- Conseil : jouer la figure en premier (à gauche) ; Déjà Vu (sceau rouge) et Justice (verre) sur un Roi de tête ; Death / Strength pour plus de figures

### Rois et Dames joués (Triboulet + Sock and Buskin) — S (gagne la partie)

- Pièces centrales : Triboulet
- Soutiens : Sock and Buskin, Hanging Chad, Dusk, Seltzer, Blueprint, Brainstorm, Photograph
- À éviter : Baron, Shoot the Moon, Reserved Parking, Caino, Ride the Bus
- Conseil : Strength (Valet → Dame → Roi) et Death pour remplir le deck de Rois et de Dames ; Hanged Man sur le reste

### Figures détruites (Canio) — S (gagne la partie)

- Pièces centrales : Caino
- Soutiens : Pareidolia, Glass Joker, Trading Card, Erosion, DNA
- À éviter : Baron, Sock and Buskin, Triboulet, Photograph
- Conseil : Hanged Man sur des figures (chaque figure détruite : +×1), Justice (verre) sur des figures

### Petites cartes (Hack) — B (bonne)

- Pièces centrales : Hack
- Soutiens : Wee Joker, Walkie Talkie, Fibonacci, Even Steven, Odd Todd, Scholar, The Idol, Hanging Chad, Dusk, Hiker, Ride the Bus
- À éviter : Pareidolia, Photograph, Sock and Buskin, Smiley Face, Scary Face
- Conseil : Hanged Man sur les figures, Death pour copier un 2 ou un 5 ; il faudra un ×Mult (The Idol, Bloodstone…)

### Couleur (jokers de couleur, Smeared Joker) — B (bonne)

- Pièces centrales : Bloodstone, Ancient Joker, Arrowhead, Onyx Agate, Rough Gem, Lusty Joker, Greedy Joker, Wrathful Joker, Gluttonous Joker, The Tribe, Smeared Joker
- Soutiens : Four Fingers, Droll Joker, Crafty Joker, Oops! All 6s, Blueprint, Card Sharp
- Conseil : The Star / Moon / Sun / World vers la couleur des jokers, Hanged Man sur les autres couleurs ; vendre les +3 Mult de couleur quand un ×Mult arrive

### Cartes chance (Lucky Cat + Oops! All 6s) — B (bonne)

- Pièces centrales : Lucky Cat
- Soutiens : Oops! All 6s, Hanging Chad, Seltzer, Splash, Bloodstone, Business Card
- À éviter : Vampire, Midas Mask
- Conseil : The Magician sur les cartes jouées le plus souvent ; Lucky Cat dès qu'il apparaît

### Cartes de verre (Glass Joker) — A (forte)

- Pièces centrales : Glass Joker
- Soutiens : Hanging Chad, Caino, Erosion, DNA, Sock and Buskin, Hack
- À éviter : Vampire, Driver's License
- Conseil : Justice sur le rang le plus joué (ou la carte de tête avec Hanging Chad) ; sceau rouge sur le verre (×4)

### Cartes d'acier tenues (Steel Joker + Mime) — A (forte)

- Pièces centrales : Steel Joker
- Soutiens : Mime, Baron, DNA, Fortune Teller, Raised Fist, Shoot the Moon
- À éviter : Vampire, Stuntman
- Conseil : The Chariot sur les cartes gardées en main (les Rois avec Baron), Death pour copier une carte d'acier

### Cartes ajoutées (Hologram + DNA) — A (forte)

- Pièces centrales : Hologram
- Soutiens : DNA, Certificate, Marble Joker, Blueprint, Brainstorm
- À éviter : Erosion
- Conseil : DNA : jouer une carte seule en première main ; Cryptid ajoute 2 cartes

### Améliorations mangées (Vampire + Midas Mask) — A (forte)

- Pièces centrales : Vampire
- Soutiens : Midas Mask, Pareidolia, Cartomancer, DNA
- À éviter : Lucky Cat, Glass Joker, Steel Joker, Driver's License, Golden Ticket
- Conseil : améliorer beaucoup de cartes jouées (Magician, Empress, Hierophant) ; Midas Mask à gauche de Vampire

### Planètes (Constellation) — A (forte)

- Pièces centrales : Constellation
- Soutiens : Astronomer, Satellite, Space Joker, Supernova
- À éviter : Campfire, Red Card, Throwback
- Conseil : prendre toutes les planètes de la main principale ; sceaux bleus (Trance) sur des cartes gardées

### Paires portées par les jokers (Card Sharp, The Duo) — A (forte)

- Pièces centrales : Card Sharp, The Duo, The Trio, The Family, Spare Trousers
- Soutiens : Square Joker, Supernova, Green Joker, Burglar, Space Joker, Splash, Hanging Chad
- À éviter : Obelisk
- Conseil : monter la Paire (Mercury) ou la double paire (Uranus), puis ajouter une source exponentielle (verre, acier, Photograph + Hanging Chad)

### Défausses (Yorick, Hit the Road) — S (gagne la partie)

- Pièces centrales : Yorick, Hit the Road
- Soutiens : Drunkard, Merry Andy, Mail-In Rebate, Castle, Burnt Joker, Faceless Joker
- À éviter : Burglar, Green Joker, Ramen, Banner, Delayed Gratification
- Conseil : défausser beaucoup (bons et jokers de défausses) ; Hit the Road : des Valets dans le deck (Strength 10 → Valet)

### Planètes copiées (Perkeo + Observatory) — S (gagne la partie)

- Pièces centrales : Perkeo
- Soutiens : Blueprint, Brainstorm, Showman, Constellation
- À éviter : Madness
- Conseil : garder une seule planète (celle de la main principale) pour que Perkeo la copie ; Telescope puis Observatory

### Suites (The Order, Runner, Shortcut) — B (bonne)

- Pièces centrales : The Order, Runner
- Soutiens : Shortcut, Four Fingers, Crazy Joker, Devious Joker, Superposition, Square Joker, Blueprint, Brainstorm
- À éviter : Flower Pot, Half Joker
- Conseil : Shortcut ou Four Fingers rendent les suites faciles ; monter la suite (Saturn), puis un ×Mult (The Order)

### Multiplicateurs par carte redéclenchés (Ancient, The Idol, Bloodstone) — A (forte)

- Pièces centrales : The Idol, Ancient Joker, Bloodstone
- Soutiens : Hanging Chad, Dusk, Seltzer, Oops! All 6s, Smeared Joker, Blueprint, Brainstorm
- À éviter : Four Fingers
- Conseil : chaque redéclenchement rejoue le ×Mult de la carte : Hanging Chad (première carte ×3), Dusk (dernière main), sceaux rouges (Déjà Vu)

### Cartes or (Golden Ticket, Midas Mask) — B (bonne)

- Pièces centrales : Golden Ticket, Midas Mask
- Soutiens : Pareidolia, Bull, Bootstraps, Mime, Hanging Chad, Sock and Buskin
- À éviter : Vampire
- Conseil : The Devil sur les cartes jouées, Midas Mask change les figures jouées en or ; l'argent nourrit Bull et Bootstraps

### L'argent devient du score (Bull, Bootstraps) — B (bonne)

- Pièces centrales : Bull, Bootstraps
- Soutiens : Golden Joker, Rocket, Cloud 9, To the Moon, Rough Gem, Golden Ticket, Satellite, Egg
- À éviter : Credit Card, Vagabond
- Conseil : garder beaucoup d'argent (Seed Money, Money Tree) ; The Hermit double l'argent

### Cartes pierre (Stone Joker, Marble Joker) — C (mineure)

- Pièces centrales : Stone Joker
- Soutiens : Marble Joker, Driver's License, Hiker
- À éviter : Vampire
- Conseil : The Tower et Marble Joker ajoutent des pierres (+25 jetons chacune) ; il faut ensuite un ×Mult

### Valeur de vente (Swashbuckler, Gift Card, Egg) — C (mineure)

- Pièces centrales : Swashbuckler
- Soutiens : Gift Card, Egg, Ceremonial Dagger
- Conseil : Gift Card augmente la valeur de vente de tout ; Swashbuckler l'ajoute au Mult

### Moteur à tarots (Fortune Teller, Cartomancer) — C (mineure)

- Pièces centrales : Fortune Teller
- Soutiens : Cartomancer, 8 Ball, Hallucination, Superposition, Vagabond, Perkeo
- Conseil : utiliser tous les tarots (Tarot Merchant) ; Perkeo en copie un en négatif à chaque boutique

### Deck amélioré (Driver's License) — B (bonne)

- Pièces centrales : Driver's License
- Soutiens : Midas Mask, Marble Joker, Steel Joker, Glass Joker, Lucky Cat, Stone Joker
- À éviter : Vampire
- Conseil : 16 cartes améliorées : Magician, Empress, Hierophant, Lovers, Chariot, Justice, Devil, Tower sur deux cartes chacun

### Peu de jokers (Joker Stencil) — B (bonne)

- Pièces centrales : Joker Stencil
- Soutiens : Blueprint, Brainstorm, Cavendish, Baron
- À éviter : Riff-raff, Abstract Joker, Baseball Card
- Conseil : chaque emplacement vide donne ×1 ; les jokers négatifs ne prennent pas de place (Ectoplasm)

### Jetons permanents (Hiker) — B (bonne)

- Pièces centrales : Hiker
- Soutiens : Hanging Chad, Dusk, Seltzer, Splash, Sock and Buskin, Hack
- Conseil : chaque carte jouée gagne +5 jetons pour toujours ; les redéclenchements et Splash multiplient le gain

### Carrés (The Family) — B (bonne)

- Pièces centrales : The Family
- Soutiens : The Duo, The Trio, Card Sharp, Supernova, Blueprint, Brainstorm
- À éviter : Half Joker, Flower Pot
- Conseil : un carré contient un brelan et une paire : The Family, The Trio et The Duo ensemble ; Death pour copier le rang

## Niveaux

- **S** : gagne la partie
- **A** : forte
- **B** : bonne
- **C** : mineure
- **X** : anti-synergie
