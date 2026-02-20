# ComfyUI Wizard Image

Private, re-owned ComfyUI base image for WAN workflows.

## ComfyWizard does
- Sync workflow-selected artifacts into ComfyUI folders.
- Resolve workflow HF requirements and download missing files.
- Activate selected workflow JSON in ComfyUI.

## ComfyWizard does not
- Install ComfyUI itself.
- Compile heavy runtime components.
- Manage Docker image lifecycle.

## Docker image should
- Ship ComfyUI + ComfyUI-Manager preinstalled.
- Ship SageAttention prebuilt for fast cold boot.
- Include `hf` CLI support through `huggingface_hub`.
- Run ComfyWizard through `runpod-launch.sh` (full repo extraction + wizard from extracted root).
- Start SSH daemon for direct TCP SSH/SCP/SFTP on internal port `22`.
- Start ComfyUI on `8188`, code-server on `8888`, and JupyterLab on `8889`.

## Startup flow
1. Container starts.
2. Requires `ARTIFACT_AUTH` to be present.
3. Seed ComfyUI is copied to `/workspace/ComfyUI` if missing.
4. Launcher `/workspace/sync-workflow.sh` is created, and `sync-workflow` command is available globally.
5. SSH keys are reconciled from existing `/root/.ssh/authorized_keys` plus `PUBLIC_KEY` / `SSH_PUBLIC_KEY` (deduplicated append).
6. `sshd` starts on internal port `22` (key-only auth, root password login disabled).
7. code-server starts on `0.0.0.0:8888` (auth disabled).
8. JupyterLab starts on `0.0.0.0:8889` (token/password disabled, terminals enabled).
9. ComfyUI starts on `0.0.0.0:8188`.

## Commands
- `sync-workflow` (recommended, runs `runpod-launch.sh` flow)
- `/workspace/sync-workflow.sh`
- `hf-model` (download a single HF file from repo-id+path or URL)
- `/workspace/hf-model.sh`
- `civitai-model` (download from CivitAI model/version id or URL)
- `/workspace/civitai-model.sh`

## Contract
- Hardcoded defaults (non-configurable):
  - `COMFY_ROOT=/workspace/ComfyUI`
  - `COMFY_PORT=8188`
  - `COMFYWIZARD_REPO=https://github.com/MPSimon/ComfyWizard.git`
  - `COMFYWIZARD_BRANCH=main`
  - `COMFYWIZARD_CHECKOUT=/root/.comfywizard`
- Required env:
  - `ARTIFACT_AUTH`
- Optional env:
  - `HF_HUB_ENABLE_HF_TRANSFER=1`
  - `HF_TOKEN` (for gated/private Hugging Face repos)
  - `CIVITAI_TOKEN` (for gated/private CivitAI downloads)

## RunPod template
- Image: `docker.io/mpsimon/comfyui-wizard-image:latest`
- Expose ports: `22`, `8188`, `8888`, `8889`
- Set env:
  - `ARTIFACT_AUTH=<RunPod Secret>`
  - `HF_HUB_ENABLE_HF_TRANSFER=1` (optional)
  - `HF_TOKEN=<HF token>` (optional)
  - `CIVITAI_TOKEN=<CivitAI token>` (optional)

RunPod maps internal `22` to a dynamic external TCP port on startup. Find the mapping in the Pod `Connect` tab under `Direct TCP Ports`.

## SSH / SCP / SFTP
- SSH:
  - `ssh root@<public_ip> -p <external_ssh_port> -i ~/.ssh/id_ed25519`
- SCP:
  - `scp -P <external_ssh_port> ./local.file root@<public_ip>:/workspace/`
- SFTP:
  - `sftp -oPort=<external_ssh_port> root@<public_ip>`

Key handling behavior:
- RunPod auto-injected account keys in `/root/.ssh/authorized_keys` remain intact.
- `PUBLIC_KEY` and `SSH_PUBLIC_KEY` (if present) are appended idempotently at startup.
- Root password login is disabled; key-based auth is required.

## Troubleshooting
- SSH daemon logs:
  - `/tmp/sshd.log`
- Jupyter logs:
  - `/tmp/jupyter.log`
- Verify Jupyter terminal API is available:
  - `curl -sSf http://127.0.0.1:8889/api/terminals`

## CircleCI release
- Push to `main`:
  - builds and pushes `docker.io/<DOCKERHUB_USER>/comfyui-wizard-image:main-<shortsha>`
- Tag format: `vX.Y.Z`
- On tag, CircleCI builds and pushes:
  - `docker.io/<DOCKERHUB_USER>/comfyui-wizard-image:vX.Y.Z`
  - `docker.io/<DOCKERHUB_USER>/comfyui-wizard-image:latest`
