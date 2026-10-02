#!/usr/bin/env bash
# Sourced by setup.sh. Keep the password in shell memory and send it to Ansible
# over stdin, never through arguments, environment variables, or a disk file.
SETUP_BECOME_PASSWORD=

authenticate_setup_sudo() {
  local attempt
  # shellcheck disable=SC2034
  for attempt in 1 2 3; do
    IFS= read -r -s -p 'Sudo password (used for this setup run): ' SETUP_BECOME_PASSWORD </dev/tty || return 1
    printf '\n' >/dev/tty
    if printf '%s\n' "$SETUP_BECOME_PASSWORD" | sudo -k -S -p '' -v; then
      return 0
    fi
  done
  SETUP_BECOME_PASSWORD=
  return 1
}

run_setup_ansible() {
  if [[ -z "$SETUP_BECOME_PASSWORD" ]]; then
    ansible-playbook "$@"
    return
  fi
  printf '%s' "$SETUP_BECOME_PASSWORD" |
    ansible-playbook "$@" --become-password-file -
}
