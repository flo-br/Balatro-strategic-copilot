# Balatro Strategic Copilot

Mod Steamodded pour **Balatro** qui agit comme un copilote stratégique : il lit l'état de la
partie, calcule les scores exacts, les probabilités, évalue la boutique, conseille mains et
défausses, et **apprend de vos parties**. **Il ne joue jamais à votre place** : il n'effectue
aucune action (sélection, jeu, défausse, achat, vente, relance).

> Statut : version 1.1.0. Développée **hors du jeu** (aucune installation de Balatro n'était
> disponible dans l'environnement de développement), puis essayée par l'utilisateur dans le vrai
> jeu (mode copier-coller). Validée par des tests automatisés, un environnement Balatro/Steamodded
> simulé, le vrai runtime LÖVE 11.5 et des parties complètes simulées ([entraînement](docs/TRAINING.md)).
> Voir [Limites](docs/LIMITATIONS.md) et [Tests](docs/TESTS.md).

![Panneau en phase de main](docs/img/overlay_hand.png)

## Fonctionnalités

| Domaine | Ce que fait le copilote |
|---|---|
| Mains | Évalue les 218 combinaisons jouables (≤ 5 cartes parmi 8), score **exact** quand tout est déterministe, distribution énumérée des aléas (Lucky, Misprint, Bloodstone, Space Joker…), probabilité de réussite immédiate ; chaque main est évaluée **dans son meilleur ordre** et l'**ordre des cartes** est affiché (JOUER 1, 2, 3…, GARDER 1, 2…) quand il change le score (Photograph, Hanging Chad, verre, polychrome, Baron + Shoot the Moon) |
| Défausses | Cibles (couleur, suite, brelan, full…) avec **probabilité exacte** de complétion sur la composition connue du deck |
| Manche | Probabilité de battre la blinde pour chaque action candidate, par simulation de la fin de manche avec une politique explicite |
| Sélection | Score exact des cartes que **vous** sélectionnez, en direct, contrôlé par l'identification de main du jeu |
| Boutique | Note stratégique /100, effet mesuré sur la prochaine blinde et le boss, coûts et intérêts perdus, ventes, remplacements, intérêt d'une relance (pool réel de jokers) |
| Synergies | Contribution **mesurée** de chaque joker, ordre optimal des jokers, et les **builds des meilleurs joueurs** (Baron + Mime, Photograph + Hanging Chad, Triboulet, Canio, couleur, verre, acier…) : synergies et anti-synergies en boutique, pièces à chercher, cibles des tarots selon le build |
| Blindes | Prochaine blinde et boss simulés avec leurs effets (malus de couleur, The Needle, The Water, The Psychic, Cerulean Bell…), **passage d'une blinde** calculé tag par tag contre son coût réel (récompense, mains, intérêts, boutique) |
| Risque | Pondérations qui dépendent continûment du danger (survie quand la situation est critique, investissement quand elle est confortable) |
| Effets | Améliorations, éditions, sceaux et autocollants des jokers affichés et pris en compte (garder l'acier et l'or en main, défausser le sceau violet, jamais vendre un éternel…) |
| Plan de partie | Leçons des meilleurs joueurs ([sources](docs/PRO_LESSONS.md)) : main principale, ×Mult attendus par ante, argent au-delà des intérêts réinvesti, boss à préparer |
| Apprentissage | Journal local des parties, calibration validée des probabilités, croissance de puissance, contributions des jokers, bilan après chaque partie qui cherche **pourquoi** le build n'a pas suffi (jamais « malchance ») ; après chaque défaite, le copilote **essaie un changement** de son développement (urgence des ×Mult, achats, épargne, sécurité, passages) selon la cause qui revient dans vos défaites, et ne le **garde que si les parties suivantes ne sont pas moins bonnes** ; chaque étape est expliquée dans le bilan |
| Mises et decks | Mises 1 à 8 lues dans le jeu (Small Blind sans récompense, blindes plus grosses, autocollants éternel / périssable / **location** comptée sur toute sa durée, une défausse de moins) : ×Mult attendus plus tôt aux mises verte et violette, joker loué revendu dès qu'il n'est plus nécessaire ; decks de départ pris en compte via l'état réel (cartes, bons, consommables). **1.0.10** : règles des meilleurs joueurs à partir de la mise verte (presque jamais passer une blinde, pas d'épargne sans ×Mult à l'ante 4 ni sans plateau vraiment sûr, une seule location), mesurées sur le simulateur ([résultats](docs/TRAINING.md)) |
| 1.1 | Tout remis en question et mesuré sur le simulateur (10 variantes) : « 25 $ d'abord » coupé par défaut, carte gratuite prise dans les paquets, éternel Négatif non pénalisé ; contre la 1.0.14 sur 72 parties : **9 victoires au lieu de 4**, +0,80 ± 0,66 blinde par partie (tendance, dans la marge d'erreur) — [résultats](docs/TRAINING.md) |
| Compatibilité | Détection des mods, éléments inconnus signalés comme « partiel », contrôle croisé avec le jeu, dégradation contrôlée |

