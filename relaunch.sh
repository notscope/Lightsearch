#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h}"
BUILD_DIR="${BUILD_DIR:-build-nits}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_PATH="$PROJECT_ROOT/$BUILD_DIR/Build/Products/$CONFIGURATION/Lightsearch.app"

cd "$PROJECT_ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "Building Lightsearch..."
xcodebuild -quiet \
  -project "$PROJECT_ROOT/Lightsearch.xcodeproj" \
  -scheme Lightsearch \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR" \
  ENABLE_USER_SCRIPT_SANDBOXING=NO \
  ENABLE_PREVIEWS=NO \
  build

echo "Stopping the previous Lightsearch instance..."
osascript -e 'tell application id "io.notscope.Lightsearch" to quit' >/dev/null 2>&1 || true

for ((attempt = 0; attempt < 50; attempt++)); do
  if ! pgrep -x Lightsearch >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

if pgrep -x Lightsearch >/dev/null 2>&1; then
  echo "Lightsearch did not quit within 5 seconds." >&2
  exit 1
fi

echo "Launching $APP_PATH..."
open "$APP_PATH"
echo "Lightsearch relaunched."
