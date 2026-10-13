# Dépannage

## Premier réflexe : le bandeau de démarrage (version 1.0.1+)

Au lancement du jeu, un bandeau s'affiche en haut de l'écran pendant 10 secondes :
* **vert « … actif — touche C : panneau »** : le mod fonctionne. Au menu principal il n'affiche
  rien d'autre (sauf l'historique avec `C`) ; les conseils apparaissent **pendant une partie**
  (résumé en haut à droite, `C` pour le panneau complet) ;
* **rouge « erreur au démarrage »** : le message indique la cause ; le détail complet est dans le
  journal de Lovely ;
* **aucun bandeau** : le mod n'est pas chargé du tout par Steamodded (voir ci-dessous).

## Trouver le journal

`%AppData%\Balatro\Mods\lovely\log\` : ouvrir le fichier le plus récent et chercher
`BSCopilot` ou `BalatroStrategicCopilot`. Une ligne `ready (update=true draw=true …)` signifie que
le mod a démarré. Le journal propre au mod est `%AppData%\Balatro\BSC\logs\bsc.log`.

| Symptôme | Cause probable | Solution |
|---|---|---|
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
