#!/usr/bin/env bash
set -euo pipefail

COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
COMFY_PORT="${COMFY_PORT:-8188}"
COMFY_BIND="${COMFY_BIND:-0.0.0.0}"
COMFY_ARGS="${COMFY_ARGS:-}"
COMFYWIZARD_REPO="${COMFYWIZARD_REPO:-https://github.com/MPSimon/ComfyWizard.git}"
COMFYWIZARD_BRANCH="${COMFYWIZARD_BRANCH:-main}"
COMFYWIZARD_CHECKOUT="${COMFYWIZARD_CHECKOUT:-/root/.comfywizard}"

fetch_latest_comfywizard() {
  if [ -d "$COMFYWIZARD_CHECKOUT/.git" ]; then
    git -C "$COMFYWIZARD_CHECKOUT" fetch --all --prune
    git -C "$COMFYWIZARD_CHECKOUT" checkout "$COMFYWIZARD_BRANCH"
    git -C "$COMFYWIZARD_CHECKOUT" pull --ff-only origin "$COMFYWIZARD_BRANCH"
  else
    rm -rf "$COMFYWIZARD_CHECKOUT"
    git clone --branch "$COMFYWIZARD_BRANCH" --single-branch "$COMFYWIZARD_REPO" "$COMFYWIZARD_CHECKOUT"
  fi

  if [ ! -x "$COMFYWIZARD_CHECKOUT/bin/wizard.sh" ]; then
    chmod +x "$COMFYWIZARD_CHECKOUT/bin/wizard.sh"
  fi
}

write_root_launcher() {
  cat > /root/sync-workflow.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec bash "${COMFYWIZARD_CHECKOUT}/bin/wizard.sh"
EOF
  chmod +x /root/sync-workflow.sh
}

if [ ! -d "$COMFY_ROOT" ]; then
  echo "[comfyui-wizard-image] Initializing ComfyUI into $COMFY_ROOT"
  mkdir -p "$(dirname "$COMFY_ROOT")"
  rsync -a --delete /opt/ComfyUI/ "$COMFY_ROOT/"
fi

if command -v nvidia-smi >/dev/null 2>&1 && ! nvidia-smi >/dev/null 2>&1; then
  echo "[comfyui-wizard-image] WARNING: nvidia-smi present but GPU not visible to container"
fi

echo "[comfyui-wizard-image] Pulling latest ComfyWizard from ${COMFYWIZARD_REPO} (${COMFYWIZARD_BRANCH})"
fetch_latest_comfywizard
write_root_launcher
echo "[comfyui-wizard-image] Run: /root/sync-workflow.sh"
echo "[comfyui-wizard-image] Advanced non-interactive sync: ${COMFYWIZARD_CHECKOUT}/bin/sync.sh --stack wan --workflow <workflow>"

echo "[comfyui-wizard-image] Starting ComfyUI on ${COMFY_BIND}:${COMFY_PORT}"
cd "$COMFY_ROOT"
exec python main.py --listen "$COMFY_BIND" --port "$COMFY_PORT" --disable-auto-launch $COMFY_ARGS
