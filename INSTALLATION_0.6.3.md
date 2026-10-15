# Poulpoints 0.6.3 — widget défilant

Installer Poulpoints_v0.6.3_Android_ARM64_essai.apk par-dessus la version existante, sans désinstallation ni effacement des données, puis ouvrir Poulpoints une fois.

Sur l’écran d’accueil, faire glisser verticalement dans la liste du widget pour voir les tâches suivantes. Le filtre de liste reste appliqué : choisir Toutes pour accéder à toutes les tâches actives. Le titre Poulpoints et le bouton + restent fixes ; le rond termine une tâche sans ouvrir la fenêtre de l’application.

Si le lanceur conserve l’ancienne présentation, retirer uniquement le widget de l’écran d’accueil puis le rajouter. Cela ne supprime pas les tâches.

Vérifier le défilement jusqu’à la dernière tâche, puis la validation d’une tâche en bas de liste. Le Pixel n’étant plus connecté lors de la finalisation, cette version n’a pas été installée automatiquement ni testée sur ce téléphone.

L’APK conserve la signature de développement des versions précédentes. Aucune mise à jour Linux n’est nécessaire.

## Depuis les sources dans Distrobox

    distrobox enter poulpoints-dev
    cd /chemin/vers/poulpoints_starter
    flutter pub get
    flutter build apk --release --target-platform android-arm64
    python3 tool/check_android_release.py build/app/outputs/flutter-apk/app-release.apk

Pour les tests Android natifs :

    cd android
    ./gradlew :app:testDebugUnitTest
