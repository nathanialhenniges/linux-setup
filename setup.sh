#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT_DIR"
export ANSIBLE_CONFIG="$ROOT_DIR/ansible.cfg"

AUR_PACKAGES=(google-chrome visual-studio-code-bin facetimehd-dkms facetimehd-firmware)
DOTFILES_URL=https://github.com/nathanialhenniges/dotfiles.git
DOTFILES_PATH="${HOME:?HOME is not set}/.local/share/dotfiles"

DRY_RUN=false
ACCEPT_TARGET_WARNING=false
TARGET_WARNING_ACCEPTED=false
TARGET_CHECKS_COMPLETE=false
ACTION=

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--dry-run] [--accept-target-warning] <action>

Actions:
  bootstrap   Upgrade the system and install local Ansible
  chrome      Install Google Chrome early so this guide can stay open on the Mac
  all         Run base, apps, tools, desktop, branding, dotfiles, verify, then ask about Firefox cleanup
  status      Show a short readiness summary
  state       Show missing packages, Flatpak origins, and service state
  verify      Fail unless the reviewed workstation state is present
  camera      Check FaceTime HD camera packages, DKMS build, and video device
  base        Install base packages and laptop power profiles
  apps        Install Hyprland, laptop apps, Wi-Fi support, Flatpaks, and LibrePods
  tools       Install the selected command-line tools
  desktop     Configure Hyprland, wallpaper, and Workspace/ChatGPT shortcuts
  branding    Install the branded Plymouth startup splash
  purge-firefox Uninstall Firefox and erase its profile data (keeps Chrome)
  dotfiles    Run only the dedicated dotfiles linux-desktop.sh profile
  drive       Show the browser-only Google Drive steps
  terminal    Show the Ghostty keyboard shortcut
  keybinds    Show the Hyprland keyboard shortcuts

--dry-run prints the reviewed plan only. It does not run sudo, Ansible, or network calls.
--accept-target-warning explicitly accepts a mismatch in the detected Mac model or OS identity.
EOF
}

fail() {
  printf 'setup.sh: %s\n' "$1" >&2
  exit 1
}

