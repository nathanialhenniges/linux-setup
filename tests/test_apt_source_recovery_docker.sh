#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
image="linux-setup-apt-e2e:local"

command -v docker >/dev/null 2>&1 || {
  printf '%s\n' 'FAIL: Docker is required' >&2
  exit 1
}

docker build --quiet --platform linux/amd64 --tag "$image" --file - "$repo_dir" <<'DOCKERFILE'
FROM ubuntu:26.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
      ansible-core ca-certificates gnupg python3-apt python3-debian sudo \
 && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home --shell /bin/bash tester \
 && printf 'tester ALL=(ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/linux-setup-e2e \
 && chmod 0440 /etc/sudoers.d/linux-setup-e2e \
 && mkdir -p /usr/share/wayland-sessions /etc/apt/keyrings /etc/ansible/facts.d \
 && touch /usr/share/wayland-sessions/ubuntu.desktop \
 && printf '%s\n' '#!/bin/sh' 'touch /tmp/unsafe-local-fact-ran' 'printf "{}\\n"' \
      >/etc/ansible/facts.d/unsafe.fact \
 && chmod 0755 /etc/ansible/facts.d/unsafe.fact \
 && printf '%s\n' \
      'Types: deb' \
      'URIs: https://downloads.claude.ai/claude-desktop/apt/stable' \
      'Suites: stable' \
      'Components: main' \
      'Architectures: amd64' \
      'Signed-By: /etc/apt/keyrings/claude-desktop.asc' \
      >/etc/apt/sources.list.d/claude-desktop.sources \
 && printf '%s\n' \
      'deb [signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main' \
      >/etc/apt/sources.list.d/claude-desktop.list
COPY . /home/tester/linux-setup
RUN chown -R tester:tester /home/tester/linux-setup
WORKDIR /home/tester/linux-setup
DOCKERFILE

docker run --rm --network none --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail

if apt-get update >/tmp/broken-apt.log 2>&1; then
  printf '%s\n' 'FAIL: fixture did not break APT' >&2
  exit 1
fi
grep -Fq 'Conflicting values set for option Signed-By' /tmp/broken-apt.log
grep -Fq '/usr/share/keyrings/claude-desktop-archive-keyring.asc != /etc/apt/keyrings/claude-desktop.asc' /tmp/broken-apt.log

if runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh --dry-run all >/tmp/dry-run.log 2>&1; then
  printf '%s\n' 'FAIL: dry-run all did not stop at the required source repair' >&2
  exit 1
fi
grep -Fq 'dry-run all stopped before APT' /tmp/dry-run.log
test ! -e /tmp/unsafe-local-fact-ran
if grep -Fq 'Conflicting values set for option Signed-By' /tmp/dry-run.log; then
  printf '%s\n' 'FAIL: dry-run all parsed the broken APT sources' >&2
  exit 1
fi
printf '%s\n' 'PASS: dry-run all stops before APT without network or local facts'
CONTAINER

docker run --rm --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail

if apt-get update >/tmp/broken-apt.log 2>&1; then
  printf '%s\n' 'FAIL: fixture did not break APT' >&2
  exit 1
fi
grep -Fq 'Conflicting values set for option Signed-By' /tmp/broken-apt.log

if ! runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh bootstrap >/tmp/bootstrap.log 2>&1; then
  tail -n 30 /tmp/bootstrap.log >&2
  exit 1
fi

test ! -e /etc/apt/sources.list.d/claude-desktop.list
test -f /etc/apt/sources.list.d/claude-desktop.sources
test ! -L /etc/apt/sources.list.d/claude-desktop.sources
test -f /etc/apt/keyrings/claude-desktop.asc
apt-get indextargets >/dev/null
grep -Fq 'Claude source preflight:' /tmp/bootstrap.log
test ! -e /tmp/unsafe-local-fact-ran
printf '%s\n' 'PASS: all bootstrap repairs the exact Claude Signed-By conflict before APT'
CONTAINER

docker run --rm --network none --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail
printf '%s\n' 'deb https://example.invalid/ unexpected main' >/etc/apt/sources.list.d/claude-desktop.list
before="$(sha256sum /etc/apt/sources.list.d/claude-desktop.list | awk '{print $1}')"
if runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh sources >/tmp/refusal.log 2>&1; then
  printf '%s\n' 'FAIL: unexpected Claude source content was accepted' >&2
  exit 1
fi
grep -Fq 'Refusing to replace unexpected content' /tmp/refusal.log
grep -Eq 'Found 1 line\(s\), SHA-256 [0-9a-f]{64}' /tmp/refusal.log
if grep -Fq 'example.invalid' /tmp/refusal.log; then
  printf '%s\n' 'FAIL: refusal leaked untrusted source contents' >&2
  exit 1
fi
test -f /etc/apt/sources.list.d/claude-desktop.list
after="$(sha256sum /etc/apt/sources.list.d/claude-desktop.list | awk '{print $1}')"
test "$before" = "$after"
test ! -e /tmp/unsafe-local-fact-ran
printf '%s\n' 'PASS: unknown Claude source content remains untouched'
CONTAINER
