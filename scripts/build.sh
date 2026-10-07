#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"
require_toolchain

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [output-app-path]" >&2
  exit 1
fi
destination="${1:-"$PROJECT_ROOT/dist/Teleprompter.app"}"
bundle_id="${TELEPROMPTER_BUNDLE_ID:-de.local.teleprompter}"
if [[ ! "$bundle_id" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  echo "TELEPROMPTER_BUNDLE_ID must be a reverse-DNS identifier." >&2
  exit 1
fi
mkdir -p "$BUILD_ROOT" "$(dirname "$destination")"
staging="$(mktemp -d "$BUILD_ROOT/bundle.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
# A plain staging name avoids synthetic Finder metadata on .app directories
# inside file-provider folders. Sign and verify before copying the bundle.
bundle="$staging/Bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
compile_swift -O "$PROJECT_ROOT"/Sources/*.swift -o "$bundle/Contents/MacOS/Teleprompter"
cp "$PROJECT_ROOT/Info.plist" "$bundle/Contents/Info.plist"
cp "$PROJECT_ROOT/LICENSE" "$bundle/Contents/Resources/LICENSE"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$bundle/Contents/Info.plist"
xattr -cr "$bundle"
codesign --force --sign - --identifier "$bundle_id" --timestamp=none "$bundle"
codesign --verify --deep --strict "$bundle"
ditto --norsrc "$bundle" "$destination"
echo "Built: $destination"
