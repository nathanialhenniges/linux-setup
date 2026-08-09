#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
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

if [[ -x "$setup" ]]; then
  pass 'setup wrapper is executable'
else
  fail 'setup wrapper mode'
fi

if "$setup" --help | grep -Fq 'Ubuntu Desktop 26.04 local Ansible setup'; then
  pass 'help works without target checks'
else
  fail 'help output'
fi

if "$setup" | grep -Fq './setup.sh bootstrap'; then
  pass 'no command defaults to help'
else
  fail 'default help behavior'
fi

if "$setup" definitely-not-a-command >/dev/null 2>&1; then
  fail 'unknown command must fail'
else
  pass 'unknown command fails closed'
fi

if "$setup" --help base >/dev/null 2>&1; then
  fail 'help mixed with a command must fail'
else
  pass 'multiple commands fail closed'
fi

if "$setup" --dry-run >/dev/null 2>&1; then
  fail 'dry-run without an action must fail'
else
  pass 'dry-run requires one action'
fi

if grep -Fq -- '--no-install-recommends ansible-core python3-apt python3-debian sudo' "$setup"; then
  pass 'bootstrap installs minimal Ansible prerequisites'
else
  fail 'minimal Ansible bootstrap'
fi

if grep -Fq 'ansible_become_exe=/usr/bin/sudo.ws' "$repo_dir/inventory.ini" &&
   grep -Fq '[[ -x /usr/bin/sudo.ws ]]' "$setup" &&
   ! grep -Eq 'update-alternatives|NOPASSWD' "$setup" "$repo_dir/inventory.ini"; then
  pass 'Ansible uses scoped Ubuntu classic sudo'
else
  fail 'Ubuntu 26.04 sudo-rs compatibility boundary'
fi

if grep -Fq -- '--limit localhost' "$setup" &&
   grep -Fq 'localhost ansible_connection=local' "$repo_dir/inventory.ini"; then
  pass 'Ansible is locked to local localhost'
else
  fail 'localhost boundary'
fi

if grep -Fq 'setup_action is defined' "$repo_dir/site.yml" &&
   grep -Fq "setup_action in supported_actions" "$repo_dir/site.yml" &&
   ! grep -Eq '(^|[[:space:]-])all($|[[:space:]])' "$repo_dir/vars.yml"; then
  pass 'one explicit action is required'
else
  fail 'explicit action boundary'
fi

if grep -A1 -F 'key: dock-fixed' "$repo_dir/vars.yml" | grep -Fq 'value: "true"'; then
  pass 'Ubuntu Dock stays visible'
else
  fail 'Ubuntu Dock visibility preference'
fi

scan_files=(
  "$setup"
  "$repo_dir/site.yml"
  "$repo_dir/verify.yml"
  "$repo_dir/vars.yml"
  "$repo_dir/tasks/vendor_repositories.yml"
)

if grep -En 'openssh-server|server-dev\.sh|config/(server|agent)|apt-key|trusted[=:][[:space:]]*(yes|true)|curl[^|]*\|[[:space:]]*(ba)?sh' "${scan_files[@]}"; then
  fail 'forbidden server, devbox, or unsafe repository pattern found'
else
  pass 'server/devbox and unsafe installer patterns are absent'
fi

if grep -Fq 'linux-desktop.sh' "$repo_dir/site.yml" &&
   ! grep -Eq '(^|[/[:space:]])(install|server|server-dev)\.sh' "$repo_dir/site.yml"; then
  pass 'dotfiles entry point is desktop-only'
else
  fail 'dotfiles boundary'
fi

for expected in \
  '6084d5d7bd8e288441e0e94fc6275570895da18e6751f70f057485dc2d1a811b' \
  '2fa9c05d591a1582a9aba276272478c262e95ad00acf60eaee1644d93941e3c6' \
  'bd70a5e4a268002704024ceba7f8446024114e94f3f0bdd11c23a9e592be81c6' \
  '0f37fc298c98e88ee3c0ee68c95b69f1dba9eb477abe3167e13982105911264d' \
  '03bc5c288b6f2fc4ad9db4e11f191e970b31e93d3aa2e55ecc09bd7096226484' \
  'f30f67f203f9da78df857ebe558321bdfd8fc313662c72fd9e9fef9d4f4c96e7'; do
  if ! grep -Fq "$expected" "$repo_dir/vars.yml"; then
    fail "missing reviewed checksum $expected"
  fi
done

if grep -Fq 'checksum: "sha256:{{ item.key_sha256 }}"' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'Read every primary signing-key fingerprint' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'Preview vendor repository drift' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'content: "{{ item.source_content }}"' "$repo_dir/tasks/vendor_repositories.yml"; then
  pass 'vendor keys and sources require integrity checks'
else
  fail 'vendor key verification gates'
fi

if grep -Fq 'not ansible_check_mode' "$repo_dir/site.yml" &&
   grep -Fq 'command+=(--check --diff)' "$setup" &&
   grep -A2 -F 'run_action() {' "$setup" | grep -Fq 'target_preflight'; then
  pass 'dry-run uses check mode and gates mutators'
else
  fail 'Ansible dry-run boundary'
fi

if grep -Fq 'Preview the dedicated desktop dotfiles profile' "$repo_dir/verify.yml" &&
   grep -Fq 'Read dotfiles HEAD and origin main' "$repo_dir/verify.yml" &&
   grep -Fq "'would apply ' not in" "$repo_dir/verify.yml"; then
  pass 'verification proves desktop dotfiles are applied'
else
  fail 'desktop dotfiles verification'
fi

if grep -Fq 'workstation_home == ansible_facts.user_dir' "$repo_dir/site.yml" &&
   grep -Fq 'Require safe prompt path types' "$repo_dir/site.yml" &&
   grep -Fq 'Require an executable packaged Zsh' "$repo_dir/site.yml"; then
  pass 'home, prompt, and login-shell paths fail closed'
else
  fail 'managed path safety gates'
fi

if command -v ansible-playbook >/dev/null 2>&1; then
  if (cd "$repo_dir" && ansible-playbook site.yml --syntax-check >/dev/null); then
    pass 'site playbook syntax'
  else
    fail 'site playbook syntax'
  fi
  if (cd "$repo_dir" && ansible-playbook verify.yml --syntax-check >/dev/null); then
    pass 'verification playbook syntax'
  else
    fail 'verification playbook syntax'
  fi
  if (cd "$repo_dir" && ansible-playbook site.yml --list-tasks --tags dotfiles -e setup_action=dotfiles >/dev/null); then
    pass 'tagged task graph resolves'
  else
    fail 'tagged task graph'
  fi
else
  printf 'SKIP: ansible-playbook is not installed; run ./setup.sh bootstrap on Ubuntu\n'
fi

if [[ "$failures" -ne 0 ]]; then
  printf '%d check(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'All Ansible setup safety checks passed.\n'
