#!/usr/bin/env bash
# Export Android (APK arm64-v8a), séparé des exports PC (tools/build_release.sh).
# Usage : tools/build_android.sh [--debug] [--install]
#   --debug   : APK de debug signé avec ~/.android/debug.keystore (tests uniquement)
#   --install : installe l'APK sur le téléphone branché (adb install -r)
# Release : signée avec la clé de publication. Ses chemins et mots de passe sont lus dans
# ~/.android/lamaisongagne-release.env (variables GODOT_ANDROID_KEYSTORE_RELEASE_*), hors dépôt.
set -euo pipefail
cd "$(dirname "$0")/.."
SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
BT="$SDK/build-tools/$(ls "$SDK/build-tools" | sort -V | tail -1)"
ADB="$SDK/platform-tools/adb"
export JAVA_HOME="${JAVA_HOME:-$HOME/.local/jdk/jdk17}"
MODE=release
INSTALL=0
for a in "$@"; do
	case "$a" in
		--debug) MODE=debug ;;
		--install) INSTALL=1 ;;
		*) echo "option inconnue : $a" >&2; exit 2 ;;
	esac
done

VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
IFS=. read -r MA MI PA <<<"$VERSION"
CODE=$((MA * 10000 + MI * 100 + PA))
# Version de l'APK = version du jeu (versionCode croissant : majeur×10000 + mineur×100 + correctif).
sed -i -e "s/^version\/code=.*/version\/code=$CODE/" -e "s/^version\/name=.*/version\/name=\"$VERSION\"/" export_presets.cfg

if [[ $MODE == release ]]; then
	ENVF="$HOME/.android/lamaisongagne-release.env"
	[[ -r "$ENVF" ]] || { echo "Clé de publication introuvable ($ENVF)" >&2; exit 1; }
	# shellcheck disable=SC1090
	source "$ENVF"
fi

OUT_DIR=build/android
mkdir -p "$OUT_DIR" && touch build/.gdignore
APK="$OUT_DIR/LaMaisonGagne.apk"
rm -f "$APK"
godot --headless --path . --import >/dev/null 2>&1
echo "== Android $VERSION ($MODE, versionCode $CODE)"
godot --headless --path . "--export-$MODE" "Android" "$APK" 2>&1 | grep -E "ERROR|error:" || true
test -s "$APK" || { echo "Export Android échoué" >&2; exit 1; }

echo "== Vérifications"
"$BT/zipalign" -c -P 16 4 "$APK" && echo "alignement : OK"
"$BT/apksigner" verify --verbose --print-certs "$APK" 2>/dev/null | grep -E "Verified using v[123]|Signer #1 certificate DN|Number of signers"
"$BT/aapt2" dump badging "$APK" | grep -E "^package:|^sdkVersion|^targetSdkVersion|uses-permission|^native-code|application-label:"
SUFFIX=""
[[ $MODE == debug ]] && SUFFIX="-debug"
FINAL="build/LaMaisonGagne-$VERSION-android-arm64$SUFFIX.apk"
cp "$APK" "$FINAL"
ls -lh "$FINAL"

if [[ $INSTALL == 1 ]]; then
	"$ADB" install -r "$FINAL"
fi
