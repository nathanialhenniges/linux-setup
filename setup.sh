#!/usr/bin/env bash
set -Eeuo pipefail

DRY_RUN=false
ACTION="help"
TEMP_DIR=""
SUDO_READY=false

readonly DOTFILES_REPO="https://github.com/nathanialhenniges/dotfiles.git"
readonly DOTFILES_DIR="${HOME:-}/.local/share/dotfiles"
readonly OH_MY_POSH_VERSION="30.5.0"
readonly OH_MY_POSH_SHA256="03bc5c288b6f2fc4ad9db4e11f191e970b31e93d3aa2e55ecc09bd7096226484"
readonly OH_MY_POSH_URL="https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v${OH_MY_POSH_VERSION}/posh-linux-amd64"
readonly NERD_FONT_VERSION="3.5.0"
readonly NERD_FONT_SHA256="f30f67f203f9da78df857ebe558321bdfd8fc313662c72fd9e9fef9d4f4c96e7"
readonly NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONT_VERSION}/CascadiaCode.tar.xz"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

usage() {
  cat <<'EOF'
Ubuntu Desktop 26.04 workstation setup

Usage:
  ./setup.sh [--dry-run] status
  ./setup.sh [--dry-run] base
  ./setup.sh [--dry-run] apps
  ./setup.sh [--dry-run] terminal
  ./setup.sh [--dry-run] codex
  ./setup.sh [--dry-run] dotfiles
  ./setup.sh [--dry-run] gnome
  ./setup.sh [--dry-run] optional

Commands:
  status    Read-only package and setup report
  base      Core command-line and shell packages
  apps      GitHub CLI, VS Code, and Ghostty
  terminal  Make launch-tested Ghostty the Ubuntu default
  codex     Official user-local Codex CLI installer
  dotfiles  Pull and run only dotfiles/linux-desktop.sh
  gnome     Small, reversible macOS-friendly GNOME preferences
  optional  Claude Desktop beta and Cloudflare WARP (install only)

This script never configures a server/devbox, sshd, Docker, credentials,
Git identity, SSH keys, Cloudflare enrollment, or a tunnel.
EOF
}

