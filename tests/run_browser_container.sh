#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
IMAGE=mcr.microsoft.com/playwright:v1.58.2-noble
CONTAINER_NAME="linux-setup-browser-${GITHUB_RUN_ID:-local}-$$"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/linux-guide-ci.XXXXXX")"
IMAGE_ADDED=false

# shellcheck disable=SC2329 # Invoked by the EXIT trap.
cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  if [[ "$IMAGE_ADDED" == true ]]; then docker image rm "$IMAGE" >/dev/null 2>&1 || true; fi
  rm -rf -- "$STAGING_DIR"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
command -v docker >/dev/null || { printf 'Docker is required for browser container checks.\n' >&2; exit 1; }
docker info >/dev/null
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  IMAGE_ADDED=true
  docker pull "$IMAGE"
fi
# Only guide sources and locked test dependencies enter the container.
tar -cf "$STAGING_DIR/source.tar" -C "$ROOT_DIR" docs package.json package-lock.json tests/test_guide.cjs
result=0
docker run --name "$CONTAINER_NAME" --user pwuser \
  --mount "type=bind,source=$STAGING_DIR/source.tar,target=/input/source.tar,readonly" \
  "$IMAGE" bash -c 'set -euo pipefail; mkdir -p /tmp/guide; cd /tmp/guide; tar -xf /input/source.tar; npm ci; npm run build:guide; GUIDE_SCREENSHOT_DIR=/tmp/guide-screenshots npm run test:guide' || result=$?
if [[ -n "${GUIDE_SCREENSHOT_DIR:-}" ]]; then
  mkdir -p "$GUIDE_SCREENSHOT_DIR"
  docker cp "$CONTAINER_NAME:/tmp/guide-screenshots/." "$GUIDE_SCREENSHOT_DIR/" || result=1
fi
exit "$result"
