#!/usr/bin/env bash
# Failure-path fixtures: no Docker daemon or image changes are needed.
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/linux-setup-cleanup-test.XXXXXX")"
trap 'rm -rf -- "$FIXTURE_DIR"' EXIT
mkdir -p "$FIXTURE_DIR/bin" "$FIXTURE_DIR/repo/tests"
cp "$ROOT_DIR/tests/run_container.sh" "$FIXTURE_DIR/repo/tests/run_container.sh"
cat > "$FIXTURE_DIR/bin/docker" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DOCKER_TRACE"
case "$*" in
  info) [[ "$FAIL_AT" != info ]] ;;
  'image inspect archlinux:base-devel') [[ "$BASE_PRESENT" == true ]] ;;
  'image build '*) exit 43 ;;
  *) exit 0 ;;
esac
STUB
cat > "$FIXTURE_DIR/bin/git" <<'STUB'
#!/usr/bin/env bash
[[ "$FAIL_AT" != git ]] || exit 41
STUB
cat > "$FIXTURE_DIR/bin/python3" <<'STUB'
#!/usr/bin/env bash
[[ "$FAIL_AT" != staging ]] || exit 42
STUB
chmod +x "$FIXTURE_DIR/bin/"*
for fail_at in git staging info build; do
  for base_present in true false; do
    trace="$FIXTURE_DIR/$fail_at-$base_present.log"
    if PATH="$FIXTURE_DIR/bin:$PATH" FAIL_AT="$fail_at" BASE_PRESENT="$base_present" DOCKER_TRACE="$trace" \
      bash "$FIXTURE_DIR/repo/tests/run_container.sh" >"$FIXTURE_DIR/output" 2>&1; then
      printf 'Expected container runner failure at %s.\n' "$fail_at" >&2
      exit 1
    fi
    if [[ "$fail_at" == build && "$base_present" == false ]]; then
      grep -Fxq 'image rm archlinux:base-devel' "$trace"
    elif grep -Fxq 'image rm archlinux:base-devel' "$trace"; then
      printf 'Cleanup removed a pre-existing or unknown base image at %s.\n' "$fail_at" >&2
      exit 1
    fi
    if compgen -G "$FIXTURE_DIR/repo/.linux-setup-ci.*" >/dev/null; then
      printf 'Cleanup left staging files at %s.\n' "$fail_at" >&2
      exit 1
    fi
  done
done
printf 'Container cleanup failure-path checks passed (8 cases).\n'
