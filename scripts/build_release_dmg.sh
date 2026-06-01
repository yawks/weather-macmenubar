#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# build_release_dmg.sh
# Compile le projet Xcode en Release et crée un DMG compressé.
# Exemples d'utilisation :
#  ./scripts/build_release_dmg.sh
#  ./scripts/build_release_dmg.sh --dry-run
#  ./scripts/build_release_dmg.sh --no-clean --dmg-name WeatherBar --output ./dist/WeatherBar.dmg
#  CODESIGN_ID="Developer ID Application: Nom (TEAMID)" ./scripts/build_release_dmg.sh --sign

PROJECT="WeatherBar.xcodeproj"
SCHEME="WeatherBar"
CONFIG="Release"
BUILD_DIR="$(pwd)/build/${CONFIG}"
APP_NAME="WeatherBar.app"
APP_BUNDLE_PATH="$BUILD_DIR/$APP_NAME"
DMG_NAME="${DMG_NAME:-WeatherBar}"
DMG_OUTPUT="${DMG_OUTPUT:-$HOME/Desktop/${DMG_NAME}.dmg}"
STAGING_DIR="$(pwd)/dist/staging"

DRY_RUN=0
CLEAN=1
CODESIGN_ID="${CODESIGN_ID:-}"

show_help() {
  cat <<EOF
Usage: $0 [--dry-run] [--no-clean] [--dmg-name NAME] [--output PATH] [--sign]

Options:
  --dry-run         Affiche les commandes sans les exécuter.
  --no-clean        Ignore l'étape 'xcodebuild clean'.
  --dmg-name NAME   Nom du volume DMG (défaut : WeatherBar).
  --output PATH     Chemin de sortie du DMG (défaut : ~/Desktop/<nom>.dmg).
  --sign            Signe le .app si CODESIGN_ID est défini dans l'environnement.
  --help            Affiche cette aide.

Environnement :
  CODESIGN_ID       Identité de signature, ex. "Developer ID Application: Nom (TEAMID)".

Exemples :
  $0
  CODESIGN_ID="Developer ID Application: Foo (TEAMID)" $0 --sign --dmg-name WeatherBar
  $0 --dry-run
EOF
}

run() {
  echo "+ $*"
  if [[ $DRY_RUN -eq 0 ]]; then
    eval "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=1; shift ;;
    --no-clean) CLEAN=0; shift ;;
    --dmg-name) DMG_NAME="$2"; DMG_OUTPUT="$HOME/Desktop/${DMG_NAME}.dmg"; shift 2 ;;
    --output)   DMG_OUTPUT="$2"; shift 2 ;;
    --sign)     shift ;; # CODESIGN_ID lu depuis l'environnement
    --help)     show_help; exit 0 ;;
    *) echo "Option inconnue : $1"; show_help; exit 1 ;;
  esac
done

echo "Projet    : $PROJECT"
echo "Scheme    : $SCHEME"
echo "Config    : $CONFIG"
echo "Build dir : $BUILD_DIR"
echo "App       : $APP_BUNDLE_PATH"
echo "DMG       : $DMG_OUTPUT"
echo

if [[ $CLEAN -eq 1 ]]; then
  run xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" clean
fi

run xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" build

if [[ $DRY_RUN -eq 0 && ! -d "$APP_BUNDLE_PATH" ]]; then
  echo "Erreur : app introuvable à $APP_BUNDLE_PATH" >&2
  exit 2
fi

run rm -rf "$STAGING_DIR"
run mkdir -p "$STAGING_DIR"
run cp -R "$APP_BUNDLE_PATH" "$STAGING_DIR/"

if [[ -n "$CODESIGN_ID" ]]; then
  echo "Signature avec : $CODESIGN_ID"
  run codesign --deep --force --timestamp --sign "$CODESIGN_ID" "$STAGING_DIR/$APP_NAME"
fi

echo "Création du DMG..."
run hdiutil create -volname "$DMG_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_OUTPUT"

if [[ $DRY_RUN -eq 0 ]]; then
  echo "Terminé. DMG écrit dans : $DMG_OUTPUT"
else
  echo "Dry-run : aucun DMG créé. Relancez sans --dry-run pour exécuter."
fi

exit 0
