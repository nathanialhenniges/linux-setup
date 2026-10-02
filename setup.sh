#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT_DIR"
export ANSIBLE_CONFIG="$ROOT_DIR/ansible.cfg"
source "$ROOT_DIR/scripts/sudo-session.sh"

AUR_PACKAGES=(google-chrome visual-studio-code-bin facetimehd-dkms facetimehd-firmware gnome-shell-extension-dash-to-dock oh-my-posh-bin 1password)
HYPRLAND_PACKAGES=(hyprland hypridle hyprlock hyprpaper hyprpolkitagent waybar wofi mako xdg-desktop-portal-hyprland network-manager-applet thunar thunar-volman tumbler grim slurp)
EXTRA_TERMINAL_PACKAGES=(gnome-console gnome-terminal konsole xfce4-terminal xterm kitty alacritty foot tilix terminator mate-terminal qterminal lxterminal rxvt-unicode yakuake wezterm)
OPENAI_CHATGPT_INSTALLER_URL=https://persistent.oaistatic.com/codex-app-prod/linux/install-arch.sh
ONEPASSWORD_SIGNING_KEY_URL=https://downloads.1password.com/linux/keys/1password.asc
ONEPASSWORD_SIGNING_KEY_FINGERPRINT=3FEF9748469ADBE15DA7CA80AC2D62742012EA22
DOTFILES_URL=https://github.com/nathanialhenniges/dotfiles.git
DOTFILES_PATH="${HOME:?HOME is not set}/.local/share/dotfiles"
ANSIBLE_COLLECTIONS_READY=false
SUDO_KEEPALIVE_PID=

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
  all         Run setup, install the official ChatGPT app, clean up old desktop items, then ask about Firefox cleanup
  status      Show a short readiness summary
  state       Show missing packages, Flatpak origins, and service state
  verify      Fail unless the reviewed workstation state is present
  camera      Check FaceTime HD camera packages, DKMS build, and video device
  base        Install base packages and laptop power profiles
  apps        Install laptop apps, Wi-Fi support, Flatpaks, LibrePods, and official ChatGPT
  chatgpt-app Install or update ChatGPT from OpenAI's signed Arch package repository
  tools       Install the selected command-line tools
  desktop     Configure wallpaper, app shortcuts, and the account photo
  gnome-dock  Set up the Mac-inspired dock, familiar shortcuts, and light GNOME styling
  cleanup-terminals  Ask before removing extra terminal apps; keep Ghostty and command-line tools
  cleanup-legacy Remove the old ChatGPT Chrome shortcut and offer to remove old Hyprland packages
  remove-hyprland Set GDM as the login screen and uninstall the Hyprland session packages
  branding    Install the branded Plymouth startup splash
  display-manager Set GNOME's GDM login screen as the default
  profile-picture Set the supplied photo as your account/login picture
  purge-firefox Uninstall Firefox and erase its profile data (keeps Chrome)
  dotfiles    Run only the dedicated dotfiles linux-desktop.sh profile
  drive       Show the browser-only Google Drive steps
  terminal    Show how to open Ghostty from GNOME

--dry-run prints the reviewed plan only. It does not run sudo, Ansible, or network calls.
--accept-target-warning explicitly accepts a mismatch in the detected Mac model or OS identity.
EOF
}

fail() {
  printf 'setup.sh: %s\n' "$1" >&2
  exit 1
}

stop_sudo_keepalive() {
  [[ -n "$SUDO_KEEPALIVE_PID" ]] || return 0
  kill -TERM "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  SUDO_KEEPALIVE_PID=
  SETUP_BECOME_PASSWORD=
}

