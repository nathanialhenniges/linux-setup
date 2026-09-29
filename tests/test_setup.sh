#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"

fail() {
  printf 'test_setup.sh: %s\n' "$1" >&2
  exit 1
}

command -v ansible-playbook >/dev/null 2>&1 || fail 'run ./setup.sh bootstrap before this check'
bash -n setup.sh
ansible-playbook -i inventory.ini --syntax-check site.yml
ansible-playbook -i inventory.ini --syntax-check verify.yml

grep -Fq -- '--limit workstation' setup.sh || fail 'setup must limit Ansible to workstation'
grep -Fq 'ansible_connection=local' inventory.ini || fail 'inventory must stay local'
grep -Fq 'setup_action in supported_actions' site.yml || fail 'Ansible must require an explicit reviewed action'
grep -Fq 'MacBookAir7,2' site.yml || fail 'Ansible must lock the target model'
grep -Fq 'hyprland' vars.yml || fail 'the reviewed desktop package set must include Hyprland'
grep -Fq 'plymouth' vars.yml || fail 'the reviewed apps package set must include Plymouth'
grep -Fq 'sddm.service' tasks/apps.yml || fail 'the Hyprland login manager must be enabled'
grep -Fq "when: setup_action == 'branding'" site.yml || fail 'branding must remain an explicit setup action'
grep -Fq '/usr/bin/reinstall-kernels' tasks/branding.yml || fail 'branding must rebuild systemd-boot kernel images'
grep -Fq 'bind = $mainMod, R, submap, remote_mac' templates/hyprland.conf.j2 || fail 'Hyprland must provide Remote Mac key passthrough'
grep -Fq 'bind = , Escape, submap, reset' templates/hyprland.conf.j2 || fail 'Remote Mac mode must have a local escape key'
grep -Fq '"hyprland/submap"' templates/waybar-config.jsonc.j2 || fail 'Waybar must show active Hyprland submaps'
grep -Fq '"format": "REMOTE MAC"' templates/waybar-config.jsonc.j2 || fail 'Waybar must label Remote Mac mode'
grep -Fq 'yay -S --needed' setup.sh || fail 'AUR package installation must stay interactive'
grep -Fq 'linux-desktop.sh' setup.sh || fail 'dotfiles must use the dedicated desktop entry point'
grep -Fq 'status --porcelain' setup.sh || fail 'dotfiles must fail closed on dirty checkouts'
grep -Fq 'sshd.service' setup.sh || fail 'setup must preflight sshd before package changes'
grep -Fq 'sshd.service' site.yml || fail 'Ansible must check that sshd remains inactive and disabled'

for package in google-chrome visual-studio-code-bin facetimehd-dkms facetimehd-firmware; do
  grep -Fq "$package" setup.sh || fail "missing reviewed AUR package: $package"
  grep -Fq "$package" THIRD-PARTY-NOTICES.md || fail "missing AUR notice: $package"
done
grep -Fq 'linux-headers' vars.yml || fail 'camera DKMS needs matching kernel headers'

for app_id in org.telegram.desktop org.upscayl.Upscayl sh.cider.Cider tv.plex.PlexDesktop; do
  grep -Fq "$app_id" vars.yml || fail "missing reviewed Flatpak: $app_id"
  grep -Fq "$app_id" THIRD-PARTY-NOTICES.md || fail "missing Flatpak notice: $app_id"
done

grep -Fq 'not ansible_check_mode' tasks/flatpak_apps.yml || fail 'Flatpak mutations need a check-mode guard'
grep -Fq 'checksum: "sha256:{{ librepods.sha256 }}"' tasks/librepods.yml || fail 'LibrePods download needs checksum validation'
grep -Fq '0569ba9a15aa58e660ec3ccb7d2d39ffd8800d6a5da3741802aefd86fd4b55a6' THIRD-PARTY-NOTICES.md || fail 'LibrePods pin needs notice coverage'
grep -Fq '1013a6ddaed8fafad60250efbce931c6a2c2d0706264558b542107126dc75840' THIRD-PARTY-NOTICES.md || fail 'wallpaper pin needs notice coverage'
grep -Fq '22903bf7891d144cf729cef04f3838567f1f9bc994e7c35dd65aeccbbeaac7f0' THIRD-PARTY-NOTICES.md || fail 'Plymouth logo pin needs notice coverage'
grep -Fq '1920f8b51754209286ce867c760993ea5e751eb81ebd6d343796dfcfc36ca673' THIRD-PARTY-NOTICES.md || fail 'profile image pin needs notice coverage'

git diff --check
printf 'Setup checks passed.\n'
