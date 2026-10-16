#!/usr/bin/env bash
# Fixed private build path avoids absolute-path fingerprints in Dart/JNI libraries.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/.." && pwd)
output=${1:?Usage: build_reproducible.sh OUTPUT_DIRECTORY}
mkdir -p "$output"
output=$(cd "$output" && pwd)
buildroot=/tmp/poulpoints-fdroid-build
# Never replace an existing directory; this also prevents symlink attacks.
mkdir -m 700 "$buildroot"
trap 'rm -rf -- "$buildroot"' EXIT
mkdir "$buildroot/source"
git -C "$source_root" archive HEAD | tar -x -C "$buildroot/source"
git clone --no-hardlinks "$source_root/vendor/flutter" "$buildroot/source/vendor/flutter" >/dev/null 2>&1
git -C "$buildroot/source/vendor/flutter" checkout "$(git -C "$source_root" rev-parse HEAD:vendor/flutter)" >/dev/null 2>&1
export PUB_CACHE="$buildroot/pub-cache"
unset POULPOINTS_TEST_SIGNING
cd "$buildroot/source"
flutter="$PWD/vendor/flutter/bin/flutter"
"$flutter" config --no-analytics
"$flutter" pub get --enforce-lockfile
"$flutter" build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk "$output/Poulpoints.apk"
