#!/usr/bin/env bash
# Tears down all created resources 
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/gcp-env.sh

ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=true ;;
  esac
done

echo "This will permanently delete, in ${PROJECT_ID} / ${REGION}:"
echo "  - workstation       '${WORKSTATION_ID}'"
echo "  - workstation config '${CONFIG_ID}'"
echo "  - workstation cluster '${CLUSTER_ID}' (can take ~20 min)"
echo "  - Artifact Registry repo '${REPOSITORY}' (and every image in it)"
if [ "${NETWORK}" != "default" ]; then
  echo "  - Cloud NAT/router '${NETWORK}-nat' / '${NETWORK}-router'"
  echo "  - subnet '${SUBNETWORK}' and VPC network '${NETWORK}'"
fi

if [ "${ASSUME_YES}" != "true" ]; then
  read -r -p "Type the project ID (${PROJECT_ID}) to confirm: " CONFIRM
  if [ "${CONFIRM}" != "${PROJECT_ID}" ]; then
    echo "Aborted: input did not match project ID." >&2
    exit 1
  fi
fi

echo "==> Deleting workstation '${WORKSTATION_ID}'"
gcloud beta workstations describe "${WORKSTATION_ID}" --cluster "${CLUSTER_ID}" --config "${CONFIG_ID}" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 && \
gcloud beta workstations delete "${WORKSTATION_ID}" \
  --cluster "${CLUSTER_ID}" --config "${CONFIG_ID}" \
  --region "${REGION}" --project "${PROJECT_ID}" --quiet \
  || echo "    (not found, skipping)"

echo "==> Deleting workstation config '${CONFIG_ID}'"
gcloud beta workstations configs describe "${CONFIG_ID}" --cluster "${CLUSTER_ID}" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 && \
gcloud beta workstations configs delete "${CONFIG_ID}" \
  --cluster "${CLUSTER_ID}" --region "${REGION}" --project "${PROJECT_ID}" --quiet \
  || echo "    (not found, skipping)"

echo "==> Deleting workstation cluster '${CLUSTER_ID}' (can take ~20 min)"
gcloud beta workstations clusters describe "${CLUSTER_ID}" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 && \
gcloud beta workstations clusters delete "${CLUSTER_ID}" \
  --region "${REGION}" --project "${PROJECT_ID}" --quiet \
  || echo "    (not found, skipping)"

echo "==> Deleting Artifact Registry repo '${REPOSITORY}'"
gcloud artifacts repositories describe "${REPOSITORY}" --location "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 && \
gcloud artifacts repositories delete "${REPOSITORY}" \
  --location "${REGION}" --project "${PROJECT_ID}" --quiet \
  || echo "    (not found, skipping)"

if [ "${NETWORK}" != "default" ]; then
  echo "==> Deleting Cloud NAT '${NETWORK}-nat'"
  gcloud compute routers nats describe "${NETWORK}-nat" --router "${NETWORK}-router" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 && \
  gcloud compute routers nats delete "${NETWORK}-nat" \
    --router "${NETWORK}-router" --region "${REGION}" --project "${PROJECT_ID}" --quiet \
    || echo "    (not found, skipping)"

  echo "==> Deleting Cloud Router '${NETWORK}-router'"
  gcloud compute routers describe "${NETWORK}-router" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 && \
  gcloud compute routers delete "${NETWORK}-router" \
    --region "${REGION}" --project "${PROJECT_ID}" --quiet \
    || echo "    (not found, skipping)"

  if [ "${SUBNETWORK}" = "default" ]; then
    echo "==> SUBNETWORK is 'default' -- refusing to delete it. Skipping subnet deletion." >&2
  else
    echo "==> Deleting subnet '${SUBNETWORK}'"
    gcloud compute networks subnets describe "${SUBNETWORK}" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 && \
    gcloud compute networks subnets delete "${SUBNETWORK}" \
      --region "${REGION}" --project "${PROJECT_ID}" --quiet \
      || echo "    (not found, skipping)"
  fi

  if [ "${NETWORK}" = "default" ]; then
    echo "==> NETWORK is 'default' -- refusing to delete it. Skipping network deletion." >&2
  else
    echo "==> Deleting VPC network '${NETWORK}'"
    gcloud compute networks describe "${NETWORK}" --project "${PROJECT_ID}" >/dev/null 2>&1 && \
    gcloud compute networks delete "${NETWORK}" \
      --project "${PROJECT_ID}" --quiet \
      || echo "    (not found, skipping)"
  fi
fi

echo "==> Done. APIs enabled by scripts/gcp-enable-apis.sh were left on (enabling them again is free; this only removes billed resources)."
