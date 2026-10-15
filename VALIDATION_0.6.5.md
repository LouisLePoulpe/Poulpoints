# Validation 0.6.5 — 15 octobre 2026

## Confirmations utilisateur précédant cette mise à jour

- Rappels Android reçus en mode normal, avec économiseur de batterie et après redémarrage réel.
- Rappel Linux reçu après redémarrage de Bazzite et ouverture de session sans ouvrir Poulpoints.
- Widget KDE conservé après redémarrage ; création et validation fonctionnelles.
- Déplacement du widget KDE confirmé en passant par le mode édition du bureau.
- Ces confirmations ne sont pas présentées comme de nouveaux essais de régression de la 0.6.5.

## Vérifications 0.6.5

- Analyse Flutter sans problème.
- 59 tests Flutter réussis dans la dernière exécution, dont 3 nouveaux tests de synchronisation sans interface.
- 13 tests Android natifs Robolectric réussis.
- APK ARM64 release et bundle Linux release compilés. Constructeurs Room, WidgetCommandWorker et CloudSyncWorker vérifiés dans le DEX optimisé.
- Linux : session isolée avec données de test ; démarrage sans fenêtre publiant la projection, activation affichant la fenêtre, fermeture la cachant sans arrêter le processus, réouverture de la même instance. Test WM_DELETE_WINDOW direct sur Xvfb.
- Installation Linux et Android effectuée sans effacement des données. Compagnon Linux actif sans fenêtre.
- Android : travail unique CloudSyncWorker enregistré avec contrainte réseau ; première exécution signalée SUCCESS. Un déclenchement manuel prématuré est différé par WorkManager conformément à son échéance ; il ne valide pas une seconde exécution à froid.

## Confirmation utilisateur complémentaire

- Le 15 octobre 2026, l’utilisateur confirme le test visuel inverse : la tâche créée côté Linux apparaît dans le widget Android sans ouvrir l’application Android. La réception inter-appareils en arrière-plan est donc confirmée dans ce scénario.
- Cette confirmation ne vaut pas test explicite après arrêt forcé ou destruction du processus Android, ni test après un nouveau redémarrage de la 0.6.5.

## Encore à confirmer en usage réel

- Observation technique confirmée : « TEST synchro widget », créée sur le Pixel, est arrivée dans la projection KDE sans ouvrir la fenêtre Linux. Confirmation visuelle du widget demandée.
- Reprise de la synchronisation Android après destruction du processus par le système ; réception ordinaire en arrière-plan désormais confirmée.
- Nouveau démarrage automatique Linux après reconnexion de session ; testé isolément, pas encore après un nouveau redémarrage réel.

## Limites

- Android : intervalle minimal 15 minutes, susceptible d’être rallongé en veille/économie d’énergie. Aucun délai instantané garanti.
- Linux : synchronisation pendant la session utilisateur uniquement ; application résidente et coffre-fort accessible nécessaires.
- Cloud Poulapp/Supabase uniquement ; ancien serveur expérimental inchangé.
- Cocher dans KDE ouvre encore Poulpoints. Filtrage et défilement KDE restent à confirmer visuellement.
