#!/usr/bin/env bash
# Fast check (no APK): analyze + render garment previews.
set -uo pipefail
cd "$(dirname "$0")/.."
flutter --version
flutter pub get || exit 1
echo "=================== analyze"; flutter analyze --no-fatal-infos --no-fatal-warnings; echo "analyze exit=$?"
echo "=================== previews"; flutter test --update-goldens test/garment_preview_test.dart; echo "golden exit=$?"
