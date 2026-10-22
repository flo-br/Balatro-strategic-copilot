# Historique des versions

## 1.0.11 — 2026-10-22

Demande : continuer à progresser aux mises élevées. **Les conseils restent ceux de la 1.0.10** :
aucune des pistes mesurées ne fait mieux (détails : `docs/TRAINING.md`, « Résultats 1.0.11 »).

### Nouvelles mesures
* **Bifurcations** (`tools/trainer/branch.lua`) : à une décision de boutique, la partie simulée est
  dupliquée et chaque alternative (le choix du copilote, acheter autre chose, partir, relancer) est
  jouée avec les mêmes futurs. Sur 24 décisions, aucune alternative ne bat nettement le choix du
  copilote.
* Régression sur 5 500 boutiques simulées : ce que valent puissance, argent et ×Mult en blindes
  gagnées par la suite (corrélations, pas des règles : voir les essais).

### Essayé sur 60 parties chacun, **non gardé** (options coupées)
* Croissance du joker acheté en remplacement d'un autre (erreur réelle : seule la croissance du
  joker vendu était comptée ; corrigée, mais −0,21 ± 0,13 : un joker qui grandit « à condition »
  ne vaut pas le joker solide qu'on revend pour lui) — `replace_growth`.
* Bonus ×Mult relevé (−0,90 ± 0,34) ou baissé (−0,41 ± 0,31) aux mises élevées — `xmult_extra`.
* Deux fois plus d'échantillons en boutique ; estimation des antes futures dans la note.

### Outils
* Options du simulateur partagées (`tools/trainer/options.lua`) ; `branch.lua` (Linux, LuaJIT).
* 273 tests.

## 1.0.10 — 2026-10-21

Demande : progresser aux mises élevées (verte à or). Chaque idée a été **mesurée** sur le
simulateur (mêmes graines, partie par partie) et n'est gardée que si elle fait mieux ; la version
finale a été validée sur **de nouvelles graines**, jamais utilisées pour choisir les réglages.
Détails et tous les chiffres : `docs/TRAINING.md`, « Résultats 1.0.10 ».

### Ce qui change aux mises élevées (à partir de la mise verte)
Règles des meilleurs joueurs (recherche sourcée : `docs/PRO_HIGH_STAKES_SOURCES.md`, synthèse :
`docs/PRO_LESSONS.md` §9) :
* **presque jamais passer une blinde** (sauf tag Investissement aux antes 1-2, et tag Boss contre
  un boss qui contre le jeu) : la boutique et la récompense perdues coûtent plus que presque tous
  les tags quand les blindes grandissent vite ; c'est le changement qui pèse le plus ;
* pas de ×Mult en entrant à l'ante 5 : plus d'épargne, tout va à la puissance ;
* **épargne seulement sur un plateau vraiment sûr** : prochaine blinde à 95 % et boss à 85 %
  (85 % / 70 % aux mises blanche et rouge) ; réglables dans `config.lua` (`hs_safe_next`, `hs_safe_boss`) ;
* mise or : une seule location avant l'ante 6, et seulement pour un ×Mult ou un joker qui
  grandit ; le loyer passe avant les intérêts ;
* mise noire et plus : un joker éternel qui n'est ni ×Mult ni croissant est plus risqué ;
* bons sans effet immédiat sur le score (Overstock, Clearance Sale…) : seulement sur un plateau sûr ;
* un joker de plus pris sans regarder les intérêts aux antes 1-2.

**Mesuré** (deck rouge, simulateur) :
* mise noire, 60 parties : **+1,36 ± 0,59 blinde gagnée par partie** par rapport à la 1.0.9 ;
  sur les 40 parties jamais utilisées pour choisir : +1,09 ± 0,80 ;
* mise or, 12 parties : +1,61 ± 0,81 (ante moyenne 3,25 → 3,75) ;
* mise blanche, 12 parties : résultats identiques (4 victoires sur 12 des deux côtés).
* **Pas plus de victoires** : 2 sur 60 de part et d'autre à la mise noire, 0 sur 12 à la mise or.
  La plupart des parties s'arrêtent toujours à l'ante 5 ; le copilote reste loin des meilleurs
  joueurs à ces mises.

