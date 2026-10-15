# Poulpoints 0.6.2 — démarrage Android réparé

Le correctif a déjà été installé et testé sur le Pixel connecté, sans désinstallation ni effacement des données.

Pour une autre installation existante, ouvrir Poulpoints_v0.6.2_Android_ARM64_essai.apk et accepter la mise à jour. Ne pas désinstaller l’ancienne application. La signature est inchangée ; l’APK reste une version d’essai signée avec la clé de développement.

Après installation, ouvrir Poulpoints. Pour bénéficier des nouvelles dimensions du widget introduites en 0.6.1, retirer uniquement l’ancien widget de l’écran d’accueil et le rajouter si cela n’a pas déjà été fait.

Le démarrage est vérifié sur le Pixel 10. Il reste à confirmer les validations depuis le widget et les rappels dans l’usage réel. Voir INSTALLATION_0.6.1.md pour le scénario détaillé et les commandes Bazzite/Distrobox.

## Recompiler depuis Distrobox

    distrobox enter poulpoints-dev
    cd /chemin/vers/poulpoints_starter
    flutter pub get
    flutter analyze
    flutter test
    flutter build apk --release --target-platform android-arm64
    python3 tool/check_android_release.py build/app/outputs/flutter-apk/app-release.apk

Conserver la même clé de signature pour mettre à jour une installation existante. Le correctif concerne la compilation Android ; aucune nouvelle installation Linux n’est nécessaire.