confirm_target_identity() {
  [[ "$TARGET_CHECKS_COMPLETE" == true ]] && return

  local os_id=unknown id_like=not-set product_name=unavailable answer
  if [[ -r /etc/os-release ]]; then
    os_id="$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release)"
    id_like="$(awk -F= '$1 == "ID_LIKE" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release)"
    os_id="${os_id:-unknown}"
    id_like="${id_like:-not-set}"
  fi
  if [[ -r /sys/class/dmi/id/product_name ]]; then
    product_name="$(</sys/class/dmi/id/product_name)"
  fi

  local -a mismatches=()
  if [[ "$os_id" != arch && "$os_id" != endeavouros ]]; then
    mismatches+=("OS identity differs from Arch/EndeavourOS (ID=$os_id, ID_LIKE=$id_like)")
  fi
  if [[ "$product_name" != MacBookAir7,2 ]]; then
    mismatches+=("Mac model differs from MacBookAir7,2 (detected: ${product_name:-unavailable})")
  fi

  if ((${#mismatches[@]})); then
    printf '\nWARNING: this setup is designed for EndeavourOS/Arch Linux on MacBookAir7,2.\n' >&2
    printf 'Detected: OS ID=%s, ID_LIKE=%s; model=%s.\n' "$os_id" "$id_like" "$product_name" >&2
    printf 'A mismatch can mean the setup is not compatible with this computer.\n' >&2
    printf 'Mismatches:\n' >&2
    printf '  - %s\n' "${mismatches[@]}" >&2
    if [[ "$ACCEPT_TARGET_WARNING" == true ]]; then
      printf 'Warning explicitly accepted with --accept-target-warning.\n' >&2
      TARGET_WARNING_ACCEPTED=true
    else
      [[ -t 0 ]] || fail 'target identity needs confirmation; rerun with --accept-target-warning to explicitly accept this warning'
      read -r -p 'Type CONTINUE to accept this warning, or press Enter to stop: ' answer || answer=
      [[ "$answer" == CONTINUE ]] || fail 'target warning was not accepted; no setup actions were run'
      TARGET_WARNING_ACCEPTED=true
    fi
  fi
  TARGET_CHECKS_COMPLETE=true
}

parse_args() {
  while (($#)); do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        ;;
      --accept-target-warning)
        ACCEPT_TARGET_WARNING=true
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
  command -v pacman >/dev/null 2>&1 || fail 'pacman is required; this setup cannot manage packages on this system'
  confirm_target_identity

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

ensure_ansible_collections() {
  command -v ansible-galaxy >/dev/null 2>&1 || fail 'ansible-galaxy is missing; run ./setup.sh bootstrap first'
  if ansible-doc -t module -F 2>/dev/null | awk '$1 == "community.general.pacman" { found = 1 } END { exit !found }'; then
    return
  fi
  ansible-galaxy collection install --requirements-file "$ROOT_DIR/requirements.yml"
  ansible-doc -t module -F 2>/dev/null | awk '$1 == "community.general.pacman" { found = 1 } END { exit !found }' || fail 'community.general.pacman is unavailable after collection installation'
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
  result="{\"aur_package_names\":$(json_array "${AUR_PACKAGES[@]}"),\"target_warning_accepted\":$TARGET_WARNING_ACCEPTED"
  [[ -z "$action" ]] || result+=",\"setup_action\":\"$action\""
  [[ -z "$mode" ]] || result+=",\"verification_mode\":\"$mode\""
  result+='}'
  printf '%s' "$result"
}

sync_system() {
  assert_target
  command -v sudo >/dev/null 2>&1 || fail 'sudo is required for pacman package updates'
  sudo pacman -Syu --needed ansible-core
  ensure_ansible_collections
}

run_site_action() {
  local action="$1"
  require_ansible
  ensure_ansible_collections
  ansible-playbook -i "$ROOT_DIR/inventory.ini" "$ROOT_DIR/site.yml" \
    --limit workstation --tags "$action" --extra-vars "$(extra_vars "$action")"
}

run_verification() {
  local mode="$1"
  require_ansible
  ansible-playbook -i "$ROOT_DIR/inventory.ini" "$ROOT_DIR/verify.yml" \
    --limit workstation --extra-vars "$(extra_vars '' "$mode")"
}

install_chrome() {
  assert_target
  command -v yay >/dev/null 2>&1 || fail 'yay is required for Google Chrome; EndeavourOS includes it, plain Arch must install it separately'
  yay -S --needed google-chrome
  [[ -x /usr/bin/google-chrome-stable ]] || fail 'Google Chrome did not install its expected executable'
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
      printf '  Install the pinned community.general.pacman collection if missing\n'
      ;;
    chrome)
      printf '  Install Google Chrome with yay -S --needed google-chrome\n'
      printf '  Keep Firefox installed for now; its optional cleanup happens at the end of all\n'
      ;;
    all)
      printf '  sudo pacman -Syu --needed ansible-core\n'
      printf '  Ensure the pinned community.general.pacman collection is installed\n'
      printf '  Ansible actions: base → apps → tools → desktop → branding, then optional Firefox cleanup\n'
      printf '  After apps installs kernel headers, interactive yay packages: %s\n' "${AUR_PACKAGES[*]}"
      printf '  Dotfiles: clean expected checkout → linux-desktop.sh → user zsh shell\n'
      printf '  Chrome installs with the AUR apps before the final Firefox cleanup prompt\n'
      printf '  Final: strict status verification, then ask whether to uninstall Firefox and erase its data\n'
      ;;
    base|apps|tools)
      printf '  sudo pacman -Syu --needed ansible-core\n'
      printf '  Ensure the pinned community.general.pacman collection is installed\n'
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
    purge-firefox)
      printf '  Ensure the pinned community.general.pacman collection is installed\n'
      printf '  Remove the Firefox package\n'
      printf '  Delete Firefox user data under ~/.mozilla, ~/.cache/mozilla, ~/.config/mozilla, ~/.local/share/mozilla, and ~/.var/app/org.mozilla.firefox\n'
      printf '  Leave Google Chrome and its profile data untouched\n'
      ;;
    dotfiles)
      printf '  Clone or fast-forward the clean expected dotfiles checkout\n'
      printf "  Run only linux-desktop.sh; set the current user's shell to /usr/bin/zsh after success\n"
      ;;
    status|state|verify)
      printf '  Read-only local Ansible verification: %s\n' "$ACTION"
      ;;
    camera)
      printf '  Read-only check for camera packages, DKMS build, and /dev/video device\n'
      printf '  Afterward, open Google Meet in Chrome and confirm the preview shows video\n'
      ;;
    drive|terminal|keybinds)
      printf '  No changes; show manual Hyprland setup steps\n'
      ;;
    *)
      fail "unknown action: $ACTION"
      ;;
  esac
}

