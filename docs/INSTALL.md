# Installation, mise à jour et désinstallation (Windows)

## 1. Prérequis

| Composant | Où le trouver | Remarque |
|---|---|---|
| Balatro (Steam, Windows) | Steam | version stable 1.0.1x |
| Lovely | `lovely-x86_64-pc-windows-msvc.zip` sur la page *Releases* de `ethangreen-dev/lovely-injector` | injecteur utilisé par Steamodded |
| Steamodded | page *Releases* de `Steamodded/smods` | chargeur de mods |

Le copilote est un mod Steamodded comme Balatro Multiplayer : **si Multiplayer fonctionne, le
copilote peut fonctionner** ; si Multiplayer ne marche plus, le problème est en amont (Lovely ou
Steamodded) et aucun mod ne peut se charger.

**Test rapide** : en lançant Balatro par Steam, une **deuxième fenêtre noire « Lovely x.x.x »**
doit s'ouvrir, puis le menu principal doit afficher un bouton **Mods**. Si les deux sont là,
passez directement à l'étape 3.

## 2. Installer (ou réinstaller) Lovely et Steamodded

Deux façons, au choix :

**A. Le lanceur de Balatro Multiplayer** (méthode recommandée par Multiplayer) : télécharger le
*Balatro Multiplayer Launcher* (Windows) depuis balatromp.com, le lancer et suivre ses
instructions ; il installe Lovely, Steamodded et Multiplayer. Puis passer à l'étape 3.

