#!/usr/bin/env bash
set -Eeuo pipefail

API_BASE="https://civitai.com/api/v1"
DEFAULT_TARGET_DIR="/workspace/ComfyUI/models/loras"

usage() {
  cat <<USAGE
Usage:
  civitai-model <id-or-url> [options]

Accepted input:
  - Model ID (example: 122359)
  - Model version ID (example: 135867)
  - CivitAI model URL (example: https://civitai.com/models/122359?modelVersionId=135867)
  - CivitAI direct download URL (example: https://civitai.com/api/download/models/135867)

Options:
  -o, --target-dir <dir>   Download destination (default: ${DEFAULT_TARGET_DIR})
  -v, --version-id <id>    Force a specific model version id
  -f, --file-index <n>     Select file index from version payload (default: 0)
      --filename <name>    Override output filename
      --token <token>      CivitAI token (fallback env: CIVITAI_TOKEN)
  -h, --help               Show this help
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
  value="${value%%\#*}"
  printf '%s' "$value"
}

append_token_query() {
  local url="$1"
  local token="$2"

  if [[ -z "$token" ]]; then
    printf '%s' "$url"
    return 0
  fi

  if [[ "$url" == *"token="* ]]; then
    printf '%s' "$url"
    return 0
  fi

  if [[ "$url" == *"?"* ]]; then
    printf '%s&token=%s' "$url" "$token"
  else
    printf '%s?token=%s' "$url" "$token"
  fi
}

api_get() {
  local path="$1"
  local token="$2"
  local url="${API_BASE}${path}"
  url="$(append_token_query "$url" "$token")"
  curl -fsSL "$url"
}

resolve_from_input() {
  local input="$1"
  local explicit_version="$2"

  local model_id=""
  local version_id="$explicit_version"

  local cleaned
  cleaned="$(strip_url_suffix "$input")"

  if [[ "$cleaned" =~ ^https?://civitai\.com/api/download/models/([0-9]+) ]]; then
    version_id="${BASH_REMATCH[1]}"
    printf '%s\t%s\n' "$model_id" "$version_id"
    return 0
  fi

  if [[ "$cleaned" =~ modelVersionId=([0-9]+) ]]; then
    version_id="${BASH_REMATCH[1]}"
  fi

  if [[ "$cleaned" =~ ^https?://civitai\.com/model-versions/([0-9]+) ]]; then
    version_id="${BASH_REMATCH[1]}"
    printf '%s\t%s\n' "$model_id" "$version_id"
    return 0
  fi

  if [[ "$cleaned" =~ ^https?://civitai\.com/models/([0-9]+) ]]; then
    model_id="${BASH_REMATCH[1]}"
    printf '%s\t%s\n' "$model_id" "$version_id"
    return 0
  fi

  if [[ "$input" =~ ^[0-9]+$ ]]; then
    printf '%s\t%s\n' "$input" "$version_id"
    return 0
  fi

  return 1
}

pick_file_json() {
  local version_json="$1"
  local file_index="$2"

  jq -cer --argjson idx "$file_index" '
    ((.files // []) | map(select((.type // "") == "Model"))) as $model_files
    | (if ($model_files | length) > 0 then $model_files else (.files // []) end)
    | .[$idx]
  ' <<< "$version_json"
}

input=""
target_dir="$DEFAULT_TARGET_DIR"
force_version_id=""
file_index=0
filename_override=""
token="${CIVITAI_TOKEN:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--target-dir)
      target_dir="$2"
      shift 2
      ;;
    -v|--version-id)
      force_version_id="$2"
      shift 2
      ;;
    -f|--file-index)
      file_index="$2"
      shift 2
      ;;
    --filename)
      filename_override="$2"
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
      if [[ -z "$input" ]]; then
        input="$1"
      else
        echo "Error: unexpected argument: $1" >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$input" ]]; then
  usage
  exit 1
fi

if ! [[ "$file_index" =~ ^[0-9]+$ ]]; then
  echo "Error: --file-index must be a non-negative integer." >&2
  exit 1
fi

require_bin curl
require_bin jq

resolved=""
if ! resolved="$(resolve_from_input "$input" "$force_version_id")"; then
  echo "Error: unsupported CivitAI input. Provide an id or supported URL." >&2
  exit 1
fi

IFS=$'\t' read -r candidate_model_id candidate_version_id <<< "$resolved"

version_json=""
model_json=""
model_id=""
version_id="$candidate_version_id"

if [[ -n "$version_id" ]]; then
  if ! version_json="$(api_get "/model-versions/${version_id}" "$token")"; then
    echo "Error: failed to fetch model version ${version_id}." >&2
    exit 1
  fi
  model_id="$(jq -r '.modelId // empty' <<< "$version_json")"
else
  if [[ -z "$candidate_model_id" ]]; then
    echo "Error: could not determine model or version id from input." >&2
    exit 1
  fi

  if model_json="$(api_get "/models/${candidate_model_id}" "$token" 2>/dev/null)"; then
    model_id="$candidate_model_id"
    version_id="$(jq -r '.modelVersions[0].id // empty' <<< "$model_json")"
    if [[ -z "$version_id" ]]; then
      echo "Error: model ${model_id} has no downloadable versions." >&2
      exit 1
    fi
    version_json="$(api_get "/model-versions/${version_id}" "$token")"
  elif version_json="$(api_get "/model-versions/${candidate_model_id}" "$token" 2>/dev/null)"; then
    version_id="$candidate_model_id"
    model_id="$(jq -r '.modelId // empty' <<< "$version_json")"
  else
    echo "Error: id ${candidate_model_id} is neither a valid model id nor model version id." >&2
    exit 1
  fi
fi

selected_file_json=""
if ! selected_file_json="$(pick_file_json "$version_json" "$file_index")"; then
  echo "Error: no file found at index ${file_index} for model version ${version_id}." >&2
  exit 1
fi

download_url="$(jq -r '.downloadUrl // empty' <<< "$selected_file_json")"
api_file_name="$(jq -r '.name // empty' <<< "$selected_file_json")"

if [[ -z "$download_url" ]]; then
  echo "Error: CivitAI response did not include a download URL." >&2
  exit 1
fi

final_file_name="$api_file_name"
if [[ -n "$filename_override" ]]; then
  final_file_name="$filename_override"
fi
if [[ -z "$final_file_name" ]]; then
  final_file_name="civitai-${version_id}.bin"
fi

download_url="$(append_token_query "$download_url" "$token")"
mkdir -p "$target_dir"
target_path="${target_dir}/${final_file_name}"

echo "CivitAI download: model_id=${model_id:-unknown} version_id=${version_id} file=${final_file_name}"
echo "Target path: ${target_path}"

curl -fL --retry 3 --retry-delay 2 --continue-at - "$download_url" -o "$target_path"

echo "Done."
