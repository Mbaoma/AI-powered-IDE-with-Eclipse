#!/bin/bash
# Seeds the sample workspace into $WORKSPACE_DIR on first boot, then
# launches Theia as the container's foreground process.

set -euo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-/home/workspace}"

if [ ! -d "${WORKSPACE_DIR}" ] || [ -z "$(ls -A "${WORKSPACE_DIR}" 2>/dev/null)" ]; then
  mkdir -p "${WORKSPACE_DIR}"
  cp -r /opt/sample-workspace/. "${WORKSPACE_DIR}/"
fi

cd /opt/theia
exec ./node_modules/.bin/theia start "${WORKSPACE_DIR}" \
  --hostname 0.0.0.0 \
  --port "${THEIA_PORT:-80}" \
  --plugins=local-dir:plugins
