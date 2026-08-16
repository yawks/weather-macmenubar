#!/bin/zsh
set -e
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
DEFAULT_OUTPUT_PROJECT="$ROOT_DIR/WeatherBar.xcodeproj"
DEFAULT_LOG_FILE="$ROOT_DIR/.build/logs/build.log"
OUTPUT_PROJECT="$DEFAULT_OUTPUT_PROJECT"
LOG_FILE="$DEFAULT_LOG_FILE"
RUN_APP=0
CLEAN=0

usage() {
    cat <<'USAGE'
Usage: ./scripts/build_weatherbar.sh [options]

Options:
  --run                  Build then launch the generated app
  --clean                Remove generated artifacts before building
  --output-dir PATH      Path to the generated .xcodeproj (default: WeatherBar.xcodeproj in repo root)
  --log-file PATH        Write build output to a custom log file (default: .build/logs/build.log)
  -h, --help             Show this help

Examples:
  ./scripts/build_weatherbar.sh
  ./scripts/build_weatherbar.sh --run --log-file ./build.log
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run)
            RUN_APP=1
            ;;
        --clean)
            CLEAN=1
            ;;
        --output-dir)
            shift
            if [[ -z "$1" ]]; then
                echo "--output-dir requires a path" >&2
                exit 1
            fi
            OUTPUT_PROJECT="$1"
            ;;
        --log-file)
            shift
            if [[ -z "$1" ]]; then
                echo "--log-file requires a path" >&2
                exit 1
            fi
            LOG_FILE="$1"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
 done

mkdir -p "$(dirname "$OUTPUT_PROJECT")"

if [[ $CLEAN -eq 1 ]]; then
    rm -rf "$OUTPUT_PROJECT" "$ROOT_DIR/.build" "$ROOT_DIR/Info.plist"
fi

mkdir -p "$(dirname "$LOG_FILE")"

PYTHON_BIN="$(command -v python3 || command -v python)"
if [[ -z "$PYTHON_BIN" ]]; then
    echo "python3 is required to generate the Xcode project." >&2
    exit 1
fi

"$PYTHON_BIN" "$ROOT_DIR/scripts/generate_xcode_project.py" "$OUTPUT_PROJECT" "$ROOT_DIR"

: > "$LOG_FILE"

BUILD_DIR="$ROOT_DIR/.build/derived-data"
APP_PATH="$BUILD_DIR/Build/Products/Debug/WeatherBar.app"

xcodebuild -project "$OUTPUT_PROJECT" -scheme WeatherBar -configuration Debug -derivedDataPath "$BUILD_DIR" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | tee "$LOG_FILE"
BUILD_STATUS=${pipestatus[1]}

if [[ $BUILD_STATUS -ne 0 ]]; then
    echo "Build failed. See $LOG_FILE" >&2
    exit $BUILD_STATUS
fi

if [[ $RUN_APP -eq 1 ]]; then
    if [[ ! -d "$APP_PATH" ]]; then
        echo "Built app not found: $APP_PATH" >&2
        exit 1
    fi
    open "$APP_PATH"
    echo "Launched $APP_PATH"
fi

echo "Projet généré dans $OUTPUT_PROJECT"
echo "Logs dans $LOG_FILE"