### Corrections (règles du jeu)
* Jokers que le jeu ne rend **jamais éternels ou périssables** (listes du wiki : un joker qui
  grandit n'est jamais périssable ; Gros Michel, Cavendish, Ramen… jamais éternels) : pris en
  compte dans l'estimation des paquets Bouffon et des relances, et dans le simulateur (qui les
  approchait par des étiquettes).
* Cartes face cachée : les candidats en double ne sont plus simulés deux fois.

### Essayé, mesuré, **non gardé** (options coupées, gardées pour reproduire les mesures)
Trajectoire de puissance des parties gagnantes ; estimation des antes futures dans la note ;
planètes centrées sur la main principale ; −8 points aux paquets Arcane / Standard / Spectral ;
relances pour chercher un ×Mult dès l'ante 3 ; poids de la puissance du plateau ×1,5 ; épargne
lue sur des chances calibrées ; seuils encore plus stricts (99 % / 95 %). Trois corrections justes
en principe mais sans gain mesuré, donc coupées elles aussi : joker d'un paquet Bouffon compté
gratuit (son prix était compté en plus de celui du paquet), croissance des jokers tirés pour un
paquet ou une relance, défausse des cartes d'un jeu qui mêle cartes cachées et visibles.

### Ce que le diagnostic a montré
* Les probabilités de la main sont bien calibrées (annoncé 40-70 % → gagné 60-85 %).
* Ce qui prédit l'issue d'une partie simulée à l'ante 4 : la puissance du plateau (corrélation
  0,49), pas le niveau de la main principale (−0,04).

### Validation
272 tests (LuaJIT et Lua 5.1), installateur (53 vérifications, 0 échec), vrais chargeurs
Steamodded 0509c et récent (bandeau « 1.0.10 actif »), mode autonome sur le vrai LÖVE 11.5.
**Pas de partie réelle de Balatro jouée** : aucune installation du jeu n'était disponible.

## 1.0.9 — 2026-10-19

Retours des parties réelles (journaux fournis) : erreurs à trouver sans aide, ordre des cartes à
indiquer, recalcul du copilote après chaque partie, toutes les mises et tous les decks.

### Erreurs trouvées dans les parties réelles (journaux de la 1.0.6)
* **Cartes jouées mal capturées sans événements Steamodded** (mode autonome / ancien Steamodded) :
  les cartes arrivent dans la zone de jeu **une par une** ; seule la première était lue, d'où des
  scores prévus faux (16 au lieu de 64) et des conseils marqués « non suivis ». La plus grande
  sélection vue pendant la main est gardée, à chaque image.
* Madness (détruit un joker à chaque blinde) était noté comme un simple ×Mult : mesuré désormais
  sur les plateaux qu'il laisse.
* Mises verte à or : les ×Mult sont attendus une à deux antes plus tôt (blindes plus grosses).

### Ordre des cartes
* Numéros **JOUER 1, 2, 3…** sur les cartes à jouer et **GARDER 1, 2…** sur les cartes gardées en
  main quand l'ordre change le score (Photograph, Hanging Chad, verre, polychrome, Triboulet,
  The Idol, Ancient Joker, Bloodstone ; Shoot the Moon + Baron en main), avec le gain dans le
  panneau ; carte imposée de Cerulean Bell : « IMPOSÉE n ».
* Chaque jeu possible est évalué **dans son meilleur ordre** (avant : dans l'ordre de l'écran ; une
  Double paire gagnante seulement avec un Roi en tête, 1 184 au lieu de 272, était écartée au
  profit d'une Paire perdante) ; la simulation de la fin de manche et l'estimation de puissance
  (boutique) font de même : Hanging Chad n'est plus sous-évalué.
* Étiquettes voisines décalées d'une rangée quand elles se chevauchent.

### Après chaque partie : le copilote recalcule son développement (`learning/adapt.lua`)
* Après une défaite, il **essaie un changement** demandé par la cause qui revient le plus dans vos
  défaites (×Mult manquants → ×Mult plus urgents en boutique ; argent dormant → dépenser plus tôt ;
  marge ou boss → plus de sécurité ; défaite juste après un passage → passer moins…), le joue
  3 parties, puis le **garde** si ces parties ne sont pas moins bonnes que les précédentes, sinon
  l'**annule**. Chaque étape est affichée dans le bilan (« Ce que je change pour la prochaine
  partie ») avec sa cause et les moyennes comparées. Nouvelle cause du bilan : défaite dans l'ante
  d'un passage de blinde.
