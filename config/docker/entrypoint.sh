#!/bin/bash
set -euo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-/home/workspace}"

if [ ! -d "${WORKSPACE_DIR}" ] || [ -z "$(ls -A "${WORKSPACE_DIR}" 2>/dev/null)" ]; then
  mkdir -p "${WORKSPACE_DIR}"
  cp -r /opt/sample-workspace/. "${WORKSPACE_DIR}/"
fi

if [ -z "${GOOGLE_API_KEY:-}" ] && [ -n "${GOOGLE_API_KEY_SECRET:-}" ] && [ -n "${GOOGLE_CLOUD_PROJECT:-}" ]; then
  ACCESS_TOKEN="$(curl -s -H 'Metadata-Flavor: Google' \
    'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' \
    | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).access_token)}catch(e){}})" || true)"
  if [ -n "${ACCESS_TOKEN}" ]; then
    GOOGLE_API_KEY="$(curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      "https://secretmanager.googleapis.com/v1/projects/${GOOGLE_CLOUD_PROJECT}/secrets/${GOOGLE_API_KEY_SECRET}/versions/latest:access" \
      | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(Buffer.from(JSON.parse(d).payload.data,'base64').toString('utf8'))}catch(e){}})" || true)"
    export GOOGLE_API_KEY
  else
    echo "WARN: could not obtain a metadata-server access token; starting without AI features." >&2
  fi
fi

mkdir -p /home/theia
chown -R theia:theia /home

cd /opt/theia
export HOME=/home/theia
exec setpriv --reuid=theia --regid=theia --init-groups \
  ./node_modules/.bin/theia start "${WORKSPACE_DIR}" \
  --hostname 0.0.0.0 \
  --port "${THEIA_PORT:-80}" \
  --plugins=local-dir:plugins
