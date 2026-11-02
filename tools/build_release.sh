#!/usr/bin/env bash
# Exports finaux autonomes : Windows (.exe, pck embarqué), Linux (binaire x86_64, pck embarqué)
# et Flatpak (bundle .flatpak, runtime org.freedesktop.Platform 25.08).
# Usage : tools/build_release.sh [--no-flatpak]
# Prérequis Flatpak : flatpak-builder et, une fois pour toutes,
#   flatpak install --user flathub org.freedesktop.Platform//25.08 org.freedesktop.Sdk//25.08
set -euo pipefail
cd "$(dirname "$0")/.."
APP_ID=io.github.jonasfreva.LaMaisonGagne
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)

godot --headless --path . --import >/dev/null 2>&1
mkdir -p build/linux build/windows build/flatpak && touch build/.gdignore
echo "== Linux $VERSION"
godot --headless --path . --export-release "Linux" build/linux/LaMaisonGagne.x86_64 2>&1 | grep -E "^ERROR" || true
echo "== Windows $VERSION"
godot --headless --path . --export-release "Windows" build/windows/LaMaisonGagne.exe 2>&1 | grep -E "^ERROR" || true
test -s build/linux/LaMaisonGagne.x86_64 && test -s build/windows/LaMaisonGagne.exe
(cd build/linux && tar -czf "../LaMaisonGagne-$VERSION-linux-x86_64.tar.gz" LaMaisonGagne.x86_64)
(cd build/windows && rm -f "../LaMaisonGagne-$VERSION-windows-x86_64.zip" && zip -q "../LaMaisonGagne-$VERSION-windows-x86_64.zip" LaMaisonGagne.exe)

if [[ "${1:-}" != "--no-flatpak" ]]; then
	echo "== Flatpak $VERSION"
	STATE=build/flatpak/.state
	flatpak-builder --user --force-clean --disable-rofiles-fuse --state-dir="$STATE" \
		--repo=build/flatpak/repo build/flatpak/app "packaging/flatpak/$APP_ID.yml" >/dev/null
	flatpak build-bundle --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
		build/flatpak/repo "build/LaMaisonGagne-$VERSION-x86_64.flatpak" "$APP_ID"
fi
ls -lh build/*.tar.gz build/*.zip build/*.flatpak 2>/dev/null
