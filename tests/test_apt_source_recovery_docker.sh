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

docker run --rm --env QEMU_CPU=max --network none --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
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

docker run --rm --env QEMU_CPU=max --network none --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail
rm /etc/apt/sources.list.d/claude-desktop.sources

if runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh --dry-run all >/tmp/no-managed-source.log 2>&1; then
  printf '%s\n' 'FAIL: dry-run missed the legacy Claude source without a managed source' >&2
  exit 1
fi
grep -Fq 'previewing the required Claude source repair' /tmp/no-managed-source.log
grep -Fq 'dry-run all stopped before APT' /tmp/no-managed-source.log
test ! -e /tmp/unsafe-local-fact-ran
printf '%s\n' 'PASS: legacy Claude source is detected without the managed source'
CONTAINER

docker run --rm --env QEMU_CPU=max --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
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

docker run --rm --env QEMU_CPU=max --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail

runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh sources >/tmp/initial-source-repair.log 2>&1

mkdir -p /tmp/claude-test-package/DEBIAN
printf '%s\n' \
  'Package: claude-desktop' \
  'Version: 0.0.0-e2e' \
  'Architecture: amd64' \
  'Maintainer: linux-setup E2E' \
  'Description: Exercise the documented Claude repository opt-out' \
  >/tmp/claude-test-package/DEBIAN/control
cat >/tmp/claude-test-package/DEBIAN/postinst <<'POSTINST'
#!/bin/sh
set -eu
CLAUDE_DESKTOP_ADD_REPO=true
if [ -r /etc/default/claude-desktop ]; then
  . /etc/default/claude-desktop
fi
if [ "$CLAUDE_DESKTOP_ADD_REPO" = true ]; then
  printf '%s\n' \
    'deb [signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main' \
    >/etc/apt/sources.list.d/claude-desktop.list
fi
POSTINST
chmod 0755 /tmp/claude-test-package/DEBIAN/postinst
dpkg-deb --build /tmp/claude-test-package /tmp/claude-desktop-e2e.deb >/dev/null

rm -f /etc/default/claude-desktop
dpkg -i /tmp/claude-desktop-e2e.deb >/dev/null
if apt-get update >/tmp/post-install-broken.log 2>&1; then
  printf '%s\n' 'FAIL: simulated Claude package did not recreate the conflict' >&2
  exit 1
fi
grep -Fq 'Conflicting values set for option Signed-By' /tmp/post-install-broken.log

runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh sources >/tmp/recurrent-source-repair.log 2>&1
grep -Fxq 'CLAUDE_DESKTOP_ADD_REPO="false"' /etc/default/claude-desktop
dpkg -i /tmp/claude-desktop-e2e.deb >/dev/null
test ! -e /etc/apt/sources.list.d/claude-desktop.list
apt-get indextargets >/dev/null
printf '%s\n' 'PASS: Claude package reinstall cannot recreate the Signed-By conflict'
CONTAINER

docker run --rm --env QEMU_CPU=max --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail

rm /etc/apt/sources.list.d/claude-desktop.list
for line in $(seq 1 40); do
  printf '# preserved source line %s\n' "$line"
done >/etc/apt/sources.list
printf '%s\n' \
  'deb [signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main' \
  >>/etc/apt/sources.list
head -n 40 /etc/apt/sources.list | sha256sum | awk '{print $1}' >/tmp/preserved-source.sha256

if apt-get update >/tmp/line-41-broken.log 2>&1; then
  printf '%s\n' 'FAIL: line-41 fixture did not break APT' >&2
  exit 1
fi
grep -Fq 'Conflicting values set for option Signed-By' /tmp/line-41-broken.log

if ! runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh bootstrap >/tmp/line-41-bootstrap.log 2>&1; then
  tail -n 30 /tmp/line-41-bootstrap.log >&2
  exit 1
fi

grep -Fq '# preserved source line 1' /etc/apt/sources.list
grep -Fq '# preserved source line 40' /etc/apt/sources.list
test "$(wc -l </etc/apt/sources.list)" -eq 40
test "$(sha256sum /etc/apt/sources.list | awk '{print $1}')" = "$(cat /tmp/preserved-source.sha256)"
if grep -Fq 'downloads.claude.ai/claude-desktop/apt/stable' /etc/apt/sources.list; then
  printf '%s\n' 'FAIL: exact Claude line 41 survived repair' >&2
  exit 1
fi
apt-get indextargets >/dev/null
grep -Fq 'Claude source preflight:' /tmp/line-41-bootstrap.log
test ! -e /tmp/unsafe-local-fact-ran
printf '%s\n' 'PASS: bootstrap removes only the verified Claude line 41 and preserves the file'
CONTAINER

docker run --rm --env QEMU_CPU=max --network none --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail
rm /etc/apt/sources.list.d/claude-desktop.list
printf '%s\n' \
  'Types: deb' \
  'uris:' \
  ' https://downloads.claude.ai/claude-desktop/apt/stable' \
  'Suites: stable' \
  'Components: main' \
  'Signed-By: /usr/share/keyrings/claude-desktop-archive-keyring.asc' \
  >/etc/apt/sources.list.d/anthropic.sources
