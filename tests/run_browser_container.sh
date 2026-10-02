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
docker create --name "$CONTAINER_NAME" --user pwuser \
  "$IMAGE" bash -c 'set -euo pipefail; mkdir -p /tmp/guide; cd /tmp/guide; tar -xf /tmp/source.tar; npm ci; npm run build:guide; GUIDE_SCREENSHOT_DIR=/tmp/guide-screenshots npm run test:guide' >/dev/null
docker cp "$STAGING_DIR/source.tar" "$CONTAINER_NAME:/tmp/source.tar"
docker start --attach "$CONTAINER_NAME" || result=$?
if [[ "$result" == 0 ]]; then
  result="$(docker inspect --format '{{.State.ExitCode}}' "$CONTAINER_NAME")"
fi
if [[ -n "${GUIDE_SCREENSHOT_DIR:-}" ]]; then
  mkdir -p "$GUIDE_SCREENSHOT_DIR"
  docker cp "$CONTAINER_NAME:/tmp/guide-screenshots/." "$GUIDE_SCREENSHOT_DIR/" || result=1
fi
exit "$result"
