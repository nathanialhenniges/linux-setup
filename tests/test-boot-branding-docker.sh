#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
image="linux-setup-boot-branding-e2e:local"

command -v docker >/dev/null 2>&1 || {
  printf '%s\n' 'FAIL: Docker is required' >&2
  exit 1
}

docker build --platform linux/amd64 --tag "$image" --file - "$repo_dir" <<'DOCKERFILE'
FROM ubuntu:26.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
      ansible-core file plymouth plymouth-theme-spinner python3-apt sudo \
 && find /usr/share/plymouth/themes/spinner -maxdepth 1 -type f \
      \( -name 'animation-*.png' -o -name 'throbber-*.png' \) \
      ! -name '*-0001.png' -delete \
 && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home --shell /bin/bash tester \
 && printf 'tester ALL=(ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/linux-setup-boot-e2e \
 && chmod 0440 /etc/sudoers.d/linux-setup-boot-e2e \
 && mkdir -p /usr/share/wayland-sessions \
 && touch /usr/share/wayland-sessions/ubuntu.desktop \
 && printf '%s\n' '#!/bin/sh' 'touch /tmp/update-initramfs-called' \
      'printf "%s\\n" "$*" >>/tmp/update-initramfs-arguments' \
      >/usr/sbin/update-initramfs \
 && chmod 0755 /usr/sbin/update-initramfs
COPY . /home/tester/linux-setup
RUN chown -R tester:tester /home/tester/linux-setup
WORKDIR /home/tester/linux-setup
DOCKERFILE

docker run --rm --env QEMU_CPU=max --network none --platform linux/amd64 \
  --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail

repo=/home/tester/linux-setup
theme=/usr/share/plymouth/themes/mrdemonwolf
state=/var/lib/linux-setup/boot-branding/previous-default.json

query_before="$(update-alternatives --query default.plymouth)"
status_before="$(awk '$1 == "Status:" { print $2 }' <<<"$query_before")"
value_before="$(awk '$1 == "Value:" { print $2 }' <<<"$query_before")"
test "$status_before" = auto -o "$status_before" = manual
test -n "$value_before"

# Password-based disk unlock remains supported; only TPM-backed FDE is skipped.
printf '%s\n' 'cryptroot UUID=fixture none luks,discard' >/etc/crypttab

# Run the privileged file-state matrix as container root. sudo.ws behavior has
# its own E2E suite; avoiding repeated sudo under QEMU keeps this test stable.
env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  ansible-playbook "$repo/tests/boot-branding.yml" \
    --extra-vars requested_boot_branding_mode=apply >/tmp/boot-apply.log 2>&1 || {
      tail -n 80 /tmp/boot-apply.log >&2
      exit 1
    }

test "$(readlink -f /usr/share/plymouth/themes/default.plymouth)" = \
  "$theme/mrdemonwolf.plymouth"
grep -Fxq 'ModuleName=two-step' "$theme/mrdemonwolf.plymouth"
grep -Fxq "ImageDir=$theme" "$theme/mrdemonwolf.plymouth"
grep -Fxq 'WatermarkHorizontalAlignment=.5' "$theme/mrdemonwolf.plymouth"
grep -Fxq 'WatermarkVerticalAlignment=.34' "$theme/mrdemonwolf.plymouth"
file "$theme/watermark.png" | grep -Fq 'PNG image data, 240 x 240'
cmp /usr/share/plymouth/themes/spinner/bullet.png "$theme/bullet.png"
cmp /usr/share/plymouth/themes/spinner/entry.png "$theme/entry.png"
cmp /usr/share/plymouth/themes/spinner/lock.png "$theme/lock.png"
cmp "$repo/assets/boot-branding/mrdemonwolf-logo.png" "$theme/watermark.png"
grep -Fq '"schema": 1' "$state"
grep -Fq "\"status\": \"$status_before\"" "$state"
grep -Fq "\"value\": \"$value_before\"" "$state"
test ! -e /tmp/update-initramfs-called
printf '%s\n' 'PASS: cloned two-step theme preserves disk-unlock assets without an initrd rebuild in Docker'

env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  ansible-playbook "$repo/tests/boot-branding.yml" \
    --extra-vars requested_boot_branding_mode=apply >/tmp/boot-idempotent.log 2>&1 || {
      tail -n 80 /tmp/boot-idempotent.log >&2
      exit 1
    }
