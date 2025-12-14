#!/bin/sh
# Entrypoint script for runtime env injection using next-runtime-env
set -e

ENV_EXAMPLE="/app/apps/readest-app/.env.local.example"
ENV_RUNTIME="/app/apps/readest-app/.env.runtime"

# Generate .env.runtime with all NEXT_PUBLIC_ vars as shell references
awk -F= '/^NEXT_PUBLIC_/ && $1 != "" { printf "%s=\"${%s}\"\n", $1, $1 }' "$ENV_EXAMPLE" > "$ENV_RUNTIME"

# Optionally print for debugging
cat "$ENV_RUNTIME"

exec "$@"
