# Poulpoints 0.7.0+19

Validation silencieuse KDE ; étiquettes recherchables ; suppression de projet avec déplacement des tâches ; déplacement/ignorance de l’occurrence courante ; rappels multiples et report de dix minutes ; résolution guidée des conflits cloud ; vérification légère des versions cloud ; préparation de la signature de production et du dossier F-Droid.

Format de sauvegarde 3 conservé avec champs optionnels `tags`, `reminderOffsets`, `occurrenceAnchor`, `snoozedUntil`. Les anciennes sauvegardes restent lisibles. Mettre à jour tous les clients qui modifient les tâches, car les versions anciennes ne préservent pas ces nouveaux champs.

Aucune migration SQL, aucune nouvelle dépendance applicative, aucune modification du logo. La publication officielle reste conditionnée au dépôt public, à la signature et à la validation F-Droid.
