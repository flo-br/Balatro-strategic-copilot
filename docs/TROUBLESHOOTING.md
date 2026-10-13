# Dépannage

## Premier réflexe : le bandeau de démarrage (version 1.0.1+)

Au lancement du jeu, un bandeau s'affiche en haut de l'écran pendant l'intro, puis 15 secondes
au menu principal (1.0.2+) :
* **vert « … actif — touche C : panneau »** : le mod fonctionne. Au menu principal il n'affiche
  rien d'autre (sauf l'historique avec `C`) ; les conseils apparaissent **pendant une partie**
  (résumé en haut à droite, `C` pour le panneau complet) ;
* **rouge « erreur au démarrage »** : le message indique la cause ; le détail complet est dans le
  journal de Lovely ;
* **aucun bandeau** : le mod n'est pas chargé du tout. D'abord vérifier que **les mods en
  général** se chargent : fenêtre « Lovely x.x.x » au lancement et bouton *Mods* au menu. Sans
  eux, c'est Lovely ou Steamodded qui manque (souvent après une réinstallation du jeu) : voir
  INSTALL.md, étape 2. Avec eux, c'est presque toujours un problème d'emplacement du copilote : `.zip` déposé sans être extrait, dossier rangé trop profond, ou dépôt
  GitHub extrait deux fois (voir « Pièges vérifiés » dans [INSTALL.md](INSTALL.md)). Vérifier :
  ```
  Get-ChildItem "$env:APPDATA\Balatro\Mods" -Recurse -Filter BalatroStrategicCopilot.json | Select-Object -ExpandProperty FullName
  ```
  (PowerShell) doit afficher exactement
  `…\AppData\Roaming\Balatro\Mods\BalatroStrategicCopilot\BalatroStrategicCopilot.json`, une seule fois.

## Trouver le journal

`%AppData%\Balatro\Mods\lovely\log\` : ouvrir le fichier le plus récent et chercher
`BSCopilot` ou `BalatroStrategicCopilot`. Une ligne `ready (update=true draw=true …)` signifie que
le mod a démarré. Le journal propre au mod est `%AppData%\Balatro\BSC\logs\bsc.log`.

| Symptôme | Cause probable | Solution |
|---|---|---|
| **Aucun mod ne marche** (Multiplayer non plus), pas de fenêtre « Lovely », pas de bouton *Mods* | Lovely absent du dossier du jeu : jeu réinstallé ou déplacé sur un autre disque (le dossier `Mods` reste, `winmm.dll` disparaît), ou `winmm.dll` supprimé par l'antivirus | réinstaller Lovely dans le **nouveau** dossier du jeu : relancer le lanceur Balatro Multiplayer, ou copier `winmm.dll` à côté de `Balatro.exe` (INSTALL.md, étape 2) |
| Fenêtre « Lovely » présente mais pas de bouton *Mods* | Steamodded mal placé | `Mods` doit être dans `%AppData%\Balatro\` (pas dans le dossier du jeu), avec `Mods\smods\<fichiers>` |
| Aucun bandeau, archive `BalatroStrategicCopilot-*.zip` dans `Mods` | Steamodded ancien (ex. `1.0.0~BETA-0509c`) : il ignore les `.zip` (vérifié avec son chargeur) | extraire l'archive et ne garder que le dossier `BalatroStrategicCopilot` ; supprimer le `.zip` |
| Aucun bandeau, le `.json` est 3 dossiers sous `Mods` (ex. `Mods\X\X\BalatroStrategicCopilot\`) | Steamodded ne cherche les mods qu'à 2 niveaux sous `Mods` | déplacer le dossier `BalatroStrategicCopilot` directement dans `Mods` |
| Aucun bandeau, mod absent de *Mods* | dossier mal placé ou dossier en double | `%AppData%\Balatro\Mods\BalatroStrategicCopilot\BalatroStrategicCopilot.json` doit exister, **une seule copie** du mod dans `Mods` (les anciens Steamodded refusent les doublons : erreur `dupe`) |
| Mod présent dans *Mods* mais désactivé | interrupteur du mod sur « off » | l'activer dans *Mods*, puis redémarrer |
| Bandeau « détection par état (Steamodded ancien) » | Steamodded antérieur au support des événements de mod | normal : tout fonctionne ; mettre Steamodded à jour reste conseillé si vos autres mods le permettent |
| Le mod n'apparaît pas dans *Mods* | dossier mal placé (un niveau de trop) | `%AppData%\Balatro\Mods\BalatroStrategicCopilot\BalatroStrategicCopilot.json` doit exister |
| « Missing dependency Steamodded » | Steamodded absent ou trop ancien | installer une version récente de Steamodded |
| Aucun panneau en partie | touche différente, ou résumé compact désactivé | appuyer sur `C` ; vérifier `ui.show_compact` et `keys.panel` dans la config |
| « Analyse en cours… » longtemps | build très chargé, budget de calcul faible | augmenter `compute.budget_ms` (ex. 6) ou réduire `compute.rollouts` |
| Badges décalés par rapport aux cartes | échelle d'affichage différente (non vérifiable hors jeu) | désactiver les badges (`B` ou config) : le panneau contient les mêmes informations ; signaler le problème avec une capture |
| « Compatibilité partielle : … » | joker/carte d'un autre mod | normal : la valeur est approchée, pas inventée |
| « Module désactivé après erreurs » | erreur répétée dans une analyse | consulter `%AppData%\Balatro\BSC\logs\bsc.log` ; le reste du mod continue de fonctionner |
| Scores « exacts » remplacés par « ≈ » | deux discordances entre score prédit et score réel dans la session | probablement un mod qui change les règles ; détail dans le log (`exact score mismatch`) |
| Données d'apprentissage perdues | fichier corrompu | la dernière copie valide est restaurée automatiquement ; les fichiers invalides sont dans `BSC\corrupt\` et les copies de sécurité dans `BSC\backups\` |
| Je veux repartir de zéro | — | Config → *Réinitialiser l'apprentissage* (deux clics), ou supprimer `BSC\` jeu fermé |

## Journal technique

`%AppData%\Balatro\BSC\logs\bsc.log` (taille bornée, une rotation conservée). Niveau réglable par
`log.level` : `off`, `error`, `warn`, `info` (défaut), `debug`, `trace`. Les messages sont aussi
envoyés à la console de Steamodded/Lovely.

## Signaler un problème

Joindre : versions (affichées dans *Mods*), extrait de `bsc.log`, capture d'écran, et si possible
l'export de données (Config → *Exporter les données*).
