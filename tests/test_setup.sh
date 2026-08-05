#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
setup="$repo_dir/setup.sh"
failures=0

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }
fake_tampered_curl() {
  local output=''
  while (($#)); do
    if [[ "$1" == '--output' ]]; then
      output="$2"
      break
    fi
    shift
  done
  printf 'tampered\n' > "$output"
}

if bash -n "$setup"; then
  pass 'Bash syntax'
else
  fail 'Bash syntax'
fi

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$setup" "$0"; then
    pass 'ShellCheck'
  else
    fail 'ShellCheck'
  fi
else
  printf 'SKIP: ShellCheck is not installed\n'
fi

if "$setup" --help | grep -Fq 'Ubuntu Desktop 26.04 workstation setup'; then
  pass 'help works without target-system checks'
else
  fail 'help output'
fi

if "$setup" --help | grep -Fq 'terminal  Make launch-tested Ghostty'; then
  pass 'default-terminal command is documented'
else
  fail 'default-terminal command help'
fi

test_root="$(mktemp -d)"
printf 'org.gnome.Terminal.desktop\ncom.mitchellh.ghostty.desktop\n' > "$test_root/terminals.list"
# Resolved from this test's repository root.
# shellcheck disable=SC1090,SC1091
source "$setup"
trap 'rm -rf "$test_root"' EXIT
terminal_result="$(terminal_list_content com.mitchellh.ghostty.desktop "$test_root/terminals.list")"
if [[ "$terminal_result" == $'com.mitchellh.ghostty.desktop\norg.gnome.Terminal.desktop' ]]; then
  pass 'Ghostty becomes first without duplicating it'
else
  fail 'default-terminal list ordering'
fi

if (
  HOME="$test_root/dry-run-home"
  mkdir -p "$HOME"
  DRY_RUN=true
  TEMP_DIR=''
  # shellcheck disable=SC2329 # install_oh_my_posh resolves this test double dynamically.
  curl() { return 99; }
  install_oh_my_posh >/dev/null
  [[ ! -e "$HOME/.local/bin/oh-my-posh" ]]
); then
  pass 'Oh My Posh dry-run has no network or writes'
else
  fail 'Oh My Posh dry-run safety'
fi

mkdir -p "$test_root/checksum-home" "$test_root/checksum-temp"
if (
  HOME="$test_root/checksum-home"
  # shellcheck disable=SC2034 # install_oh_my_posh reads the sourced globals dynamically.
  DRY_RUN=false
  # shellcheck disable=SC2034
  TEMP_DIR="$test_root/checksum-temp"
  # shellcheck disable=SC2329 # install_oh_my_posh resolves this test double dynamically.
  curl() { fake_tampered_curl "$@"; }
  install_oh_my_posh >/dev/null 2>&1
); then
  fail 'checksum mismatch must stop Oh My Posh installation'
elif [[ ! -e "$test_root/checksum-home/.local/bin/oh-my-posh" ]]; then
  pass 'checksum mismatch fails before Oh My Posh installation'
else
  fail 'checksum mismatch wrote the Oh My Posh target'
fi

if (
  HOME="$test_root/font-dry-run-home"
  mkdir -p "$HOME"
  DRY_RUN=true
  TEMP_DIR=''
  # shellcheck disable=SC2329 # install_nerd_font resolves this test double dynamically.
  curl() { return 99; }
  install_nerd_font >/dev/null
  [[ ! -e "$HOME/.local/share/fonts/CaskaydiaCove/.nerd-font-version" ]]
); then
  pass 'Nerd Font dry-run has no network or writes'
else
  fail 'Nerd Font dry-run safety'
fi

mkdir -p "$test_root/font-checksum-home" "$test_root/font-checksum-temp"
if (
  HOME="$test_root/font-checksum-home"
  # shellcheck disable=SC2034 # install_nerd_font reads the sourced globals dynamically.
  DRY_RUN=false
  # shellcheck disable=SC2034
  TEMP_DIR="$test_root/font-checksum-temp"
  # shellcheck disable=SC2329 # install_nerd_font resolves these test doubles dynamically.
  curl() { fake_tampered_curl "$@"; }
  # shellcheck disable=SC2329
  tar() { return 99; }
  # shellcheck disable=SC2329
  fc-cache() { return 99; }
  install_nerd_font >/dev/null 2>&1
); then
  fail 'checksum mismatch must stop Nerd Font installation'
elif [[ ! -e "$test_root/font-checksum-home/.local/share/fonts/CaskaydiaCove" ]]; then
  pass 'checksum mismatch fails before Nerd Font installation'
else
  fail 'checksum mismatch wrote the Nerd Font target'
fi

if (
  sequence=''
  # shellcheck disable=SC2329 # main resolves these test doubles dynamically.
  apply_dotfiles() { sequence="${sequence}dotfiles "; }
  # shellcheck disable=SC2329
  set_default_login_shell() { sequence="${sequence}shell"; }
  main dotfiles
  [[ "$sequence" == 'dotfiles shell' ]]
); then
  pass 'dotfiles apply before the login-shell change'
else
  fail 'dotfiles and login-shell ordering'
fi

if (
  shell_change_called=false
  # shellcheck disable=SC2329 # main resolves these test doubles dynamically.
  apply_dotfiles() { return 7; }
  # shellcheck disable=SC2329
  set_default_login_shell() { shell_change_called=true; }
  main dotfiles >/dev/null 2>&1 || true
  [[ "$shell_change_called" == false ]]
); then
  pass 'failed dotfiles cannot change the login shell'
else
  fail 'dotfiles failure boundary'
fi

if (
  # shellcheck disable=SC2329 # configured_login_shell resolves these test doubles dynamically.
  id() { printf 'tester\n'; }
  # shellcheck disable=SC2329
  getent() { printf 'tester:x:1000:1000::/home/tester:/usr/bin/zsh\n'; }
  [[ "$(configured_login_shell)" == '/usr/bin/zsh' ]]
); then
  pass 'configured login shell is read from the account record'
else
  fail 'configured login-shell lookup'
fi

# shellcheck disable=SC2016 # The literal source expression is the assertion target.
if grep -Fq 'chsh -s "$zsh_path"' "$setup" && ! grep -Eq 'sudo[[:space:]]+chsh' "$setup"; then
  pass 'Zsh login-shell change is current-user only'
else
  fail 'Zsh login-shell safety boundary'
fi

if "$setup" definitely-not-a-command >/dev/null 2>&1; then
  fail 'unknown command must fail'
else
  pass 'unknown command fails closed'
fi

if "$setup" --help base >/dev/null 2>&1; then
  fail 'help mixed with a command must fail'
else
  pass 'help cannot trigger an install command'
fi

if grep -En 'openssh-server|server-dev\.sh|config/(server|agent)|apt-key|trusted=yes|curl[^|]*\|[[:space:]]*(ba)?sh' "$setup"; then
  fail 'forbidden server or unsafe repository pattern found'
else
  pass 'server and unsafe APT patterns absent'
fi

if grep -Fq 'linux-desktop.sh' "$setup" && ! grep -Eq 'bash .*install\.sh|/server\.sh' "$setup"; then
  pass 'dotfiles entry point is desktop-only'
else
  fail 'dotfiles boundary'
fi

if [[ "$failures" -ne 0 ]]; then
  printf '%d check(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'All setup safety checks passed.\n'
