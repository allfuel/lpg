#!/usr/bin/env bash
# Backward-compatible wrapper: builds for darwin-arm64.
# The generic orchestrator (build.sh) handles all platforms.
set -euo pipefail
export PLATFORM=darwin ARCH=arm64
exec "$(dirname "${BASH_SOURCE[0]}")/build.sh" "$@"
