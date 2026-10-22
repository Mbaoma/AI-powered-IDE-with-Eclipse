#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-3099}"
LOG="$(mktemp)"
WORKSPACE="$(cd workspace && pwd)"

cleanup() {
  if [ -n "${SERVER_PID:-}" ]; then
    pkill -P "$SERVER_PID" >/dev/null 2>&1 || true
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi

  pids=$(lsof -ti ":${PORT}" 2>/dev/null || true)
  if [ -n "${pids}" ]; then
    echo "${pids}" | xargs kill -9 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "==> Starting server on port ${PORT} (log: ${LOG})"
(cd ide && exec ./node_modules/.bin/theia start "${WORKSPACE}" --hostname 127.0.0.1 --port "${PORT}" --plugins=local-dir:plugins) >"${LOG}" 2>&1 &
SERVER_PID=$!

echo "==> Waiting for backend to come up"
for _ in $(seq 1 60); do
  if curl -s -o /dev/null "http://127.0.0.1:${PORT}/"; then
    break
  fi
  sleep 1
done

status=$(curl -s -o /tmp/theia-smoke-root.html -w "%{http_code}" "http://127.0.0.1:${PORT}/")
fail=0

if [ "$status" != "200" ]; then
  echo "FAIL: root page returned HTTP ${status}"
  fail=1
else
  echo "PASS: root page returned HTTP 200"
fi

if grep -qi "AI-Powered Cloud IDE" /tmp/theia-smoke-root.html; then
  echo "PASS: branded application name present in served page"
else
  echo "FAIL: branded application name missing from served page"
  fail=1
fi

deployed=""
for _ in $(seq 1 20); do
  deployed=$(grep -o "Deploy batch of [0-9]* accepted plugins" "${LOG}" | grep -o "[0-9]*" | head -1)
  [ -n "${deployed:-}" ] && break
  sleep 0.5
done
if [ -n "${deployed:-}" ] && [ "${deployed}" -ge 8 ]; then
  echo "PASS: ${deployed} plugins deployed"
else
  echo "FAIL: expected >= 8 deployed plugins, got '${deployed:-0}' (see ${LOG})"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "---- server log ----"
  cat "${LOG}"
  exit 1
fi

echo "==> Smoke test passed"
