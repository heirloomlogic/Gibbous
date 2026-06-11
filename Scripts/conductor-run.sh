#!/usr/bin/env bash
#
# Conductor "Run" script for Gibbous.
#
# Builds the macOS app for this workspace into a workspace-local DerivedData
# directory, then launches the freshly built .app bundle. Invoked by the
# Conductor Run button; runs from the workspace directory in a non-interactive
# shell, so all toolchain flags are passed explicitly rather than relying on
# shell startup.
set -euo pipefail

SCHEME="Gibbous"
PROJECT="Gibbous.xcodeproj"
CONFIGURATION="Debug"
DERIVED_DATA="${CONDUCTOR_WORKSPACE_PATH:-$PWD}/.context/DerivedData"

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

echo "Launching ${APP_PATH}..."
# -n forces a fresh instance; -W keeps the script attached so Conductor's stop
# signal (SIGHUP) tears the app down with the run.
exec open -n -W "$APP_PATH"
