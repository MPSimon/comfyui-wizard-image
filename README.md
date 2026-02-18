# comfyui-wizard-image

Private base image for ComfyUI workloads.

## Release flow
- CircleCI builds and pushes on tags matching `v*`.
- Tag image is pushed as `docker.io/<dockerhub_user>/comfyui-wizard-image:<tag>`.
- The same build is additionally tagged as `latest`.
