# Validation Poulpoints 0.7.0 — 15 octobre 2026

## Vérifications réalisées
- Analyse Flutter sans erreur.
- Suite Flutter : 69 tests réussis, puis un test supplémentaire réussi pour les échanges cloud limités aux révisions en absence de changement (70 tests distincts).
- Compagnon Linux : 7 tests réussis.
- Android natif : 15 tests réussis, dont rappels multiples et report depuis la notification.
- Compilation Android ARM64 signée pour essais et compilation sans signature réussies. Absence de signature de cette dernière vérifiée. Contrôle des constructeurs DEX réussi sur la version d’essai.
- Compilation Linux release réussie.
- Intégration Linux isolée avec véritable binaire et compagnon : terminer une tâche, enregistrer et actualiser la projection sans fenêtre visible. Aucune donnée personnelle utilisée.
- Mise à jour Android 0.7.0 (19) installée par-dessus l’existante sur le Pixel ; application lancée et processus actif.
- Version Linux 0.7.0 et compagnon KDE installés ; ancienne instance remplacée, nouveau processus actif.

## Validation humaine et limites
Les essais antérieurs Android/Linux de rappels, redémarrage, économie d’énergie et synchronisation des widgets sont conservés comme validés par l’utilisateur, sans être repris.
Les nouveaux rappels multiples, les choix de conflits, la suppression de projet et les exceptions d’occurrence disposent de tests automatisés ; leur validation complète en usage réel de cette livraison reste à effectuer.
La résolution cloud compare deux versions entières, sans fusion champ par champ. Les exceptions concernent l’occurrence courante. Le report Linux est proposé dans l’application ; Android le propose aussi dans la notification.
Windows et navigateur restent en attente.

## Publication
Archive source, paquet Linux, APK d’essai, notices, documentation de signature et métadonnées F-Droid préparés. Pas de publication publique effectuée.
Le dépôt public, la signature de production et l’audit complet des dépendances natives restent à finaliser. La recette F-Droid est un modèle désactivé, non validé sur le serveur de construction F-Droid.
Le budget cloud pour 1 à 10 personnes est une estimation documentée, non une garantie de gratuité ni une mesure réelle du compte. Aucun suivi de quota automatique n’a été configuré.
