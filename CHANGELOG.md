# Historique des versions

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
