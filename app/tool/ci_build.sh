#!/usr/bin/env bash
# CI entry point (.github/workflows/build-apk.yml): builds a signed RELEASE APK.
# Signing: set GitHub secrets ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
# to keep one permanent key (so new builds install over old ones). Without them a temporary key is generated per build.
set -uo pipefail
cd "$(dirname "$0")/.."
step() { echo; echo "=================== $* ==================="; }

SUPABASE_URL="https://dmlshapbrcwvzewlihhe.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRtbHNoYXBicmN3dnpld2xpaGhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NTEwMTgsImV4cCI6MjEwODIyNzAxOH0.EUj2yzO8A-bXetdR0AIBATDGAvKnTHwuVzP9G2HWyr4"

step "flutter --version"; flutter --version
step "flutter create (android)"
flutter create --platforms=android --org com.novaki --project-name novaki . || exit 1
rm -f test/widget_test.dart
cp tool/android_overrides/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
G=android/app/build.gradle; [ -f "$G.kts" ] && G="$G.kts"
sed -i -E 's/applicationId ?=? ?"[^"]+"/applicationId = "com.novaki.app"/' "$G"
sed -i -E 's/minSdk ?=? ?flutter\.minSdkVersion/minSdk = 23/' "$G"

step "release signing"
KS="$PWD/android/app/novaki-release.jks"
if [ -n "${ANDROID_KEYSTORE_BASE64:-}" ]; then
  echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$KS"
  ALIAS="${ANDROID_KEY_ALIAS:-novaki}"; SP="$ANDROID_KEYSTORE_PASSWORD"; KP="${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}"
  echo "using release key from GitHub secrets"
else
  ALIAS=novaki; SP="$(head -c 24 /dev/urandom | base64 | tr -dc A-Za-z0-9)"; KP="$SP"
  keytool -genkeypair -v -keystore "$KS" -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$SP" -keypass "$KP" -dname "CN=NOVAKI, O=NOVAKI, C=EG" >/dev/null 2>&1 || exit 1
  echo "WARNING: no keystore secrets — signed with a temporary key (uninstall the previous build before installing this one)"
fi
printf "storeFile=%s\nstorePassword=%s\nkeyAlias=%s\nkeyPassword=%s\n" "$KS" "$SP" "$ALIAS" "$KP" > android/key.properties
python3 tool/patch_signing.py || exit 1
python3 tool/patch_compilesdk.py || exit 1
grep -nE "applicationId|minSdk|signingConfig" "$G"

step "flutter pub get"; flutter pub get || exit 1
step "launcher icons"; dart run flutter_launcher_icons || echo "WARN: icons step failed (non-fatal)"
step "flutter analyze"; flutter analyze --no-fatal-infos --no-fatal-warnings; echo "analyze exit=$?"
step "flutter build apk --release"
build_apk() {
  flutter build apk --release --obfuscate --split-debug-info=build/symbols \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
}
if ! build_apk; then
  echo "WARN: build failed — retrying once after cleaning partial SDK downloads"
  SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/usr/local/lib/android/sdk}}"
  rm -rf "$SDK"/ndk/*.temp "$SDK"/.temp "$SDK"/temp 2>/dev/null || true
  sleep 20
  build_apk || exit 1
fi
mkdir -p ../dist && cp build/app/outputs/flutter-apk/app-release.apk ../dist/novaki.apk
ls -la ../dist
step "BUILD OK"
