FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

ARG COMFYUI_REF=239ddd332724c63934bf517cfc6d0026214d8aee
ARG COMFYUI_MANAGER_REF=f41365abe95723d078ce2946e82dfb7bc6e9d9c7
ARG SAGEATTENTION_REF=d1a57a546c3d395b1ffcbeecc66d81db76f3b4b5
ARG COMFYWIZARD_REPO=https://github.com/MPSimon/ComfyWizard.git
ARG COMFYWIZARD_REF=1fb8d0387792cb00b8e6db76d4af3d08ccd00a21
ARG IMAGE_SOURCE=https://github.com/MPSimon/comfyui-wizard-image

LABEL org.opencontainers.image.title="ComfyUI Wizard Image" \
      org.opencontainers.image.description="Private ComfyUI base with prebuilt SageAttention and pinned ComfyWizard" \
      org.opencontainers.image.source="${IMAGE_SOURCE}"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    COMFY_SEED_ROOT=/opt/ComfyUI \
    COMFYWIZARD_HOME=/opt/ComfyWizard \
    COMFYWIZARD_REPO=${COMFYWIZARD_REPO}

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3-pip \
    git git-lfs curl ca-certificates jq tini rsync \
    build-essential ninja-build pkg-config \
    libgl1 libglib2.0-0 ffmpeg \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && python -m venv "$VIRTUAL_ENV" \
    && git lfs install \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip setuptools wheel \
    && pip install --index-url https://download.pytorch.org/whl/cu128 torch torchvision torchaudio \
    && pip install huggingface_hub==0.35.3

RUN git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_SEED_ROOT" \
    && cd "$COMFY_SEED_ROOT" \
    && git checkout "$COMFYUI_REF" \
    && pip install -r requirements.txt

RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$COMFY_SEED_ROOT/custom_nodes/ComfyUI-Manager" \
    && cd "$COMFY_SEED_ROOT/custom_nodes/ComfyUI-Manager" \
    && git checkout "$COMFYUI_MANAGER_REF" \
    && if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

RUN git clone https://github.com/thu-ml/SageAttention.git /tmp/SageAttention \
    && cd /tmp/SageAttention \
    && git checkout "$SAGEATTENTION_REF" \
    && pip install -e . \
    && rm -rf /tmp/SageAttention

RUN git clone "$COMFYWIZARD_REPO" "$COMFYWIZARD_HOME" \
    && cd "$COMFYWIZARD_HOME" \
    && git checkout "$COMFYWIZARD_REF" \
    && chmod +x bin/sync.sh bin/wizard.sh

RUN python - <<'PY'
import importlib
import torch
importlib.import_module("sageattention")
assert importlib.import_module("huggingface_hub")
print(torch.__version__)
PY

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY scripts/cw /usr/local/bin/cw
COPY scripts/cw-update-latest /usr/local/bin/cw-update-latest
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/cw /usr/local/bin/cw-update-latest

WORKDIR /workspace
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=5 CMD ["/usr/local/bin/healthcheck.sh"]
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
