#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
PROJECT="$ROOT_DIR/WeatherBar.xcodeproj"
BUILD_DIR="$ROOT_DIR/.build/derived-data"
APP_PATH="$BUILD_DIR/Build/Products/Debug/WeatherBar.app"
LOG_FILE="$ROOT_DIR/.build/build.log"
RUN_APP=0
CLEAN=0
FOLLOW_LOGS=0

usage() {
    cat <<'USAGE'
Usage: ./scripts/build.sh [options]

Options:
  --run          Build then launch the app
  --clean        Remove build artifacts before building
  --logs         After launching, stream app logs to console (requires --run)
  -h, --help     Show this help

Examples:
  ./scripts/build.sh
  ./scripts/build.sh --run
  ./scripts/build.sh --run --logs
  ./scripts/build.sh --clean --run --logs
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run)   RUN_APP=1 ;;
        --clean) CLEAN=1 ;;
        --logs)  FOLLOW_LOGS=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

mkdir -p "$(dirname "$LOG_FILE")"

if [[ $CLEAN -eq 1 ]]; then
    echo "→ Nettoyage des artefacts..."
    rm -rf "$BUILD_DIR"
fi

echo "→ Compilation en cours..."
echo "  Projet : $PROJECT"
echo "  Logs   : $LOG_FILE"
echo ""

xcodebuild \
    -project "$PROJECT" \
    -scheme WeatherBar \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    2>&1 | tee "$LOG_FILE"

BUILD_STATUS=${pipestatus[1]}

if [[ $BUILD_STATUS -ne 0 ]]; then
    echo ""
    echo "✗ Compilation échouée (code $BUILD_STATUS). Voir : $LOG_FILE" >&2
    exit $BUILD_STATUS
fi

echo ""
echo "✓ Compilation réussie → $APP_PATH"

if [[ $RUN_APP -eq 1 ]]; then
    if [[ ! -d "$APP_PATH" ]]; then
        echo "✗ App introuvable : $APP_PATH" >&2
        exit 1
    fi

    echo "→ Lancement de l'application..."
    open "$APP_PATH"

    if [[ $FOLLOW_LOGS -eq 1 ]]; then
        echo "→ Logs en direct (Ctrl+C pour arrêter) :"
        echo ""
        log stream --predicate 'subsystem == "com.local.WeatherBar" OR process == "WeatherBar"' --level debug
    fi
fi
