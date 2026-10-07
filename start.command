#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
project_root="$(cd "$(dirname "$0")" && pwd)"
if [[ ! -d "$project_root/dist/Teleprompter.app" ]]; then
  "$project_root/scripts/build.sh"
fi
open "$project_root/dist/Teleprompter.app"
