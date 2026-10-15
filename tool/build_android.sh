#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-unsigned}"
unset POULPOINTS_TEST_SIGNING
case "$mode" in
  test) unset POULPOINTS_SIGNING_PROPERTIES; export POULPOINTS_TEST_SIGNING=1 ;;
  unsigned) unset POULPOINTS_SIGNING_PROPERTIES ;;
  production) : "${POULPOINTS_SIGNING_PROPERTIES:?Specify a private signing.properties file outside the repository}" ;;
  *) echo 'Usage: tool/build_android.sh test|unsigned|production' >&2; exit 2 ;;
esac
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
python3 tool/check_android_release.py build/app/outputs/flutter-apk/app-release.apk
sha256sum build/app/outputs/flutter-apk/app-release.apk