* Pourquoi des essais : mesuré sur le simulateur, appliquer directement les leçons d'une défaite
  faisait **moins bien** que ne rien changer (1 victoire sur 10 au lieu de 4, puis 6 sur 20 au lieu
  de 9 avec seulement les causes qui distinguent les défaites ; les leçons de la 1.0.7, qui
  pesaient d'office sur le plan, aussi : 7 sur 20). « Main sous la mise » et « décrochage », présentes
  dans toutes les défaites, ne changent plus rien.
* Version par essais mesurée sur les mêmes graines : 7 sur 20 contre 9 sans recalcul (écart dans le
  bruit de 20 parties) ; l'essai qui faisait moins bien a bien été annulé. **Pas de progrès
  démontré** : le recalcul reste prudent et se coupe avec `learning.adapt = false` (`config.lua`).

### Mises et decks (erreurs trouvées en faisant jouer le copilote à toutes les mises)
* **Location** (mise or) : un joker loué coûte 1 $ puis 3 $ à chaque manche ; il était noté comme un
  joker à 1 $ (deux locations prises à l'ante 1 vidaient l'argent de toute la partie : −5 $ à la
  fin). Coût compté sur deux antes, pris seulement s'il est fort ou nécessaire, **revendu** dès que
  la suite reste sûre sans lui (s'il porte le score, plus de 15 %, seulement quand il reste moins
  de 10 $ : le loyer bloque alors tout achat). Paquets Bouffon et relances estimés avec les autocollants que leurs
  jokers peuvent porter (éternel, périssable, location).
* **Joker qui grandit** : sa revente compte ce qu'il deviendra (Runner, Hologram, Glass Joker
  étaient achetés pour leur croissance puis revendus dans la même boutique, « 0 % du score »).
* **Remplacer le seul ×Mult** attendu à l'ante suivante par un joker sans ×Mult est pénalisé.
* **Danger critique** (prochaine blinde ou boss sous 50 %) : l'argent gardé ne vaut rien après une
  défaite, les relances ne sont plus limitées (parties perdues aux antes 6-7 avec 50 à 75 $).
* **Bons** : valeur par ante restante (Overstock, Clearance Sale, Reroll Surplus, Telescope…) ;
  avant, une valeur fixe toujours sous leur prix les faisait presque toujours refuser (3 achetés
  en 22 parties) ; les bons +1 main / +1 défausse / +1 taille de main comptent pour toutes les
  antes restantes.
* Tags Double cumulés : un tag passé vaut plus quand des tags Double sont déjà en attente.
* Une manche sans issue (aucune option ne gagne une seule simulation sur 32) n'est plus simulée
  jusqu'au bout : conseil en ≈ 3 s de calcul au lieu de ≈ 7 s.

### Entraînement
* Simulateur : mises 1 à 8 (Small Blind sans récompense, échelles 2 et 3, autocollants éternel /
  périssable / location, une défausse de moins), 15 decks de départ, Madness et Ceremonial Dagger,
  tags Double cumulés ; option `learn=1` (profil partagé, réglages recalculés après chaque partie).
* Résultats des parties simulées par mise et par deck : [docs/TRAINING.md](docs/TRAINING.md).

## 1.0.8 — 2026-10-19

Retours de la partie de test : boss qui impose une carte mal pris en compte, plus aucune blinde
passée, synergies des builds des pros.

