#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${TELEPROMPTER_BUILD_DIR:-"$PROJECT_ROOT/.build"}"

require_toolchain() {
  if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "Teleprompter currently requires an Apple Silicon Mac." >&2
    exit 1
  fi
  local sdk_version
  sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
  if [[ "${sdk_version%%.*}" -lt 26 ]]; then
    echo "Select Xcode 26 or newer (macOS SDK 26+ is required)." >&2
    exit 1
  fi
  mkdir -p "$BUILD_ROOT/module-cache"
}

compile_swift() {
  xcrun --sdk macosx swiftc -swift-version 5 -warnings-as-errors \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$BUILD_ROOT/module-cache" \
    -target arm64-apple-macos26.0 -parse-as-library "$@"
}
