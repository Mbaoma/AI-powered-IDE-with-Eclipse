#!/usr/bin/env bash
# Builds the image via Cloud Build and pushes it to Artifact Registry. 
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/gcp-env.sh

TAG="${1:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"

gcloud artifacts repositories describe "${REPOSITORY}" \
  --location "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 || \
gcloud artifacts repositories create "${REPOSITORY}" \
  --repository-format=docker \
  --location "${REGION}" \
  --project "${PROJECT_ID}" \
  --description="AI-powered IDE container images"

echo "==> Submitting Cloud Build: ${IMAGE}:${TAG}"
gcloud builds submit . \
  --project "${PROJECT_ID}" \
  --config config/gcp/cloudbuild.yaml \
  --substitutions "_IMAGE=${IMAGE},_TAG=${TAG}"

echo "==> Pushed ${IMAGE}:${TAG} and ${IMAGE}:latest"
