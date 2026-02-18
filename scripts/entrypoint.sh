#!/usr/bin/env bash
set -euo pipefail

COMFY_ROOT="/workspace/ComfyUI"
COMFY_PORT="8188"
COMFY_BIND="0.0.0.0"
COMFY_ARGS=""
COMFYWIZARD_REPO="https://github.com/MPSimon/ComfyWizard.git"
COMFYWIZARD_BRANCH="main"
COMFYWIZARD_CHECKOUT="/root/.comfywizard"
RUNPOD_LAUNCHER="/usr/local/lib/comfywizard/runpod-launch.sh"
WORKSPACE_LAUNCHER="/workspace/sync-workflow.sh"
GLOBAL_LAUNCHER="/usr/local/bin/sync-workflow"

start_tools_ui() {
  echo "[comfyui-wizard-image] Starting code-server on 0.0.0.0:8888 (auth=none)"
  code-server \
    --bind-addr 0.0.0.0:8888 \
    --auth none \
    /workspace \
    >/tmp/code-server.log 2>&1 &
  CODE_SERVER_PID=$!

  echo "[comfyui-wizard-image] Starting JupyterLab on 0.0.0.0:8889 (no auth)"
  jupyter lab \
    --ip=0.0.0.0 \
    --port=8889 \
    --allow-root \
    --no-browser \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --notebook-dir=/workspace \
    >/tmp/jupyter.log 2>&1 &
  JUPYTER_PID=$!

  if ! kill -0 "$CODE_SERVER_PID" >/dev/null 2>&1; then
    echo "[comfyui-wizard-image] ERROR: code-server failed to start. See /tmp/code-server.log" >&2
    exit 1
  fi
  if ! kill -0 "$JUPYTER_PID" >/dev/null 2>&1; then
    echo "[comfyui-wizard-image] ERROR: JupyterLab failed to start. See /tmp/jupyter.log" >&2
    exit 1
  fi
}

write_launchers() {
  cat > "$WORKSPACE_LAUNCHER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /usr/local/lib/comfywizard/runpod-launch.sh "$@"
EOF
  chmod +x "$WORKSPACE_LAUNCHER"
  ln -sf "$WORKSPACE_LAUNCHER" /root/sync-workflow.sh
  ln -sf "$WORKSPACE_LAUNCHER" "$GLOBAL_LAUNCHER"
}

if [[ -z "${ARTIFACT_AUTH:-}" ]]; then
  echo "[comfyui-wizard-image] ERROR: ARTIFACT_AUTH is required for RunPod launcher flow." >&2
  exit 1
fi

if [ ! -d "$COMFY_ROOT" ]; then
  echo "[comfyui-wizard-image] Initializing ComfyUI into $COMFY_ROOT"
  mkdir -p "$(dirname "$COMFY_ROOT")"
  rsync -a --delete /opt/ComfyUI/ "$COMFY_ROOT/"
fi

if command -v nvidia-smi >/dev/null 2>&1 && ! nvidia-smi >/dev/null 2>&1; then
  echo "[comfyui-wizard-image] WARNING: nvidia-smi present but GPU not visible to container"
fi

write_launchers
start_tools_ui

echo "[comfyui-wizard-image] ComfyWizard launcher contract: runpod-launch.sh (full repo extraction + wizard)"
echo "[comfyui-wizard-image] Run wizard: sync-workflow (or /workspace/sync-workflow.sh)"
echo "[comfyui-wizard-image] ComfyUI: http://<pod>:8188"
echo "[comfyui-wizard-image] code-server: http://<pod>:8888"
echo "[comfyui-wizard-image] JupyterLab: http://<pod>:8889"
echo "[comfyui-wizard-image] Fixed defaults: COMFY_ROOT=${COMFY_ROOT}, COMFY_PORT=${COMFY_PORT}, COMFYWIZARD_REPO=${COMFYWIZARD_REPO}, COMFYWIZARD_BRANCH=${COMFYWIZARD_BRANCH}, COMFYWIZARD_CHECKOUT=${COMFYWIZARD_CHECKOUT}"

echo "[comfyui-wizard-image] Starting ComfyUI on ${COMFY_BIND}:${COMFY_PORT}"
cd "$COMFY_ROOT"
exec python main.py --listen "$COMFY_BIND" --port "$COMFY_PORT" --disable-auto-launch $COMFY_ARGS
