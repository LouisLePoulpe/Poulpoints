# Validation 0.6.2 — 14 octobre 2026

## Diagnostic confirmé

Le journal du Pixel 10 signale « Unable to get provider androidx.startup.InitializationProvider », causé par « NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> [] ».

L’échec survient dans WorkManagerInitializer, avant MainActivity et l’affichage Flutter. L’APK 0.6.1 conserve le nom de WorkDatabase_Impl mais pas son constructeur sans argument. Les tests Robolectric non optimisés ne détectaient pas cette suppression par R8.

## Correction

La compilation release charge android/app/proguard-rules.pro, qui conserve explicitement WorkDatabase_Impl et son constructeur public sans argument. L’optimisation générale reste active. Aucun changement du format des tâches, du moteur partagé ou de la synchronisation.

## Vérifications réalisées

- Compilation APK release ARM64 0.6.2+15 réussie.
- Contrôle du DEX final avec tool/check_android_release.py : échec attendu sur la 0.6.1, succès sur la 0.6.2. Vérifie aussi le constructeur du WidgetCommandWorker chargé par réflexion.
- Signature identique à celle des APK 0.6.0 et 0.6.1 ; paquet org.poulapp.poulpoints, versionCode 15.
- Analyse Flutter : aucun problème.
- 56 tests Flutter réussis.
- Installation réelle sur le Pixel 10 par mise à jour, sans désinstallation ni effacement des données.
- Premier démarrage à froid : succès, interface Poulpoints et bouton Nouvelle tâche présents.
- Retour depuis l’écran d’accueil : succès, même processus.
- Arrêt complet puis nouveau démarrage à froid : succès.
- Aucun crash enregistré pour les processus de ces essais.

## Portée

Le plantage de démarrage est corrigé et vérifié sur le téléphone. Cette séance ne constitue pas une validation complète des widgets, des récurrences, des rappels et des échanges cloud sur appareils réels. Les tests Android et Linux de la 0.6.1 restent documentés dans VALIDATION_0.6.1.md ; ils ne sont pas présentés comme de nouveaux tests physiques.

## Reproduction

    flutter analyze
    flutter test
    flutter build apk --release --target-platform android-arm64
    python3 tool/check_android_release.py build/app/outputs/flutter-apk/app-release.apk

Tester ensuite l’APK release réellement distribué sur Android, pas seulement une compilation debug.

Référence : https://developer.android.com/topic/performance/app-optimization/full-mode
