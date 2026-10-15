# Poulpoints 0.6.1+14

- Widget Android : dimensions initiales 2 × 2, dimensions minimales de redimensionnement explicites, nombre de lignes recalculé lors du changement de taille.
- Le bouton de validation du widget et l’action « Terminer » des notifications utilisent un BroadcastReceiver privé et un travail AndroidX WorkManager persistant ; ils ne lancent plus MainActivity.
- Un seul FlutterEngine et un seul TaskRepository servent l’interface Android et le travail en arrière-plan. MainActivity réutilise ce moteur et conserve une instance unique.
- Le démarrage sans fenêtre traite les commandes avant runApp, indépendamment du rendu. L’ouverture de l’interface attend la fin d’une mutation déjà en cours.
- La validation relit la dernière version dans une transaction, vérifie la version de la tâche et conserve les modifications des autres tâches, suppressions et point de synchronisation cloud.
- Des reçus persistants (256 derniers) évitent de rejouer une validation après un échec de publication ou un redémarrage. Les versions de tâche périmées sont refusées.
- La commande est acquittée après sauvegarde et actualisation du widget et des rappels. Un échec laisse la commande disponible pour une reprise.
- Le contrôle de révision des sauvegardes ordinaires reste actif ; il n’a pas été supprimé pour masquer l’erreur.
- Logo officiel conservé. Aucun service Google Play ou Firebase ajouté ; publication F-Droid toujours à préparer.

La 0.6.0 pouvait créer plusieurs contextes Flutter et enregistrer une copie ancienne des données. Ce chemin a été supprimé. Le journal du téléphone ne permet pas de reconstruire l’ordre exact des événements à l’origine du conflit observé.
