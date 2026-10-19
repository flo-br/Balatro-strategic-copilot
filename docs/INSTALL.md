# Installation, mise à jour et désinstallation (Windows)

## Méthode sans programme : le mode autonome (1.0.4+, recommandée)

Pour les PC qui bloquent les scripts (`.bat`, PowerShell) ou la DLL de Lovely (`winmm.dll`,
souvent supprimée par les antivirus ou contrôles parentaux) : **ni Lovely, ni Steamodded, ni
programme** — seulement des fichiers texte à copier.

1. Extraire `BalatroStrategicCopilot-1.0.8.zip` (clic droit → *Extraire tout…*).
2. Ouvrir le dossier `COPIER_DANS_AppData_Balatro`, tout sélectionner (`main.lua` et `Mods`),
   copier, puis coller dans `%AppData%\Balatro\` (touche Windows + R, taper `%AppData%\Balatro`).
   Accepter de remplacer les fichiers si Windows le demande.
3. Lancer Balatro normalement. Bandeau vert : « Balatro Strategic Copilot 1.0.8 actif — touche C :
   panneau (mode autonome, sans Steamodded) ».

Résultat :
```
%AppData%\Balatro\
  main.lua                                   amorce du mode autonome
  Mods\BalatroStrategicCopilot\…              le copilote
  1\ 2\ 3\                                   vos profils (non touchés)
  BSC\amorce.log                             trace de démarrage (créée au lancement)
