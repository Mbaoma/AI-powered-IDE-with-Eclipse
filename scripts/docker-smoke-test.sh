#!/usr/bin/env bash
# checks that the Phase 2 image builds and serves the IDE 
set -uo pipefail
cd "$(dirname "$0")/.."

IMAGE_TAG="ai-ide:smoke-test"
PORT="${PORT:-3098}"
CONTAINER_NAME="ai-ide-smoke-test"
ROOT_HTML="$(mktemp)"

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  rm -f "${ROOT_HTML}"
}
trap cleanup EXIT

echo "==> Building ${IMAGE_TAG} (this runs the full yarn install/build/download:plugins -- a few minutes)"
docker build -f config/docker/Dockerfile -t "${IMAGE_TAG}" . || { echo "FAIL: docker build"; exit 1; }

echo "==> Running on port ${PORT}"
docker run -d --rm --name "${CONTAINER_NAME}" -e THEIA_PORT=80 -p "${PORT}:80" "${IMAGE_TAG}" >/dev/null

echo "==> Waiting for backend to come up"
for _ in $(seq 1 60); do
  if curl -s -o /dev/null "http://127.0.0.1:${PORT}/"; then
    break
  fi
  sleep 1
done

status=$(curl -s -o "${ROOT_HTML}" -w "%{http_code}" "http://127.0.0.1:${PORT}/")
fail=0

if [ "$status" != "200" ]; then
  echo "FAIL: root page returned HTTP ${status}"
  fail=1
else
  echo "PASS: root page returned HTTP 200"
fi

if grep -qi "AI-Powered Cloud IDE" "${ROOT_HTML}"; then
  echo "PASS: branded application name present in served page"
else
  echo "FAIL: branded application name missing from served page"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "---- container log ----"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi

echo "==> Docker smoke test passed"
