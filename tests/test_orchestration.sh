#!/usr/bin/env bash
# Exercise the wrapper's ordering without invoking package managers or Ansible.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"
# Loading through the supported dry run defines the functions without changes.
# shellcheck disable=SC1091
source "$ROOT_DIR/setup.sh" --dry-run terminal >/dev/null
# These globals are consumed by functions sourced from setup.sh.
# shellcheck disable=SC2034
DRY_RUN=false
# shellcheck disable=SC2034
ACTION=

events=()
require_ansible() { :; }
ensure_ansible_collections() { :; }
assert_target() { :; }
require_gnome_session() { events+=(gnome-session); }
sync_system() { events+=(sync); }
install_aur_apps() { events+=(aur); }
install_chatgpt_app() { events+=(chatgpt); }
offer_legacy_package_cleanup() { events+=(legacy-package-offer); }
cleanup_terminals() { events+=(terminal-offer); }
run_dotfiles() { events+=(dotfiles); }
run_verification() { events+=("verify:$1"); }
confirm_firefox_purge() { events+=(firefox-offer); return 1; }
run_site_action() { events+=("single:$1"); }
run_setup_ansible() {
  local tags='' vars='' limit='' arg
  while (($#)); do
    arg="$1"
    shift
    case "$arg" in
      --tags) tags="$1"; shift ;;
      --extra-vars) vars="$1"; shift ;;
      --limit) limit="$1"; shift ;;
    esac
  done
  [[ "$limit" == workstation ]] || return 91
  case "$tags" in
    base,apps) [[ "$vars" == *'"setup_actions":["base","apps"]'* ]] || return 92 ;;
    tools,desktop,cleanup-legacy) [[ "$vars" == *'"setup_actions":["tools","desktop","cleanup-legacy"]'* ]] || return 92 ;;
    gnome-dock,branding) [[ "$vars" == *'"setup_actions":["gnome-dock","branding"]'* ]] || return 92 ;;
    *) return 93 ;;
  esac
  events+=("ansible:$tags")
}

main all >/dev/null
expected=(gnome-session sync 'ansible:base,apps' aur chatgpt
  'ansible:tools,desktop,cleanup-legacy' legacy-package-offer terminal-offer
  'ansible:gnome-dock,branding' dotfiles verify:verify firefox-offer)
[[ "${events[*]}" == "${expected[*]}" ]] || {
  printf 'Unexpected all sequence: %s\n' "${events[*]}" >&2
  exit 1
}

events=()
cleanup_legacy
[[ "${events[*]}" == 'gnome-session single:cleanup-legacy legacy-package-offer' ]] || {
  printf 'Standalone cleanup lost its focused task or approval order.\n' >&2
  exit 1
}

# A grouped failure must stop all before any later package or cleanup action.
failure_output="$(bash -e -c '
  source "$1" --dry-run terminal >/dev/null
  DRY_RUN=false
  ACTION=
  require_gnome_session() { :; }
  sync_system() { :; }
  run_site_actions() { printf "group-failed\\n"; return 77; }
  install_aur_apps() { printf "UNEXPECTED-AUR\\n"; }
  main all
' _ "$ROOT_DIR/setup.sh")" && {
  printf 'A failed grouped action unexpectedly succeeded.\n' >&2
  exit 1
}
[[ "$failure_output" != *UNEXPECTED-AUR* ]] || {
  printf 'Setup continued after a failed grouped action.\n' >&2
  exit 1
}

# Dotfiles guards: run the real run_dotfiles against local Git fixtures (no network).
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/linux-setup-dotfiles-test.XXXXXX")"
trap 'rm -rf -- "$fixture_dir"' EXIT
fixture_git() {
  HOME="$fixture_dir/home" GIT_CONFIG_NOSYSTEM=1 git -c user.name='Dotfiles fixture' \
    -c user.email='dotfiles-fixture@example.invalid' -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}
mkdir -p "$fixture_dir/home" "$fixture_dir/seed"
fixture_git init --quiet "$fixture_dir/seed"
# shellcheck disable=SC2016 # The fixture profile expands the marker path when it runs.
printf '#!/usr/bin/env bash\ntouch "$DOTFILES_MARKER"\n' >"$fixture_dir/seed/linux-desktop.sh"
chmod 0755 "$fixture_dir/seed/linux-desktop.sh"
fixture_git -C "$fixture_dir/seed" add linux-desktop.sh
fixture_git -C "$fixture_dir/seed" commit --quiet --message='Fixture profile'
fixture_git clone --quiet --bare "$fixture_dir/seed" "$fixture_dir/origin.git"
fixture_git clone --quiet --bare "$fixture_dir/seed" "$fixture_dir/other.git"

