# Validation 0.6.1 — 14 octobre 2026

La 0.6.0 a échoué à la validation utilisateur du widget Android : trop grand, ouverture de la fenêtre et conflit de sauvegarde. Les tests automatisés précédents n'avaient pas couvert ce chemin réel. La 0.6.1 est un correctif à valider sur le téléphone.

## Vérifications réalisées sur la 0.6.1

- Flutter 3.47.7 / Dart 3.13.5 dans Fedora 43 Distrobox.
- Analyse Flutter sans problème.
- 56 tests Flutter réussis.
- Nouveaux tests avec stockage Sembast réel : conservation d'une modification concurrente d'une autre tâche, des suppressions et du point de synchronisation cloud ; rappel et sous-tâches d'une récurrence ; doublons simultanés ; rejet d'une version périmée ; reprise après échec de publication ; reçu conservé après fermeture et réouverture d'une base sur disque.
- Démarrage du traitement Dart sans construire l'interface testé avec un pont natif simulé. Ce test ne lance pas un moteur Android réel.
- Test d'interface : réception de la commande, affichage et reprogrammation, avec repository simulé. Les garanties transactionnelles sont vérifiées séparément avec Sembast.
- 8 tests natifs Android Robolectric/API 35 réussis : alarmes et notifications existantes, authentification des commandes, PendingIntent de type broadcast vers le récepteur privé (pas une activité), rendu et filtre, passage d'une à sept lignes puis retour à une lors du redimensionnement.
- 5 tests du compagnon Linux réussis.
- Test d'intégration Linux sous Xvfb, avec dossiers XDG temporaires : vraie sauvegarde d'une action de widget, récurrence, prochain rappel et acquittement. Aucun accès aux données personnelles.
- Compilation Linux release réussie.
- Compilation APK Android ARM64 release réussie, version 0.6.1+14, signature de développement.

## Limites de validation

Le lancement du FlutterEngine Android sans Activity et sa réutilisation au retour dans l'application n'ont pas été exécutés sur un téléphone ni dans un émulateur fonctionnel. L'émulateur disponible avait échoué au démarrage. Les tests Robolectric ne remplacent pas ces vérifications, ni celles du lanceur, des restrictions de batterie et des notifications.

Le test Pixel doit couvrir : ouverture/fermeture de l'application, validation depuis le widget sans fenêtre, nouvelle modification sans erreur de sauvegarde, double appui, récurrence avec rappel, redimensionnement et synchronisation après retour au premier plan.

Aucune connexion au cloud réel ni modification du serveur Supabase pendant le correctif. Le fonctionnement cloud reste au premier plan. Les dernières données sauvegardées sont conservées lors de la mise à jour ; exporter les modifications encore en mémoire avant de fermer l'ancienne application.

## Reproduction

Dans Distrobox, depuis le dossier source :

    flutter analyze
    flutter test
    python3 -m unittest discover -s desktop -v
    cd android
    ./gradlew :app:testDebugUnitTest

Le test integration_test/desktop_bridge_test.dart écrit des fixtures : utiliser uniquement des dossiers XDG_DATA_HOME et XDG_CONFIG_HOME temporaires, jamais le profil personnel.

## Références

- Moteur Flutter partagé : https://docs.flutter.dev/add-to-app/android/add-flutter-screen
- Taille des widgets : https://developer.android.com/develop/ui/views/appwidgets/layouts
- AndroidX WorkManager 2.10.2 : https://developer.android.com/jetpack/androidx/releases/work
