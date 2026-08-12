#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
image="linux-setup-sudo-e2e:local"
password="ubuntu-test-password"

command -v docker >/dev/null 2>&1 || {
  printf '%s\n' 'FAIL: Docker is required' >&2
  exit 1
}

docker build --quiet --platform linux/amd64 --tag "$image" --file - "$repo_dir" <<'DOCKERFILE'
FROM ubuntu:26.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install --yes --no-install-recommends ansible-core sudo \
 && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home --shell /bin/bash tester \
 && printf '%s\n' 'tester:ubuntu-test-password' | chpasswd \
 && printf '%s\n' 'tester ALL=(ALL:ALL) ALL' >/etc/sudoers.d/linux-setup-sudo-e2e \
 && chmod 0440 /etc/sudoers.d/linux-setup-sudo-e2e
DOCKERFILE

docker run --rm --env QEMU_CPU=max --platform linux/amd64 --interactive "$image" \
  bash -s "$password" <<'CONTAINER'
set -Eeuo pipefail
password="$1"
ansible_command=(
  ansible localhost
  --inventory localhost,
  --connection local
  --module-name command
  --args '/usr/bin/id -u'
  --become
  --extra-vars ansible_become_exe=/usr/bin/sudo.ws
)

test -x /usr/bin/sudo.ws
printf '%s\n' "$password" |
  runuser -u tester -- /usr/bin/sudo.ws -S -k -p '' -v

if runuser -u tester -- env HOME=/home/tester "${ansible_command[@]}" \
  >/tmp/without-password.log 2>&1; then
  printf '%s\n' 'FAIL: separate Ansible process unexpectedly reused the sudo timestamp' >&2
  exit 1
fi
grep -Fq 'sudo: a password is required' /tmp/without-password.log
printf '%s\n' 'PASS: separate Ansible process cannot reuse the wrapper sudo timestamp'

printf '%s\n' "$password" |
  runuser -u tester -- env HOME=/home/tester "${ansible_command[@]}" --ask-become-pass \
  >/tmp/with-password.log 2>&1
grep -Fq 'localhost | CHANGED | rc=0' /tmp/with-password.log
grep -Fxq '0' /tmp/with-password.log
printf '%s\n' 'PASS: Ansible ask-become-pass works with Ubuntu 26.04 sudo.ws'
CONTAINER