start_sudo_keepalive() {
  [[ -n "$SUDO_KEEPALIVE_PID" ]] && return 0
  command -v sudo >/dev/null 2>&1 || fail 'sudo is required for this action'
  [[ -t 0 && -t 1 ]] || fail 'run this action from an interactive terminal so sudo can authenticate once'

  authenticate_setup_sudo || fail 'sudo authentication failed'
  (
    SETUP_BECOME_PASSWORD=
    sleep_pid=
    trap 'if [[ -n "$sleep_pid" ]]; then kill "$sleep_pid" 2>/dev/null || true; fi; exit 0' TERM INT
    while true; do
      sleep 60 &
      sleep_pid=$!
      wait "$sleep_pid" || exit 0
      sleep_pid=
      # Open the controlling terminal for sudo's cached-ticket refresh; -n prevents a prompt.
      # shellcheck disable=SC2024
      sudo -n -v </dev/tty || exit 0
    done
  ) </dev/null >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!
  trap stop_sudo_keepalive EXIT
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
  [[ "$ANSIBLE_COLLECTIONS_READY" == true ]] && return
  command -v ansible-galaxy >/dev/null 2>&1 || fail 'ansible-galaxy is missing; run ./setup.sh bootstrap first'
  if ansible-doc -t module -F 2>/dev/null | awk '$1 == "community.general.pacman" { found = 1 } END { exit !found }'; then
    ANSIBLE_COLLECTIONS_READY=true
    return
  fi
  ansible-galaxy collection install --requirements-file "$ROOT_DIR/requirements.yml"
  ansible-doc -t module -F 2>/dev/null | awk '$1 == "community.general.pacman" { found = 1 } END { exit !found }' || fail 'community.general.pacman is unavailable after collection installation'
  ANSIBLE_COLLECTIONS_READY=true
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
  start_sudo_keepalive
  sudo pacman -Syu --needed ansible-core
  ensure_ansible_collections
}

run_site_action_local() {
  local action="$1"
  require_ansible
  run_setup_ansible -i "$ROOT_DIR/inventory.ini" "$ROOT_DIR/site.yml" \
    --limit workstation --tags "$action" --extra-vars "$(extra_vars "$action")"
}

run_site_action() {
  ensure_ansible_collections
  run_site_action_local "$1"
}

extra_vars_for_actions() {
  printf '{"aur_package_names":%s,"target_warning_accepted":%s,"setup_actions":%s}' \
    "$(json_array "${AUR_PACKAGES[@]}")" \
    "$TARGET_WARNING_ACCEPTED" \
    "$(json_array "$@")"
}

run_site_actions() {
  require_ansible
  ensure_ansible_collections
  run_setup_ansible -i "$ROOT_DIR/inventory.ini" "$ROOT_DIR/site.yml" \
    --limit workstation --extra-vars "$(extra_vars_for_actions "$@")"
}

run_verification() {
  local mode="$1"
  require_ansible
  run_setup_ansible -i "$ROOT_DIR/inventory.ini" "$ROOT_DIR/verify.yml" \
    --limit workstation --extra-vars "$(extra_vars '' "$mode")"
}

install_chrome() {
  assert_target
  command -v yay >/dev/null 2>&1 || fail 'yay is required for Google Chrome; EndeavourOS includes it, plain Arch must install it separately'
  start_sudo_keepalive
  yay -S --needed google-chrome
  [[ -x /usr/bin/google-chrome-stable ]] || fail 'Google Chrome did not install its expected executable'
}

