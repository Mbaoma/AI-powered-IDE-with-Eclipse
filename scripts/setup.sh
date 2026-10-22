#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Checking prerequisites"
node_version=$(node -v | sed 's/^v//')
node_major=${node_version%%.*}
if [ "$node_major" -lt 20 ]; then
  echo "Node.js >= 20 is required (found $node_version). See README.md Prerequisites." >&2
  exit 1
fi

echo "==> Syncing config/theia.app.json -> ide/package.json"
node scripts/sync-theia-config.js

echo "==> Installing dependencies (yarn install)"

(cd ide && yarn install --ignore-engines)

echo "==> Building the application"
(cd ide && yarn build)

echo "==> Downloading bundled VS Code extensions from Open VSX"

(cd ide && yarn theia download:plugins --ignore-errors)

echo "==> Setup complete. Run scripts/start.sh to launch the IDE."
