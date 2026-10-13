# Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
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
