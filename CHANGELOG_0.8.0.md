# Poulpoints 0.8.0

- Ajout et consultation de pièces jointes privées dans le cloud depuis les détails d’une tâche, sous les notes.
- Suppression déclenchée à la complétion/suppression synchronisée ; reprise automatique après échec et nettoyage des transferts abandonnés.
- Pièces jointes limitées à l’occurrence actuelle pour les tâches récurrentes ; les originaux de l’appareil sont conservés.
- Limites : 10 Mo par fichier, 10 fichiers par tâche, 100 Mo par compte.
- Correction des droits serveur nécessaires à la lecture des tâches et à l’envoi des fichiers.
- Installation Linux dans un dossier distinct pour éviter de remplacer un exécutable ouvert.

Validation : 74 tests Flutter, test PostgreSQL avec le rôle réel du service, compilation Android/Linux, fonctionnement confirmé par l’utilisateur.

Android ARM64 signé en production ; Linux Bazzite/KDE. Windows et Web restent en attente. La publication F-Droid reste en préparation.
