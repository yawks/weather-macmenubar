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
BACKGROUND=""
DAY_MODE=""

usage() {
    cat <<'USAGE'
Usage: ./scripts/build.sh [options]

Options:
  --run          Build then launch the app
  --clean        Remove build artifacts before building
  --logs         After launching, stream app logs to console (requires --run)
  --background X Force the animated background: clear, cloudy, rain, drizzle,
                 snow, thunderstorm, or atmosphere (implies --run)
  --day          Force the daytime palette (implies --run)
  --night        Force the nighttime palette (implies --run)
  -h, --help     Show this help

Examples:
  ./scripts/build.sh
  ./scripts/build.sh --run
  ./scripts/build.sh --run --logs
  ./scripts/build.sh --clean --run --logs
  ./scripts/build.sh --background rain --day
  ./scripts/build.sh --background thunderstorm --night --logs
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run)   RUN_APP=1 ;;
        --clean) CLEAN=1 ;;
        --logs)  FOLLOW_LOGS=1 ;;
        --background)
            if [[ $# -lt 2 ]]; then
                echo "Missing value after --background" >&2
                usage
                exit 1
            fi
            BACKGROUND="$2"
            case "$BACKGROUND" in
                clear|cloudy|rain|drizzle|snow|thunderstorm|atmosphere) ;;
                *)
                    echo "Unknown background: $BACKGROUND" >&2
                    echo "Expected: clear, cloudy, rain, drizzle, snow, thunderstorm, atmosphere" >&2
                    exit 1
                    ;;
            esac
            RUN_APP=1
            shift
            ;;
        --day)
            DAY_MODE="day"
            RUN_APP=1
            ;;
        --night)
            DAY_MODE="night"
            RUN_APP=1
            ;;
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
    SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG \
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

    BINARY="$APP_PATH/Contents/MacOS/WeatherBar"
    APP_ARGS=()
    if [[ -n "$BACKGROUND" ]]; then
        APP_ARGS+=(--weather-background "$BACKGROUND")
    fi
    if [[ "$DAY_MODE" == "day" ]]; then
        APP_ARGS+=(--weather-day)
    elif [[ "$DAY_MODE" == "night" ]]; then
        APP_ARGS+=(--weather-night)
    fi

    if [[ -n "$BACKGROUND" || -n "$DAY_MODE" ]]; then
        echo "→ Aperçu forcé : ${BACKGROUND:-météo actuelle}, ${DAY_MODE:-heure actuelle}"

        # A menu-bar app may already be running invisibly. Stop the previous
        # debug instance so there is only one status item and the new launch
        # arguments are guaranteed to be used.
        if pgrep -x WeatherBar >/dev/null 2>&1; then
            echo "→ Arrêt de l'instance WeatherBar précédente..."
            pkill -x WeatherBar
            for _ in {1..20}; do
                if ! pgrep -x WeatherBar >/dev/null 2>&1; then
                    break
                fi
                sleep 0.1
            done
        fi
    fi

    if [[ $FOLLOW_LOGS -eq 1 ]]; then
        echo "→ Lancement avec logs en direct (Ctrl+C pour arrêter) :"
        echo ""
        "$BINARY" "${APP_ARGS[@]}"
    else
        echo "→ Lancement de l'application..."
        if [[ ${#APP_ARGS[@]} -gt 0 ]]; then
            open "$APP_PATH" --args "${APP_ARGS[@]}"
        else
            open "$APP_PATH"
        fi
    fi
fi
