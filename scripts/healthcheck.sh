#!/usr/bin/env bash
set -euo pipefail

PORT="${COMFY_PORT:-8188}"
curl --fail --silent --show-error "http://127.0.0.1:${PORT}/system_stats" >/dev/null