ensure_1password_signing_key() (
  command -v gpg >/dev/null 2>&1 || fail 'GnuPG is required to verify the official 1Password package signature'
  command -v curl >/dev/null 2>&1 || fail 'curl is required to retrieve the official 1Password signing key'
  if gpg --list-keys --with-colons "$ONEPASSWORD_SIGNING_KEY_FINGERPRINT" 2>/dev/null \
      | awk -F: -v expected="$ONEPASSWORD_SIGNING_KEY_FINGERPRINT" '$1 == "fpr" && $10 == expected { found = 1 } END { exit !found }'; then
    return 0
  fi

  local key_file actual_fingerprint
  key_file="$(mktemp "${TMPDIR:-/tmp}/linux-setup-1password-key.XXXXXX")"
  trap 'rm -f -- "$key_file"' EXIT
  curl --proto '=https' --tlsv1.2 -fL --retry 3 -o "$key_file" "$ONEPASSWORD_SIGNING_KEY_URL"
  actual_fingerprint="$(gpg --show-keys --with-colons "$key_file" | awk -F: '$1 == "fpr" { print $10; exit }')"
  [[ "$actual_fingerprint" == "$ONEPASSWORD_SIGNING_KEY_FINGERPRINT" ]] \
    || fail 'the downloaded 1Password signing key fingerprint did not match the reviewed vendor fingerprint'
  gpg --import "$key_file"
)

install_aur_apps() {
  assert_target
  command -v yay >/dev/null 2>&1 || fail 'yay is required for the reviewed AUR apps; EndeavourOS includes it, plain Arch must install it separately'
  start_sudo_keepalive
  ensure_1password_signing_key
  yay -S --needed "${AUR_PACKAGES[@]}"
  [[ -x /usr/bin/google-chrome-stable ]] || fail 'Google Chrome did not install its expected executable'
  [[ -x /usr/bin/code ]] || fail 'Visual Studio Code did not install its expected executable'
  command -v oh-my-posh >/dev/null 2>&1 || fail 'Oh My Posh did not install; the configured Zsh theme needs it'
  [[ -x /usr/bin/1password ]] || fail '1Password did not install its expected executable'
  [[ -f /usr/share/applications/com.onepassword.OnePassword.desktop ]] || fail '1Password did not install its expected GNOME launcher'
}

install_zsh_theme_dependencies() {
  assert_target
  command -v yay >/dev/null 2>&1 || fail 'yay is required for Oh My Posh; EndeavourOS includes it, plain Arch must install it separately'
  command -v sudo >/dev/null 2>&1 || fail 'sudo is required to install the terminal font'
  start_sudo_keepalive
  sudo pacman -Syu --needed ttf-cascadia-code-nerd
  yay -S --needed oh-my-posh-bin
  command -v oh-my-posh >/dev/null 2>&1 || fail 'Oh My Posh did not install; the configured Zsh theme needs it'
}

install_chatgpt_app() (
  assert_target
  local update_existing=false
  [[ "${1:-}" == --update ]] && update_existing=true
  if [[ "$update_existing" == false ]] && pacman -Qq chatgpt-bin >/dev/null 2>&1; then
    printf 'The official ChatGPT package is already installed; skipping its separate installer. Use ./setup.sh chatgpt-app to update it.\n'
    exit 0
  fi
  command -v curl >/dev/null 2>&1 || fail 'curl is required to download the official OpenAI Linux installer'
  command -v sudo >/dev/null 2>&1 || fail 'sudo is required by the official OpenAI Linux installer'
  start_sudo_keepalive

  local installer_file
  installer_file="$(mktemp "${TMPDIR:-/tmp}/linux-setup-chatgpt-installer.XXXXXX")"
  trap 'rm -f -- "$installer_file"' EXIT
  chmod 0600 "$installer_file"
  curl --proto '=https' --tlsv1.2 -fL --retry 3 -o "$installer_file" "$OPENAI_CHATGPT_INSTALLER_URL"
  bash -n "$installer_file" || fail 'the downloaded official OpenAI installer did not pass the shell syntax check'
  printf 'Starting OpenAI’s official Arch installer. It verifies the signed package and asks pacman to confirm a full system upgrade.\n'
  sudo bash "$installer_file"
  pacman -Qq chatgpt-bin >/dev/null 2>&1 || fail 'the official OpenAI installer finished without installing chatgpt-bin'
  [[ -x /usr/bin/chatgpt ]] || fail 'the official ChatGPT command was not found at /usr/bin/chatgpt'
  [[ -f /usr/share/applications/chatgpt.desktop ]] || fail 'the official ChatGPT desktop launcher was not installed'
)

