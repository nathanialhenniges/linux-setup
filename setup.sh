#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
dry_run=false
action="help"
readonly -a all_actions=(base apps tools terminal dotfiles gnome keybinds)
readonly toshy_tag="Toshy_v26.08.0"
readonly toshy_commit="c39ee06d8d7fa299a082034d75275e6da97e0275"
readonly toshy_tree_sha256="dfa142bd53177d038098b9b6919c50f4904d3c37f4cbd33c6bad5e969c85ed57"
readonly xwaykeyz_commit="7d6904cf64dee3bb52f1cea75040ae943bc8fe32"
readonly xwaykeyz_tree_sha256="ff312b70705b9bd63524223f4b48755605b6f0970c77c8e35303ce1f20841cab"
readonly toshy_repo="https://github.com/RedBearAK/toshy.git"
readonly xwaykeyz_repo="https://github.com/RedBearAK/xwaykeyz.git"
readonly focus_extension="focused-window-dbus@flexagoon.com"
readonly claude_managed_source=/etc/apt/sources.list.d/claude-desktop.sources
readonly claude_repository_uri=https://downloads.claude.ai/claude-desktop/apt/stable
readonly claude_list_repository_pattern='^[[:space:]]*deb(-src)?[[:space:]].*https://downloads\.claude\.ai/claude-desktop/apt/stable'

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Ubuntu Desktop 26.04 local Ansible setup

Usage:
  ./setup.sh [--dry-run] bootstrap
  ./setup.sh [--dry-run] all
  ./setup.sh [--dry-run] status
  ./setup.sh [--dry-run] verify
  ./setup.sh [--dry-run] sources
  ./setup.sh [--dry-run] base
  ./setup.sh [--dry-run] apps
  ./setup.sh [--dry-run] tools
  ./setup.sh [--dry-run] terminal
  ./setup.sh [--dry-run] codex
  ./setup.sh [--dry-run] dotfiles
  ./setup.sh [--dry-run] gnome
  ./setup.sh [--dry-run] keybinds

Commands:
  bootstrap  With Ansible present, repair a reviewed APT conflict; then bootstrap
  all        Bootstrap, run seven workstation actions in order, then verify
  status     Read-only ADHD-friendly state board; missing items are allowed
  verify     Read-only state board that fails until the core setup is ready
  sources    Repair verified vendor APT sources without refreshing APT
  base       Core packages, Oh My Posh, and CaskaydiaCove Nerd Font
  apps       Approved APT apps, Postman Snap, Upscayl Flatpak, and LibrePods
  tools      Eight Ubuntu APT tools; removes local command shadows
  terminal   Make launch-tested Ghostty the Ubuntu default
  codex      Show the official Codex CLI route; make no change
  dotfiles   Fast-forward and run only dotfiles/linux-desktop.sh; set user Zsh
  gnome      Small, reversible macOS-friendly GNOME preferences
  keybinds   Guarded interactive Toshy install for physical Command shortcuts

--dry-run previews without network, sudo, downloads, or managed-state writes.
Ansible actions may create their ignored local temporary directory.

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
      bootstrap | all | status | verify | sources | base | apps | tools | terminal | codex | dotfiles | gnome | keybinds)
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

claude_unmanaged_source_present() {
  local path pattern result
  local -a grep_args

  for path in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [[ "$path" != "$claude_managed_source" ]] || continue
    [[ -e "$path" || -L "$path" ]] || continue
    [[ -f "$path" ]] || continue
    if [[ "$path" == *.sources ]]; then
      pattern="$claude_repository_uri"
      grep_args=(-Fq)
    else
      pattern="$claude_list_repository_pattern"
      grep_args=(-Eq)
    fi
    if grep "${grep_args[@]}" "$pattern" "$path"; then
      [[ ! -L "$path" ]] || die "refusing symlinked Claude APT source: $path"
      return 0
    else
      result=$?
      [[ "$result" -eq 1 ]] || die "could not inspect Claude APT source candidate: $path"
    fi
  done

  return 1
}

