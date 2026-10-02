#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
RUN_ID="${GITHUB_RUN_ID:-local}-$$"
IMAGE_TAG="linux-setup-arch-ci:${RUN_ID}"
CONTAINER_NAME="linux-setup-arch-ci-${RUN_ID}"
BASE_IMAGE=archlinux:base-devel
BASE_IMAGE_WAS_PRESENT=unknown

command -v docker >/dev/null 2>&1 || {
  printf 'tests/run_container.sh: Docker is required (start Colima or Docker Desktop first).\n' >&2
  exit 1
}

STAGING_DIR="$(mktemp -d "$ROOT_DIR/.linux-setup-ci.XXXXXX")"
CONTEXT_DIR="$STAGING_DIR/context"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker image rm "$IMAGE_TAG" >/dev/null 2>&1 || true
  docker image prune --force --filter "label=org.mrdemonwolf.linux-setup-test.run=$RUN_ID" >/dev/null 2>&1 || true
  if [[ "$BASE_IMAGE_WAS_PRESENT" == false ]]; then
    docker image rm "$BASE_IMAGE" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$STAGING_DIR"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$CONTEXT_DIR"

git -C "$ROOT_DIR" diff --check
git -C "$ROOT_DIR" diff --cached --check
python3 - "$ROOT_DIR" "$STAGING_DIR/source.tar" "$CONTEXT_DIR" "$STAGING_DIR" "$RUN_ID" <<'PY'
import pathlib
import shutil
import subprocess
import sys
import tarfile

root = pathlib.Path(sys.argv[1])
archive_path = pathlib.Path(sys.argv[2])
context = pathlib.Path(sys.argv[3])
staging_dir_name = pathlib.Path(sys.argv[4]).name
run_id = sys.argv[5]
listed = subprocess.check_output(
    ["git", "-C", str(root), "ls-files", "--cached", "--others", "--exclude-standard", "-z"]
).split(b"\0")
excluded_components = {".git", ".ansible", "node_modules", staging_dir_name}

with tarfile.open(archive_path, "w") as archive:
    for raw_path in listed:
        if not raw_path:
            continue
        relative = pathlib.PurePosixPath(raw_path.decode())
        name = relative.as_posix()
        if any(part in excluded_components for part in relative.parts):
            continue
        if relative.name == ".DS_Store" or relative.name == ".env" or relative.name.startswith(".env."):
            continue
        if relative.suffix == ".log":
            continue
        source = root.joinpath(*relative.parts)
        if source.exists() or source.is_symlink():
            archive.add(source, arcname=name, recursive=False)
for relative in (
    "tests/container/Dockerfile",
    "requirements.yml",
    "tests/container/gnome-test.gschema.xml",
    "tests/container/run-inside.sh",
):
    source = root / relative
    destination = context / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    if relative == "tests/container/Dockerfile":
        content = source.read_text(encoding="utf-8")
        content = content.replace("__LINUX_SETUP_TEST_RUN_ID__", run_id)
        destination.write_text(content, encoding="utf-8")
    else:
        shutil.copy2(source, destination)
PY

docker info >/dev/null
if docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
  BASE_IMAGE_WAS_PRESENT=true
else
  BASE_IMAGE_WAS_PRESENT=false
fi
docker image build --platform linux/amd64 --pull \
  --file "$CONTEXT_DIR/tests/container/Dockerfile" --tag "$IMAGE_TAG" "$CONTEXT_DIR"
docker create --platform linux/amd64 --name "$CONTAINER_NAME" "$IMAGE_TAG" >/dev/null
docker cp "$STAGING_DIR/source.tar" "$CONTAINER_NAME:/tmp/source.tar"
docker start --attach "$CONTAINER_NAME"
container_exit="$(docker inspect --format '{{.State.ExitCode}}' "$CONTAINER_NAME")"
if [[ "$container_exit" != 0 ]]; then
  printf 'Arch test container exited with status %s.\n' "$container_exit" >&2
  exit "$container_exit"
fi