cleanup() {
  [[ -z "$TEMP_DIR" || ! -d "$TEMP_DIR" ]] || rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

parse_args() {
  local selected=""

  while (($#)); do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      -h | --help)
        [[ -z "$selected" ]] || die "help cannot be combined with a command"
        selected="help"
        ;;
      status | base | apps | terminal | codex | dotfiles | gnome | optional)
        [[ -z "$selected" ]] || die "choose one command; help cannot be combined"
        selected="$1"
        ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done

  ACTION="${selected:-help}"
}

require_target() {
  [[ ${EUID:-$(id -u)} -ne 0 ]] || die "run as your desktop user, not root"
  [[ -n "${HOME:-}" && "$HOME" == /* && "$HOME" != "/" && -d "$HOME" && ! -L "$HOME" ]] ||
    die "HOME must be a real, safe absolute directory"
  [[ -r /etc/os-release ]] || die "cannot read /etc/os-release"
  command -v dpkg >/dev/null 2>&1 || die "dpkg is required"

  local os_id os_version architecture memory_mb
  # This root-owned file is the OS identity source.
  # shellcheck disable=SC1091
  os_id="$(. /etc/os-release; printf '%s' "${ID:-}")"
  # shellcheck disable=SC1091
  os_version="$(. /etc/os-release; printf '%s' "${VERSION_ID:-}")"
  architecture="$(dpkg --print-architecture)"

  [[ "$os_id" == "ubuntu" && "$os_version" == "26.04" ]] ||
    die "supported target is Ubuntu 26.04 only (found ${os_id:-unknown} ${os_version:-unknown})"
  [[ "$architecture" == "amd64" ]] || die "supported architecture is amd64 (found $architecture)"

  if [[ -z "${XDG_CURRENT_DESKTOP:-}" &&
        ! -e /usr/share/wayland-sessions/ubuntu.desktop &&
        ! -e /usr/share/xsessions/ubuntu.desktop ]]; then
    die "Ubuntu Desktop was not detected; this is not a server bootstrap"
  fi

  memory_mb="$(awk '/^MemTotal:/ { print int($2 / 1024); exit }' /proc/meminfo 2>/dev/null || true)"
  if [[ -n "$memory_mb" && "$memory_mb" -lt 6144 ]]; then
    printf 'warning: %s MB RAM is below Ubuntu Desktop\047s comfortable 6 GB target\n' "$memory_mb" >&2
  fi
}

ensure_sudo() {
  [[ "$SUDO_READY" == true ]] && return
  if [[ "$DRY_RUN" == true ]]; then
    note '[dry-run] sudo credentials would be requested once'
  else
    sudo -v
  fi
  SUDO_READY=true
}

run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

make_temp_dir() {
  [[ -n "$TEMP_DIR" ]] || TEMP_DIR="$(mktemp -d)"
}

install_oh_my_posh() {
  local install_dir="$HOME/.local/bin"
  local target="$install_dir/oh-my-posh"
  local downloaded actual_version

  [[ ! -L "$HOME/.local" && ! -L "$install_dir" && ! -L "$target" ]] ||
    die "refusing symbolic link in the Oh My Posh install path"
  [[ ! -e "$target" || -f "$target" ]] || die "Oh My Posh target is not a regular file: $target"

  if [[ -x "$target" ]] && actual_version="$("$target" version 2>/dev/null)" &&
     [[ "$actual_version" == "$OH_MY_POSH_VERSION" ]]; then
    note "Oh My Posh $OH_MY_POSH_VERSION is already installed."
    return
  fi

  if [[ "$DRY_RUN" == true ]]; then
    note "[dry-run] download and SHA-256 verify Oh My Posh $OH_MY_POSH_VERSION"
    note "[dry-run] install $target"
    return
  fi

  command -v curl >/dev/null 2>&1 || die "curl is required to install Oh My Posh"
  command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required to verify Oh My Posh"
  make_temp_dir
  downloaded="$TEMP_DIR/oh-my-posh"
  curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' \
    --output "$downloaded" "$OH_MY_POSH_URL"
  printf '%s  %s\n' "$OH_MY_POSH_SHA256" "$downloaded" | sha256sum --check --status ||
    die "Oh My Posh checksum verification failed"
  install -d -m 0755 "$install_dir"
  install -m 0755 "$downloaded" "$target"
  [[ "$("$target" version)" == "$OH_MY_POSH_VERSION" ]] ||
    die "installed Oh My Posh version did not match $OH_MY_POSH_VERSION"
  note "Installed Oh My Posh $OH_MY_POSH_VERSION."
}

install_nerd_font() {
  local font_dir="$HOME/.local/share/fonts/CaskaydiaCove"
  local marker="$font_dir/.nerd-font-version"
  local archive extract_dir font
  local -a fonts=(
    CaskaydiaCoveNerdFontMono-Regular.ttf
    CaskaydiaCoveNerdFontMono-Bold.ttf
    CaskaydiaCoveNerdFontMono-Italic.ttf
    CaskaydiaCoveNerdFontMono-BoldItalic.ttf
  )

  [[ ! -L "$HOME/.local" && ! -L "$HOME/.local/share" &&
     ! -L "$HOME/.local/share/fonts" && ! -L "$font_dir" && ! -L "$marker" ]] ||
    die "refusing symbolic link in the Nerd Font install path"
  for font in "${fonts[@]}"; do
    [[ ! -L "$font_dir/$font" ]] || die "refusing symbolic-link font target: $font_dir/$font"
  done

  if [[ -f "$marker" && "$(<"$marker")" == "$NERD_FONT_VERSION" ]]; then
    for font in "${fonts[@]}"; do
      [[ -f "$font_dir/$font" ]] || break
    done
    if [[ -n "$font" && -f "$font_dir/$font" ]]; then
      note "CaskaydiaCove Nerd Font $NERD_FONT_VERSION is already installed."
      return
    fi
  fi

  if [[ "$DRY_RUN" == true ]]; then
    note "[dry-run] download and SHA-256 verify CaskaydiaCove Nerd Font $NERD_FONT_VERSION"
    note "[dry-run] install four font styles in $font_dir"
    return
  fi

  command -v curl >/dev/null 2>&1 || die "curl is required to install the Nerd Font"
  command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required to verify the Nerd Font"
  command -v tar >/dev/null 2>&1 || die "tar is required to install the Nerd Font"
  command -v fc-cache >/dev/null 2>&1 || die "fontconfig is required to activate the Nerd Font"
  make_temp_dir
  archive="$TEMP_DIR/CascadiaCode.tar.xz"
  extract_dir="$TEMP_DIR/CaskaydiaCove"
  mkdir -p "$extract_dir"
  curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' \
    --output "$archive" "$NERD_FONT_URL"
  printf '%s  %s\n' "$NERD_FONT_SHA256" "$archive" | sha256sum --check --status ||
    die "Nerd Font checksum verification failed"
  tar --extract --xz --file "$archive" --directory "$extract_dir" -- "${fonts[@]}"
  install -d -m 0755 "$font_dir"
  for font in "${fonts[@]}"; do
    [[ -f "$extract_dir/$font" && ! -L "$extract_dir/$font" ]] ||
      die "Nerd Font archive is missing a regular file: $font"
    install -m 0644 "$extract_dir/$font" "$font_dir/$font"
  done
  printf '%s\n' "$NERD_FONT_VERSION" > "$extract_dir/version"
  install -m 0644 "$extract_dir/version" "$marker"
  fc-cache -f "$font_dir"
  note "Installed CaskaydiaCove Nerd Font $NERD_FONT_VERSION."
}

require_base_tools() {
  command -v curl >/dev/null 2>&1 || die "curl is missing; run ./setup.sh base first"
  command -v gpg >/dev/null 2>&1 || die "gpg is missing; run ./setup.sh base first"
}

verify_key() {
  local key_file="$1" accepted_csv="$2" actual allowed fingerprint
  actual="$(gpg --batch --quiet --show-keys --with-colons "$key_file" |
    awk -F: '$1 == "pub" { primary = 1; next }
             primary && $1 == "fpr" { print toupper($10); primary = 0 }')"
  [[ -n "$actual" ]] || die "downloaded signing key had no primary-key fingerprint"

  allowed=",${accepted_csv^^},"
  while IFS= read -r fingerprint; do
    [[ "$allowed" == *",$fingerprint,"* ]] ||
      die "download contained an undocumented primary signing key"
  done <<< "$actual"
}

install_source() {
  local name="$1" key_url="$2" fingerprints="$3" key_path="$4"
  local source_path="$5" uri="$6" suite="$7" components="$8"

  if [[ "$DRY_RUN" == true ]]; then
    note "[dry-run] verify $name signing key: $key_url"
    note "[dry-run] install $source_path with Signed-By=$key_path"
    return
  fi

  make_temp_dir
  local downloaded_key="$TEMP_DIR/${name}.key" source_file="$TEMP_DIR/${name}.sources"
  curl -fsSL "$key_url" -o "$downloaded_key"
  verify_key "$downloaded_key" "$fingerprints"

  printf 'Types: deb\nURIs: %s\nSuites: %s\nComponents: %s\nArchitectures: amd64\nSigned-By: %s\n' \
    "$uri" "$suite" "$components" "$key_path" > "$source_file"

  ensure_sudo
  sudo install -d -m 0755 /etc/apt/keyrings
  sudo install -m 0644 "$downloaded_key" "$key_path"
  sudo install -m 0644 "$source_file" "$source_path"
}

install_github_source() {
  install_source \
    github-cli \
    https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    2C6106201985B60E6C7AC87323F3D4EA75716059,7F38BBB59D064DBCB3D84D725612B36462313325 \
    /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    /etc/apt/sources.list.d/github-cli.sources \
    https://cli.github.com/packages stable main
}

install_code_source() {
  install_source \
    microsoft-code \
    https://packages.microsoft.com/keys/microsoft.asc \
    BC528686B50D79E339D3721CEB3E94ADBE1229CF \
    /etc/apt/keyrings/microsoft.asc \
    /etc/apt/sources.list.d/vscode.sources \
    https://packages.microsoft.com/repos/code stable main
}

install_claude_source() {
  install_source \
    claude-desktop \
    https://downloads.claude.ai/claude-desktop/key.asc \
    31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE \
    /etc/apt/keyrings/claude-desktop.asc \
    /etc/apt/sources.list.d/claude-desktop.sources \
    https://downloads.claude.ai/claude-desktop/apt/stable stable main
}

install_warp_source() {
  install_source \
    cloudflare-warp \
    https://pkg.cloudflareclient.com/pubkey.gpg \
    C068A2B5771775193CBE1F2F6E2DD2174FA1C3BA \
    /etc/apt/keyrings/cloudflare-warp.asc \
    /etc/apt/sources.list.d/cloudflare-client.sources \
    https://pkg.cloudflareclient.com/ resolute main
}

install_base() {
  require_target
  ensure_sudo
  run sudo apt-get update
  run sudo apt-get install --yes \
    ca-certificates curl direnv eza fontconfig fonts-cascadia-code fzf git gnupg jq openssh-client rsync \
    unzip xz-utils zip zsh zsh-autosuggestions zsh-syntax-highlighting
  install_oh_my_posh
  install_nerd_font
}

install_apps() {
  require_target
  require_base_tools
  install_github_source
  install_code_source
  ensure_sudo
  run sudo apt-get update
  run sudo apt-get install --yes gh code ghostty
  note 'Ghostty needs OpenGL 4.3; launch-test it before making it the default terminal.'
}

terminal_list_content() {
  local desktop_id="$1" list_file="$2"
  printf '%s\n' "$desktop_id"
  if [[ -f "$list_file" ]]; then
    awk -v id="$desktop_id" '$0 != id { print }' "$list_file"
  fi
}

set_default_terminal() {
  require_target

  local desktop_id="com.mitchellh.ghostty.desktop"
  local desktop_file="/usr/share/applications/$desktop_id"
  local config_dir="$HOME/.config"
  local list_file="$config_dir/ubuntu-xdg-terminals.list"

  [[ -f "$desktop_file" ]] || die "Ghostty desktop entry is missing: $desktop_file"
  [[ ! -L "$config_dir" && ! -L "$list_file" ]] ||
    die "refusing symlink in the default-terminal path"
  [[ ! -e "$list_file" || -f "$list_file" ]] ||
    die "default-terminal path is not a regular file: $list_file"

  if [[ -f "$list_file" && "$(head -n 1 "$list_file")" == "$desktop_id" ]]; then
    note 'Ghostty is already the default terminal.'
    return
  fi

  if [[ "$DRY_RUN" == true ]]; then
    note "[dry-run] place $desktop_id first in $list_file"
    note '[dry-run] preserve the current list in a timestamped backup'
    return
  fi

  mkdir -p "$config_dir"
  local temporary_file backup_file=""
  temporary_file="$(mktemp "$config_dir/.ubuntu-xdg-terminals.list.XXXXXX")"
  terminal_list_content "$desktop_id" "$list_file" > "$temporary_file"
  chmod 0644 "$temporary_file"

  if [[ -f "$list_file" ]]; then
    backup_file="$list_file.backup-$(date -u +%Y%m%dT%H%M%SZ)-$$"
    cp -p "$list_file" "$backup_file"
  fi
  mv "$temporary_file" "$list_file"

  note 'Ghostty is now first in Ubuntu\047s default-terminal list.'
  [[ -z "$backup_file" ]] || note "Previous list backup: $backup_file"
  note 'Press Ctrl+Alt+T to verify it opens Ghostty.'
}

install_optional() {
  require_target
  require_base_tools
  install_claude_source
  install_warp_source
  ensure_sudo
  run sudo apt-get update
  run sudo apt-get install --yes claude-desktop cloudflare-warp
  note 'WARP was installed only. Enrollment and connection remain manual.'
  note 'Claude Cowork was not enabled; it is too heavy for this 8 GB laptop.'
}

install_codex() {
  require_target
  note 'No change made: this repo does not execute an unpinned remote installer.'
  note 'Use OpenAI\047s official Linux instructions: https://github.com/openai/codex#quickstart'
  note 'After installation, run codex and choose Sign in with ChatGPT.'
}

apply_dotfiles() {
  require_target
  command -v git >/dev/null 2>&1 || die "git is missing; run ./setup.sh base first"

  local path_component
  for path_component in "$HOME/.local" "$HOME/.local/share" "$DOTFILES_DIR"; do
    [[ ! -L "$path_component" ]] || die "refusing symlink in managed dotfiles path: $path_component"
  done

  if [[ ! -e "$DOTFILES_DIR" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      run git clone --branch main --single-branch "$DOTFILES_REPO" "$DOTFILES_DIR"
      note "[dry-run] verify and run $DOTFILES_DIR/linux-desktop.sh --dry-run"
      return
    fi
    mkdir -p "$(dirname "$DOTFILES_DIR")"
    git clone --branch main --single-branch "$DOTFILES_REPO" "$DOTFILES_DIR"
  else
    [[ -d "$DOTFILES_DIR/.git" ]] || die "dotfiles path exists but is not a Git repository: $DOTFILES_DIR"
    local origin branch
    origin="$(git -C "$DOTFILES_DIR" remote get-url origin)"
    case "$origin" in
      https://github.com/nathanialhenniges/dotfiles | "$DOTFILES_REPO" | git@github.com:nathanialhenniges/dotfiles | git@github.com:nathanialhenniges/dotfiles.git) ;;
      *) die "refusing unexpected dotfiles origin: $origin" ;;
    esac
    branch="$(git -C "$DOTFILES_DIR" symbolic-ref --quiet --short HEAD || true)"
    [[ "$branch" == "main" ]] || die "dotfiles checkout must be on main (found ${branch:-detached})"
    [[ -z "$(git -C "$DOTFILES_DIR" status --porcelain)" ]] ||
      die "dotfiles checkout has local changes; review them before updating"
    run git -C "$DOTFILES_DIR" fetch origin main
    run git -C "$DOTFILES_DIR" merge --ff-only origin/main
  fi

  if [[ "$(git -C "$DOTFILES_DIR" rev-parse HEAD)" != "$(git -C "$DOTFILES_DIR" rev-parse origin/main)" ]]; then
    die "dotfiles HEAD does not exactly match origin/main"
  fi

  local desktop_entry="$DOTFILES_DIR/linux-desktop.sh"
  [[ -f "$desktop_entry" && ! -L "$desktop_entry" ]] ||
    die "dedicated linux-desktop.sh is missing; generic/server installers are forbidden"

  if [[ "$DRY_RUN" == true ]]; then
    bash "$desktop_entry" --dry-run
  else
    bash "$desktop_entry"
  fi
}

configured_login_shell() {
  local account entry
  account="$(id -un)"
  entry="$(getent passwd "$account")" || return 1
  [[ "$entry" == *:* ]] || return 1
  printf '%s\n' "${entry##*:}"
}

set_default_login_shell() {
  local current_shell
  local -r zsh_path='/usr/bin/zsh'

  command -v getent >/dev/null 2>&1 || die "getent is required to verify the login shell"
  [[ -x "$zsh_path" ]] || die "Zsh is missing at $zsh_path; run ./setup.sh base first"
  [[ -r /etc/shells ]] || die "cannot read /etc/shells"
  grep -Fxq "$zsh_path" /etc/shells || die "$zsh_path is not an approved login shell in /etc/shells"
  current_shell="$(configured_login_shell || true)"
  [[ -n "$current_shell" ]] || die "could not resolve the current user's login shell"

  case "$current_shell" in
    /bin/zsh | /usr/bin/zsh)
      note 'Zsh is already the default login shell.'
      return 0
      ;;
  esac

  command -v chsh >/dev/null 2>&1 || die "chsh is required to change the login shell"
  if [[ "$DRY_RUN" == true ]]; then
    run chsh -s "$zsh_path"
    note 'After the real change, sign out and back in once.'
    return 0
  fi

  note 'Ubuntu may ask for your account password to make Zsh the default shell.'
  chsh -s "$zsh_path" || die "chsh could not set Zsh as the login shell"
  current_shell="$(configured_login_shell || true)"
  [[ "$current_shell" == "$zsh_path" ]] || die "the login shell did not change to $zsh_path"
  note 'Zsh is now the default login shell. Sign out and back in once.'
}

gsettings_has_key() {
  local schema="$1" key="$2"
  gsettings list-keys "$schema" 2>/dev/null | grep -Fxq "$key"
}

set_gsetting() {
  local schema="$1" key="$2" value="$3"
  if ! gsettings_has_key "$schema" "$key"; then
    printf 'warning: skipped unavailable GNOME key %s %s\n' "$schema" "$key" >&2
    return
  fi
  run gsettings set "$schema" "$key" "$value"
}

apply_gnome() {
  require_target
  command -v gsettings >/dev/null 2>&1 || die "gsettings is unavailable"
  [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" && -n "${XDG_RUNTIME_DIR:-}" &&
     -n "${WAYLAND_DISPLAY:-${DISPLAY:-}}" ]] ||
    die "run gnome from a terminal inside the logged-in Ubuntu desktop session"

  set_gsetting org.gnome.desktop.interface color-scheme "'prefer-dark'"
  set_gsetting org.gnome.desktop.interface show-battery-percentage true
  set_gsetting org.gnome.desktop.interface enable-hot-corners false
  set_gsetting org.gnome.shell.extensions.dash-to-dock dock-position "'BOTTOM'"
  set_gsetting org.gnome.shell.extensions.dash-to-dock extend-height false
  set_gsetting org.gnome.shell.extensions.dash-to-dock dock-fixed false

  note 'Super opens GNOME Overview search—the built-in Spotlight-style launcher.'
  note 'Toshy key remapping remains a separate, manual step with its own rollback.'
}

package_state() {
  if dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^ii '; then
    printf 'installed'
  else
    printf 'not installed'
  fi
}

show_status() {
  require_target
  printf '%-18s %s\n' 'ITEM' 'STATUS'
  printf '%-18s %s\n' '1Password' "$(package_state 1password)"
  printf '%-18s %s\n' 'Chrome' "$(package_state google-chrome-stable)"
  printf '%-18s %s\n' 'GitHub CLI' "$(package_state gh)"
  printf '%-18s %s\n' 'VS Code' "$(package_state code)"
  printf '%-18s %s\n' 'Ghostty' "$(package_state ghostty)"
  printf '%-18s %s\n' 'Claude Desktop' "$(package_state claude-desktop)"
  printf '%-18s %s\n' 'Cloudflare WARP' "$(package_state cloudflare-warp)"
  if command -v codex >/dev/null 2>&1; then
    printf '%-18s %s\n' 'Codex CLI' 'installed'
  else
    printf '%-18s %s\n' 'Codex CLI' 'not installed'
  fi
  if [[ -x "$HOME/.local/bin/oh-my-posh" ]]; then
    printf '%-18s %s\n' 'Zsh prompt' 'Oh My Posh'
  else
    printf '%-18s %s\n' 'Zsh prompt' 'plain fallback'
  fi
  if [[ -f "$HOME/.local/share/fonts/CaskaydiaCove/.nerd-font-version" &&
        "$(<"$HOME/.local/share/fonts/CaskaydiaCove/.nerd-font-version")" == "$NERD_FONT_VERSION" ]]; then
    printf '%-18s %s\n' 'Zsh font' 'CaskaydiaCove Nerd Font'
  else
    printf '%-18s %s\n' 'Zsh font' 'not installed'
  fi
  if [[ -f "$HOME/.config/ubuntu-xdg-terminals.list" &&
        "$(head -n 1 "$HOME/.config/ubuntu-xdg-terminals.list")" == "com.mitchellh.ghostty.desktop" ]]; then
    printf '%-18s %s\n' 'Default terminal' 'Ghostty'
  else
    printf '%-18s %s\n' 'Default terminal' 'Ubuntu default'
  fi
  local login_shell
  login_shell="$(configured_login_shell 2>/dev/null || true)"
  case "$login_shell" in
    /bin/zsh | /usr/bin/zsh) printf '%-18s %s\n' 'Login shell' 'Zsh' ;;
    '') printf '%-18s %s\n' 'Login shell' 'unknown' ;;
    *) printf '%-18s %s\n' 'Login shell' "$login_shell" ;;
  esac
  if [[ -f "$DOTFILES_DIR/linux-desktop.sh" ]]; then
    printf '%-18s %s\n' 'Desktop dotfiles' 'available'
  else
    printf '%-18s %s\n' 'Desktop dotfiles' 'not applied'
  fi
}

main() {
  parse_args "$@"
  case "$ACTION" in
    help) usage ;;
    status) show_status ;;
    base) install_base ;;
    apps) install_apps ;;
    terminal) set_default_terminal ;;
    codex) install_codex ;;
    dotfiles)
      apply_dotfiles || return
      set_default_login_shell
      ;;
    gnome) apply_gnome ;;
    optional) install_optional ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
