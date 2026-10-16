# Données utilisées par Poulpoints

Les tâches, projets, notes, lieux saisis, sous-tâches, étiquettes et rappels sont conservés sur l’appareil. Le lieu est un texte saisi par l’utilisateur ; Poulpoints n’utilise pas une localisation GPS pour cette fonctionnalité.

Si vous activez Cloud Poulapp/Supabase, les données de tâches et projets sont envoyées au serveur configuré pour les retrouver sur les appareils connectés au même compte. Le serveur traite aussi les données nécessaires à la connexion et ses journaux techniques. Les jetons de session natifs sont conservés par le coffre-fort du système ; le mot de passe n’est pas stocké dans les préférences de Poulpoints.

Le compagnon KDE utilise une projection locale et une file de commandes. Les notifications peuvent révéler les titres selon les réglages du téléphone ou du bureau. Les exports de sauvegarde contiennent vos données : conservez-les dans un emplacement privé.

Aucun module publicitaire ou analytique n’a été ajouté à l’application. Pour effacer les données hébergées et le compte, contacter l’administrateur du serveur choisi ; une interface d’effacement complet du compte n’est pas encore fournie. Les suppressions de tâches utilisent des marqueurs conservés pour synchroniser les appareils.

## Pièces jointes

Les fichiers choisis sont copiés dans un espace cloud privé associé au compte. Ils ne sont pas inclus dans les sauvegardes JSON de tâches et leur consultation nécessite Internet. Les liens de téléchargement expirent après 30 secondes. Une copie téléchargée par l’utilisateur ne peut pas être effacée à distance.

Terminer ou supprimer une tâche déclenche la suppression de ses copies cloud dès la synchronisation. Les échecs sont réessayés automatiquement chaque minute. Les transferts interrompus sont nettoyés après expiration. Pour une tâche récurrente, les fichiers appartiennent à l’occurrence actuelle et ne sont pas transmis à la suivante. Rouvrir une tâche ne restaure pas ses fichiers supprimés. Les fichiers originaux sur l’appareil ne sont jamais supprimés.

Limites : 10 Mo par fichier, 10 fichiers par tâche, 100 Mo par compte.