**B. À la main** (guide officiel de Steamodded, docs.smods.dev, que Multiplayer cite pour
l'installation manuelle) :
1. Dans Steam : clic droit sur Balatro → *Gérer* → *Parcourir les fichiers locaux*. C'est le
   **dossier du jeu** (celui de `Balatro.exe`). Si l'antivirus supprime `winmm.dll`, ajouter une
   exclusion pour ce dossier.
2. Télécharger `lovely-x86_64-pc-windows-msvc.zip` (page *Releases* de
   `ethangreen-dev/lovely-injector`) et copier le `winmm.dll` qu'il contient **dans le dossier du
   jeu**. Si un ancien `version.dll` (Lovely ≤ 0.9.0) s'y trouve, le supprimer.
3. Lancer Balatro par Steam : la fenêtre « Lovely x.x.x » doit apparaître. Sinon `winmm.dll`
   n'est pas à côté de `Balatro.exe`.
4. Télécharger Steamodded (*Source code (zip)* de la dernière version, release.smods.dev),
   l'extraire et placer **le** dossier qu'il contient dans `%AppData%\Balatro\Mods\`
   (résultat `Mods\smods\<fichiers>`, pas `Mods\smods\smods\`).
5. Relancer : le menu principal affiche un bouton *Mods*.

**Le dossier du jeu et le dossier `Mods` sont deux endroits différents.** `Mods` est dans
`%AppData%\Balatro\` et ne bouge pas quand on réinstalle le jeu ; `winmm.dll` est dans le dossier
du jeu et **disparaît si le jeu est réinstallé ou déplacé sur un autre disque**. Dans ce cas les
mods sont toujours là mais plus aucun ne se charge : refaire l'étape 2 (A ou B) pour le nouveau
dossier du jeu.

## 3. Installer Balatro Strategic Copilot

**Seul le dossier `BalatroStrategicCopilot` va dans `Mods`** (celui qui contient directement
`BalatroStrategicCopilot.json` et `main.lua`). Le reste du dépôt GitHub (`docs`, `tests`,
`tools`, `README.md`…) ne sert pas au jeu.

1. Fermer le jeu.
2. Supprimer toute ancienne copie du mod dans `%AppData%\Balatro\Mods\` (dossier ou `.zip`).
3. Ouvrir l'archive `BalatroStrategicCopilot-1.0.2.zip` (ou le zip téléchargé depuis GitHub) et
   **glisser le dossier `BalatroStrategicCopilot` qu'elle contient** dans `%AppData%\Balatro\Mods\`.
4. Vérifier que ce fichier existe **exactement** à cet endroit :
   ```
   %AppData%\Balatro\Mods\BalatroStrategicCopilot\BalatroStrategicCopilot.json
   ```
   Arborescence attendue :
   ```
   %AppData%\Balatro\Mods\
     smods-main\                   (Steamodded, le nom peut varier)
     BalatroStrategicCopilot\
       BalatroStrategicCopilot.json
       main.lua
       config.lua
       LISEZMOI.txt
       src\core\ src\engine\ src\game\ src\io\ src\learning\ src\model\ src\ui\
   ```
5. Lancer le jeu : un bandeau vert « Balatro Strategic Copilot 1.0.2 actif » s'affiche en haut de
   l'écran pendant l'intro puis 15 secondes au menu principal. Dans *Mods*, « Balatro Strategic
   Copilot » apparaît. En partie, le résumé compact s'affiche en haut à droite ; `C` ouvre le
   panneau complet.

### Pièges vérifiés sur le chargeur de Steamodded

Vérifié en exécutant le vrai chargeur de Steamodded `1.0.0~BETA-0509c` sur chaque disposition
(`tools/smods_loader_check.lua`, voir TESTS.md) :

| Disposition dans `Mods` | Résultat |
|---|---|
| `Mods\BalatroStrategicCopilot\BalatroStrategicCopilot.json` | ✔ chargé (disposition recommandée) |
| un dossier intermédiaire : `Mods\BalatroStrategicCopilot-1.0.2\BalatroStrategicCopilot\…json` ou dépôt GitHub entier `Mods\balatro-strategic-copilot-…\BalatroStrategicCopilot\…json` | ✔ chargé (toléré) |
| **deux** dossiers intermédiaires, par exemple après « Extraire tout » de Windows dans un dossier déjà créé : `Mods\X\X\BalatroStrategicCopilot\…json` | ✘ **ignoré sans aucun message** : Steamodded ne cherche pas plus profond |
| **archive `.zip` déposée telle quelle** dans `Mods` | ✘ **ignorée sans aucun message** avec ce Steamodded (les versions récentes de Steamodded savent monter un zip, pas celle-ci) : il faut l'extraire |
| deux copies du mod | une seule est chargée, l'autre provoque l'erreur `dupe` (bouton *Mods* signalé) : n'en garder qu'une |

Dans tous les cas « ignoré », **aucun bandeau** n'apparaît : c'est le signe que le mod n'a pas été
trouvé. Pour voir où se trouvent les copies du mod, coller dans PowerShell :
```
Get-ChildItem "$env:APPDATA\Balatro\Mods" -Recurse -Filter BalatroStrategicCopilot.json | Select-Object -ExpandProperty FullName
Get-ChildItem "$env:APPDATA\Balatro\Mods" -Filter *.zip | Select-Object -ExpandProperty Name
```
La première commande doit afficher une seule ligne,
`C:\Users\<vous>\AppData\Roaming\Balatro\Mods\BalatroStrategicCopilot\BalatroStrategicCopilot.json` ;
la seconde ne doit pas lister d'archive du mod.

## 4. Où sont les données ?

| Contenu | Emplacement |
|---|---|
| Configuration (sauvegardée par Steamodded) | `%AppData%\Balatro\config\BalatroStrategicCopilot.jkr` |
| Profil appris (statistiques) | `%AppData%\Balatro\BSC\profile.a.json` / `profile.b.json` |
| Journaux bruts des parties | `%AppData%\Balatro\BSC\runs\` |
| Sauvegardes de sécurité | `%AppData%\Balatro\BSC\backups\` |
| Fichiers corrompus mis de côté | `%AppData%\Balatro\BSC\corrupt\` |
| Exports / imports | `%AppData%\Balatro\BSC\export\`, `%AppData%\Balatro\BSC\import\` |
| Journal technique | `%AppData%\Balatro\BSC\logs\bsc.log` (taille bornée) |

Ces fichiers sont séparés des sauvegardes de Balatro, qui ne sont jamais modifiées.

## 5. Mise à jour

1. Fermer le jeu.
2. Supprimer le dossier `Mods\BalatroStrategicCopilot`, puis y glisser celui de la nouvelle
   version (ne pas l'extraire **dans** l'ancien dossier : dossiers en trop et fichiers mélangés).
3. Les données `BSC\` sont conservées ; si leur format change, elles sont migrées
   automatiquement après une copie de sécurité dans `BSC\backups\`.

## 6. Désinstallation

1. Fermer le jeu.
2. Supprimer `%AppData%\Balatro\Mods\BalatroStrategicCopilot`.
3. Optionnel : supprimer `%AppData%\Balatro\BSC\` (historique et apprentissage) et
   `%AppData%\Balatro\config\BalatroStrategicCopilot.jkr` (configuration).

Aucun autre fichier n'est créé ni modifié. Pour désactiver temporairement le mod sans le
supprimer, utiliser le bouton d'activation du menu *Mods* de Steamodded.

## 7. Steam Deck / Linux / Mac

Non ciblés, mais rien n'est spécifique à Windows : le dossier `Mods` se trouve à
l'emplacement indiqué par la documentation de Lovely pour la plateforme.
