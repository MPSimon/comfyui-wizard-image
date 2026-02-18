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
- Start ComfyUI on `8188`, code-server on `8888`, and JupyterLab on `8889`.

## Startup flow
1. Container starts.
2. Requires `ARTIFACT_AUTH` to be present.
3. Seed ComfyUI is copied to `/workspace/ComfyUI` if missing.
4. Launcher `/workspace/sync-workflow.sh` is created, and `sync-workflow` command is available globally.
5. code-server starts on `0.0.0.0:8888` (auth disabled).
6. JupyterLab starts on `0.0.0.0:8889` (token/password disabled).
7. ComfyUI starts on `0.0.0.0:8188`.

## Commands
- `sync-workflow` (recommended, runs `runpod-launch.sh` flow)
- `/workspace/sync-workflow.sh`

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

## RunPod template
- Image: `docker.io/mpsimon/comfyui-wizard-image:latest`
- Expose ports: `8188`, `8888`, `8889`
- Set env:
  - `ARTIFACT_AUTH=<RunPod Secret>`
  - `HF_HUB_ENABLE_HF_TRANSFER=1` (optional)

## CircleCI release
- Push to `main`:
  - builds and pushes `docker.io/<DOCKERHUB_USER>/comfyui-wizard-image:main-<shortsha>`
- Tag format: `vX.Y.Z`
- On tag, CircleCI builds and pushes:
  - `docker.io/<DOCKERHUB_USER>/comfyui-wizard-image:vX.Y.Z`
  - `docker.io/<DOCKERHUB_USER>/comfyui-wizard-image:latest`
