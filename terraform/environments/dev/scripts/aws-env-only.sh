#!/usr/bin/env bash
set -euo pipefail
# Wrapper to run commands with env-only AWS credentials.
# Example:
#   ./scripts/aws-env-only.sh aws sts get-caller-identity

if [ -f ./.env ]; then
  set -a; source ./.env; set +a
fi
source ./.env.strict-aws

exec "$@"