confirm_firefox_purge() {
  local answer
  printf 'Firefox cleanup removes its local profiles, bookmarks, saved logins, cookies, extensions, settings, and cache. Google Chrome and Chrome data stay untouched.\n'
  if [[ ! -t 0 ]] || ! read -r -p 'Remove Firefox now? [y/N] ' answer; then
    printf 'Skipped Firefox cleanup; no changes made.\n'
    return 1
  fi
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *)
      printf 'Skipped Firefox cleanup; no changes made.\n'
      return 1
      ;;
  esac
}

camera_diagnostics() {
  local missing=0 package dkms_camera_status running_kernel
  printf 'FaceTime HD camera check (best after reboot):\n'

  for package in facetimehd-dkms facetimehd-firmware v4l-utils; do
    if pacman -Q "$package"; then
      :
    else
      printf '  MISSING: %s\n' "$package"
      missing=1
    fi
  done

  if command -v dkms >/dev/null 2>&1; then
    dkms_camera_status="$(dkms status 2>/dev/null | grep -i facetimehd || true)"
    running_kernel="$(uname -r)"
    if [[ "$dkms_camera_status" == *"$running_kernel"* && "$dkms_camera_status" == *installed* ]]; then
      printf 'FaceTime camera driver build: %s\n' "$dkms_camera_status"
    else
      printf 'FaceTime camera driver is not built for the running kernel (%s) yet.\n' "$running_kernel"
      [[ -z "$dkms_camera_status" ]] || printf '%s\n' "$dkms_camera_status"
      missing=1
    fi
  else
    printf 'DKMS is unavailable; the camera driver cannot be checked.\n'
    missing=1
  fi

  if ! command -v v4l2-ctl >/dev/null 2>&1; then
    printf 'v4l2-ctl is unavailable; install v4l-utils and rerun this check.\n'
    missing=1
  elif ! compgen -G '/dev/video*' >/dev/null; then
    printf 'No /dev/video device detected yet.\n'
    missing=1
  else
    printf 'Detected video device(s):\n'
    v4l2-ctl --list-devices || missing=1
  fi

  printf '\nTo confirm the camera produces an image, open Google Meet in Chrome and check its camera preview.\n'
  if ((missing)); then
    printf 'If you just installed the camera support, reboot and run ./setup.sh camera again. If it still fails, share this output.\n' >&2
    return 1
  fi
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
    chrome)
      install_chrome
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
      if confirm_firefox_purge; then
        run_site_action purge-firefox
      fi
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
    purge-firefox)
      assert_target
      if confirm_firefox_purge; then
        run_site_action purge-firefox
      fi
      ;;
    dotfiles)
      run_dotfiles
      ;;
    status)
      assert_target
      run_verification status
      ;;
    state)
      assert_target
      run_verification state
      ;;
    verify)
      assert_target
      run_verification verify
      ;;
    drive|terminal|keybinds)
      manual_action
      ;;
    camera)
      assert_target
      camera_diagnostics
      ;;
    *)
      fail "unknown action: $ACTION"
      ;;
  esac
}

main "$@"
