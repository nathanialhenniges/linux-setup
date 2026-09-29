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
grep -Fq 'ansible-doc -t module -F' setup.sh || fail 'collection detection must confirm the pacman module is listed'
grep -Fq '  - fuse2' vars.yml || fail 'Arch AppImage support must use the fuse2 package name'
! grep -Fq '  - libfuse2' vars.yml || fail 'use Arch package fuse2 instead of libfuse2'
grep -Fq '  - broadcom-wl-dkms' vars.yml || fail 'Arch Wi-Fi support must use broadcom-wl-dkms'
! grep -Eq '  - broadcom-wl$' vars.yml || fail 'use Arch package broadcom-wl-dkms instead of broadcom-wl'
grep -Fq '  - v4l-utils' vars.yml || fail 'camera diagnostics need v4l-utils'
grep -Fq '  - linux-lts-headers' vars.yml || fail 'FaceTime and Broadcom DKMS need LTS headers for the fallback kernel'
ansible-playbook -i inventory.ini --syntax-check site.yml
ansible-playbook -i inventory.ini --syntax-check verify.yml

grep -Fq -- '--limit workstation' setup.sh || fail 'setup must limit Ansible to workstation'
grep -Fq 'ansible_connection=local' inventory.ini || fail 'inventory must stay local'
grep -Fq 'setup_action in supported_actions' site.yml || fail 'Ansible must require an explicit reviewed action'
grep -Fq 'MacBookAir7,2' site.yml || fail 'Ansible must lock the target model'
! grep -Fq '  - hyprland' vars.yml || fail 'the regular desktop package set must stay GNOME-only'
grep -Fq 'HYPRLAND_PACKAGES=(hyprland' setup.sh || fail 'legacy Hyprland removal must use an explicit package list'
grep -Fq 'sudo pacman -Rns --' setup.sh || fail 'legacy package removal must remain interactive and let pacman review dependencies'
grep -Fq "when: setup_action == 'gnome-dock'" site.yml || fail 'GNOME dock setup must be a standalone action'
grep -Fq 'dash-to-dock@micxgx.gmail.com' tasks/gnome_dock.yml || fail 'GNOME dock setup must enable the reviewed Dash to Dock extension'
grep -Fq 'org.gnome.shell, favorite-apps' tasks/gnome_dock.yml || fail 'GNOME dock setup must pin the curated app favorites'
grep -Fq "value: \"'BOTTOM'\"" tasks/gnome_dock.yml || fail 'GNOME dock must use the bottom edge'
grep -Fq "background-color, value: \"'#3a2515'\"" tasks/gnome_dock.yml || fail 'GNOME dock must use the reviewed warm tint'
grep -Fq 'gnome_personalization_preferences' tasks/gnome_dock.yml || fail 'GNOME dock action must apply the reviewed appearance and shortcut preferences'
grep -Fq "regex_replace('^@as\\\\s*', '')" tasks/gnome_dock.yml || fail 'empty GNOME shortcut arrays must compare idempotently with GSettings output'
grep -Fq "key: color-scheme, value: \"'prefer-dark'\"" vars.yml || fail 'GNOME should use its built-in dark appearance'
grep -Fq "key: button-layout, value: \"'close,minimize,maximize:'\"" vars.yml || fail 'GNOME window controls should sit on the left'
grep -Fq "key: toggle-application-view, value: \"['<Super>a', '<Super>space']\"" vars.yml || fail 'the app grid must remain available on Super+A and match the old Super+Space launcher'
grep -Fq 'Preserve existing custom shortcuts and add the setup terminal shortcut' tasks/gnome_dock.yml || fail 'registering the Terminal shortcut must preserve existing custom shortcuts'
grep -Fq 'custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/linux-setup-terminal/' vars.yml || fail 'the terminal shortcut must use a namespaced GNOME custom keybinding'
grep -Fq "key: switch-input-source, value: \"['<Control><Super>space']\"" vars.yml || fail 'keyboard layout switching must remain available after using Super+Space for the app grid'
grep -Fq "key: switch-to-workspace-4, value: \"['<Super>4']\"" vars.yml || fail 'the fourth workspace must have the reviewed shortcut'
grep -Fq "key: move-to-workspace-4, value: \"['<Shift><Super>4']\"" vars.yml || fail 'moving windows to the fourth workspace must have the reviewed shortcut'
grep -Fq "key: switch-to-application-9, value: \"[]\"" vars.yml || fail 'GNOME app switching shortcuts must not conflict with workspace shortcuts'
grep -Fq '{ key: hot-keys, value: "false" }' tasks/gnome_dock.yml || fail 'Dash to Dock number shortcuts must not conflict with workspace shortcuts'
for app_id in org.gnome.Nautilus.desktop google-chrome.desktop org.telegram.desktop.desktop discord.desktop linux-setup-notion.desktop linux-setup-chatgpt.desktop sh.cider.Cider.desktop code.desktop com.mitchellh.ghostty.desktop tv.plex.PlexDesktop.desktop org.upscayl.Upscayl.desktop librepods.desktop; do
  grep -Fq "$app_id" vars.yml || fail "missing curated GNOME dock favorite: $app_id"
