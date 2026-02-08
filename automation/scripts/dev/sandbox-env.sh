#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${REPO_ROOT}/terraform/environments"
META_FILE=".sandbox-meta.json"

usage() {
  cat <<'EOF'
Usage: sandbox-env.sh <command> [options]

Commands:
  create   Create a sandbox environment (copies from --source)
  destroy  Destroy a sandbox environment and remove files

Options:
  --name NAME           Sandbox name (default: sandbox-$USER)
  --source ENV          Source environment to copy (default: dev)
  --ttl-hours HOURS     TTL hint stored in metadata (default: 8)
  --auto-apply          After init, run terraform plan+apply
  --dry-run             Print commands without executing
EOF
}

cmd="${1:-}"
if [[ -z "${cmd}" ]]; then
  usage
  exit 1
fi
shift

NAME="sandbox-${USER}"
SOURCE="dev"
TTL_HOURS=8
AUTO_APPLY=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --ttl-hours) TTL_HOURS="$2"; shift 2 ;;
    --auto-apply) AUTO_APPLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option $1" >&2; usage; exit 1 ;;
  esac
done

# Validate NAME and SOURCE contain only safe characters (alphanumeric, dash, underscore)
if [[ ! "${NAME}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Invalid sandbox name: ${NAME} (only alphanumeric, dash, underscore allowed)" >&2
  exit 1
fi
if [[ ! "${SOURCE}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Invalid source environment: ${SOURCE} (only alphanumeric, dash, underscore allowed)" >&2
  exit 1
fi

SRC_PATH="${ENV_DIR}/${SOURCE}"
DST_PATH="${ENV_DIR}/${NAME}"

run_cmd() {
  if (( DRY_RUN )); then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    "$@"
  fi
}

create_env() {
  if [[ ! -d "${SRC_PATH}" ]]; then
    echo "Source environment ${SRC_PATH} missing" >&2
    exit 2
  fi
  if [[ -d "${DST_PATH}" ]]; then
    echo "Destination ${DST_PATH} already exists" >&2
    exit 3
  fi

  run_cmd rsync -a "${SRC_PATH}/" "${DST_PATH}/" --exclude='.terraform' --exclude='*.tfstate*' --exclude='.terraform.lock.hcl' --exclude='plan.tfplan'

  created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  meta_path="${DST_PATH}/${META_FILE}"
  meta_content=$(cat <<EOF
{
  "name": "${NAME}",
  "source": "${SOURCE}",
  "ttl_hours": ${TTL_HOURS},
  "created_at": "${created_at}"
}
EOF
)
  if (( DRY_RUN )); then
    echo "[dry-run] write ${meta_path}"
    printf '%s\n' "${meta_content}"
  else
    printf '%s\n' "${meta_content}" > "${meta_path}"
  fi

  run_cmd terraform -chdir="${DST_PATH}" init -upgrade

  if (( AUTO_APPLY )); then
    run_cmd terraform -chdir="${DST_PATH}" plan -out=plan.tfplan
    run_cmd terraform -chdir="${DST_PATH}" apply -auto-approve plan.tfplan
  fi

  echo "Sandbox ${NAME} created at ${DST_PATH}"
}

destroy_env() {
  if [[ ! -d "${DST_PATH}" ]]; then
    echo "Sandbox ${DST_PATH} does not exist" >&2
    exit 4
  fi
  if [[ -d "${DST_PATH}/.terraform" ]]; then
    run_cmd terraform -chdir="${DST_PATH}" destroy -auto-approve || true
  fi
  run_cmd rm -rf "${DST_PATH}"
  echo "Sandbox ${NAME} destroyed."
}

case "${cmd}" in
  create) create_env ;;
  destroy) destroy_env ;;
  *) usage; exit 1 ;;
esac
