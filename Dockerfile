FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

ARG COMFYUI_REF=239ddd332724c63934bf517cfc6d0026214d8aee
ARG COMFYUI_MANAGER_REF=f41365abe95723d078ce2946e82dfb7bc6e9d9c7
ARG SAGEATTENTION_REF=d1a57a546c3d395b1ffcbeecc66d81db76f3b4b5
ARG SAGE_CUDA_ARCH_LIST=8.9
ARG SAGE_MAX_JOBS=8
ARG SAGE_EXT_PARALLEL=1
ARG SAGE_NVCC_THREADS=2
ARG IMAGE_SOURCE=https://github.com/MPSimon/comfyui-wizard-image

LABEL org.opencontainers.image.title="ComfyUI Wizard Image" \
      org.opencontainers.image.description="Private ComfyUI base with prebuilt SageAttention and latest-at-boot ComfyWizard UI launcher" \
      org.opencontainers.image.source="${IMAGE_SOURCE}"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    COMFY_SEED_ROOT=/opt/ComfyUI \
    TORCH_CUDA_ARCH_LIST=${SAGE_CUDA_ARCH_LIST} \
    MAX_JOBS=${SAGE_MAX_JOBS}

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-dev python3.12-venv python3-pip \
    git git-lfs curl ca-certificates jq tini rsync \
    openssh-server \
    build-essential ninja-build pkg-config \
    libgl1 libglib2.0-0 ffmpeg \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && python -m venv "$VIRTUAL_ENV" \
    && git lfs install \
    && mkdir -p /run/sshd \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip setuptools wheel \
    && pip install --index-url https://download.pytorch.org/whl/cu128 torch torchvision torchaudio \
    && pip install huggingface_hub==0.35.3 jupyterlab==4.4.0 terminado

RUN mkdir -p /etc/ssh/sshd_config.d \
    && cat > /etc/ssh/sshd_config.d/50-comfyui-wizard.conf <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
EOF

RUN curl -fsSL https://code-server.dev/install.sh | sh

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
    && export EXT_PARALLEL="$SAGE_EXT_PARALLEL" \
    && export MAX_JOBS="$SAGE_MAX_JOBS" \
    && export NVCC_APPEND_FLAGS="--threads ${SAGE_NVCC_THREADS}" \
    && set -e; \
       ( while true; do echo "[sageattention-build] compiling... $(date -u +%Y-%m-%dT%H:%M:%SZ)"; sleep 60; done ) & \
       SAGE_HEARTBEAT_PID=$!; \
       set +e; \
       pip install -v --no-build-isolation .; \
       SAGE_RC=$?; \
       set -e; \
       kill "$SAGE_HEARTBEAT_PID" >/dev/null 2>&1 || true; \
       wait "$SAGE_HEARTBEAT_PID" 2>/dev/null || true; \
       test "$SAGE_RC" -eq 0 \
    && rm -rf /tmp/SageAttention

RUN python - <<'PY'
import importlib
import torch
importlib.import_module("sageattention")
assert importlib.import_module("huggingface_hub")
print(torch.__version__)
PY

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY scripts/runpod-launch.sh /usr/local/lib/comfywizard/runpod-launch.sh
COPY scripts/hf-model.sh /usr/local/lib/comfywizard/hf-model.sh
COPY scripts/civitai-model.sh /usr/local/lib/comfywizard/civitai-model.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/lib/comfywizard/runpod-launch.sh /usr/local/lib/comfywizard/hf-model.sh /usr/local/lib/comfywizard/civitai-model.sh

WORKDIR /workspace
EXPOSE 22 8188 8888 8889
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=5 CMD ["/usr/local/bin/healthcheck.sh"]
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
