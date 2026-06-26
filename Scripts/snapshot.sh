#!/usr/bin/env bash
#
# Snapshot script for Gibbous.
#
# Builds the macOS app (Debug) and launches it with the clock frozen at a fixed
# waxing-gibbous instant, so App Store / marketing screenshots all share one
# consistent moment in time. Open the menu-bar popover and capture the states you
# want (Moon, Settings, light/dark) with macOS screen capture — the Moon won't
# move between shots.
#
# Snapshot mode is driven entirely by the process environment (see SnapshotMode):
#   GIBBOUS_SNAPSHOT=1            turns snapshot mode on (set here)
#   GIBBOUS_SNAPSHOT_DATE=<ISO>  optional override of the frozen instant
#
# Usage:
#   Scripts/snapshot.sh                        # curated default (waxing gibbous)
#   Scripts/snapshot.sh 2025-09-04T03:00:00Z   # a custom ISO-8601 instant
set -euo pipefail

SCHEME="Gibbous"
PROJECT="Gibbous.xcodeproj"
CONFIGURATION="Debug"
DERIVED_DATA="${CONDUCTOR_WORKSPACE_PATH:-$PWD}/.context/DerivedData"
SNAPSHOT_DATE="${1:-}"

echo "Building ${SCHEME} (${CONFIGURATION}) for macOS..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  ENABLE_CODE_COVERAGE=NO \
  build

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$SCHEME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: built app not found at $APP_PATH" >&2
  exit 1
fi

# --env passes the flags through LaunchServices to the freshly launched app.
ENV_ARGS=(--env "GIBBOUS_SNAPSHOT=1")
if [[ -n "$SNAPSHOT_DATE" ]]; then
  ENV_ARGS+=(--env "GIBBOUS_SNAPSHOT_DATE=$SNAPSHOT_DATE")
  echo "Launching in snapshot mode, clock locked to ${SNAPSHOT_DATE}..."
else
  echo "Launching in snapshot mode, clock locked to the curated waxing-gibbous default..."
fi

# -n forces a fresh instance; -W keeps the script attached so a stop signal
# (SIGHUP) tears the app down with the run.
exec open -n -W "${ENV_ARGS[@]}" "$APP_PATH"
