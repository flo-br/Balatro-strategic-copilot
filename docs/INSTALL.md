# Installation, mise à jour et désinstallation (Windows)

## 1. Prérequis

| Composant | Où le trouver | Remarque |
|---|---|---|
| Balatro (Steam, Windows) | Steam | version stable 1.0.1x |
| Lovely | `lovely-x86_64-pc-windows-msvc.zip` sur la page *Releases* de `ethangreen-dev/lovely-injector` | injecteur utilisé par Steamodded |
| Steamodded | page *Releases* de `Steamodded/smods` | chargeur de mods |

Si Steamodded est déjà installé et fonctionne (le menu *Mods* apparaît dans Balatro), passez
directement à l'étape 3.

## 2. Installer Lovely et Steamodded

1. Dans Steam : clic droit sur Balatro → *Gérer* → *Parcourir les fichiers locaux*.
2. Copier `winmm.dll` (contenu de l'archive Lovely) dans ce dossier du jeu. Si une ancienne
   version de Lovely a laissé un `version.dll`, le supprimer.
3. Ouvrir `%AppData%\Balatro\` (touche Windows + R, taper `%AppData%\Balatro`). Créer le
   dossier `Mods` s'il n'existe pas (ou lancer le jeu une fois avec Lovely : il le crée).
4. Extraire Steamodded dans `%AppData%\Balatro\Mods\` (un dossier, par exemple `smods`).
5. Lancer Balatro : le menu principal doit afficher un bouton *Mods*.

## 3. Installer Balatro Strategic Copilot

Option A — dossier :
1. Copier le dossier `BalatroStrategicCopilot` (celui qui contient `BalatroStrategicCopilot.json`
   et `main.lua`) dans `%AppData%\Balatro\Mods\`.
2. Arborescence attendue :
   ```
   %AppData%\Balatro\Mods\
     smods\                         (Steamodded)
     BalatroStrategicCopilot\
       BalatroStrategicCopilot.json
       main.lua
       config.lua
       LISEZMOI.txt
       src\core\ src\engine\ src\game\ src\io\ src\learning\ src\model\ src\ui\
   ```

Option B — archive : copier `BalatroStrategicCopilot-1.0.1.zip` tel quel dans
`%AppData%\Balatro\Mods\` (Steamodded sait charger un mod zippé) ou l'extraire à cet endroit.
L'archive se construit avec `python tools/build.py` (dossier `dist/`).

Lancer le jeu. Dans *Mods*, « Balatro Strategic Copilot » doit apparaître sans avertissement.
En partie, le résumé compact s'affiche en haut à droite ; `C` ouvre le panneau complet.

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
2. Remplacer le dossier `Mods\BalatroStrategicCopilot` par la nouvelle version.
3. Les données `BSC\` sont conservées ; si leur format change, elles sont migrées
   automatiquement après une copie de sécurité dans `BSC\backups\`.

## 6. Désinstallation

1. Fermer le jeu.
2. Supprimer `%AppData%\Balatro\Mods\BalatroStrategicCopilot` (ou l'archive zip).
3. Optionnel : supprimer `%AppData%\Balatro\BSC\` (historique et apprentissage) et
   `%AppData%\Balatro\config\BalatroStrategicCopilot.jkr` (configuration).

Aucun autre fichier n'est créé ni modifié. Pour désactiver temporairement le mod sans le
supprimer, utiliser le bouton d'activation du menu *Mods* de Steamodded.

## 7. Steam Deck / Linux / Mac

Non ciblés, mais rien n'est spécifique à Windows : le dossier `Mods` se trouve à
l'emplacement indiqué par la documentation de Lovely pour la plateforme.
