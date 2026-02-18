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
- Include pinned ComfyWizard and expose `cw` command.
- Start ComfyUI directly without runtime clone/build steps.

## Startup flow
1. Container starts.
2. Seed ComfyUI is copied to `COMFY_ROOT` if missing.
3. ComfyUI starts on `0.0.0.0:${COMFY_PORT:-8188}`.
4. You run `cw ...` to sync workflow assets.

## Commands
- `cw --stack wan --workflow WAN2-2-Animate-TinyDeps`
- `cw-update-latest` (manual opt-in update from ComfyWizard `main`)

## Environment
- `COMFY_ROOT` default: `/workspace/ComfyUI`
- `COMFY_PORT` default: `8188`
- `COMFYWIZARD_HOME` default: `/opt/ComfyWizard`
- `COMFYWIZARD_REPO` default: `https://github.com/MPSimon/ComfyWizard.git`

## CircleCI release
- Push to `main`:
  - builds and pushes `docker.io/<DOCKERHUB_USER>/comfyui-wizard-image:main-<shortsha>`
  - updates `docker.io/<DOCKERHUB_USER>/comfyui-wizard-image:latest`
- Tag format: `vX.Y.Z`
- On tag, CircleCI builds and pushes:
  - `docker.io/<DOCKERHUB_USER>/comfyui-wizard-image:vX.Y.Z`
  - `docker.io/<DOCKERHUB_USER>/comfyui-wizard-image:latest`
