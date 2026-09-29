#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT_DIR"
export ANSIBLE_CONFIG="$ROOT_DIR/ansible.cfg"

AUR_PACKAGES=(google-chrome visual-studio-code-bin facetimehd-dkms facetimehd-firmware)
DOTFILES_URL=https://github.com/nathanialhenniges/dotfiles.git
DOTFILES_PATH="${HOME:?HOME is not set}/.local/share/dotfiles"

DRY_RUN=false
ACTION=

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--dry-run] <action>

Actions:
  bootstrap   Upgrade the system and install local Ansible
  all         Run base, apps, tools, desktop, branding, dotfiles, then verify
  status      Show a short readiness summary
  state       Show missing packages, Flatpak origins, and service state
  verify      Fail unless the reviewed workstation state is present
  base        Install base packages and laptop power profiles
  apps        Install Hyprland, laptop apps, Wi-Fi support, Flatpaks, and LibrePods
  tools       Install the selected command-line tools
  desktop     Configure Hyprland, wallpaper, and Workspace/ChatGPT shortcuts
  branding    Install the branded Plymouth startup splash
  dotfiles    Run only the dedicated dotfiles linux-desktop.sh profile
  drive       Show the browser-only Google Drive steps
  terminal    Show the Ghostty keyboard shortcut
  keybinds    Show the Hyprland keyboard shortcuts

--dry-run prints the reviewed plan only. It does not run sudo, Ansible, or network calls.
EOF
}

fail() {
  printf 'setup.sh: %s\n' "$1" >&2
  exit 1
}