before="$(sha256sum /etc/apt/sources.list.d/anthropic.sources | awk '{print $1}')"

if apt-get indextargets >/tmp/deb822-broken.log 2>&1; then
  printf '%s\n' 'FAIL: folded deb822 fixture did not break APT' >&2
  exit 1
fi
grep -Fq 'Conflicting values set for option Signed-By' /tmp/deb822-broken.log

if runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh bootstrap >/tmp/deb822-refusal.log 2>&1; then
  printf '%s\n' 'FAIL: unmanaged Claude deb822 source was accepted' >&2
  exit 1
fi
grep -Fq 'Refusing unmanaged Claude deb822 source' /tmp/deb822-refusal.log
grep -Eq 'Found 6 line\(s\), SHA-256 [0-9a-f]{64}' /tmp/deb822-refusal.log
if grep -Fq 'downloads.claude.ai' /tmp/deb822-refusal.log; then
  printf '%s\n' 'FAIL: deb822 refusal leaked untrusted source contents' >&2
  exit 1
fi
after="$(sha256sum /etc/apt/sources.list.d/anthropic.sources | awk '{print $1}')"
test "$before" = "$after"
test ! -e /tmp/unsafe-local-fact-ran
printf '%s\n' 'PASS: unmanaged Claude deb822 source is refused unchanged'
CONTAINER

docker run --rm --env QEMU_CPU=max --network none --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail
rm /etc/apt/sources.list.d/claude-desktop.list
printf '%s\n' \
  'deb-src [signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] "https://downloads.claude.ai/claude-desktop/apt/stable/" stable main' \
  >/etc/apt/sources.list.d/claude-source.list
before="$(sha256sum /etc/apt/sources.list.d/claude-source.list | awk '{print $1}')"

if apt-get indextargets >/tmp/deb-src-broken.log 2>&1; then
  printf '%s\n' 'FAIL: deb-src fixture did not break APT' >&2
  exit 1
fi
grep -Fq 'Conflicting values set for option Signed-By' /tmp/deb-src-broken.log

if runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh bootstrap >/tmp/deb-src-refusal.log 2>&1; then
  printf '%s\n' 'FAIL: unreviewed Claude deb-src source was accepted' >&2
  exit 1
fi
grep -Fq 'Refusing unexpected Claude content' /tmp/deb-src-refusal.log
grep -Eq 'Found 1 line\(s\), SHA-256 [0-9a-f]{64}' /tmp/deb-src-refusal.log
if grep -Fq 'downloads.claude.ai' /tmp/deb-src-refusal.log; then
  printf '%s\n' 'FAIL: deb-src refusal leaked untrusted source contents' >&2
  exit 1
fi
after="$(sha256sum /etc/apt/sources.list.d/claude-source.list | awk '{print $1}')"
test "$before" = "$after"
test ! -e /tmp/unsafe-local-fact-ran
printf '%s\n' 'PASS: unreviewed Claude deb-src source is refused unchanged'
CONTAINER

docker run --rm --env QEMU_CPU=max --network none --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail
printf '%s\n' 'touch /tmp/root-code-ran' >/etc/default/claude-desktop
before="$(sha256sum /etc/default/claude-desktop | awk '{print $1}')"

if runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh --dry-run sources >/tmp/opt-out-refusal.log 2>&1; then
  printf '%s\n' 'FAIL: unsafe root-sourced Claude opt-out content was accepted' >&2
  exit 1
fi
grep -Fq 'Refusing unsafe content in /etc/default/claude-desktop' /tmp/opt-out-refusal.log
grep -Eq 'Found 1 line\(s\), SHA-256 [0-9a-f]{64}' /tmp/opt-out-refusal.log
if grep -Fq 'root-code-ran' /tmp/opt-out-refusal.log; then
  printf '%s\n' 'FAIL: opt-out refusal leaked untrusted contents' >&2
  exit 1
fi
after="$(sha256sum /etc/default/claude-desktop | awk '{print $1}')"
test "$before" = "$after"
test ! -e /tmp/root-code-ran
test ! -e /tmp/unsafe-local-fact-ran
printf '%s\n' 'PASS: unsafe Claude opt-out content is refused unchanged'
CONTAINER

docker run --rm --env QEMU_CPU=max --network none --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail
rm /etc/apt/sources.list.d/claude-desktop.list
rm /etc/sudoers.d/linux-setup-e2e
printf '%s' 'CLAUDE_DESKTOP_ADD_REPO="false"' >/etc/default/claude-desktop
chmod 0644 /etc/default/claude-desktop

runuser -u tester -- env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  /home/tester/linux-setup/setup.sh --dry-run sources >/tmp/unprivileged-dry-run.log 2>&1
grep -Fq 'TASK [Preview Claude package repository opt-out]' /tmp/unprivileged-dry-run.log
test ! -e /tmp/unsafe-local-fact-ran
printf '%s\n' 'PASS: sources dry-run previews exact opt-out drift without passwordless sudo'
CONTAINER

docker run --rm --env QEMU_CPU=max --network none --platform linux/amd64 --interactive "$image" bash -s <<'CONTAINER'
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