repair_known_claude_source_conflict() {
  claude_unmanaged_source_present || return 0
  command -v ansible-playbook >/dev/null 2>&1 ||
    die "Claude has conflicting APT sources, but Ansible is unavailable for the guarded repair"

  printf '%s\n' 'Claude source preflight: verifying the managed source before removing the exact duplicate'
  "$repo_dir/setup.sh" sources ||
    die "Claude source preflight refused the local files; leave them untouched and report its first error"
}

bootstrap_ansible() {
  target_preflight
  if [[ "$dry_run" == true ]]; then
    printf '%s\n' '[dry-run] sudo apt-get update'
    printf '%s\n' '[dry-run] sudo apt-get install --yes --no-install-recommends ansible-core python3-apt python3-debian sudo'
    return
  fi
  repair_known_claude_source_conflict
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

verify_git_source() {
  local source_dir="$1" expected_repo="$2" expected_commit="$3" expected_tree_sha256="$4"
  local origin head tree_sha256

  [[ -d "$source_dir/.git" && ! -L "$source_dir" ]] ||
    die "$source_dir is not a safe Git checkout"
  origin="$(git -C "$source_dir" remote get-url origin)"
  [[ "$origin" == "$expected_repo" ]] || die "unexpected source origin: $origin"
  [[ -z "$(git -C "$source_dir" status --porcelain)" ]] ||
    die "source checkout is not clean: $source_dir"
  head="$(git -C "$source_dir" rev-parse HEAD)"
  [[ "$head" == "$expected_commit" ]] ||
    die "source commit verification failed: expected $expected_commit, found $head"
  tree_sha256="$(git -C "$source_dir" ls-tree -r --full-tree HEAD | sha256sum | awk '{print $1}')"
  [[ "$tree_sha256" == "$expected_tree_sha256" ]] ||
    die "source tree SHA-256 verification failed for $source_dir"
}

show_macos_key_checklist() {
  printf '%s\n' \
    "MAC MODE MANUAL CHECKLIST" \
    "  GUI:      Command+C/V/X/Z/Shift+Z/A/S/F/N/T/W/Q" \
    "  SEARCH:   Command+Space" \
    "  WINDOWS:  Command+Tab, Command+Shift+Tab, Command+grave" \
    "  DESKTOP:  Control+Left/Right changes workspace; Control+Command+Q locks" \
    "  TEXT:     Option+Left/Right, Option+Delete, Command+arrows" \
    "  CAPTURE:  Command+Shift+3/4/5" \
    "  GHOSTTY:  Command+C/V/T/W/D/Shift+D/K; physical Control+C still interrupts" \
    "If one group fails, run: toshy-debug"
}

require_live_gnome_session() {
  local desktop="${XDG_CURRENT_DESKTOP:-}"

  [[ -z "${SSH_CONNECTION:-}${SSH_TTY:-}" ]] ||
    die "keybinds must run in Ghostty on the MacBook Air, not through SSH"
  [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] ||
    die "keybinds must run inside the logged-in Ubuntu desktop, not SSH or a TTY"
  [[ "${XDG_RUNTIME_DIR:-}" == /* && -d "${XDG_RUNTIME_DIR:-}" ]] ||
    die "the desktop runtime directory is unavailable; open Ghostty from Ubuntu and retry"
  [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] ||
    die "no live Wayland or X11 display was detected"
  [[ "${desktop,,}" == *gnome* || "${desktop,,}" == *ubuntu* ]] ||
    die "keybinds supports the Ubuntu GNOME desktop only; detected: ${desktop:-unknown}"
}

refuse_competing_keymappers() {
  local unit

  [[ ! -e "$HOME/.Xmodmap" ]] ||
    die "move ~/.Xmodmap aside before using Toshy; two global keymaps will conflict"

  for unit in xremap.service input-remapper.service input-remapper-daemon.service; do
    systemctl --user is-active --quiet "$unit" 2>/dev/null &&
      die "stop and disable the competing user service before Toshy: $unit"
  done
  for unit in keyd.service input-remapper-daemon.service; do
    systemctl is-active --quiet "$unit" 2>/dev/null &&
      die "stop and disable the competing system service before Toshy: $unit"
  done
  return 0
}

start_toshy_services() {
  local bin_dir="$HOME/.local/bin"
  local command_name
  local unit

  for command_name in toshy-services-enable toshy-services-restart toshy-services-status; do
    [[ -x "$bin_dir/$command_name" ]] ||
      die "Toshy command is missing: $bin_dir/$command_name"
  done

  "$bin_dir/toshy-services-enable" || die "Toshy could not enable its user services"
  "$bin_dir/toshy-services-restart" ||
    die "Toshy is installed but cannot start in this login. Reboot, then rerun: ./setup.sh keybinds"
  for unit in toshy-config.service toshy-session-monitor.service; do
    systemctl --user is-enabled --quiet "$unit" ||
      die "Toshy user service is not enabled at login: $unit"
    systemctl --user is-active --quiet "$unit" ||
      die "Toshy user service is not healthy: $unit. Reboot, then rerun: ./setup.sh keybinds"
  done
  "$bin_dir/toshy-services-status"
  show_macos_key_checklist
}

install_keybinds() {
  (( EUID != 0 )) || die "run keybinds as the desktop user, not root"
  [[ "$HOME" == /* && "$HOME" != "/" ]] || die "HOME must be a safe absolute path"
  target_preflight
  local source_parent="$HOME/.local/src"
  local source_dir="$source_parent/toshy-$toshy_tag"
  local keymapper_dir="$source_parent/xwaykeyz-$xwaykeyz_commit"
  local answer

  if [[ "$dry_run" == true ]]; then
    printf '%s\n' "[dry-run] require enabled GNOME extension: $focus_extension"
    printf '%s\n' "[dry-run] require a live Ubuntu GNOME session and refuse competing keymappers"
    printf '%s\n' "[dry-run] clone $toshy_repo tag $toshy_tag"
    printf '%s\n' "[dry-run] verify Toshy commit and tree SHA-256: $toshy_commit"
    printf '%s\n' "[dry-run] verify xwaykeyz commit and tree SHA-256: $xwaykeyz_commit"
    printf '%s\n' "[dry-run] run the pinned interactive Toshy user installer"
    printf '%s\n' "[dry-run] enable, restart, and check Toshy's user services"
    show_macos_key_checklist
    return
  fi

  [[ -t 0 && -t 1 ]] || die "keybinds must run in an interactive desktop terminal"
  command -v git >/dev/null 2>&1 || die "git is missing. Run: ./setup.sh base"
  command -v systemctl >/dev/null 2>&1 || die "systemctl is missing"
  require_live_gnome_session
  refuse_competing_keymappers

  if [[ "${XDG_SESSION_TYPE:-}" == wayland || -n "${WAYLAND_DISPLAY:-}" ]]; then
    command -v gnome-extensions >/dev/null 2>&1 || die "gnome-extensions is missing"
    gnome-extensions list --enabled | grep -Fxq "$focus_extension" ||
      die "enable Focused Window D-Bus first: https://extensions.gnome.org/extension/5592/focused-window-d-bus/"
  fi

  if [[ -f "$HOME/.config/toshy/toshy_config.py" &&
        ! -L "$HOME/.config/toshy/toshy_config.py" &&
        -d "$source_dir/.git" && -d "$keymapper_dir/.git" ]]; then
    verify_git_source "$source_dir" "$toshy_repo" "$toshy_commit" "$toshy_tree_sha256"
    verify_git_source "$keymapper_dir" "$xwaykeyz_repo" "$xwaykeyz_commit" "$xwaykeyz_tree_sha256"
    printf '%s\n' "Verified the existing pinned Toshy installation"
    start_toshy_services
    return
  fi

  printf '%s\n' "Toshy does not yet list Ubuntu 26.04 in its tested matrix."
  printf '%s\n' "This runs Toshy's pinned interactive user installer; it may ask for sudo."
  read -r -p "Continue with the guarded trial? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || die "keybinds install cancelled"

  mkdir -p "$source_parent"
  if [[ -e "$source_dir" ]]; then
    [[ -d "$source_dir" ]] || die "$source_dir exists but is not a directory"
  else
    git clone --depth 1 --branch "$toshy_tag" --single-branch "$toshy_repo" "$source_dir"
  fi
  verify_git_source "$source_dir" "$toshy_repo" "$toshy_commit" "$toshy_tree_sha256"

  if [[ -e "$keymapper_dir" ]]; then
    [[ -d "$keymapper_dir" ]] || die "$keymapper_dir exists but is not a directory"
  else
    git init "$keymapper_dir"
    git -C "$keymapper_dir" remote add origin "$xwaykeyz_repo"
    git -C "$keymapper_dir" fetch --depth 1 origin "$xwaykeyz_commit"
    git -C "$keymapper_dir" checkout --detach FETCH_HEAD
  fi
  verify_git_source "$keymapper_dir" "$xwaykeyz_repo" "$xwaykeyz_commit" "$xwaykeyz_tree_sha256"

  printf '%s\n' "Verified Toshy $toshy_tag and xwaykeyz source trees"
  (cd "$source_dir" && ./setup_toshy.py install --dev-keymapper "$xwaykeyz_commit")

  start_toshy_services
  printf '%s\n' "If the installer showed its REBOOT banner, reboot before judging any shortcut."
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
      sources | base | apps | tools)
        require_classic_sudo
        /usr/bin/sudo.ws -n /usr/bin/true 2>/dev/null || command+=(--ask-become-pass)
        ;;
      dotfiles)
        if dotfiles_needs_become; then
          require_classic_sudo
          /usr/bin/sudo.ws -n /usr/bin/true 2>/dev/null || command+=(--ask-become-pass)
        fi
        ;;
    esac
  fi
  exec "${command[@]}"
}

run_all() {
  local step final_step="verify" step_number=0
  local total_steps=$(( ${#all_actions[@]} + 1 ))
  local -a command

  if [[ "$dry_run" == false ]]; then
    printf '\n[%d/%d] %s\n' 1 "$((total_steps + 1))" bootstrap
    "$repo_dir/setup.sh" bootstrap || die "all stopped at bootstrap; fix that error, then rerun ./setup.sh all"
    total_steps=$((total_steps + 1))
    step_number=1
  else
    final_step="status"
    if claude_unmanaged_source_present; then
      printf '%s\n' '[dry-run] previewing the required Claude source repair before any APT-backed action'
      "$repo_dir/setup.sh" --dry-run sources ||
        die "dry-run all could not verify the Claude source repair; leave the files untouched"
      die "dry-run all stopped before APT; run ./setup.sh sources, then rerun ./setup.sh --dry-run all"
    fi
    printf '%s\n' '[dry-run] bootstrap skipped: preview never uses network or sudo'
  fi

  for step in "${all_actions[@]}"; do
    step_number=$((step_number + 1))
    printf '\n[%d/%d] %s\n' "$step_number" "$total_steps" "$step"
    command=("$repo_dir/setup.sh")
    [[ "$dry_run" == false ]] || command+=(--dry-run)
    command+=("$step")
    "${command[@]}" || die "all stopped at $step; fix that error, then rerun ./setup.sh all"
  done

  step_number=$((step_number + 1))
  printf '\n[%d/%d] %s\n' "$step_number" "$total_steps" "$final_step"
  "$repo_dir/setup.sh" "$final_step" ||
    die "all stopped at $final_step; use ./setup.sh status, fix the failed checks, then rerun ./setup.sh all"
}

main() {
  parse_args "$@"
  case "$action" in
    help) usage ;;
    bootstrap) bootstrap_ansible ;;
    all) run_all ;;
    status) run_status false ;;
    verify) run_status true ;;
    codex)
      target_preflight
      printf '%s\n' "No change made. Follow OpenAI's official Linux instructions:"
      printf '%s\n' 'https://github.com/openai/codex#quickstart'
      printf '%s\n' 'Then run codex and choose Sign in with ChatGPT.'
      ;;
    keybinds) install_keybinds ;;
    *) run_action ;;
  esac
}

main "$@"
