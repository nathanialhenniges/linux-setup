#!/usr/bin/env bash
set -euo pipefail

tar -xf /tmp/source.tar -C /workspace
cd /workspace
git init --quiet
git add --all
git -c user.name='Linux setup container test' \
  -c user.email='linux-setup-test@example.invalid' \
  commit --quiet --message='Temporary container source snapshot'

printf '%s\n' '== Static checks and Ansible syntax =='
./tests/test_setup.sh

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

printf '%s\n' '== Confirm setup dry-run does not call privileged or network/package commands =='
stub_dir="$tmp_dir/stubs"
mkdir -p "$stub_dir"
for command_name in sudo pacman ansible-playbook ansible-galaxy curl yay git; do
  cat > "$stub_dir/$command_name" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "unexpected command: ${0##*/}" >> "$BLOCKED_COMMANDS"
exit 97
STUB
  chmod 0755 "$stub_dir/$command_name"
done
export BLOCKED_COMMANDS="$tmp_dir/blocked-commands"
dry_run_output="$(PATH="$stub_dir:$PATH" ./setup.sh --dry-run all)"
grep -Fq 'Dry run: all' <<<"$dry_run_output"
[[ ! -e "$BLOCKED_COMMANDS" ]] || {
  cat "$BLOCKED_COMMANDS" >&2
  printf 'The setup dry-run invoked a command that must not run.\n' >&2
  exit 1
}
printf '%s\n' 'Dry-run stayed local and did not invoke sudo, Ansible, package managers, or download tools.'

printf '%s\n' '== Runtime: resolve and run the installed Arch pacman Ansible module without changing packages =='
pacman_result="$tmp_dir/pacman-module.log"
ANSIBLE_NOCOLOR=1 ansible localhost -i 'localhost,' --connection=local \
  -m community.general.pacman \
  -a 'name=ansible-core state=present' \
  --check >"$pacman_result"
cat "$pacman_result"
grep -Fq '"changed": false' "$pacman_result"

printf '%s\n' '== Runtime: verify Flatpak system remote/list argument parsing through Ansible argv =='
cat > "$tmp_dir/flatpak-smoke.yml" <<'PLAYBOOK'
---
- name: Check Flatpak CLI read-only arguments in Arch
  hosts: workstation
  connection: local
  gather_facts: false
  tasks:
    - name: Read configured system Flatpak remotes
      ansible.builtin.command:
        argv: [flatpak, remotes, --system, "--columns=name,url"]
      changed_when: false
      register: system_flatpak_remotes

    - name: Read installed system Flatpak IDs
      ansible.builtin.command:
        argv: [flatpak, list, --system, "--columns=application"]
      changed_when: false
      register: system_flatpak_ids

    - name: Require both Flatpak read-only queries to succeed
      ansible.builtin.assert:
        that:
          - system_flatpak_remotes.rc == 0
          - system_flatpak_ids.rc == 0
PLAYBOOK
ANSIBLE_CONFIG="$PWD/ansible.cfg" ANSIBLE_NOCOLOR=1 \
  ansible-playbook -i inventory.ini --limit workstation "$tmp_dir/flatpak-smoke.yml"

printf '%s\n' '== Runtime: exercise the actual read-only setup status action in Arch =='
status_output="$(./setup.sh --accept-target-warning status 2>&1)" || {
  printf '%s\n' "$status_output" >&2
  exit 1
}
printf '%s\n' "$status_output"
grep -Fq 'Needs setup' <<<"$status_output"

printf '%s\n' '== Runtime: GNOME dock shortcut preservation and rerun idempotence under D-Bus =='
XDG_CURRENT_DESKTOP=GNOME \
GSETTINGS_SCHEMA_DIR=/opt/linux-setup-test/schemas \
dbus-run-session -- bash tests/container/run-gnome-smoke.sh

python3 tests/container/test-sudo.py

printf '%s\n' 'Arch container checks passed.'
