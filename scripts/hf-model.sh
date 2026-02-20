#!/usr/bin/env bash
set -Eeuo pipefail

DEFAULT_TARGET_DIR="/workspace/ComfyUI/models/loras"

usage() {
  cat <<USAGE
Usage:
  hf-model <hf-file-url>
  hf-model <repo_id> <filename> [--revision <ref>] [--target-dir <dir>] [--repo-type <model|dataset|space>]

Examples:
  hf-model https://huggingface.co/Kijai/some-lora/resolve/main/model.safetensors
  hf-model Kijai/some-lora model.safetensors --revision main

Options:
  -o, --target-dir <dir>  Download destination (default: ${DEFAULT_TARGET_DIR})
  -r, --revision <ref>    Git revision/branch/tag to download from
      --repo-type <type>  HF repo type: model (default), dataset, or space
      --token <token>     Optional token for gated/private repos
  -h, --help              Show this help
USAGE
}

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Error: required command not found: $name" >&2
    exit 1
  fi
}

strip_url_suffix() {
  local value="$1"
  value="${value%%\?*}"
  value="${value%%\#*}"
  printf '%s' "$value"
}

parse_hf_url() {
  local input="$1"
  local cleaned
  cleaned="$(strip_url_suffix "$input")"

  if [[ "$cleaned" =~ ^https?://huggingface\.co/(datasets|spaces)/([^/]+/[^/]+)/(resolve|blob)/([^/]+)/(.+)$ ]]; then
    printf '%s\t%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[4]}" "${BASH_REMATCH[5]}"
    return 0
  fi

  if [[ "$cleaned" =~ ^https?://huggingface\.co/([^/]+/[^/]+)/(resolve|blob)/([^/]+)/(.+)$ ]]; then
    printf '%s\t%s\t%s\t%s\n' "model" "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
    return 0
  fi

  return 1
}

target_dir="$DEFAULT_TARGET_DIR"
revision=""
repo_type="model"
token="${HF_TOKEN:-}"

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--target-dir)
      target_dir="$2"
      shift 2
      ;;
    -r|--revision)
      revision="$2"
      shift 2
      ;;
    --repo-type)
      repo_type="$2"
      shift 2
      ;;
    --token)
      token="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

if (( ${#args[@]} == 0 )); then
  usage
  exit 1
fi

require_bin hf

repo_id=""
filename=""
parsed=""

if [[ "${args[0]}" =~ ^https?://huggingface\.co/ ]]; then
  if ! parsed="$(parse_hf_url "${args[0]}")"; then
    echo "Error: unsupported Hugging Face URL format." >&2
    echo "Expected: .../repo/resolve/<revision>/<file> (or datasets/spaces variant)." >&2
    exit 1
  fi

  IFS=$'\t' read -r parsed_repo_type repo_id parsed_revision filename <<< "$parsed"
  if [[ -z "$revision" ]]; then
    revision="$parsed_revision"
  fi
  if [[ "$repo_type" == "model" ]]; then
    repo_type="$parsed_repo_type"
  fi
else
  if (( ${#args[@]} < 2 )); then
    echo "Error: when not using a URL, provide both <repo_id> and <filename>." >&2
    usage
    exit 1
  fi
  repo_id="${args[0]}"
  filename="${args[1]}"
fi

if [[ -z "$repo_id" || -z "$filename" ]]; then
  echo "Error: could not resolve Hugging Face repo/file from input." >&2
  exit 1
fi

mkdir -p "$target_dir"

cmd=(hf download "$repo_id" "$filename" --local-dir "$target_dir")
if [[ -n "$revision" ]]; then
  cmd+=(--revision "$revision")
fi
if [[ "$repo_type" != "model" ]]; then
  cmd+=(--repo-type "$repo_type")
fi

echo "HF download: repo=${repo_id} file=${filename} revision=${revision:-default} repo_type=${repo_type}"
echo "Target dir: ${target_dir}"

if [[ -n "$token" ]]; then
  HF_TOKEN="$token" "${cmd[@]}"
else
  "${cmd[@]}"
fi

echo "Done."