parse_args() {
  while (($#)); do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        [[ -z "$ACTION" ]] || fail 'choose one action'
        ACTION="$1"
        ;;
    esac
    shift
  done
  [[ -n "$ACTION" ]] || { usage; exit 2; }
}

assert_target() {
  [[ $EUID -ne 0 ]] || fail 'run as your normal user, not root'
  [[ "$(uname -m)" == x86_64 ]] || fail 'this setup supports x86-64 only'
  [[ -r /etc/os-release ]] && grep -Eq '^ID=("?(arch|endeavouros)"?)$' /etc/os-release || fail 'this setup supports Arch Linux or EndeavourOS only'
  [[ -r /sys/class/dmi/id/product_name ]] || fail 'cannot verify the Mac model'
  [[ "$(< /sys/class/dmi/id/product_name)" == MacBookAir7,2 ]] || fail 'this setup supports MacBookAir7,2 only'

  local sshd_enabled
  if systemctl is-active --quiet sshd.service; then
    fail 'sshd is active; stop it manually before running setup. This repo will not change SSH service state.'
  fi
  sshd_enabled="$(systemctl is-enabled sshd.service 2>/dev/null || true)"
  case "$sshd_enabled" in
    enabled|enabled-runtime|linked|linked-runtime)
      fail 'sshd is enabled; disable it manually before running setup. This repo will not change SSH service state.'
      ;;
  esac
}

require_ansible() {
  command -v ansible-playbook >/dev/null 2>&1 || fail 'Ansible is missing; run ./setup.sh bootstrap first'
}

json_array() {
  local result='[' separator='' item
  for item in "$@"; do
    result+="$separator\"$item\""
    separator=,
  done
  printf '%s]' "$result"
}

extra_vars() {
  local action="${1:-}" mode="${2:-}" result
  result="{\"aur_package_names\":$(json_array "${AUR_PACKAGES[@]}")"
  [[ -z "$action" ]] || result+=",\"setup_action\":\"$action\""
  [[ -z "$mode" ]] || result+=",\"verification_mode\":\"$mode\""
  result+='}'
  printf '%s' "$result"
}

sync_system() {
  assert_target
  command -v sudo >/dev/null 2>&1 || fail 'sudo is required for pacman package updates'
  sudo pacman -Syu --needed ansible-core
}

run_site_action() {
  local action="$1"
  require_ansible
  ansible-playbook -i "$ROOT_DIR/inventory.ini" "$ROOT_DIR/site.yml" \
    --limit workstation --tags "$action" --extra-vars "$(extra_vars "$action")"
}

run_verification() {
  local mode="$1"
  require_ansible
  ansible-playbook -i "$ROOT_DIR/inventory.ini" "$ROOT_DIR/verify.yml" \
    --limit workstation --extra-vars "$(extra_vars '' "$mode")"
}

install_aur_apps() {
  assert_target
  command -v yay >/dev/null 2>&1 || fail 'yay is required for the reviewed AUR apps; EndeavourOS includes it, plain Arch must install it separately'
  yay -S --needed "${AUR_PACKAGES[@]}"
  [[ -x /usr/bin/google-chrome-stable ]] || fail 'Google Chrome did not install its expected executable'
  [[ -x /usr/bin/code ]] || fail 'Visual Studio Code did not install its expected executable'
}

ensure_dotfiles_parent() {
  local parent
  for parent in "$HOME/.local" "$HOME/.local/share"; do
    [[ ! -L "$parent" ]] || fail "refusing linked dotfiles parent: $parent"
    [[ ! -e "$parent" || -d "$parent" ]] || fail "refusing non-directory dotfiles parent: $parent"
  done
  mkdir -p "$HOME/.local/share"
}

run_dotfiles() {
  assert_target
  command -v git >/dev/null 2>&1 || fail 'Git is required for the dotfiles desktop profile'
  ensure_dotfiles_parent

  if [[ -e "$DOTFILES_PATH" || -L "$DOTFILES_PATH" ]]; then
    [[ -d "$DOTFILES_PATH" && ! -L "$DOTFILES_PATH" ]] || fail 'dotfiles path exists but is not a real directory'
    git -C "$DOTFILES_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail 'existing dotfiles path is not a Git checkout'
    [[ "$(git -C "$DOTFILES_PATH" remote get-url origin 2>/dev/null || true)" == "$DOTFILES_URL" ]] || fail 'dotfiles origin does not match the reviewed repository'
    [[ -z "$(git -C "$DOTFILES_PATH" status --porcelain)" ]] || fail 'dotfiles checkout is not clean; refusing to update or run it'
    [[ "$(git -C "$DOTFILES_PATH" branch --show-current)" == main ]] || fail 'dotfiles checkout is not on main'
    git -C "$DOTFILES_PATH" fetch origin main:refs/remotes/origin/main
    git -C "$DOTFILES_PATH" merge-base --is-ancestor HEAD origin/main || fail 'dotfiles checkout diverged from origin/main'
    git -C "$DOTFILES_PATH" merge --ff-only origin/main
  else
    git clone --branch main --single-branch "$DOTFILES_URL" "$DOTFILES_PATH"
  fi

  [[ "$(git -C "$DOTFILES_PATH" remote get-url origin 2>/dev/null || true)" == "$DOTFILES_URL" ]] || fail 'dotfiles origin does not match the reviewed repository'
  [[ "$(git -C "$DOTFILES_PATH" branch --show-current)" == main ]] || fail 'dotfiles checkout is not on main'
  [[ -z "$(git -C "$DOTFILES_PATH" status --porcelain)" ]] || fail 'dotfiles checkout is not clean after update'
  [[ -f "$DOTFILES_PATH/linux-desktop.sh" && ! -L "$DOTFILES_PATH/linux-desktop.sh" && -x "$DOTFILES_PATH/linux-desktop.sh" ]] || fail 'dotfiles linux-desktop.sh is missing, linked, or not executable'
  "$DOTFILES_PATH/linux-desktop.sh"

  local user_name current_shell shell_path
  user_name="$(id -un)"
  shell_path=/usr/bin/zsh
  [[ -x "$shell_path" && ! -L "$shell_path" ]] || fail 'packaged /usr/bin/zsh is missing or unsafe'
  grep -Fxq "$shell_path" /etc/shells || fail '/usr/bin/zsh is not listed in /etc/shells'
  current_shell="$(getent passwd "$user_name" | cut -d: -f7)"
  [[ -n "$current_shell" ]] || fail "could not read the current user's login shell"
  if [[ "$current_shell" != "$shell_path" ]]; then
    sudo chsh --shell "$shell_path" "$user_name"
  fi
}

dry_run() {
  printf 'Dry run: %s\n' "$ACTION"
  case "$ACTION" in
    bootstrap)
      printf '  sudo pacman -Syu --needed ansible-core\n'
      ;;
    all)
      printf '  sudo pacman -Syu --needed ansible-core\n'
      printf '  Ansible actions: base → apps → tools → desktop → branding\n'
      printf '  After apps installs kernel headers, interactive yay packages: %s\n' "${AUR_PACKAGES[*]}"
      printf '  Dotfiles: clean expected checkout → linux-desktop.sh → user zsh shell\n'
      printf '  Final: strict status verification\n'
      ;;
    base|apps|tools)
      printf '  sudo pacman -Syu --needed ansible-core\n'
      printf '  Local Ansible action: %s\n' "$ACTION"
      [[ "$ACTION" != apps ]] || printf '  Then install reviewed AUR packages: %s\n' "${AUR_PACKAGES[*]}"
      ;;
    desktop)
      printf '  Local Ansible action: desktop\n'
      printf '  Install Hyprland and Waybar configs, logo and wallpaper, and reviewed Chrome shortcuts\n'
      ;;
    branding)
      printf '  Local Ansible action: branding\n'
      printf '  Set the custom Plymouth theme and quiet splash, then rebuild systemd-boot entries and initrds\n'
      ;;
    dotfiles)
      printf '  Clone or fast-forward the clean expected dotfiles checkout\n'
      printf "  Run only linux-desktop.sh; set the current user's shell to /usr/bin/zsh after success\n"
      ;;
    status|state|verify)
      printf '  Read-only local Ansible verification: %s\n' "$ACTION"
      ;;
    drive|terminal|keybinds)
      printf '  No changes; show manual Hyprland setup steps\n'
      ;;
    *)
      fail "unknown action: $ACTION"
      ;;
  esac
}