## Installation rapide (Windows)

**Méthode sans programme (recommandée, 1.0.4+)** — ni Lovely, ni Steamodded, ni script, ni DLL ;
fonctionne aussi sur un PC protégé (contrôle parental, antivirus strict) :

1. Extraire l'archive `BalatroStrategicCopilot-1.1.0.zip`.
2. Copier le **contenu** du dossier `COPIER_DANS_AppData_Balatro` (`main.lua` + `Mods`) dans
   `%AppData%\Balatro\` (touche Windows + R, `%AppData%\Balatro`).
3. Lancer Balatro : bandeau vert « … actif — touche C : panneau (mode autonome, sans Steamodded) ».

Balatro tourne sur LÖVE 11, qui lit `main.lua` d'abord dans le dossier de sauvegarde : le
`main.lua` fourni exécute celui du jeu, inchangé, puis démarre le copilote (détails et limites :
[docs/INSTALL.md](docs/INSTALL.md)). Désinstaller : supprimer `%AppData%\Balatro\main.lua`.

**Avec Lovely + Steamodded** : copier le dossier `BalatroStrategicCopilot` dans
`%AppData%\Balatro\Mods\` (de sorte que `Mods\BalatroStrategicCopilot\BalatroStrategicCopilot.json`
existe ; une archive `.zip` déposée telle quelle est ignorée par les anciens Steamodded). L'archive
`BalatroStrategicCopilot-1.1.0-installateur.zip` contient `INSTALLER_COPILOT.bat`, qui vérifie et
répare toute la chaîne (dossier du jeu, Lovely, Steamodded, copilote) puis confirme que tout s'est
chargé. Un **bandeau vert « actif »** s'affiche au lancement ; **aucun bandeau = mod non trouvé**
([pièges vérifiés](docs/INSTALL.md)).

Désinstallation : supprimer `%AppData%\Balatro\main.lua` (mode autonome) et
`%AppData%\Balatro\Mods\BalatroStrategicCopilot` (et, si souhaité,
les données apprises `%AppData%\Balatro\BSC\`). Détails dans [docs/INSTALL.md](docs/INSTALL.md).

## Utilisation

| Touche (configurable) | Action |
|---|---|
| `C` | ouvrir / fermer le panneau stratégique |
| `V` | afficher / masquer les alternatives et les détails |
| `B` | afficher / masquer les badges sur les cartes |
| `X` | **« Mon choix »** : votre choix à la place du conseil, avec la raison et une explication (ci-dessous) |
| `O` | **« Je joue, tu apprends »** : plus aucun conseil, vous jouez, le copilote apprend de ce que vous faites (ci-dessous) |

### Une étape à la fois (« À FAIRE »)

Le copilote indique **une seule action à faire maintenant**, avec une étiquette au-dessus de ce
qu'il faut toucher ; dès que vous l'avez faite, il recalcule et montre la suivante :

| Étiquette | Où | Quand |
|---|---|---|
| **JOUER** / **DÉFAUSSER** | sur les cartes de la main | la meilleure action de la manche (aussi avec des cartes face cachée, ex. boss The House) ; **IMPOSÉE** sur la carte que Cerulean Bell sélectionne d'office (elle part avec le jeu ou la défausse) |
| **JOUER 1, 2, 3…** / **GARDER 1, 2…** | sur les cartes de la main | quand l'ordre des cartes change le score : glissez les cartes jouées (et les cartes gardées en main) dans l'ordre des numéros, de gauche à droite ; le gain est écrit dans le panneau |
| **À PRENDRE** | sur l'objet de boutique ou la carte du paquet | le meilleur achat rentable (avec sa note /100) |
| **À VENDRE** | sur un joker ou un consommable | pour remplacer un joker par un meilleur, faire de la place, gagner de l'argent avec un joker inutile, ou un effet de vente (Luchador contre un boss dangereux, Invisible Joker prêt) |
| **RELANCER** | sur le bouton de relance | relance gratuite, meilleure boutique assez probable, ou une relance avant de partir (habitude des meilleurs joueurs), sans casser l'épargne des intérêts |
| **BLINDE SUIVANTE** | sur le bouton pour quitter la boutique | quand plus rien n'est rentable, ou pour garder 25 $ d'intérêts à partir de l'ante 2 si la suite est sûre (« 25 $ d'abord » dès l'ante 1 : option, ci-dessous) |
| **JOUER** / **PASSER** | sur les boutons du choix de blinde | passer quand le tag vaut plus que ce que coûte le passage (récompense, mains, intérêts, boutique) et que la blinde suivante reste sûre sans boutique ; détail affiché dans le panneau ; seul le choix définitif s'affiche |
| **UTILISER** + **CIBLE** | sur un consommable (+ les cartes à sélectionner) | planètes, argent (Hermit, Temperance), tarots et spectrales sur les cartes visées ; **Death** : DEVIENT (gauche) et MODÈLE (droite), avec la consigne de glisser la carte à gauche si besoin ; Hanged Man : À DÉTRUIRE |
| **PASSER** | sur le bouton du paquet | quand aucune carte du paquet n'améliore le jeu ; depuis la 1.1, avec un emplacement vide, un joker correct (jamais éternel) ou une planète est pris plutôt que rien, puisqu'il est gratuit |
| **1, 2, 3…** | sous les jokers | seulement quand l'ordre actuel n'est pas le bon (un ×Mult avant un +Mult) : glissez les jokers pour suivre les numéros |

Le panneau se place sous la zone des consommables pour ne pas cacher l'étiquette UTILISER. Les
achats suivent une discipline inspirée des meilleurs joueurs (paquets souvent achetés, intérêts
préservés, une relance avant de quitter la boutique, blindes passées pour les bons tags) ; seuils
réglables dans `config.lua`, section `advice` (détails : [docs/MATHS.md](docs/MATHS.md) §7–8).

La ligne « À FAIRE » est aussi la première du résumé compact, avec la probabilité qui justifie le
choix (visible par défaut ; `V` masque les détails et alternatives). Si l'étiquette d'un bouton
n'apparaît pas, l'étape reste écrite dans le résumé (voir [docs/LIMITATIONS.md](docs/LIMITATIONS.md)).

Panneau fermé, un résumé compact reste visible. Au menu principal, `C` affiche l'**historique** :
dernier bilan de partie, taux de victoire avec intervalle, calibration et précision des scores.
Les options (badges, alertes, apprentissage, export, import, réinitialisation) sont dans
*Mods → Balatro Strategic Copilot → Config*.

### « Je joue, tu apprends » (touche `O`, 1.0.14)

Appuyez sur `O` : le copilote **n'affiche plus aucun conseil** (ni étiquettes, ni « À FAIRE », ni
alertes d'achat) et vous jouez comme d'habitude. Il continue d'analyser chaque situation en
silence et compare **chacune de vos actions** au conseil qu'il aurait donné pour exactement le
même état du jeu :

* en boutique et dans les paquets, ce que vous achetez, prenez, vendez, si vous relancez ou partez
  sans acheter : quand c'est différent de son conseil, il **apprend** (l'objet que vous prenez +2
  points de note, celui qu'il aurait pris −2 ; partir avec l'argent ou relancer quand il conseillait
  l'inverse règle son habitude d'épargne). C'est la moitié du poids d'une correction avec `X`, dans
  les mêmes limites (±15 par objet), puisque vous ne donnez pas de raison ;
* vos jeux, défausses, consommables et blindes passées sont **comptés** (combien de fois vous
  faites comme lui), sans en tirer de règle pour l'instant.

Une ligne « MODE APPRENTISSAGE — vous jouez, j'observe : 12 choix vus, 7 comme mon conseil,
5 appris » reste visible ; un message dit ce qui est appris (« Hologram +2 · The Duo −2 »). Chaque
leçon est écrite dans `mes_choix.txt` (marquée « observé ») et le bilan de fin de partie les liste.
`O` à nouveau : les conseils reviennent, avec ce qu'il a appris. Le mode reste actif d'une partie à
l'autre jusqu'à ce que vous le coupiez ; `Suppr` dans la boîte `X` efface tout ce qui a été appris.

![Je joue, tu apprends](docs/img/overlay_observe.png)

### « 25 $ d'abord » (1.0.13, option coupée par défaut depuis la 1.1)

**1.1 : coupée par défaut.** Mesurée sur le simulateur, la couper fait mieux ou autant à chaque
mise essayée (mise blanche : 7 victoires sur 12 au lieu de 4 ; mise noire : 2 sur 20 au lieu de 0 ;
mise orange : pareil) : l'argent épargné arrive trop tard et les premiers jokers manquent
([docs/TRAINING.md](docs/TRAINING.md), « Résultats 1.1 »). Pour la remettre :
`rush_cap = true` dans `config.lua`, section `advice`.

Votre stratégie : en début de partie (antes 1 à 3), tant que vous avez moins de 25 $, l'argent
va aux 25 $ qui rapportent 5 $ d'intérêts à chaque manche. Le copilote ne fait acheter que ce
dont la prochaine blinde a besoin pour rester sûre (et le boss, dès les boutiques qui le
précèdent s'il paraît difficile), en choisissant seulement ce qui augmente vraiment les chances
de passer ; un objet très fort (note ≥ 75) ou un joker d'argent qui se rembourse en 3 manches
(Golden Joker, Rocket…) reste autorisé. Sous 25 $ : pas de paquet, pas de relance, pas de joker
pris « pour remplir ». L'étape le dit : « 25 $ d'abord : 14 $ sur 25… ». Une fois les 25 $
atteints, le copilote reprend sa discipline habituelle (garder 25 $, dépenser l'excédent).
Réglages dans `config.lua` (`rush_cap = true` l'active). Mesures sur le simulateur :
[docs/TRAINING.md](docs/TRAINING.md), « Résultats 1.0.13 » et « Résultats 1.1 ».

### Éditions et autocollants des jokers

| | Effet dans le jeu | Ce que fait le copilote |
|---|---|---|
| **Brillant** | +50 jetons | compté dans le score simulé de chaque main et dans la note d'achat |
| **Holographique** | +10 Mult | idem |
| **Polychrome** | ×1,5 Mult | idem (compté comme un ×Mult par le plan de partie) |
| **Négatif** | +1 emplacement de joker | il ne prend pas de place ; un éternel Négatif n'est pas pénalisé (1.1) |
| **Éternel** (mise noire et plus) | ni vendu ni détruit | jamais conseillé à la vente ; sur un joker « temporaire » (+Mult, +jetons, argent, utilitaire), risque dans la note à partir de l'ante 3 aux mises élevées (il occupera une place jusqu'à la fin) ; jamais pris gratuitement dans un paquet |
| **Périssable** (mise orange et plus) | inactif après 5 manches | risque selon les manches restantes, revendu une fois expiré |
| **Location** (mise or) | 1 $ puis 3 $ par manche | loyer compté sur sa durée, une seule location avant l'ante 6, revendue dès qu'elle n'est plus utile |

Les éternels achetés tôt qui restent jusqu'à la fin sont un vrai problème en mise orange (45 % des
jokers restants en fin de partie simulée). Les refuser plus tôt a été mesuré : on meurt plus tôt
faute de jokers ([docs/TRAINING.md](docs/TRAINING.md), « Résultats 1.1 »).

### « Mon choix » : apprendre de vos décisions (touche `X`, 1.0.12)

Vous n'êtes pas d'accord avec le conseil ? **Sélectionnez dans le jeu** (clic, comme d'habitude)
ce que vous choisiriez — un joker ou un paquet de la boutique, des cartes de la main, un
consommable — puis appuyez sur `X`. Une boîte s'ouvre : un chiffre pour votre choix (acheter,
vendre, jouer ces cartes, défausser, partir, relancer…), un chiffre pour la raison (synergie,
×Mult, garder l'argent, la main principale, le boss, l'avenir, le risque…), puis une explication
libre (facultative, 200 caractères) et Entrée.

![« Mon choix »](docs/img/overlay_choice.png)

* Le copilote **ne fait rien dans le jeu** : il lit seulement ce que vous avez sélectionné ; vous
  achetez, jouez ou vendez vous-même. Pendant la saisie, **aucune touche n'atteint le jeu**
  (taper « r » ne relance pas la partie).
* Ce qu'il apprend est **borné et visible** : l'objet choisi gagne 4 points de note par correction
  (15 au plus, et 8 de plus au plus pour son type : joker ×Mult, paquet Céleste…), celui qu'il
  conseillait en perd autant ; les raisons ajustent quelques poids (synergies ×1,5 au
  plus, risque, intérêts, urgence des ×Mult…). La raison apparaît dans les notes (« vos choix :
  +4 ») et le panneau de la boutique résume ce qui a changé.
* `Suppr` dans la boîte efface tout ce qui a été appris de vos choix. Le bilan de fin de partie
  liste vos corrections ; elles sont aussi écrites, lisibles, dans `%AppData%\Balatro\BSC\mes_choix.txt`.
* Ces préférences ne s'appliquent qu'à votre jeu : le simulateur d'entraînement ne les utilise pas
  (leur effet sur vos parties ne peut donc pas être mesuré à l'avance).

### Synergies (1.0.12)

Le copilote connaît **373 synergies joker + joker et 111 synergies joker + carte, bon ou
paquet** (Baron + Mime, Blueprint + Triboulet, Steel Joker + The Chariot, Constellation + les
planètes, Hologram + paquet Standard, Yorick + Wasteful…), des anti-synergies (Vampire et les
cartes améliorées, Erosion et les cartes ajoutées…), 26 builds, et des règles générales (même
main, même couleur, copies). Le panneau indique les **« Synergies à chercher »** pour vos jokers
et chaque note dit la synergie qui la porte. Comme le moteur de score mesure déjà ce que vos
jokers font ensemble maintenant, une synergie ne s'ajoute à la note que pour ce que cette mesure
ne voit pas encore (un joker qui grandit, rapporte de l'argent, ajoute des cartes…) : mesuré sur
60 parties simulées, +0,22 ± 0,21 blinde par partie (compter tout deux fois faisait −0,33).
Liste complète : [docs/SYNERGIES.md](docs/SYNERGIES.md).

![Synergies à chercher](docs/img/overlay_synergies.png)

### Lire les indicateurs

* **Probabilité** (`Victoire blinde : 87 %`) : probabilité estimée d'atteindre un objectif
  défini, toujours accompagnée de sa **méthode** (calcul exact, énumération, simulation n=…)
  et d'un **niveau de confiance**. Une simulation n'affiche jamais « 100 % » mais sa borne
  (`≥ 94 %`).
* **Note stratégique** (`82/100`) : sert à **comparer** des options, ce n'est **pas** une
  probabilité.
* **Couleurs** vert / orange / rouge toujours doublées d'un symbole (`+` `~` `-`) pour les
  joueurs qui distinguent mal les couleurs.
* `≈` et « partiel » : un élément (joker moddé, carte cachée…) n'a pas pu être analysé.

Explications détaillées : [docs/PERCENTAGES.md](docs/PERCENTAGES.md).

![Étape en main : jouer, et ordre des jokers à corriger](docs/img/overlay_hand.png)

![Death : la carte qui devient et le modèle, panneau sous les consommables](docs/img/overlay_death.png)

![Effets des cartes en main et autocollants des jokers](docs/img/overlay_effects.png)

![Panneau en boutique](docs/img/overlay_shop.png)

![Panneau au choix de la blinde](docs/img/overlay_blind.png)

![Boss The House : toutes les cartes face cachée](docs/img/overlay_house.png)

![Boss Cerulean Bell : la carte imposée part avec le jeu](docs/img/overlay_bell.png)

![Ordre des cartes : Photograph + Hanging Chad, le Roi joué en premier](docs/img/overlay_order.png)

*Captures produites avec le vrai runtime LÖVE 11.5 sur un état de jeu simulé (cartes factices) :
elles montrent le rendu du mod, pas l'apparence du jeu.*

## Documentation

* [Audit de l'environnement](docs/AUDIT.md) — ce qui a été vérifié, et comment
* [Architecture et cahier des charges](docs/ARCHITECTURE.md)
* [Description des modules](docs/MODULES.md)
* [Installation / désinstallation / mise à jour](docs/INSTALL.md)
* [Pourcentages et notes affichés](docs/PERCENTAGES.md)
* [Méthodes mathématiques et limites des estimations](docs/MATHS.md)
* [Leçons des meilleurs joueurs appliquées](docs/PRO_LESSONS.md) (recherches sourcées : [générale](docs/PRO_LESSONS_SOURCES.md), [blindes passées](docs/PRO_SKIPS_SOURCES.md), [synergies des builds](docs/PRO_SYNERGIES_SOURCES.md))
* [Entraînement sur des parties simulées](docs/TRAINING.md)
* [Système d'apprentissage, export, réinitialisation](docs/LEARNING.md)
* [Tests et résultats](docs/TESTS.md)
* [Limites connues](docs/LIMITATIONS.md)
* [Dépannage](docs/TROUBLESHOOTING.md)
* [Historique des versions](CHANGELOG.md)

## Dépendances

| Composant | Version | Rôle |
|---|---|---|
| Balatro | 1.0.1 (série 1.0.1x, lue via `G.VERSION`) | jeu |
| Lovely | ≥ 0.9.0 (dépendance de Steamodded) | injecteur |
| Steamodded | ≥ `1.0.0~BETA-0301a` déclaré ; API vérifiées sur `26.1002.0` et `1.0.0~BETA-0509c` (mai 2025, sans événements de mod : détection par état) | chargeur de mods |

Aucune autre dépendance, aucune connexion réseau, aucune télémétrie. Le mod n'utilise
**aucun patch Lovely** et ne modifie aucun fichier du jeu ni ses sauvegardes.

## Développement

```bash
luajit tests/run.lua            # suite complète (LuaJIT, comme le jeu)
lua5.1 tests/run.lua            # même suite sous Lua 5.1
luajit tests/run.lua score      # filtre par nom de fichier
python3 tools/build.py          # paquet dist/BalatroStrategicCopilot-<version>.zip
luajit tools/smods_loader_check.lua <sources_steamodded> <dossier_Mods>  # vrai chargeur Steamodded
pwsh -File tests/installer/test_installer.ps1 -Zip dist/BalatroStrategicCopilot-<version>-installateur.zip
tests/standalone/run_love_standalone.sh dist/BalatroStrategicCopilot-<version>.zip   # mode autonome, vrai LÖVE
xvfb-run -s "-screen 0 1600x900x24" love tools/love_harness "$(pwd)" hand   # rendu réel LÖVE
```