```

**Comment ça marche (vérifié dans le code de LÖVE 11.3, 11.4 et 11.5, `boot.lua`).** Juste avant
de charger le `main.lua` du jeu, LÖVE appelle
`love.filesystem.setIdentity(c.identity or …, c.appendidentity)` ; avec la valeur par défaut
`appendidentity = false`, le dossier de sauvegarde (`%AppData%\Balatro`) est consulté **avant** le
contenu de `Balatro.exe`. Le `main.lua` fourni est donc lu à sa place. Il place un instant le
dossier de sauvegarde en dernier pour lire le `main.lua` **d'origine**, l'exécute sans le
modifier, rétablit l'ordre normal, puis démarre le copilote à la première image du jeu.
Aucun fichier du jeu n'est modifié ; supprimer `main.lua` rend le jeu strictement d'origine.

**Limites.** Ce mode suppose que Balatro ne demande pas `appendidentity = true` dans son
`conf.lua` : c'est le cas par défaut de LÖVE, mais cela n'a pas pu être vérifié sur le jeu réel
(non disponible ici). Si c'est le cas, rien ne se passe (pas de `BSC\amorce.log`) et le jeu reste
normal. Sans Steamodded, l'onglet de configuration du menu *Mods* n'existe pas : les réglages se
font dans `Mods\BalatroStrategicCopilot\config.lua` ; les touches sont lues directement au clavier
(jamais pendant la saisie d'un texte, ni avec Ctrl/Alt). Avec Lovely + Steamodded, `main.lua` est
inutile : s'il est présent, il laisse Steamodded charger le copilote (vérifié).

Diagnostic : `%AppData%\Balatro\BSC\amorce.log` décrit chaque étape (amorce lue, `main.lua`
d'origine exécuté, copilote démarré ou erreur). Voir [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Méthode avec Lovely + Steamodded

### L'installateur (1.0.3+)

1. Extraire **toute** l'archive `BalatroStrategicCopilot-1.0.8-installateur.zip` (clic droit →
   *Extraire tout…*).
2. Fermer Balatro, puis double-cliquer sur **`INSTALLER_COPILOT.bat`** dans le dossier extrait
   (si Windows affiche « Windows a protégé votre ordinateur » : *Informations complémentaires* →
   *Exécuter quand même*).
3. Accepter « Lancer Balatro maintenant » : le programme lance le jeu par Steam, lit le journal de
   Lovely et dit si tout s'est chargé. Un rapport `Rapport_Copilot_Balatro.txt` est écrit sur le
   Bureau.

Ce que le programme vérifie, dans l'ordre de la chaîne de chargement (chaque modification est
proposée et doit être acceptée ; rien n'est téléchargé ni supprimé) :

| Maillon | Vérifications | Réparation proposée |
|---|---|---|
| Jeu | dossier de `Balatro.exe` via le registre et les bibliothèques Steam (`libraryfolders.vdf`, `appmanifest_2379780.acf`), recherche sur les disques, autres installations, version Xbox (non prise en charge), options de lancement Steam `--vanilla` / `-d` | — (options : indiquées) |
| Lovely | `winmm.dll` à côté de `Balatro.exe` (DLL valide), ancien `version.dll` / `dwmapi.dll` (Lovely refuse alors de démarrer) | copie de `winmm.dll` depuis une ancienne installation du jeu ou depuis `lovely-x86_64-pc-windows-msvc.zip` téléchargé par vous (page officielle ouverte sur demande) ; ancien fichier **renommé** |
| Steamodded | présent **directement** dans `Mods`, une seule copie, pas désactivé (`.lovelyignore`, `Mods\lovely\blacklist.txt`), version | remonté s'il est rangé trop bas, copies en trop déplacées hors de `Mods`, réactivation ; installation depuis l'archive *Source code (zip)* téléchargée par vous |
| Copilote | toutes les copies (dossiers imbriqués, `.zip`), version, désactivation (`.lovelyignore`, `blacklist.txt`) | installation propre dans `Mods\BalatroStrategicCopilot`, anciennes copies **déplacées** dans `%AppData%\Balatro\BSC_anciennes_copies\`, réactivation (copie de sécurité de `blacklist.txt`) |
| Lancement | journal `Mods\lovely\log\lovely-*.log` : Lovely démarré, dossier du jeu réellement lancé, dossier `Mods` utilisé, mode vanilla, Steamodded chargé, copilote prêt ou erreur, plantage | — (diagnostic précis) |

`DIAGNOSTIC_COPILOT.bat` fait les mêmes vérifications **sans rien modifier** (à lancer après avoir
lancé le jeu une fois). Paramètres utiles de `outils\installer_copilot.ps1` : `-DossierJeu`,
`-DiagnosticSeul`, `-SansLancement`.

Les sections suivantes décrivent la même chose à la main.

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
3. Ouvrir l'archive `BalatroStrategicCopilot-1.0.8-installateur.zip` (ou le zip téléchargé depuis GitHub) et
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
5. Lancer le jeu : un bandeau vert « Balatro Strategic Copilot 1.0.8 actif » s'affiche en haut de
   l'écran pendant l'intro puis 15 secondes au menu principal. Dans *Mods*, « Balatro Strategic
   Copilot » apparaît. En partie, le résumé compact s'affiche en haut à droite ; `C` ouvre le
   panneau complet.

### Pièges vérifiés sur le chargeur de Steamodded

Vérifié en exécutant les vrais chargeurs de Steamodded `1.0.0~BETA-0509c` (mai 2025) et
`26.1009.0` (récent) sur chaque disposition (`tools/smods_loader_check.lua`, voir TESTS.md) :

| Disposition dans `Mods` | Résultat |
|---|---|
| `Mods\BalatroStrategicCopilot\BalatroStrategicCopilot.json` | ✔ chargé (disposition recommandée) |
| un dossier intermédiaire : `Mods\BalatroStrategicCopilot-1.0.3\BalatroStrategicCopilot\…json` ou dépôt GitHub entier `Mods\balatro-strategic-copilot-…\BalatroStrategicCopilot\…json` | ✔ chargé (toléré) |
| **deux** dossiers intermédiaires, par exemple après « Extraire tout » de Windows dans un dossier déjà créé : `Mods\X\X\BalatroStrategicCopilot\…json` | ✘ **ignoré sans aucun message** : Steamodded ne cherche pas plus profond |
| **archive `.zip` déposée telle quelle** dans `Mods` | ✘ **ignorée sans aucun message** avec ce Steamodded (les versions récentes de Steamodded savent monter un zip, pas celle-ci) : il faut l'extraire |
| deux copies du mod | Steamodded ancien : une seule est chargée, l'autre provoque l'erreur `dupe`. Steamodded récent : il **désactive durablement** une copie en écrivant le nom de son dossier dans `Mods\lovely\blacklist.txt` ; si c'est `BalatroStrategicCopilot`, le mod reste désactivé même après le ménage. N'en garder qu'une et la réactiver (l'installateur le fait) |
| `BalatroStrategicCopilot` listé dans `Mods\lovely\blacklist.txt` (mod désactivé depuis le menu *Mods* d'un Steamodded récent) | ✘ chargé **désactivé** : aucun bandeau ; le réactiver dans le menu *Mods* ou retirer la ligne |

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
