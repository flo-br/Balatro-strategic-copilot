# Système d'apprentissage

L'apprentissage est **local, hors ligne, automatique et progressif**. Il améliore les
estimations et, depuis 1.0.9, recalcule après chaque partie les seuils des conseils (bornés,
expliqués) ; il ne modifie jamais le jeu et ne joue jamais à la place du joueur.

## 1. Données enregistrées (journal brut)

Pour chaque partie (`BSC/runs/run_<horodatage>_<empreinte>.a|b.json`) :

| Donnée | Contenu |
|---|---|
| Métadonnées | versions du jeu, de Steamodded et du mod ; deck ; mise ; défi ; graine (si accessible) |
| Blindes | ante, manche, blinde, taille, **probabilité prédite au départ** et méthode, résultat |
| Mains | main jouée, score prédit (moyenne, min, max, exact ?), **score réel**, probabilité de réussite avant la main, recommandation suivie ?, contribution mesurée de chaque joker, jokers inconnus |
| Décisions | jeu, défausse, achat, vente, relance, ouverture de paquet, consommable, blinde passée : options disponibles et leurs notes, recommandation, choix effectif, danger |
| Économie, puissance | argent par manche, puissance estimée par ante |
| Fin | victoire / défaite / abandon, ante atteinte, blinde fatale |

Aucune donnée personnelle (ni nom, ni chemin, ni identifiant de compte) n'est enregistrée.
Le nombre de journaux bruts est borné (`learning.max_runs_kept`, 300 par défaut) ; leurs
résumés restent dans le profil.

## 2. Statistiques apprises (profil, séparé des données brutes)

`BSC/profile.a|b.json` (schéma versionné, migrations automatiques avec copie de sécurité) :

| Statistique | Méthode | Utilisation |
|---|---|---|
| Calibration des probabilités de blinde et de manche | classes de fiabilité, a priori Bêta centré sur la prédiction (force 10), rendu monotone ; **activée seulement si elle améliore le score de Brier sur les 25 % de données les plus récentes** (validation temporelle) et s'il y a au moins 30 observations | corrige les probabilités affichées |
| Croissance de puissance par ante | moyenne géométrique, rétrécie vers l'a priori ×2,0 (poids 5 parties) | estimation de victoire à long terme |
| Contribution des jokers | part du score mesurée main par main (score avec / sans le joker) | bilan, jokers déterminants |
| Jokers inconnus (moddés) | rapport score réel / prédit, rétréci vers 1 (poids 10), utilisé seulement après 3 observations | estimation « partielle, ajustée » au lieu d'ignorer le joker |
| Précision des scores | erreur relative ; nombre de prédictions « exactes » démenties | diagnostic de compatibilité |
| Suivi des recommandations | Bêta-binomiale, stratifiée par niveau de danger, avec intervalles | descriptif uniquement |
| Résultats par deck/mise | Bêta-binomiale | descriptif |
| **Développement du copilote** (1.0.9, `learning/adapt.lua`) | causes comptées dans les défaites et les victoires, résultat des 20 dernières parties ; un changement à l'essai pendant 3 parties, gardé seulement si les résultats ne baissent pas ; 10 dernières étapes gardées avec leurs causes et verdicts | conseils des parties suivantes ; affiché dans le bilan (« Ce que je change pour la prochaine partie ») — détails : [MATHS.md](MATHS.md) §10 |

## 3. Garde-fous

* **Pas de certitude après quelques parties** : toutes les estimations sont rétrécies vers
  un a priori ; 3 défaites à 90 % ne transforment pas 90 % en 0 % (testé).
* **Une défaite n'est pas forcément une mauvaise décision** : le bilan ne qualifie une décision
  d'« erreur probable » qu'en comparant ses estimations à celles de la meilleure option **au
  moment de la décision** (testé).
* **Mais toute partie est jouable** (1.0.7) : le bilan ne conclut jamais par « malchance ». Il
  cherche pourquoi le build n'a pas suffi, à partir de la trajectoire de la partie (puissance
  estimée à chaque boutique, plan, argent, planètes) et de la liste de vérification des meilleurs
  joueurs ([PRO_LESSONS.md](PRO_LESSONS.md)) : ante où une main typique est passée sous la mise de
  base, ×Mult manquants, argent dormant, planètes dispersées, trop peu de jokers, boss non préparé,
  marge trop faible (une blinde perdue à 85 % = 15 % de risque accepté). Ces causes visent aussi
  le plan du copilote lui-même, pas seulement le joueur.