done
grep -Fq '⌘ + Return' docs/index.html || fail 'the public guide must list the terminal shortcut'
grep -Fq '⌘ + Shift + 1–4' docs/index.html || fail 'the public guide must list the move-workspace shortcut'
grep -Fq '⌘ + Shift + S' docs/index.html || fail 'the public guide must list the screenshot shortcut'
grep -Fq 'plymouth' vars.yml || fail 'the reviewed apps package set must include Plymouth'
grep -Fq 'gdm.service' tasks/login_manager.yml || fail 'GDM must remain the default login manager'
grep -Fq 'sddm.service' tasks/login_manager.yml || fail 'SDDM must be disabled when restoring GNOME'
grep -Fq 'profile-picture' setup.sh || fail 'profile picture must have a standalone setup action'
grep -Fq 'SetIconFile' tasks/profile_picture.yml || fail 'the profile picture action must update AccountsService'
grep -Fq 'mrdemonwolf' tasks/branding.yml || fail 'branding must select the MrDemonWolf Plymouth theme'
grep -Fq "when: setup_action == 'branding'" site.yml || fail 'branding must remain an explicit setup action'
grep -Fq '/usr/bin/reinstall-kernels' tasks/branding.yml || fail 'branding must rebuild systemd-boot kernel images'
grep -Fq 'yay -S --needed' setup.sh || fail 'AUR package installation must stay interactive'
grep -Fq 'linux-desktop.sh' setup.sh || fail 'dotfiles must use the dedicated desktop entry point'
grep -Fq 'status --porcelain' setup.sh || fail 'dotfiles must fail closed on dirty checkouts'
grep -Fq 'sshd.service' setup.sh || fail 'setup must preflight sshd before package changes'
grep -Fq 'sshd.service' site.yml || fail 'Ansible must check that sshd remains inactive and disabled'

for package in google-chrome visual-studio-code-bin facetimehd-dkms facetimehd-firmware gnome-shell-extension-dash-to-dock; do
  grep -Fq "$package" setup.sh || fail "missing reviewed AUR package: $package"
  grep -Fq "$package" THIRD-PARTY-NOTICES.md || fail "missing AUR notice: $package"
done
grep -Fq 'linux-headers' vars.yml || fail 'camera DKMS needs matching kernel headers'
grep -Fq 'camera_diagnostics' setup.sh || fail 'setup must provide the post-reboot camera check'
grep -Fq 'id="cmd-camera"' docs/index.html || fail 'the public guide must include the camera check command'
for action in display-manager branding profile-picture gnome-dock remove-hyprland; do
  grep -Fq "id=\"cmd-$action\"" docs/index.html || fail "the public guide must include the $action repair command"
done

for app_id in org.telegram.desktop org.upscayl.Upscayl sh.cider.Cider tv.plex.PlexDesktop; do
  grep -Fq "$app_id" vars.yml || fail "missing reviewed Flatpak: $app_id"
  grep -Fq "$app_id" THIRD-PARTY-NOTICES.md || fail "missing Flatpak notice: $app_id"
done

grep -Fq 'not ansible_check_mode' tasks/flatpak_apps.yml || fail 'Flatpak mutations need a check-mode guard'
grep -Fq 'argv: [flatpak, remotes, --system, "--columns=name,url"]' tasks/flatpak_apps.yml || fail 'Flatpak remote columns must remain one command argument'
grep -Fq 'argv: [flatpak, remotes, --system, "--columns=name,url"]' verify.yml || fail 'Flatpak verification remote columns must remain one command argument'
grep -Fq 'checksum: "sha256:{{ librepods.sha256 }}"' tasks/librepods.yml || fail 'LibrePods download needs checksum validation'
grep -Fq '0569ba9a15aa58e660ec3ccb4d2d39ffd8800d6a5da3741802aefd86fd4b55a6' vars.yml || fail 'LibrePods version pin must match the reviewed AppImage checksum'
grep -Fq '0569ba9a15aa58e660ec3ccb4d2d39ffd8800d6a5da3741802aefd86fd4b55a6' THIRD-PARTY-NOTICES.md || fail 'LibrePods pin needs notice coverage'
grep -Fq '1013a6ddaed8fafad60250efbce931c6a2c2d0706264558b542107126dc75840' THIRD-PARTY-NOTICES.md || fail 'wallpaper pin needs notice coverage'
grep -Fq '22903bf7891d144cf729cef04f3838567f1f9bc994e7c35dd65aeccbbeaac7f0' THIRD-PARTY-NOTICES.md || fail 'Plymouth logo pin needs notice coverage'
grep -Fq '1920f8b51754209286ce867c760993ea5e751eb81ebd6d343796dfcfc36ca673' THIRD-PARTY-NOTICES.md || fail 'profile image pin needs notice coverage'
grep -Fq 'cc3daf6176c3c7797b436fd446daacbd14640984cc4d7517fb99a1ec037134d3' THIRD-PARTY-NOTICES.md || fail 'AccountsService profile PNG pin needs notice coverage'

git diff --check
printf 'Setup checks passed.\n'
