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

printf 'Wrapper orchestration checks passed.\n'
