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
SAGE_BOOTSTRAP="/usr/local/lib/comfywizard/ensure-sage-attention.sh"
WORKSPACE_LAUNCHER="/workspace/sync-workflow.sh"
GLOBAL_LAUNCHER="/usr/local/bin/sync-workflow"
HF_HELPER_SOURCE="/usr/local/lib/comfywizard/hf-model.sh"
CIVITAI_HELPER_SOURCE="/usr/local/lib/comfywizard/civitai-model.sh"
WORKSPACE_HF_HELPER="/workspace/hf-model.sh"
WORKSPACE_CIVITAI_HELPER="/workspace/civitai-model.sh"
GLOBAL_HF_HELPER="/usr/local/bin/hf-model"
GLOBAL_CIVITAI_HELPER="/usr/local/bin/civitai-model"
SSH_DIR="/root/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

append_unique_keys() {
  local key_block="$1"

  if [[ -z "${key_block}" ]]; then
    return 0
  fi

  while IFS= read -r key_line; do
    [[ -z "${key_line// }" ]] && continue
    if [[ ! -f "$AUTHORIZED_KEYS" ]] || ! grep -Fxq "$key_line" "$AUTHORIZED_KEYS"; then
      printf '%s\n' "$key_line" >> "$AUTHORIZED_KEYS"
    fi
  done <<< "$key_block"
}

start_sshd() {
  echo "[comfyui-wizard-image] Preparing SSH daemon"
  mkdir -p "$SSH_DIR" /run/sshd
  chmod 700 "$SSH_DIR"
  touch "$AUTHORIZED_KEYS"

  # Keep RunPod-injected keys and append env keys without duplicates.
  append_unique_keys "${PUBLIC_KEY:-}"
  append_unique_keys "${SSH_PUBLIC_KEY:-}"
  chmod 600 "$AUTHORIZED_KEYS"

  if [[ ! -s "$AUTHORIZED_KEYS" ]]; then
    echo "[comfyui-wizard-image] WARNING: /root/.ssh/authorized_keys is empty; SSH login may fail until keys are injected."
  fi

  ssh-keygen -A >/dev/null 2>&1 || true
  /usr/sbin/sshd -D >/tmp/sshd.log 2>&1 &
  SSHD_PID=$!

  sleep 1
  if ! kill -0 "$SSHD_PID" >/dev/null 2>&1; then
    echo "[comfyui-wizard-image] ERROR: sshd failed to start. See /tmp/sshd.log" >&2
    exit 1
  fi
}

start_tools_ui() {
  export SHELL=/bin/bash

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
    --ServerApp.terminals_enabled=True \
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

  if [[ -x "$HF_HELPER_SOURCE" ]]; then
    ln -sf "$HF_HELPER_SOURCE" "$WORKSPACE_HF_HELPER"
    ln -sf "$WORKSPACE_HF_HELPER" /root/hf-model.sh
    ln -sf "$WORKSPACE_HF_HELPER" "$GLOBAL_HF_HELPER"
  else
    echo "[comfyui-wizard-image] WARNING: missing HF helper script at $HF_HELPER_SOURCE"
  fi

  if [[ -x "$CIVITAI_HELPER_SOURCE" ]]; then
    ln -sf "$CIVITAI_HELPER_SOURCE" "$WORKSPACE_CIVITAI_HELPER"
    ln -sf "$WORKSPACE_CIVITAI_HELPER" /root/civitai-model.sh
    ln -sf "$WORKSPACE_CIVITAI_HELPER" "$GLOBAL_CIVITAI_HELPER"
  else
    echo "[comfyui-wizard-image] WARNING: missing CivitAI helper script at $CIVITAI_HELPER_SOURCE"
  fi
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

if [[ -x "$SAGE_BOOTSTRAP" ]]; then
  "$SAGE_BOOTSTRAP"
fi

write_launchers
start_sshd
start_tools_ui

echo "[comfyui-wizard-image] ComfyWizard launcher contract: runpod-launch.sh (full repo extraction + wizard)"
echo "[comfyui-wizard-image] Run wizard: sync-workflow (or /workspace/sync-workflow.sh)"
echo "[comfyui-wizard-image] HF helper: hf-model (or /workspace/hf-model.sh)"
echo "[comfyui-wizard-image] CivitAI helper: civitai-model (or /workspace/civitai-model.sh)"
echo "[comfyui-wizard-image] ComfyUI: http://<pod>:8188"
echo "[comfyui-wizard-image] SSH/SCP/SFTP: tcp://<public-ip>:<mapped-port> -> :22"
echo "[comfyui-wizard-image] code-server: http://<pod>:8888"
echo "[comfyui-wizard-image] JupyterLab: http://<pod>:8889"
echo "[comfyui-wizard-image] Fixed defaults: COMFY_ROOT=${COMFY_ROOT}, COMFY_PORT=${COMFY_PORT}, COMFYWIZARD_REPO=${COMFYWIZARD_REPO}, COMFYWIZARD_BRANCH=${COMFYWIZARD_BRANCH}, COMFYWIZARD_CHECKOUT=${COMFYWIZARD_CHECKOUT}"

echo "[comfyui-wizard-image] Starting ComfyUI on ${COMFY_BIND}:${COMFY_PORT}"
cd "$COMFY_ROOT"
exec python main.py --listen "$COMFY_BIND" --port "$COMFY_PORT" --disable-auto-launch $COMFY_ARGS
