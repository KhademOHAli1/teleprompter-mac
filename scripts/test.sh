#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"
require_toolchain
test_dir="$(mktemp -d "$BUILD_ROOT/tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
compile_swift -O "$PROJECT_ROOT/Sources/Localization.swift" "$PROJECT_ROOT/Sources/Alignment.swift" \
  "$PROJECT_ROOT/Tests/AlignmentTests.swift" -o "$test_dir/alignment-tests"
"$test_dir/alignment-tests"
compile_swift -O "$PROJECT_ROOT/Sources/Localization.swift" "$PROJECT_ROOT/Sources/VoiceQuality.swift" \
  "$PROJECT_ROOT/Tests/VoiceQualityTests.swift" -o "$test_dir/voice-quality-tests"
"$test_dir/voice-quality-tests"
compile_swift -O "$PROJECT_ROOT/Sources/Localization.swift" "$PROJECT_ROOT/Sources/Alignment.swift" "$PROJECT_ROOT/Sources/RealtimeConfiguration.swift" \
  "$PROJECT_ROOT/Tests/RealtimeConfigurationTests.swift" -o "$test_dir/realtime-tests"
"$test_dir/realtime-tests"
compile_swift -O "$PROJECT_ROOT/Sources/Localization.swift" "$PROJECT_ROOT/Sources/Alignment.swift" \
  "$PROJECT_ROOT/Tests/LocalizationTests.swift" -o "$test_dir/localization-tests"
"$test_dir/localization-tests" "$PROJECT_ROOT/Resources"
