#!/usr/bin/env bash
# Creates the workstation cluster, config, and a workstation pointing at the exisiting image

set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/gcp-env.sh

NETWORK_FLAGS=()
if [ "${NETWORK}" != "default" ]; then
  NETWORK_FLAGS+=(--network="projects/${PROJECT_ID}/global/networks/${NETWORK}")
  NETWORK_FLAGS+=(--subnetwork="projects/${PROJECT_ID}/regions/${REGION}/subnetworks/${SUBNETWORK}")
fi

echo "==> Cluster '${CLUSTER_ID}' in ${REGION} (first create only; this blocks for ~20 min while the cluster provisions)"
gcloud beta workstations clusters describe "${CLUSTER_ID}" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 || \
gcloud beta workstations clusters create "${CLUSTER_ID}" \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  ${NETWORK_FLAGS[@]+"${NETWORK_FLAGS[@]}"}

CONFIG_NETWORK_FLAGS=()
if [ "${NETWORK}" != "default" ]; then
  CONFIG_NETWORK_FLAGS+=(--disable-public-ip-addresses)
fi

# Phase 3: thread GOOGLE_API_KEY into the container so AI features work in the deployed workstation too.
CONTAINER_ENV_FLAGS=()
if [ -n "${GOOGLE_API_KEY:-}" ]; then
  CONTAINER_ENV_FLAGS+=(--container-env="GOOGLE_API_KEY=${GOOGLE_API_KEY}")
fi

echo "==> Config '${CONFIG_ID}' (image: ${IMAGE}:latest)"
if gcloud beta workstations configs describe "${CONFIG_ID}" --cluster "${CLUSTER_ID}" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  if [ -n "${GOOGLE_API_KEY:-}" ]; then
    echo "    already exists -- syncing container env (GOOGLE_API_KEY)"
    gcloud beta workstations configs update "${CONFIG_ID}" \
      --project "${PROJECT_ID}" \
      --region "${REGION}" \
      --cluster "${CLUSTER_ID}" \
      "${CONTAINER_ENV_FLAGS[@]}"
  else
    echo "    already exists, skipping (no GOOGLE_API_KEY in config/.env to sync)"
  fi
else
  gcloud beta workstations configs create "${CONFIG_ID}" \
    --project "${PROJECT_ID}" \
    --region "${REGION}" \
    --cluster "${CLUSTER_ID}" \
    --container-custom-image "${IMAGE}:latest" \
    --service-account "${SERVICE_ACCOUNT_ID:-theia-ai-ide-ws}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --machine-type "${MACHINE_TYPE}" \
    --boot-disk-size "${BOOT_DISK_SIZE_GB}" \
    --pd-disk-type "${PERSISTENT_DISK_TYPE:-pd-balanced}" \
    --pd-disk-size "${PERSISTENT_DISK_SIZE_GB}" \
    --idle-timeout "${IDLE_TIMEOUT_SECONDS}" \
    --running-timeout "${RUNNING_TIMEOUT_SECONDS}" \
    ${CONFIG_NETWORK_FLAGS[@]+"${CONFIG_NETWORK_FLAGS[@]}"} \
    ${CONTAINER_ENV_FLAGS[@]+"${CONTAINER_ENV_FLAGS[@]}"}
fi

echo "==> Workstation '${WORKSTATION_ID}'"
gcloud beta workstations describe "${WORKSTATION_ID}" --cluster "${CLUSTER_ID}" --config "${CONFIG_ID}" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 || \
gcloud beta workstations create "${WORKSTATION_ID}" \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --cluster "${CLUSTER_ID}" \
  --config "${CONFIG_ID}"

echo "==> Starting it"
gcloud beta workstations start "${WORKSTATION_ID}" \
  --cluster "${CLUSTER_ID}" --config "${CONFIG_ID}" \
  --region "${REGION}" --project "${PROJECT_ID}"

echo "==> Open https://console.cloud.google.com/workstations/list?project=${PROJECT_ID} and click Launch next to '${WORKSTATION_ID}'."
