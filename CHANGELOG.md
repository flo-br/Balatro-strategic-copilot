# Historique des versions

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