* **Leçons retenues** : les causes des 10 dernières défaites sont gardées dans le profil. Jusqu'à
  la 1.0.8, la même cause revenue donnait d'office plus de poids au plan (×1 à ×1,5) ; depuis la
  1.0.9, ce poids passe par un essai (ci-dessous) et n'est gardé que s'il paie.
* **Un succès ne valide pas une stratégie** : les taux sont affichés avec leur intervalle ; la
  comparaison « parties anciennes / récentes » n'est déclarée significative que si les
  intervalles ne se recouvrent pas, et seulement à partir de 20 parties.
* **Pas de contrefactuel inventé** : le résultat d'une option non choisie n'est jamais affirmé ;
  seules les estimations au moment de la décision sont comparées.
* **Idempotence** : une partie n'est comptée qu'une fois (même après import ou redémarrage).
* **Développement recalculé, mais seulement ce qui paie** (1.0.9) : après une défaite, le
  copilote essaie **un** changement (urgence des ×Mult, poids des planètes, seuils d'achat,
  d'épargne, de sécurité ou de passage) demandé par la cause qui revient le plus dans vos
  défaites et qui les distingue des victoires ; il le joue 3 parties et ne le **garde** que si
  ces parties ne sont pas moins bonnes que les précédentes, sinon il l'**annule** et ne le réessaie
  pas avant 10 parties. Un pas à la fois, dans des bornes fixes ; une même partie n'est jamais
  comptée deux fois ; une partie abandonnée ne compte pas. Chaque étape est écrite dans le bilan.
  Les réglages de `config.lua` restent la base : effacer le profil remet tout à zéro. Pourquoi :
  sur le simulateur, appliquer directement les leçons d'une défaite faisait **moins bien** que ne
  rien changer (MATHS.md §10).
* **Poids de la note non auto-ajustés** : écarté volontairement (attribution trop bruitée).

## 4. Évaluation objective

Disponible dans le bilan de fin de partie (panneau, détail `V`) et dans le profil :
* score de Brier, log-loss et erreur de calibration attendue (ECE) des probabilités de blinde,
  table de fiabilité par classes ;
* Brier sur l'échantillon de validation postérieur, avant / après calibration ;
* erreur relative moyenne des scores prédits ; nombre de scores « exacts » vérifiés et démentis ;
* taux de victoire et ante moyenne par deck/mise, avec intervalles ;
* tendance anciennes / récentes parties (validation temporelle).

## 5. Export, import, réinitialisation

Depuis *Mods → Balatro Strategic Copilot → Config* :

| Action | Effet |
|---|---|
| **Exporter les données** | écrit `BSC/export/bsc_export_<date>.json` (profil + index + journaux bruts) |
| **Importer** | lit chaque fichier déposé dans `BSC/import/` ; ajoute les parties inconnues (sans double comptage) ; le fichier importé est déplacé dans `BSC/backups/` ; un fichier invalide est ignoré |
| **Réinitialiser l'apprentissage** | deux clics à moins de 5 s ; copie le profil dans `BSC/backups/` puis repart d'un profil vide (les journaux bruts sont conservés) |

Pour tout effacer : supprimer le dossier `%AppData%\Balatro\BSC\` jeu fermé.
L'apprentissage peut être désactivé (`learning.enabled`) : le journal brut reste tenu, le profil
n'est plus mis à jour. `learning.adapt = false` (dans `config.lua`) coupe seulement les essais de
changements après une défaite : les conseils suivent alors toujours les valeurs de `config.lua`.

## 6. Robustesse du stockage

Écriture en double emplacement A/B avec numéro de séquence, longueur et somme de contrôle
Adler-32 ; relecture de vérification après écriture ; au chargement, la copie valide la plus
récente est retenue. Une écriture interrompue ne peut endommager que l'emplacement en cours
d'écriture. Un fichier invalide est déplacé dans `BSC/corrupt/` (jamais supprimé en silence).
Les fichiers de données sont lus comme du JSON pur (jamais exécutés). Un profil d'un schéma plus
récent (version future du mod) n'est jamais écrasé.
