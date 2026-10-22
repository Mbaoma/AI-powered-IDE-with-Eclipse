#!/usr/bin/env bash
# Starts the local IDE and opens it on the sample workspace.
set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-3000}"
WORKSPACE="$(cd workspace && pwd)"

unset PREFIX

echo "==> Starting Theia on http://localhost:${PORT}"
echo "==> Workspace: ${WORKSPACE}"
cd ide
exec ./node_modules/.bin/theia start "${WORKSPACE}" --hostname 0.0.0.0 --port "${PORT}" --plugins=local-dir:plugins
