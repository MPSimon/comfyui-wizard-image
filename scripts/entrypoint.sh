#!/usr/bin/env bash
set -euo pipefail

COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
COMFY_PORT="${COMFY_PORT:-8188}"
COMFY_BIND="${COMFY_BIND:-0.0.0.0}"
COMFY_ARGS="${COMFY_ARGS:-}"

if [ ! -d "$COMFY_ROOT" ]; then
  echo "[entrypoint] Initializing ComfyUI into $COMFY_ROOT"
  mkdir -p "$(dirname "$COMFY_ROOT")"
  rsync -a --delete /opt/ComfyUI/ "$COMFY_ROOT/"
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  if ! nvidia-smi >/dev/null 2>&1; then
    echo "[entrypoint] WARNING: nvidia-smi detected but GPU not available to container."
  fi
else
  echo "[entrypoint] WARNING: nvidia-smi missing in runtime path."
fi

cd "$COMFY_ROOT"
exec python main.py --listen "$COMFY_BIND" --port "$COMFY_PORT" --disable-auto-launch $COMFY_ARGS