### Corrigé
* **Cerulean Bell** (une carte toujours sélectionnée) : la carte imposée part avec **chaque jeu et
  chaque défausse** ; une défausse conseillée ne contient plus que 4 autres cartes au plus (avant :
  jusqu'à 5 autres, soit 6 cartes, impossible dans le jeu) ; « défausser la seule carte imposée »
  est une option. Dans la simulation de la fin de manche, une nouvelle carte est imposée après
  chaque pioche (avant, la simulation ne trouvait plus de jeu possible : 30 % annoncés au lieu de
  ~100 % sur un cas test). Étiquette **IMPOSÉE** sur la carte et explication dans le panneau.
  L'analyse repart quand le jeu impose la carte (après la pioche).
* Boss dont l'effet change d'une main à l'autre, désormais simulés dans la fin de manche : The Eye,
  The Mouth, The Arm (niveau perdu pour la suite), The Hook (2 cartes tenues défaussées), Crimson
  Heart (un autre joker désactivé), The Fish / The Wheel / The Mark (cartes piochées face cachée).
* Prévision des boss : cartes Joker (Wild) et, avec Smeared Joker, les deux couleurs rouges ou
  noires affaiblies par les boss de couleur ; toutes les cartes contre The Plant avec Pareidolia ;
  cartes déjà jouées dans l'ante contre The Pillar ; Cerulean Bell.
* Symboles de couleur (♣…) dans le texte du panneau remplacés par les lettres des cartes quand la
  police ne les a pas.

### Blindes passées : recalcul complet (`engine/skip.lua`)
* La règle « presque jamais » reposait sur des avis d'avant le patch 1.0.1f (mai 2024), qui a
  rendu gratuits les jokers des tags et porté Investment à 25 $. Nouvelle recherche sourcée :
  [docs/PRO_SKIPS_SOURCES.md](docs/PRO_SKIPS_SOURCES.md).
* Coût réel du passage, affiché : récompense (0 $ pour la Small Blind dès la mise rouge, lu dans
  le jeu), mains restantes, intérêts, argent des jokers (location économisée), boutique sautée
  (plus chère au fil des antes et quand le build manque de pièces), croissance perdue, ce que le
  passage préserve (Throwback, jokers qui s'usent, The Pillar).
* Valeur de chacun des 24 tags selon la situation (classement des pros : Investment et Coupon
  tôt, Polychrome, Holographic tôt, Negative, Economy avec de l'argent, Orbital seulement sur la
  main principale, Boss seulement contre un boss qui contre le jeu, Speed / Handy / Garbage selon
  le montant affiché ; presque jamais Voucher, Juggle, D6 ; autocollants des mises noire et or).
* Sécurité : la blinde qui suit doit rester battue sans la boutique sautée (boss ≥ 90 % pour
  passer une Big Blind), chances tirées d'une simulation complète de la manche (l'ancienne
  estimation, sans défausses, était beaucoup trop pessimiste : 70-81 % pour une Big Blind d'ante 1
  gagnée 60 fois sur 60).
* Nom du tag lu dans le jeu, main de l'Orbital Tag lue dans le jeu.

### Synergies des builds des meilleurs joueurs (`model/builds_db.lua`, `engine/builds.lua`)
* 15 builds (Baron + Mime, Photograph + Hanging Chad, Triboulet + Sock and Buskin, Canio,
  petites cartes avec Hack, couleur, chance, verre, acier, cartes ajoutées, Vampire, planètes,
  paires portées par les jokers, défausses, Perkeo), ≈ 110 paires de jokers notées S / A / B / C
  et anti-synergies, synergies joker + deck. Recherche sourcée :
  [docs/PRO_SYNERGIES_SOURCES.md](docs/PRO_SYNERGIES_SOURCES.md).
* Boutique : bonus de note et raison affichée (« synergie : Baron, chaque Roi tenu compte deux
  fois ») ; plus faible aux antes 1-2 (ne pas forcer un build) ; une pièce de build garde sa valeur
  à la vente et au remplacement.
* Tarots : cibles selon le build (Strength Dame → Roi avec Baron, Hanged Man sur les figures avec
  Canio, tarots de couleur vers la couleur des jokers de couleur…).
* Plan : « Build en cours », pièces à chercher et comment l'assembler.

### Entraînement
* Simulateur corrigé (Cerulean Bell, affaiblissements dès le début de la blinde, tags de
  boutique, main de l'Orbital Tag).
* Sur les mêmes 40 parties simulées : 1.0.7 gagne 8 parties (20 %), 1.0.8 en gagne 16 (40 %) ;
  ante 8 atteinte 58 % → 60 % ; 38 blindes passées au lieu de 23, pour 10 tags différents au lieu
  de 2. Mesure sur le simulateur, pas sur le vrai jeu ([docs/TRAINING.md](docs/TRAINING.md)).

## 1.0.7 — 2026-10-19

Retours de la partie de test : effets de cartes et de jokers mal pris en compte, Judgement avec
les jokers pleins, jeu trop simple, défaites mises sur le compte du hasard.

### Effets des cartes et des jokers
* **Base des effets** (`model/effects_db.lua`) : améliorations (bonus, multi, joker, verre, acier,
  pierre, or, chance), éditions (brillant, holographique, polychrome, négatif), sceaux (or, rouge,
  bleu, violet) et autocollants des jokers (éternel, périssable, location), avec leur rôle :
  à jouer, à garder en main, à défausser, à jouer seulement si nécessaire.
* Le panneau montre les effets : les cartes sont suivies de leurs effets (« R♠(acier) ») et une
  section « Effets des cartes en main » dit ce que fait chaque carte modifiée et quoi en faire ;
  les autocollants des jokers sont affichés (périssable : manches restantes).
* Pendant la main : les cartes **Or** et à **sceau bleu** ne sont plus jouées comme cartes
  d'accompagnement d'une main déjà gagnante ; l'**acier** est gardé en main ; le **verre** n'est
  joué que s'il sert ; le **sceau violet** est défaussé de préférence ; la **chance** n'est plus
  surévaluée (+20 multi seulement 1 fois sur 5).
* **The Ox** : le copilote joue une autre main que la plus jouée quand les chances sont presque les
  mêmes (sinon l'argent tombe à 0), et dépense avant ce boss.
* Autocollants : un joker **éternel** n'est jamais proposé à la vente (Luchador, Invisible Joker,
  remplacement, Verdant Leaf) ; un **périssable** est compté selon ses manches restantes et vendu une
  fois expiré ; la **location** coûte 3 $ par manche dans l'économie et la note.
* Cartes à jouer (boutique, paquet Standard) notées selon leurs effets ; une carte sans effet dilue
  le deck.

### Judgement, Wraith, The Soul, Hex, Ankh
* Avec les jokers pleins, Judgement (comme Wraith et The Soul) n'est plus conseillé sans plan : le
  copilote mesure si un joker aléatoire a de bonnes chances d'être meilleur que le plus faible des
  vôtres ; si oui, il indique **quel joker vendre d'abord** (À VENDRE), puis UTILISER.
* Hex et Ankh (qui détruisent les autres jokers), Ectoplasm et Ouija (−1 taille de main) sont
  mesurés sur le plateau qu'ils laissent ; avant, une valeur fixe positive les faisait prendre et
  ils rasaient le plateau.

### Jeu inspiré des meilleurs joueurs ([docs/PRO_LESSONS.md](docs/PRO_LESSONS.md))
* Recherche sourcée (wiki officiel, guides, forums) : 140 règles, dont celles appliquées ici.
* **Plan de partie** (`engine/plan.lua`, affiché en boutique) : main principale, multiplicateurs
  ×Mult présents / attendus (0, 0, 0, 1, 1, 2, 2, 3 aux antes 1 à 8), ce qui manque ; les ×Mult
  gagnent de la valeur avec les antes, les +Mult / +Jetons en perdent en fin de partie, les jokers
  qui grandissent valent plus tôt, les planètes de la main principale aussi.
* « En retard » quand une main typique ne marque plus la mise de base de l'ante : le score passe
  avant les intérêts.
* **Argent** : au-delà du plafond d'intérêts (25 $), l'argent ne rapporte rien ; il est dépensé dès
  qu'un achat améliore le jeu, et relancé quand il manque un ×Mult ; dernière ante : tout devient
  du score ; The Hermit utilisé à partir de 20 $.
* Antes 1-2 : les premiers jokers de score passent avant l'épargne (un joker vaut mieux qu'un
  emplacement vide).
* Verdant Leaf : vendre le joker qui marque le moins pour lever l'effet.
* Simulations de manche plus précises quand les meilleures options sont proches.

### Bilan de partie : toute partie est jouable
* Le bilan ne conclut plus jamais par « malchance ». Il cherche **pourquoi le build n'a pas suffi**
  : ante où une main typique est passée sous la mise de base, pas d'amélioration à la fin de l'ante
  2, trop peu de jokers à l'ante 3, ×Mult manquants, argent dormant, planètes dispersées, main
  principale peu montée, exigences du boss perdu, marge trop faible avant une blinde décisive.
* Les causes des dernières défaites sont retenues : quand une même cause revient, le plan lui donne
  plus de poids aux parties suivantes.

### Entraînement ([docs/TRAINING.md](docs/TRAINING.md))
* `tools/trainer/` : un simulateur de parties complètes où **chaque décision est prise par le
  moteur de conseils du copilote**, pour mesurer et corriger ses faiblesses (ce n'est pas le vrai
  jeu ; simplifications documentées). Les défauts corrigés ci-dessus viennent de ces parties.
* Sur les mêmes 40 parties simulées (deck rouge, mise blanche) : 1.0.6 gagne 6 parties (15 %),
  atteint l'ante 8 dans 25 % des cas, ante moyenne 5,58 ; 1.0.7 gagne 11 parties (28 %), atteint
  l'ante 8 dans 43 % des cas, ante moyenne 6,63. Mesure sur le simulateur, pas sur le vrai jeu.

## 1.0.6 — 2026-10-18

Retours de la partie en mise basse (gagnée).

### Corrigé
* **Tarots et spectrales qui demandent des cartes** : le copilote indique désormais les cartes à
  sélectionner, chacune avec son étiquette. **Death** : DEVIENT (gauche) et MODÈLE (droite), et si
  la carte qui devient est à droite, la consigne « glissez la carte DEVIENT à gauche de la carte
  MODÈLE » ; Strength, Hanged Man (À DÉTRUIRE), Magician (Chance), Chariot (Acier), Empress,
  Hierophant, Lovers, Justice, Devil, Tower, Star / Moon / Sun / World, Talisman, Déjà Vu, Trance,
  Medium, Aura, Cryptid. Aussi pour les cartes prises dans un paquet Arcane ou Spectral.
* **Choix de blinde** : seul le choix **définitif** est affiché (plus de « JOUER » qui devient
  « PASSER » quand l'analyse se termine).
* **Étiquette UTILISER cachée par le panneau** : le panneau se place sous la zone des
  consommables ; les étiquettes sont dessinées par-dessus le panneau.
* Le texte d'un paquet Méga Buffon ne peut plus annoncer une valeur au-dessus de 100/100.

### Stratégie inspirée des meilleurs joueurs
* **Blindes presque jamais passées** : passer coûte la récompense **et la boutique** qui suit
  (10 $ jusqu'à l'ante 4, 8 $ ensuite) ; la blinde d'après doit rester ≥ 95 %. En pratique, seul
  un tag Investment ou Economy (avec beaucoup d'argent) le justifie.
* **Paquets achetés souvent** : valeur calculée sur leur contenu (Buffon : jokers simulés ;
  Céleste : planètes des mains jouées ; Arcane / Spectral : cartes notées comme en boutique) et
  seuil d'achat abaissé à 52/100.
* **Intérêts** : à partir de l'ante 2, si la suite est sûre, le copilote garde 25 $ et ne dépense
  que l'excédent (sauf objet noté ≥ 75) ; à l'ante 1, chaque dollar d'intérêts perdu relève le
  seuil d'achat. En danger, la puissance passe d'abord.
* **Une relance avant de quitter la boutique** (si elle respecte l'épargne), relance gratuite
  toujours utilisée.
* Consommables qui créent des cartes (High Priestess, Emperor, Judgement, Wheel of Fortune)
  conseillés quand il y a la place.
* Nouveaux réglages dans `config.lua`, section `advice` : `booster_note`, `strong_note`,
  `save_from_ante`, `interest_weight`, `safe_next`, `safe_boss`, `reroll_once`,
  `reroll_once_max_loss`.

## 1.0.5 — 2026-10-18

Retours de la première phase de test.

### Ajouté
* **Une étape à la fois (« À FAIRE »)** : le copilote indique UNE action à faire maintenant, avec
  une étiquette au-dessus de ce qu'il faut toucher, et recalcule après chaque action : JOUER /
  DÉFAUSSER (cartes), À PRENDRE (boutique, paquet), À VENDRE (remplacement, place pour un
  consommable, joker inutile, Luchador contre un boss dangereux, Invisible Joker prêt), RELANCER,
  BLINDE SUIVANTE, JOUER / PASSER au choix de la blinde, UTILISER + CIBLE (planètes, Hermit,
  Temperance, tarots sur les cartes qui vont jouer), PASSER un paquet. Probabilité qui justifie le
  choix visible par défaut. Seuils réglables (`config.lua`, section `advice`).
* **Ordre des jokers** : numéros 1, 2, 3… sous les jokers, seulement quand l'ordre actuel n'est
  pas le bon (×Mult avant +Mult) ; calculé aussi pendant une main ; disparaît une fois corrigé.
* Étiquettes sur les **boutons du jeu** (relance, blinde suivante, sélectionner / passer la
  blinde, passer le paquet), repérés en lecture seule ; si un bouton n'est pas trouvé, l'étape
  reste écrite et les boutons vus sont notés dans le journal.

### Corrigé
* **Boss The House** (toutes les cartes face cachée) : « Aucune analyse disponible ». Le conseil
  porte désormais sur un nombre de cartes cachées à jouer ou défausser, évalué sur les cartes
  possibles (pioche visible dans la vue du deck), sans jamais lire l'identité d'une carte cachée ;
  vaut aussi pour The Mark, The Wheel, The Fish.
* Le panneau ne répète plus la recommandation (la ligne « À FAIRE » la porte).
* Un ordre de jokers calculé avant un déplacement ne peut plus être appliqué à la nouvelle
  disposition.
* Lua 5.1 : le calcul de l'ordre des jokers échouait silencieusement (suspension impossible dans
  un `pcall`) ; nouvelle protection compatible (`Sched.protected`).

## 1.0.4 — 2026-10-18

### Ajouté
* **Mode autonome : installation sans Lovely, sans Steamodded, sans script ni DLL**, pour les PC
  qui bloquent les `.bat`, PowerShell ou `winmm.dll`. Il suffit de copier `main.lua` et `Mods` dans
  `%AppData%\Balatro\`. LÖVE 11 lit `main.lua` d'abord dans le dossier de sauvegarde (vérifié dans
  son `boot.lua`) ; l'amorce exécute le `main.lua` d'origine du jeu sans le modifier, puis démarre
  le copilote. Trace de chaque étape dans `BSC\amorce.log`, bandeau rouge si le copilote ne peut
  pas démarrer (le jeu continue), désinstallation = supprimer `main.lua`.
* Sans Steamodded : modules lus via `love.filesystem`, `config.lua` lu directement, touches C/V/B
  lues au clavier (jamais pendant une saisie de texte ni avec Ctrl/Alt).
* Deux archives : `BalatroStrategicCopilot-1.0.4.zip` (sans aucun script) et
  `BalatroStrategicCopilot-1.0.4-installateur.zip` (installateur 1.0.3).
* Tests : 7 tests Lua du mode autonome ; exécution sur le **vrai LÖVE 11.5** avec un exécutable
  fusionné comme `Balatro.exe` (5 scénarios, `tests/standalone/run_love_standalone.sh`).

## 1.0.3 — 2026-10-18

### Ajouté
* **Installateur-diagnostic Windows** livré à la racine de l'archive : `INSTALLER_COPILOT.bat`
  (vérifie et répare) et `DIAGNOSTIC_COPILOT.bat` (vérifie seulement). Il suit toute la chaîne de
  chargement : dossier du jeu trouvé via Steam (bibliothèques sur d'autres disques comprises),
  options de lancement `--vanilla`, Lovely (`winmm.dll` absent après une réinstallation du jeu,
  ancien `version.dll`/`dwmapi.dll`), Steamodded (absent, rangé trop bas, en double, désactivé),
  copilote (copies multiples, zip, désactivation), puis lance le jeu et lit le journal de Lovely
  pour dire ce qui s'est réellement chargé. Rapport sur le Bureau. Aucun téléchargement, aucune
  suppression : les anciennes copies sont déplacées, les fichiers modifiés sont sauvegardés.
* `tools/smods_loader_check.lua` exécute aussi le chargeur des Steamodded **récents**
  (`src/preflight/loader.lua`).
* Tests de l'installateur : 9 scénarios, 53 vérifications (`tests/installer/test_installer.ps1`),
  compatibilité Windows PowerShell 5.1 vérifiée par analyse statique.

### Corrigé (découvert en exécutant le chargeur récent)
* Un Steamodded récent désactive durablement un mod présent en deux exemplaires en écrivant le
  nom de son dossier dans `Mods\lovely\blacklist.txt` : le copilote pouvait rester désactivé
  même après suppression du doublon. L'installateur le détecte et le réactive ; documenté.

## 1.0.2 — 2026-10-13

### Corrigé
* **Documentation d'installation erronée** : elle affirmait qu'une archive `.zip` déposée telle
  quelle dans `Mods` était chargée. C'est faux avec les anciens Steamodded (vérifié en exécutant
  le vrai chargeur de `1.0.0~BETA-0509c`) : le mod est alors **ignoré sans aucun message**. Il en
  va de même si le dossier est rangé trop profond (par exemple dépôt GitHub extrait deux fois).
  INSTALL.md, LISEZMOI.txt, README et TROUBLESHOOTING.md indiquent désormais l'emplacement exact,
  les pièges vérifiés et une commande PowerShell pour localiser les copies du mod.
* **Bandeau de démarrage** : le compte à rebours (15 s) ne commence qu'après l'intro du jeu, pour
  qu'il soit encore visible au menu principal.
* Installation de Lovely/Steamodded alignée sur le guide officiel de Steamodded et sur le lanceur
  de Balatro Multiplayer ; diagnostic « aucun mod ne marche » (Lovely absent du dossier du jeu
  après une réinstallation ou un déplacement du jeu).

### Ajouté
* `tools/smods_loader_check.lua` : exécute le vrai chargeur d'un Steamodded ancien sur un dossier
  `Mods` pour vérifier qu'il trouve et démarre le copilote (8 dispositions vérifiées, TESTS.md).

## 1.0.1 — 2026-10-13

### Corrigé / ajouté
* **Bandeau de démarrage visible** : « actif » pendant 10 s au lancement, ou **message d'erreur
  en rouge** si le démarrage échoue (auparavant l'erreur n'allait que dans le journal et rien ne
  s'affichait au menu principal).
* **Compatibilité avec les anciens Steamodded** (vérifiée sur le code de `1.0.0~BETA-0509c`, mai
  2025) : ces versions n'envoient pas les événements de partie aux mods ; les actions (main jouée,
  défausse, achat, vente, relance, paquet, blinde passée) sont désormais reconstruites en
  comparant les états successifs. Bascule automatique, sans double comptage si les événements
  natifs existent.

## 1.0.0 — 2026-10-13

Première version complète.

### Ajouté
* Audit de l'environnement et vérification des API Steamodded/Lovely dans leurs sources.
* Lecteur d'état non intrusif (connu / déduit / inconnu ; ordre du deck jamais lu ; cartes face
  cachée masquées ; nombres Talisman pris en charge).
* Moteur de score : pipeline Steamodded complet, 150 jokers vanilla, boss, Plasma, Observatory,
  aléas énumérés exactement ou par Monte-Carlo reproductible.
* Probabilités exactes de complétion des défausses ; simulation de manche avec politique explicite.
* Évaluation exacte de la sélection en cours, contrôlée par l'identification de main du jeu.
* Boutique : notes /100, effet sur la prochaine blinde et le boss, ventes, remplacements, relance
  sur le pool réel, intérêts perdus ; paquets ; choix de blinde (passer ou jouer).
* Synergies : contributions mesurées, ordre optimal des jokers, adéquation au build.
* Gestion adaptative du risque (pondérations continues selon le danger).
* Apprentissage : journal des parties, calibration validée dans le temps, croissance de puissance,
  contributions des jokers, multiplicateurs appris des jokers moddés, bilan de fin de partie.
* Persistance robuste (A/B + sommes de contrôle, migrations, quarantaine), export, import,
  réinitialisation.
* Interface : panneau, résumé compact, badges, alertes dédupliquées, français et anglais.
* 169 tests automatisés (unitaires, référence, apprentissage, intégration, performance) et
  harnais LÖVE réel.
