#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
setup="$repo_dir/setup.sh"
failures=0

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }

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
