#!/usr/bin/env bash
# Optional: creates a dedicated VPC/subnet/NAT for the workstation cluster
# instead of using the project's default network.
#
# Skip this (leave NETWORK=default / SUBNETWORK=default in
# config/gcp/deploy.env) to use the default VPC and subnet
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/gcp-env.sh

if [ "${NETWORK}" = "default" ]; then
  echo "NETWORK=default in config/gcp/deploy.env -- nothing to create. Set NETWORK/SUBNETWORK to a non-default name first if you want a dedicated VPC." >&2
  exit 1
fi

echo "==> Creating VPC network '${NETWORK}' (custom subnet mode)"
gcloud compute networks describe "${NETWORK}" --project "${PROJECT_ID}" >/dev/null 2>&1 || \
gcloud compute networks create "${NETWORK}" \
  --project "${PROJECT_ID}" \
  --subnet-mode=custom

echo "==> Creating subnet '${SUBNETWORK}' in ${REGION} with Private Google Access"
gcloud compute networks subnets describe "${SUBNETWORK}" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 || \
gcloud compute networks subnets create "${SUBNETWORK}" \
  --project "${PROJECT_ID}" \
  --network "${NETWORK}" \
  --region "${REGION}" \
  --range=10.10.0.0/20 \
  --enable-private-ip-google-access

echo "==> Creating Cloud Router + Cloud NAT (outbound internet for package installs)"
gcloud compute routers describe "${NETWORK}-router" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 || \
gcloud compute routers create "${NETWORK}-router" \
  --project "${PROJECT_ID}" \
  --network "${NETWORK}" \
  --region "${REGION}"

gcloud compute routers nats describe "${NETWORK}-nat" --router "${NETWORK}-router" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 || \
gcloud compute routers nats create "${NETWORK}-nat" \
  --project "${PROJECT_ID}" \
  --router "${NETWORK}-router" \
  --region "${REGION}" \
  --nat-all-subnet-ip-ranges \
  --auto-allocate-nat-external-ips

echo "==> Done. Create the cluster with --disable-public-ip-addresses (scripts/gcp-create-workstation.sh does this) to keep workstations on private IPs behind this NAT."