manual_action() {
  case "$ACTION" in
    drive)
      cat <<'EOF'
Google Drive:
  1. Open Chrome from the app launcher.
  2. Visit https://drive.google.com/ and sign in manually.
  3. Keep Google Drive browser-only; do not copy browser profiles or OAuth data.
EOF
      ;;
    terminal)
      cat <<'EOF'
Default terminal:
  Press Super + Enter to open Ghostty.
EOF
      ;;
    keybinds)
      cat <<'EOF'
Hyprland keyboard shortcuts (Super is the Mac Command key):
  Super + Enter       Ghostty
  Super + Space       App launcher
  Super + E           File manager
  Super + Q           Close window
  Super + L           Lock screen
  Super + F           Toggle fullscreen
  Super + 1…4         Switch workspace
  Super + Shift + 1…4 Move window to workspace
  Super + R           Enter Remote Mac mode before Chrome Remote Desktop
  Escape              Leave Remote Mac mode
  Print               Screenshot
  Super + Shift + S   Select screenshot area and copy it
  Brightness and media keys work directly.
EOF
      ;;
  esac
}

main() {
  parse_args "$@"
  if [[ "$DRY_RUN" == true ]]; then
    dry_run
    return
  fi

  case "$ACTION" in
    bootstrap)
      sync_system
      ;;
    all)
      sync_system
      run_site_action base
      run_site_action apps
      install_aur_apps
      run_site_action tools
      run_site_action desktop
      run_site_action branding
      run_dotfiles
      run_verification verify
      ;;
    base)
      sync_system
      run_site_action base
      ;;
    apps)
      sync_system
      run_site_action apps
      install_aur_apps
      ;;
    tools)
      sync_system
      run_site_action tools
      ;;
    desktop)
      assert_target
      run_site_action desktop
      ;;
    branding)
      assert_target
      run_site_action branding
      ;;
    dotfiles)
      run_dotfiles
      ;;
    status)
      run_verification status
      ;;
    state)
      run_verification state
      ;;
    verify)
      run_verification verify
      ;;
    drive|terminal|keybinds)
      manual_action
      ;;
    *)
      fail "unknown action: $ACTION"
      ;;
  esac
}

main "$@"