installed_hyprland_packages() {
  local package
  for package in "${HYPRLAND_PACKAGES[@]}"; do
    if pacman -Qq "$package" >/dev/null 2>&1; then
      printf '%s\n' "$package"
    fi
  done
}

installed_extra_terminals() {
  local package
  for package in "${EXTRA_TERMINAL_PACKAGES[@]}"; do
    if pacman -Qq "$package" >/dev/null 2>&1; then
      printf '%s\n' "$package"
    fi
  done
}

cleanup_terminals() {
  assert_target

  local answer
  local -a installed_packages=()
  mapfile -t installed_packages < <(installed_extra_terminals)
  if ((${#installed_packages[@]} == 0)); then
    printf 'No extra terminal apps from the reviewed list were found. Ghostty stays installed.\n'
    return 0
  fi

  printf 'Found extra terminal apps: %s\n' "${installed_packages[*]}"
  printf 'This keeps Ghostty and command-line tools such as btop, fastfetch, and Git.\n'
  if [[ ! -t 0 ]] || ! read -r -p 'Offer these packages to pacman for removal? [y/N] ' answer; then
    printf 'Left the extra terminal apps installed.\n'
    return 0
  fi
  case "$answer" in
    y|Y|yes|YES|Yes)
      command -v sudo >/dev/null 2>&1 || fail 'sudo is required to remove terminal packages'
      start_sudo_keepalive
      sudo pacman -Rns -- "${installed_packages[@]}"
      ;;
    *) printf 'Left the extra terminal apps installed.\n' ;;
  esac
}

cleanup_legacy() {
  assert_target
  require_gnome_session
  run_site_action cleanup-legacy

  local answer
  local -a installed_packages=()
  mapfile -t installed_packages < <(installed_hyprland_packages)
  if ((${#installed_packages[@]} == 0)); then
    printf 'No old Hyprland session packages were found. The retired ChatGPT Chrome shortcut has been checked.\n'
    return 0
  fi

  printf 'Found old Hyprland packages: %s\n' "${installed_packages[*]}"
  if [[ ! -t 0 ]] || ! read -r -p 'Remove these old session packages now? Pacman will show its own confirmation list. [y/N] ' answer; then
    printf 'Left the old Hyprland packages installed. You can run ./setup.sh remove-hyprland later.\n'
    return 0
  fi
  case "$answer" in
    y|Y|yes|YES|Yes) remove_hyprland ;;
    *) printf 'Left the old Hyprland packages installed.\n' ;;
  esac
}

install_gnome_dock_extension() {
  if pacman -Qq gnome-shell-extension-dash-to-dock >/dev/null 2>&1; then
    return 0
  fi
  command -v yay >/dev/null 2>&1 || fail 'yay is required for the Dash to Dock extension; EndeavourOS includes it, plain Arch must install it separately'
  start_sudo_keepalive
  yay -S --needed gnome-shell-extension-dash-to-dock
}

require_gnome_session() {
  local desktop="${XDG_CURRENT_DESKTOP:-} ${XDG_SESSION_DESKTOP:-}"
  [[ "$desktop" == *GNOME* ]] || fail 'log in to the GNOME session, open Terminal, and rerun this action there'
}

remove_hyprland() {
  assert_target
  [[ -t 0 ]] || fail 'run this action in an interactive terminal so you can review and approve pacman’s removal list'
  start_sudo_keepalive

  printf 'This removes the old Hyprland session. Save open work; you will need to reboot when it finishes.\n'
  run_site_action_local display-manager

  local package
  local -a installed_packages=()
  for package in "${HYPRLAND_PACKAGES[@]}"; do
    if pacman -Qq "$package" >/dev/null 2>&1; then
      installed_packages+=("$package")
    fi
  done

  if ((${#installed_packages[@]} == 0)); then
    printf 'No Hyprland session packages are installed. GDM is enabled for GNOME.\n'
    return 0
  fi

  printf 'Pacman will show the exact packages and any now-unused dependencies before asking for confirmation:\n  %s\n' "${installed_packages[*]}"
  start_sudo_keepalive
  sudo pacman -Rns -- "${installed_packages[@]}"
  printf 'Hyprland session packages removed. Reboot to refresh the login screen. Personal config files remain untouched.\n'
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
      printf '  Require an active GNOME session before any changes\n'
      printf '  sudo pacman -Syu --needed ansible-core\n'
      printf '  Authenticate with sudo once; reuse and refresh its temporary ticket while setup runs\n'
      printf '  Ensure the pinned community.general.pacman collection is installed\n'
      printf '  Group Ansible actions: base + apps → tools + desktop → GNOME dock + branding\n'
      printf '  After apps installs kernel headers, interactive yay packages: %s\n' "${AUR_PACKAGES[*]}"
      printf '  Verify the official 1Password signing key before importing it for yay\n'
      printf '  If missing, install ChatGPT from OpenAI’s signed Arch repository; pacman asks before its full system upgrade\n'
      printf '  Install the CaskaydiaCove Nerd Font from the official Arch repositories as part of the apps step\n'
      printf '  Configure AppIndicator and Dash to Dock to load at the next GNOME login\n'
      printf '  Dotfiles: clean expected checkout → linux-desktop.sh → user zsh shell\n'
      printf '  Offer to remove detected legacy Hyprland packages; pacman shows the exact removal list\n'
      printf '  Offer to remove detected extra terminal apps; keep Ghostty and command-line tools\n'
      printf '  Final: strict status verification, then ask whether to uninstall Firefox and erase its data\n'
      ;;
    base|apps|tools)
      printf '  sudo pacman -Syu --needed ansible-core\n'
      printf '  Authenticate with sudo once; reuse its temporary ticket for Ansible and package installs\n'
      printf '  Ensure the pinned community.general.pacman collection is installed\n'
      printf '  Local Ansible action: %s\n' "$ACTION"
      if [[ "$ACTION" == apps ]]; then
        printf '  Then install reviewed AUR packages: %s\n' "${AUR_PACKAGES[*]}"
        printf '  Verify the official 1Password signing key before importing it for yay\n'
        printf '  If missing, install ChatGPT from OpenAI’s signed Arch repository; pacman asks before its full system upgrade\n'
      fi
      ;;
    chatgpt-app)
      printf '  Download OpenAI’s official Arch installer over HTTPS and check its shell syntax\n'
      printf '  The installer verifies OpenAI’s signed repository and package, then asks pacman to confirm a full system upgrade\n'
      ;;
    desktop)
      printf '  Local Ansible action: desktop\n'
      printf '  Copy the logo and wallpaper, set the account photo, and create reviewed Google Workspace, Notion, and Quo Chrome shortcuts\n'
      ;;
    gnome-dock)
      printf '  Require an active GNOME session\n'
      printf '  Authenticate with sudo once; reuse its temporary ticket for yay and Ansible\n'
      printf '  Install Dash to Dock from the AUR after reviewing yay’s prompt\n'
      printf '  Configure AppIndicator and Dash to Dock for the next GNOME login\n'
      printf '  Set a warm translucent dock, pin installed apps, restore dynamic workspaces and GNOME default number shortcuts, and apply dark style\n'
      ;;
    cleanup-legacy)
      printf '  Require an active GNOME session before changing its dock favorites\n'
      printf '  Remove the old ChatGPT Chrome shortcut only if its content matches the version this repo created\n'
      printf '  Detect the explicit old Hyprland package list; if found, ask before offering Pacman’s removal prompt\n'
      printf '  Leave personal Hyprland configuration files untouched\n'
      ;;
    cleanup-terminals)
      printf '  Check only the reviewed list of extra terminal app packages\n'
      printf '  Ask before offering found packages to pacman; Ghostty and command-line tools stay\n'
      printf '  Pacman will show the full package and dependency removal list for approval\n'
      ;;
    remove-hyprland)
      printf '  Enable GDM for GNOME, then offer to remove these installed packages: %s\n' "${HYPRLAND_PACKAGES[*]}"
      printf '  Pacman will include any now-unused dependencies in its review list\n'
      printf '  Pacman will show its removal list and ask before changing packages; personal config files are left untouched\n'
      printf '  Reboot after removal to refresh the login screen\n'
      ;;
    branding)
      printf '  Local Ansible action: branding\n'
      printf '  Set the custom Plymouth theme and quiet splash, then rebuild systemd-boot entries and initrds\n'
      ;;
    display-manager)
      printf '  Local Ansible action: display-manager\n'
      printf '  Disable SDDM at startup and enable GNOME GDM; reboot to use the GNOME login flow\n'
      ;;
    profile-picture)
      printf '  Local Ansible action: profile-picture\n'
      printf '  Set the bundled PNG as the current account photo through AccountsService\n'
      printf '  Requires ./setup.sh apps to have been run once\n'
      ;;
    purge-firefox)
      printf '  Ensure the pinned community.general.pacman collection is installed\n'
      printf '  Remove the Firefox package\n'
      printf '  Delete Firefox user data under ~/.mozilla, ~/.cache/mozilla, ~/.config/mozilla, ~/.local/share/mozilla, and ~/.var/app/org.mozilla.firefox\n'
      printf '  Leave Google Chrome and its profile data untouched\n'
      ;;
    dotfiles)
      printf '  sudo pacman -Syu --needed ttf-cascadia-code-nerd\n'
      printf '  Install the CaskaydiaCove Nerd Font from the official Arch repository\n'
      printf '  Install the reviewed Oh My Posh AUR package so the configured Zsh theme can load\n'
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
    drive|terminal)
      printf '  No changes; show manual setup steps\n'
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
  Open GNOME's app grid and choose Ghostty.
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
      require_gnome_session
      sync_system
      run_site_actions base apps
      install_aur_apps
      install_chatgpt_app
      run_site_actions tools desktop
      cleanup_legacy
      cleanup_terminals
      run_site_actions gnome-dock branding
      printf 'GNOME tray and dock extensions are configured; the planned reboot loads them.\n'
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
      install_chatgpt_app
      ;;
    chatgpt-app)
      assert_target
      start_sudo_keepalive
      install_chatgpt_app --update
      ;;
    tools)
      sync_system
      run_site_action tools
      ;;
    desktop)
      assert_target
      start_sudo_keepalive
      run_site_action desktop
      ;;
    gnome-dock)
      assert_target
      require_gnome_session
      install_gnome_dock_extension
      run_site_action_local gnome-dock
      printf 'GNOME tray and dock extensions are configured. Log out and back in, or reboot, to load them.\n'
      ;;
    cleanup-legacy)
      cleanup_legacy
      ;;
    cleanup-terminals)
      cleanup_terminals
      ;;
    remove-hyprland)
      remove_hyprland
      ;;
    branding)
      assert_target
      start_sudo_keepalive
      run_site_action branding
      ;;
    display-manager)
      assert_target
      start_sudo_keepalive
      run_site_action_local display-manager
      ;;
    profile-picture)
      assert_target
      start_sudo_keepalive
      run_site_action_local profile-picture
      ;;
    purge-firefox)
      assert_target
      if confirm_firefox_purge; then
        start_sudo_keepalive
        run_site_action purge-firefox
      fi
      ;;
    dotfiles)
      assert_target
      start_sudo_keepalive
      install_zsh_theme_dependencies
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
    drive|terminal)
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
