#!/usr/bin/env bash
# Compile l'APK Android ARM64 Poulpoints 0.6.0 dans l'environnement poulpoints-dev.
set -Eeuo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SOURCE_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter introuvable. Depuis Bazzite : distrobox enter poulpoints-dev' >&2
  exit 1
fi

if ! command -v java >/dev/null 2>&1; then
  echo 'Java introuvable. Installer java-21-openjdk-devel dans Distrobox.' >&2
  exit 1
fi

if ! grep -q '^version: 0\.6\.0+13$' pubspec.yaml; then
  echo 'Version inattendue dans pubspec.yaml — compilation annulée.' >&2
  exit 1
fi

printf '\n== Téléchargement des dépendances Flutter ==\n'
flutter pub get

printf '\n== Tests Flutter ==\n'
flutter analyze
flutter test --timeout 60s

printf '\n== Compilation APK Android ARM64 ==\n'
flutter build apk --release --target-platform android-arm64

apk="$SOURCE_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -s "$apk" ]]; then
  echo "APK non trouvé : $apk" >&2
  exit 1
fi

out="$HOME/Téléchargements/Poulpoints_0.6.0_arm64.apk"
mkdir -p "$(dirname "$out")"
cp -f "$apk" "$out"
printf '\n== Compilation réussie ==\n'
printf 'APK Android ARM64 : %s\n' "$out"
ls -lh "$out"
if command -v sha256sum >/dev/null 2>&1; then sha256sum "$out"; fi
printf '\nNote : cette version de test est signée avec la clé Android debug locale, et ne doit pas être publiée telle quelle sur F-Droid.\n'
