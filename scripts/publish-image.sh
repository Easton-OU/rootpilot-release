#!/usr/bin/env bash
# Publish the RootPilot self-hosted image to GitHub Container Registry (ghcr.io).
#
# This repository contains no application source. This script does NOT build from
# source — it takes an already-built image (produced by the product's own build
# pipeline) and publishes it to ghcr.io under two tags: a semantic version and `latest`.
#
# Usage:
#   VERSION=1.0.0 SOURCE_IMAGE=<built-image> ./scripts/publish-image.sh
#   (override the target owner with GHCR_OWNER=<org> if it ever moves)
#
# Prereqs:
#   - `docker login ghcr.io` with a token that has write:packages
#   - the SOURCE_IMAGE is pullable (or already present locally)
set -euo pipefail

GHCR_OWNER="${GHCR_OWNER:-easton-ou}"
VERSION="${VERSION:?set VERSION, e.g. 1.0.0}"
SOURCE_IMAGE="${SOURCE_IMAGE:?set SOURCE_IMAGE to the built image, e.g. rootpilot:local}"

TARGET="ghcr.io/${GHCR_OWNER}/rootpilot"

echo "Pulling source image ${SOURCE_IMAGE} ..."
docker pull "${SOURCE_IMAGE}" || echo "(using local ${SOURCE_IMAGE})"

echo "Tagging -> ${TARGET}:${VERSION} and ${TARGET}:latest"
docker tag "${SOURCE_IMAGE}" "${TARGET}:${VERSION}"
docker tag "${SOURCE_IMAGE}" "${TARGET}:latest"

echo "Pushing ..."
docker push "${TARGET}:${VERSION}"
docker push "${TARGET}:latest"

echo "Done. docker-compose.yml already references ${TARGET}:latest."
