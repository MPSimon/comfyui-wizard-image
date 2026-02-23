#!/usr/bin/env bash
set -Eeuo pipefail

API_BASE="${COMFYWIZARD_API_BASE:-https://www.comfywizard.tech}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage:
  workflow-install --workflow <slug> [--version <semver>] [--dry-run]

Examples:
  workflow-install --workflow sample --version 1.0.0
  workflow-install --workflow sample --dry-run
USAGE
  exit 0
fi

exec bash -c "curl -fsSL '${API_BASE%/}/api/install/script' | bash -s -- $*"
