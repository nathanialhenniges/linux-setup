#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
dry_run=false
action="help"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Ubuntu Desktop 26.04 local Ansible setup

Usage:
  ./setup.sh bootstrap
  ./setup.sh [--dry-run] status
  ./setup.sh [--dry-run] verify
  ./setup.sh [--dry-run] base
  ./setup.sh [--dry-run] apps
  ./setup.sh [--dry-run] terminal
  ./setup.sh [--dry-run] codex
  ./setup.sh [--dry-run] dotfiles
  ./setup.sh [--dry-run] gnome
  ./setup.sh [--dry-run] optional

Commands:
  bootstrap  Install minimal Ubuntu ansible-core prerequisites
  status     Read-only ADHD-friendly state board; missing items are allowed
  verify     Read-only state board that fails until the core setup is ready
  base       Core packages, Oh My Posh, and CaskaydiaCove Nerd Font
  apps       GitHub CLI, VS Code, and Ghostty
  terminal   Make launch-tested Ghostty the Ubuntu default
  codex      Show the official Codex CLI route; make no change
  dotfiles   Fast-forward and run only dotfiles/linux-desktop.sh; set user Zsh
  gnome      Small, reversible macOS-friendly GNOME preferences
  optional   Claude Desktop beta and Cloudflare WARP packages only

--dry-run uses Ansible check mode. Network, sudo, downloads, and managed-state
writes are skipped; Ansible may create its ignored local temporary directory.

This repository never configures a server/devbox, sshd, Docker, credentials,
SSH keys, Cloudflare enrollment, or a tunnel.
EOF
}

parse_args() {
  local selected="" argument
  for argument in "$@"; do
    case "$argument" in
      --dry-run)
        [[ "$dry_run" == false ]] || die "--dry-run was supplied more than once"
        dry_run=true
        ;;
      -h | --help)
        [[ -z "$selected" ]] || die "choose exactly one command"
        selected="help"
        ;;
      bootstrap | status | verify | base | apps | terminal | codex | dotfiles | gnome | optional)
        [[ -z "$selected" ]] || die "choose exactly one command"
        selected="$argument"
        ;;
      *) die "unknown option or command: $argument" ;;
    esac
  done
  action="${selected:-help}"
  [[ "$action" != "help" || "$dry_run" == false ]] || die "--dry-run needs an action"
}

target_preflight() {
  [[ ${EUID:-$(id -u)} -ne 0 ]] || die "run as your desktop user, not root"
  [[ -n "${HOME:-}" && "$HOME" == /* && "$HOME" != "/" && -d "$HOME" && ! -L "$HOME" ]] ||
    die "HOME must be a real, safe absolute directory"
  [[ -r /etc/os-release ]] || die "cannot read /etc/os-release"
  command -v dpkg >/dev/null 2>&1 || die "dpkg is required"

  local os_id os_version architecture
  # Root-owned OS identity file.
  # shellcheck disable=SC1091
  os_id="$(. /etc/os-release; printf '%s' "${ID:-}")"
  # shellcheck disable=SC1091
  os_version="$(. /etc/os-release; printf '%s' "${VERSION_ID:-}")"
  architecture="$(dpkg --print-architecture)"

  [[ "$os_id" == "ubuntu" && "$os_version" == "26.04" ]] ||
    die "supported target is Ubuntu 26.04 only (found ${os_id:-unknown} ${os_version:-unknown})"
  [[ "$architecture" == "amd64" ]] || die "supported architecture is amd64 (found $architecture)"
  [[ -n "${XDG_CURRENT_DESKTOP:-}" || -e /usr/share/wayland-sessions/ubuntu.desktop ||
     -e /usr/share/xsessions/ubuntu.desktop ]] || die "Ubuntu Desktop was not detected"
}

bootstrap_ansible() {
  target_preflight
  if [[ "$dry_run" == true ]]; then
    printf '%s\n' '[dry-run] sudo apt-get update'
    printf '%s\n' '[dry-run] sudo apt-get install --yes --no-install-recommends ansible-core python3-apt python3-debian sudo'
    return
  fi
  sudo apt-get update
  sudo apt-get install --yes --no-install-recommends ansible-core python3-apt python3-debian sudo
  ansible-playbook --version | sed -n '1p'
}

require_ansible_files() {
  command -v ansible-playbook >/dev/null 2>&1 ||
    die "Ansible is missing. Run: ./setup.sh bootstrap"
  [[ -f "$repo_dir/site.yml" && ! -L "$repo_dir/site.yml" ]] || die "site.yml is missing or unsafe"
  [[ -f "$repo_dir/verify.yml" && ! -L "$repo_dir/verify.yml" ]] || die "verify.yml is missing or unsafe"
  [[ -f "$repo_dir/inventory.ini" && ! -L "$repo_dir/inventory.ini" ]] || die "inventory.ini is missing or unsafe"
}

dotfiles_needs_become() {
  local entry
  entry="$(getent passwd "$(id -un)" 2>/dev/null || true)"
  case "${entry##*:}" in
    /bin/zsh | /usr/bin/zsh) return 1 ;;
    *) return 0 ;;
  esac
}

require_classic_sudo() {
  [[ -x /usr/bin/sudo.ws ]] ||
    die "Ubuntu's /usr/bin/sudo.ws is required for Ansible. Run: ./setup.sh bootstrap"
}

run_status() {
  local strict="$1"
  require_ansible_files
  cd "$repo_dir"
  exec ansible-playbook verify.yml --limit localhost -e "strict_verify=$strict"
}

run_action() {
  target_preflight
  require_ansible_files
  cd "$repo_dir"
  local -a command=(ansible-playbook site.yml --limit localhost --tags "$action" -e "setup_action=$action")

  if [[ "$dry_run" == true ]]; then
    command+=(--check --diff)
  else
    case "$action" in
      base | apps | optional)
        require_classic_sudo
        command+=(--ask-become-pass)
        ;;
      dotfiles)
        if dotfiles_needs_become; then
          require_classic_sudo
          command+=(--ask-become-pass)
        fi
        ;;
    esac
  fi
  exec "${command[@]}"
}

main() {
  parse_args "$@"
  case "$action" in
    help) usage ;;
    bootstrap) bootstrap_ansible ;;
    status) run_status false ;;
    verify) run_status true ;;
    codex)
      target_preflight
      printf '%s\n' "No change made. Follow OpenAI's official Linux instructions:"
      printf '%s\n' 'https://github.com/openai/codex#quickstart'
      printf '%s\n' 'Then run codex and choose Sign in with ChatGPT.'
      ;;
    *) run_action ;;
  esac
}

main "$@"
