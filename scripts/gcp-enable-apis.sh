#!/usr/bin/env bash
#enables the APIs Phase 2 needs.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/gcp-env.sh

echo "==> Enabling required APIs on ${PROJECT_ID}"
gcloud services enable \
  workstations.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  compute.googleapis.com \
  secretmanager.googleapis.com \
  --project "${PROJECT_ID}"

echo "==> Creating Artifact Registry repository '${REPOSITORY}' in ${REGION} (skips if it already exists)"
gcloud artifacts repositories describe "${REPOSITORY}" \
  --location "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 || \
gcloud artifacts repositories create "${REPOSITORY}" \
  --repository-format=docker \
  --location "${REGION}" \
  --project "${PROJECT_ID}" \
  --description="AI-powered IDE container images"

SERVICE_ACCOUNT_ID="${SERVICE_ACCOUNT_ID:-theia-ai-ide-ws}"
SA_EMAIL="${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "==> Creating workstation service account '${SA_EMAIL}' (skips if it already exists)"
gcloud iam service-accounts describe "${SA_EMAIL}" --project "${PROJECT_ID}" >/dev/null 2>&1 || \
gcloud iam service-accounts create "${SERVICE_ACCOUNT_ID}" \
  --project "${PROJECT_ID}" \
  --display-name="Theia AI IDE workstation"

echo "==> Granting it read access to '${REPOSITORY}' (so workstation VMs can pull the image)"
gcloud artifacts repositories add-iam-policy-binding "${REPOSITORY}" \
  --location "${REGION}" --project "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.reader" >/dev/null

echo "==> Granting it logging/monitoring write (so the workstation can report health)"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/logging.logWriter" >/dev/null
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/monitoring.metricWriter" >/dev/null

echo "==> Done."
