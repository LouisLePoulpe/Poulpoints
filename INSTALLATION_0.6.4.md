# Poulpoints 0.6.4 — installation

Installer Poulpoints_v0.6.4_Android_ARM64_essai.apk par-dessus la version existante, sans désinstallation ni effacement des données. Cette mise à jour a été installée sur le Pixel pendant les essais du 14 octobre 2026.

Le widget suit le thème du système Android. Activer le thème sombre du téléphone pour obtenir le fond sombre. Il ne suit pas un éventuel choix de thème propre à l’application Flutter.

L’APK garde la signature de développement précédente. Aucune mise à jour Linux n’est nécessaire pour ce changement Android.

## Compilation dans Distrobox

```sh
distrobox enter poulpoints-dev
cd /chemin/vers/poulpoints_starter
flutter pub get
flutter build apk --release --target-platform android-arm64
python3 tool/check_android_release.py build/app/outputs/flutter-apk/app-release.apk
cd android
./gradlew :app:testDebugUnitTest
```
