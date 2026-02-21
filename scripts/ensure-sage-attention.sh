#!/usr/bin/env bash
set -euo pipefail

SAGE3_SRC="/opt/SageAttention/sageattention3_blackwell"

python - <<'PY'
import importlib.util
import torch

cuda_ok = torch.cuda.is_available()
cc = torch.cuda.get_device_capability(0) if cuda_ok else None
print(f"[comfyui-wizard-image] torch={torch.__version__} cuda={torch.version.cuda} cuda_available={cuda_ok} cc={cc}")
print(f"[comfyui-wizard-image] sageattention_installed={importlib.util.find_spec('sageattention') is not None}")
print(f"[comfyui-wizard-image] sageattn3_installed={importlib.util.find_spec('sageattn3') is not None}")
PY

if ! python - <<'PY'
import torch
if not torch.cuda.is_available():
    raise SystemExit(1)
major, _minor = torch.cuda.get_device_capability(0)
raise SystemExit(0 if major >= 12 else 1)
PY
then
  echo "[comfyui-wizard-image] SageAttention3 bootstrap skipped (non-Blackwell or CUDA unavailable)"
  exit 0
fi

if python - <<'PY'
import importlib.util
raise SystemExit(0 if importlib.util.find_spec("sageattn3") else 1)
PY
then
  echo "[comfyui-wizard-image] SageAttention3 already installed"
  exit 0
fi

if [[ ! -d "$SAGE3_SRC" ]]; then
  echo "[comfyui-wizard-image] WARNING: SageAttention3 source not found at $SAGE3_SRC"
  exit 0
fi

echo "[comfyui-wizard-image] Installing SageAttention3 for Blackwell from $SAGE3_SRC"
export FAHOPPER_FORCE_BUILD=TRUE
export MAX_JOBS="${SAGE_MAX_JOBS:-8}"
python -m pip install -v --no-build-isolation "$SAGE3_SRC" || {
  echo "[comfyui-wizard-image] WARNING: SageAttention3 install failed; use non-sageattn_3 attention mode until fixed"
  exit 0
}

python - <<'PY'
import importlib
import torch
importlib.import_module("sageattn3")
print(f"[comfyui-wizard-image] SageAttention3 OK on cc={torch.cuda.get_device_capability(0)}")
print("[comfyui-wizard-image] For RTX 50xx, set Wan attention_mode to 'sageattn_3'")
PY
