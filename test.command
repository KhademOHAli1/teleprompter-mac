#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
exec "$(dirname "$0")/scripts/test.sh" "$@"