grep -Eq 'changed=0[[:space:]]' /tmp/boot-idempotent.log
test ! -e /tmp/update-initramfs-called
printf '%s\n' 'PASS: boot branding is idempotent'

env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  ansible-playbook "$repo/tests/boot-branding.yml" \
    --extra-vars requested_boot_branding_mode=rollback >/tmp/boot-rollback.log 2>&1 || {
      tail -n 80 /tmp/boot-rollback.log >&2
      exit 1
    }

query_after="$(update-alternatives --query default.plymouth)"
test "$(awk '$1 == "Status:" { print $2 }' <<<"$query_after")" = "$status_before"
test "$(awk '$1 == "Value:" { print $2 }' <<<"$query_after")" = "$value_before"
! grep -Fxq "Alternative: $theme/mrdemonwolf.plymouth" <<<"$query_after"
test ! -e "$theme"
test ! -e /var/lib/linux-setup/boot-branding
test ! -e /tmp/update-initramfs-called
printf '%s\n' 'PASS: rollback restores the exact prior Plymouth value and mode'

# An unrelated directory at the managed path must remain byte-for-byte untouched.
mkdir -p "$theme"
printf '%s\n' 'owner-created content' >"$theme/custom.txt"
unsafe_before="$(sha256sum "$theme/custom.txt")"
if env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  ansible-playbook "$repo/tests/boot-branding.yml" \
    --extra-vars requested_boot_branding_mode=apply >/tmp/boot-refusal.log 2>&1; then
  printf '%s\n' 'FAIL: unmanaged theme directory was accepted' >&2
  exit 1
fi
grep -Fq 'Refusing unmanaged Plymouth theme directory' /tmp/boot-refusal.log
test "$(sha256sum "$theme/custom.txt")" = "$unsafe_before"
test "$(readlink -f /usr/share/plymouth/themes/default.plymouth)" = "$value_before"
rm -rf -- "$theme"
printf '%s\n' 'PASS: unknown theme content is refused unchanged'

# Ubuntu TPM-backed FDE and UKI layouts are outside this action's boundary.
mkdir -p /var/lib/snapd/device/fde
env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  ansible-playbook "$repo/tests/boot-branding.yml" \
    --extra-vars requested_boot_branding_mode=apply >/tmp/boot-fde-skip.log 2>&1 || {
      tail -n 80 /tmp/boot-fde-skip.log >&2
      exit 1
    }
grep -Fq 'Skipping boot branding on an unsupported TPM-backed FDE or UKI layout' \
  /tmp/boot-fde-skip.log
test ! -e "$theme"
test "$(readlink -f /usr/share/plymouth/themes/default.plymouth)" = "$value_before"
rmdir /var/lib/snapd/device/fde

mkdir -p /boot/efi/EFI/Linux
env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  ansible-playbook "$repo/tests/boot-branding.yml" \
    --extra-vars requested_boot_branding_mode=apply >/tmp/boot-uki-skip.log 2>&1 || {
      tail -n 80 /tmp/boot-uki-skip.log >&2
      exit 1
    }
grep -Fq 'Skipping boot branding on an unsupported TPM-backed FDE or UKI layout' \
  /tmp/boot-uki-skip.log
test ! -e "$theme"
test "$(readlink -f /usr/share/plymouth/themes/default.plymouth)" = "$value_before"
printf '%s\n' 'PASS: unsupported TPM-backed FDE and UKI layouts are skipped unchanged'
CONTAINER

docker run --rm --env QEMU_CPU=max --network none --platform linux/amd64 \
  --interactive "$image" bash -s <<'CONTAINER'
set -Eeuo pipefail

env HOME=/home/tester XDG_CURRENT_DESKTOP=ubuntu:GNOME \
  ansible-playbook /home/tester/linux-setup/tests/boot-branding.yml --check \
    --extra-vars requested_boot_branding_mode=apply >/tmp/boot-check.log 2>&1 || {
      tail -n 80 /tmp/boot-check.log >&2
      exit 1
    }

test ! -e /usr/share/plymouth/themes/mrdemonwolf
test ! -e /var/lib/linux-setup/boot-branding
test ! -e /tmp/update-initramfs-called
grep -Fq 'Would install the managed MrDemonWolf Plymouth theme' /tmp/boot-check.log
printf '%s\n' 'PASS: boot dry-run writes no managed state'
CONTAINER