# Usage: run_dotfiles_case <name> <setup command run inside the checkout>
# Prints run_dotfiles output; returns its status. The marker shows whether linux-desktop.sh ran.
run_dotfiles_case() {
  local name="$1" setup_command="$2" case_dir="$fixture_dir/$1"
  mkdir -p "$case_dir/home"
  fixture_git clone --quiet --branch main "$fixture_dir/origin.git" "$case_dir/home/.local/share/dotfiles"
  (cd "$case_dir/home/.local/share/dotfiles" && eval "$setup_command")
  # Publish a newer origin commit so a guard that runs too late shows up as a moved HEAD.
  fixture_git -C "$fixture_dir/seed" commit --quiet --allow-empty --message="Newer commit for $name"
  fixture_git -C "$fixture_dir/seed" push --quiet "$fixture_dir/origin.git" main
  HOME="$case_dir/home" GIT_CONFIG_NOSYSTEM=1 DOTFILES_MARKER="$case_dir/ran" \
    bash -c '
      source "$1" --dry-run terminal >/dev/null
      DOTFILES_URL="$2"
      DOTFILES_PATH="$HOME/.local/share/dotfiles"
      assert_target() { :; }
      sudo() { return 1; }
      run_dotfiles
    ' _ "$ROOT_DIR/setup.sh" "$fixture_dir/origin.git" 2>&1
}

expect_dotfiles_refusal() {
  local name="$1" setup_command="$2" message="$3" output head_before head_after checkout
  checkout="$fixture_dir/$name/home/.local/share/dotfiles"
  if output="$(run_dotfiles_case "$name" "$setup_command")"; then
    printf 'Dotfiles guard did not refuse the %s checkout.\n%s\n' "$name" "$output" >&2
    exit 1
  fi
  [[ "$output" == *"$message"* ]] || {
    printf 'Dotfiles %s refusal lost its message (%s):\n%s\n' "$name" "$message" "$output" >&2
    exit 1
  }
  [[ ! -e "$fixture_dir/$name/ran" ]] || {
    printf 'linux-desktop.sh ran from a refused %s checkout.\n' "$name" >&2
    exit 1
  }
  head_before="$(fixture_git -C "$fixture_dir/origin.git" rev-parse main~1)"
  head_after="$(fixture_git -C "$checkout" rev-parse HEAD)"
  [[ "$head_after" == "$head_before" ]] || {
    printf 'The %s dotfiles checkout was updated before the refusal.\n' "$name" >&2
    exit 1
  }
}

expect_dotfiles_refusal dirty 'touch untracked-file' 'dotfiles checkout is not clean'
# The other remote holds a fast-forward commit, so only the origin guard can stop the update.
expect_dotfiles_refusal wrong-origin "fixture_git commit --quiet --allow-empty --message='Other remote' \
  && fixture_git push --quiet --force '$fixture_dir/other.git' HEAD:main && git reset --quiet --hard HEAD~1 \
  && git remote set-url origin '$fixture_dir/other.git'" 'dotfiles origin does not match'
expect_dotfiles_refusal non-main 'git checkout --quiet -b feature' 'dotfiles checkout is not on main'

# A clean checkout of the expected origin fast-forwards and runs only linux-desktop.sh.
# The later login-shell step may stop here (no zsh, getent, or real sudo); only the profile run matters.
clean_output="$(run_dotfiles_case clean ':')" || true
[[ -e "$fixture_dir/clean/ran" ]] || {
  printf 'A clean expected dotfiles checkout did not run linux-desktop.sh:\n%s\n' "$clean_output" >&2
  exit 1
}
[[ "$(fixture_git -C "$fixture_dir/clean/home/.local/share/dotfiles" rev-parse HEAD)" == \
  "$(fixture_git -C "$fixture_dir/origin.git" rev-parse main)" ]] || {
  printf 'A clean dotfiles checkout was not fast-forwarded to origin/main.\n' >&2
  exit 1
}

printf 'Wrapper orchestration checks passed.\n'
