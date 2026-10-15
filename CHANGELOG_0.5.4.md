# 0.5.4 — fiabilité et première livraison Web

Correction du test de navigation/paramètres bloqué par le mélange de la base asynchrone et de l’horloge simulée des tests Flutter. Les tests de base utilisent leur cycle de vie asynchrone réel ; le test d’interface reçoit un dépôt adapté.

La synchronisation conserve les éditions locales effectuées pendant un envoi et sauvegarde son état de référence avec les tâches dans une transaction. Les réponses distantes sont contrôlées avant application. Les sessions natives utilisent un coffre-fort, avec restauration et rotation des jetons sérialisée. Aucune modification du schéma cloud distant.

Livraisons Linux, APK Android ARM64 d’essai, sources et Web. Logo inchangé. Voir VALIDATION.md pour les contrôles réalisés et README.md pour le travail restant.
