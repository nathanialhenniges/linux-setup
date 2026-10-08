#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"

fail() {
  printf 'test_setup.sh: %s\n' "$1" >&2
  exit 1
}

command -v ansible-playbook >/dev/null 2>&1 || fail 'install ansible-core (./setup.sh bootstrap on the laptop) before this check'
bash -n setup.sh
grep -Fq 'ansible-doc -t module -F' setup.sh || fail 'collection detection must confirm the pacman module is listed'
grep -Fq '  - fuse2' vars.yml || fail 'Arch AppImage support must use the fuse2 package name'
! grep -Fq '  - libfuse2' vars.yml || fail 'use Arch package fuse2 instead of libfuse2'
grep -Fq '  - broadcom-wl-dkms' vars.yml || fail 'Arch Wi-Fi support must use broadcom-wl-dkms'
grep -Fq '  - ttf-cascadia-code-nerd' vars.yml || fail 'Ghostty needs the CaskaydiaCove Nerd Font used by its configured profile'
grep -Fq '  - gnome-shell-extension-appindicator' vars.yml || fail 'GNOME needs AppIndicator support to show the LibrePods tray icon'
grep -Fq '1password' setup.sh || fail 'the reviewed AUR package list must install 1Password'
grep -Fq 'ONEPASSWORD_SIGNING_KEY_FINGERPRINT=3FEF9748469ADBE15DA7CA80AC2D62742012EA22' setup.sh || fail '1Password must use the reviewed vendor signing-key fingerprint'
grep -Fq 'gpg --show-keys --with-colons "$key_file"' setup.sh || fail '1Password vendor key must be fingerprint-checked before import'
! grep -Eq '  - broadcom-wl$' vars.yml || fail 'use Arch package broadcom-wl-dkms instead of broadcom-wl'
grep -Fq '  - v4l-utils' vars.yml || fail 'camera diagnostics need v4l-utils'
grep -Fq '  - linux-lts-headers' vars.yml || fail 'FaceTime and Broadcom DKMS need LTS headers for the fallback kernel'
ansible-playbook -i inventory.ini --syntax-check site.yml
ansible-playbook -i inventory.ini --syntax-check verify.yml

grep -Fq -- '--limit workstation' setup.sh || fail 'setup must limit Ansible to workstation'
grep -Fq 'ansible_connection=local' inventory.ini || fail 'inventory must stay local'
grep -Fq 'selected_setup_actions | difference(supported_actions) | length == 0' site.yml || fail 'Ansible must require only explicit reviewed actions'
grep -Fq "selected_setup_actions: \"{{ setup_actions | default([setup_action | default('')]) }}\"" site.yml || fail 'Ansible must support grouped reviewed actions and standalone actions'
grep -Fq 'MacBookAir7,2' site.yml || fail 'Ansible must lock the target model'
grep -Fq 'become_ask_pass = false' ansible.cfg || fail 'Ansible must reuse the one sudo authentication instead of prompting for BECOME'
grep -Fq 'authenticate_setup_sudo || fail' setup.sh || fail 'setup must request sudo authentication once'
grep -Fq 'sudo -n -v </dev/tty' setup.sh || fail 'setup must refresh the sudo ticket without asking again'
grep -Fq 'trap stop_sudo_keepalive EXIT' setup.sh || fail 'setup must stop its temporary sudo keepalive when it exits'
grep -Fq 'run_site_actions base apps' setup.sh || fail 'all must group the base and apps Ansible phases'
grep -Fq 'run_site_actions tools desktop' setup.sh || fail 'all must group the tools and desktop Ansible phases'
grep -Fq 'run_site_actions gnome-dock branding' setup.sh || fail 'all must group the GNOME dock and branding Ansible phases'
grep -Fq 'chatgpt-bin' setup.sh || fail 'all must skip the official ChatGPT installer when its package is already installed'
grep -Fq 'pacman -Qq gnome-shell-extension-dash-to-dock' setup.sh || fail 'all must not perform a redundant second yay pass for the dock extension'
! grep -Fq '  - hyprland' vars.yml || fail 'the regular desktop package set must stay GNOME-only'
grep -Fq 'HYPRLAND_PACKAGES=(hyprland' setup.sh || fail 'legacy Hyprland removal must use an explicit package list'
grep -Fq 'sudo pacman -Rns --' setup.sh || fail 'legacy package removal must remain interactive and let pacman review dependencies'
grep -Fq "when: \"'gnome-dock' in selected_setup_actions\"" site.yml || fail 'GNOME dock setup must remain a selectable action'
grep -Fq 'dash-to-dock@micxgx.gmail.com' vars.yml || fail 'GNOME dock setup must configure the reviewed Dash to Dock extension'
grep -Fq 'appindicatorsupport@rgcjonas.gmail.com' vars.yml || fail 'GNOME dock setup must configure AppIndicator support for the LibrePods tray icon'
grep -Fq 'enabled-extensions' tasks/gnome_dock.yml || fail 'new system extensions must be configured for the next GNOME login'
! grep -Fq 'gnome-extensions, enable' tasks/gnome_dock.yml || fail 'do not try to enable newly installed system extensions in the current GNOME session'
grep -Fq 'gnome_extensions_configured' verify.yml || fail 'verification must confirm GNOME extensions are configured to load'
grep -Fq 'gnome_extensions_active' verify.yml || fail 'status must distinguish active GNOME extensions from those queued for next login'
grep -Fq 'gnome_dock_required_ids | reject(' verify.yml || fail 'verification must confirm the required apps, including 1Password, are pinned in the GNOME dock'
required_dock_block="$(awk '/^gnome_dock_required_ids:/{inside=1; next} inside && /^[^ ]/{exit} inside{print}' vars.yml)"
for app_id in com.onepassword.OnePassword.desktop chatgpt.desktop; do
  grep -Fxq "  - $app_id" <<<"$required_dock_block" || fail "gnome_dock_required_ids must require $app_id"
done
grep -Fq 'workstation_unready_checks | length == 0' verify.yml || fail 'status and verify must share one readiness list'
grep -Fiq 'log out and back in, or reboot' setup.sh || fail 'the GNOME dock action must explain how to load newly installed extensions'
grep -Fq 'next GNOME login' README.md || fail 'the setup guide must explain delayed GNOME extension activation'
grep -Fq 'next GNOME login' docs/index.html || fail 'the web guide must explain delayed GNOME extension activation'
grep -Fq 'librepods_autostart_ready' verify.yml || fail 'verification must confirm LibrePods minimized login start'
grep -Fq 'org.gnome.shell, favorite-apps' tasks/gnome_dock.yml || fail 'GNOME dock setup must pin the curated app favorites'
grep -Fq "value: \"'BOTTOM'\"" tasks/gnome_dock.yml || fail 'GNOME dock must use the bottom edge'
grep -Fq "background-color, value: \"'#3a2515'\"" tasks/gnome_dock.yml || fail 'GNOME dock must use the reviewed warm tint'
grep -Fq 'gnome_personalization_preferences' tasks/gnome_dock.yml || fail 'GNOME dock action must apply the reviewed appearance and shortcut preferences'
grep -Fq 'gsettings, range' tasks/gnome_dock.yml || fail 'GNOME dock must skip settings unavailable in this GNOME version'
grep -Fq 'Skipping unavailable GSettings key' tasks/gnome_dock.yml || fail 'GNOME dock must name settings skipped for version compatibility'
grep -Fq "replace('@as ', '')" tasks/gnome_dock.yml || fail 'empty GNOME shortcut arrays must be parsed and compared without their GSettings type marker'
grep -Fq "key: color-scheme, value: \"'prefer-dark'\"" vars.yml || fail 'GNOME should use its built-in dark appearance'
grep -Fq "key: button-layout, value: \"'close,minimize,maximize:'\"" vars.yml || fail 'GNOME window controls should sit on the left'
grep -Fq 'schema: org.gnome.shell, key: always-show-log-out, value: "true"' vars.yml || fail 'GNOME should always show the Log Out action in the system menu'
grep -Fq "key: toggle-application-view, value: \"['<Super>a', '<Super>space']\"" vars.yml || fail 'the app grid must remain available on Super+A and match the old Super+Space launcher'
grep -Fq 'Preserve existing custom shortcuts and add the setup terminal shortcut' tasks/gnome_dock.yml || fail 'registering the Terminal shortcut must preserve existing custom shortcuts'
grep -Fq 'custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/linux-setup-terminal/' vars.yml || fail 'the terminal shortcut must use a namespaced GNOME custom keybinding'
grep -Fq "key: switch-input-source, value: \"['<Control><Super>space']\"" vars.yml || fail 'keyboard layout switching must remain available after using Super+Space for the app grid'
grep -Fq 'key: dynamic-workspaces, value: "true"' vars.yml || fail 'GNOME should use its default dynamic workspaces'
grep -Fq 'key: num-workspaces, value: "1"' vars.yml || fail 'GNOME should start with one dynamic workspace'
grep -Fq 'Restore those GNOME shortcuts to this version' tasks/gnome_dock.yml || fail 'the dock action must remove this setup’s old fixed-workspace shortcuts'
grep -Fq 'gnome_previous_workspace_preferences' tasks/gnome_dock.yml || fail 'workspace shortcut cleanup must be scoped to the previous values set here'
grep -Fq 'key: hot-keys, value: "false"' tasks/gnome_dock.yml || fail 'Dash to Dock number shortcuts must not compete with GNOME defaults'
favorite_block="$(awk '/^gnome_dock_favorites:/{inside=1; next} inside && /^[^ ]/{exit} inside{print}' vars.yml)"
for app_id in org.gnome.Nautilus.desktop google-chrome.desktop com.onepassword.OnePassword.desktop org.telegram.desktop.desktop discord.desktop linux-setup-notion.desktop chatgpt.desktop sh.cider.Cider.desktop code.desktop com.mitchellh.ghostty.desktop; do
  printf '%s\n' "$favorite_block" | grep -Fq "$app_id" || fail "missing curated GNOME dock favorite: $app_id"
done
for app_id in tv.plex.PlexDesktop.desktop org.upscayl.Upscayl.desktop librepods.desktop; do
  if printf '%s\n' "$favorite_block" | grep -Fq "$app_id"; then
    fail "removed app must not stay pinned in the GNOME dock: $app_id"
  fi
done
grep -Fq 'cleanup_terminals' setup.sh || fail 'the script must offer standalone extra-terminal cleanup'
grep -Fq 'cleanup_terminals' <(sed -n '/    all)/,/    base)/p' setup.sh) || fail 'the all action must offer extra-terminal cleanup'
grep -Fq 'EXTRA_TERMINAL_PACKAGES=' setup.sh || fail 'terminal cleanup must use an explicit package list'
grep -Fq 'sudo pacman -Rns -- "${installed_packages[@]}"' setup.sh || fail 'terminal removal must let pacman review packages and dependencies'
grep -Fq 'Ghostty and command-line tools' setup.sh || fail 'terminal cleanup must preserve Ghostty and command-line tools'
grep -Fq 'OPENAI_CHATGPT_INSTALLER_URL=https://persistent.oaistatic.com/codex-app-prod/linux/install-arch.sh' setup.sh || fail 'ChatGPT must use OpenAI’s official Arch installer'
grep -Fq 'sudo bash "$installer_file"' setup.sh || fail 'the downloaded official ChatGPT installer must run through sudo after a syntax check'
grep -Fq 'chatgpt-bin' vars.yml || fail 'verification must require the official ChatGPT package'
grep -Fq "when: \"'cleanup-legacy' in selected_setup_actions\"" site.yml || fail 'legacy cleanup must remain a selectable standalone action'
grep -Fq "reject('equalto', legacy_chatgpt_launcher.desktop_id)" tasks/retired_chatgpt_launcher.yml || fail 'legacy cleanup must remove only the retired ChatGPT dock pin'
grep -Fq 'legacy_chatgpt.desktop.j2' tasks/retired_chatgpt_launcher.yml || fail 'legacy cleanup must identify its known launcher template'
grep -Fq 'require_gnome_session' setup.sh || fail 'legacy dock cleanup must run inside GNOME'
grep -Fq 'OpenAI’s signed Arch repository' README.md || fail 'README must explain the official ChatGPT install source'
grep -Fq 'id="cmd-chatgpt-app"' docs/index.html || fail 'the guide must include the standalone ChatGPT install action'
grep -Fq 'id="cmd-cleanup-legacy"' docs/index.html || fail 'the guide must include the standalone legacy cleanup action'
grep -Fq '⌘ + Return' docs/index.html || fail 'the public guide must list the terminal shortcut'
grep -Fq 'Super + Page Up/Down' docs/index.html || fail 'the public guide must list GNOME’s dynamic-workspace shortcut'
grep -Fq '1Password' docs/index.html || fail 'the public guide must list 1Password'
grep -Fq 'dynamic workspaces' README.md || fail 'the setup guide must explain dynamic workspaces'
grep -Fq '⌘ + Shift + S' docs/index.html || fail 'the public guide must list the screenshot shortcut'
grep -Fq 'plymouth' vars.yml || fail 'the reviewed apps package set must include Plymouth'
grep -Fq 'kernel-install-for-dracut' vars.yml || fail 'the apps package set must include the EndeavourOS systemd-boot rebuild helper'
grep -Fq 'argv: [/usr/bin/plymouth-set-default-theme, mrdemonwolf]' tasks/branding.yml || fail 'branding must select its theme through Plymouth'
grep -Fq "when: current_plymouth_theme.stdout | trim != 'mrdemonwolf'" tasks/branding.yml || fail 'Plymouth theme selection must be idempotent'
grep -Fq 'gdm.service' tasks/login_manager.yml || fail 'GDM must remain the default login manager'
grep -Fq 'sddm.service' tasks/login_manager.yml || fail 'SDDM must be disabled when restoring GNOME'
grep -Fq 'profile-picture' setup.sh || fail 'profile picture must have a standalone setup action'
grep -Fq 'SetIconFile' tasks/profile_picture.yml || fail 'the profile picture action must update AccountsService'
grep -Fq 'mrdemonwolf' tasks/branding.yml || fail 'branding must select the MrDemonWolf Plymouth theme'
grep -Fq 'WatermarkVerticalAlignment=.96' themes/mrdemonwolf.plymouth || fail 'the Plymouth logo must sit near the bottom of the splash'
grep -Fq 'BackgroundStartColor=0x000000' themes/mrdemonwolf.plymouth || fail 'the Plymouth splash background must be black'
grep -Fq 'BackgroundEndColor=0x000000' themes/mrdemonwolf.plymouth || fail 'the Plymouth splash must stay black through transitions'
grep -Fq 'UseProgressBar=true' themes/mrdemonwolf.plymouth || fail 'the Plymouth boot-up theme must not use the spinner animation'
grep -Fq 'UseEndAnimation=false' themes/mrdemonwolf.plymouth || fail 'the Plymouth boot-up theme must not show a spinner at completion'
theme_sha256="$(shasum -a 256 themes/mrdemonwolf.plymouth 2>/dev/null || sha256sum themes/mrdemonwolf.plymouth)"
[[ "${theme_sha256%% *}" == 90e6561f6640dd62afd139534ad03191e2336feb4014587bc3180199b9369f83 ]] || fail 'the reviewed Plymouth theme file changed; update its pin and keep the old one as a previous version'
grep -Fq 'plymouth_theme_sha256: 90e6561f6640dd62afd139534ad03191e2336feb4014587bc3180199b9369f83' vars.yml || fail 'the static black splash needs its matching theme checksum'
grep -Fq '  - e0bad97e187eb224d37723eb38109de70ef70cc5b7f5738ac646f0a73f8c7e1f' vars.yml || fail 'branding must allow upgrading the prior boot-only static theme'
for section in '[boot-up]' '[shutdown]' '[reboot]'; do
  grep -Fxq "$section" themes/mrdemonwolf.plymouth || fail "the Plymouth theme must configure its $section mode"
done
[[ "$(grep -Fxc 'UseAnimation=false' themes/mrdemonwolf.plymouth)" == 3 ]] || fail 'the Plymouth theme must disable the spinner at startup, shutdown, and reboot'
grep -Fq 'plymouth_previous_theme_sha256s:' vars.yml || fail 'branding must allow upgrading previously installed Plymouth themes'
grep -Fq 'A static wolf logo sits near the bottom of a black splash' docs/index.html || fail 'the web guide must explain the black static boot splash'
grep -Fq 'without the spinner animation' README.md || fail 'the setup guide must explain the static boot splash'
grep -Fq 'no spinner; the text-only systemd-boot menu stays the same' docs/index.html || fail 'the branding command help must explain that the spinner is removed'
grep -Fq '7282e6db16cc5b884a93fc284af1667961745061092aef5c8d09fad72c7da493' vars.yml || fail 'branding must allow upgrading the prior bottom-logo theme'
grep -Fq '93b025f20c1745717ca3750d38b68f37c107dafdc8c589cdfd5c0203e66b4899' vars.yml || fail 'branding must allow upgrading the prior upper-logo theme'
grep -Fq 'b580642ff16800847051de2e3e57e83e7f7b876fe027f7f4520f07d20b45eefa' vars.yml || fail 'branding must allow upgrading the original centered-logo theme'
grep -Fq 'item.stat.checksum in plymouth_previous_theme_sha256s' tasks/branding.yml || fail 'Plymouth theme file checks must allow only explicitly pinned prior versions'
grep -Fq 'checksum in ([plymouth_theme_sha256] + plymouth_previous_theme_sha256s)' tasks/branding.yml || fail 'Plymouth directory markers must accept the current or pinned previous themes'
grep -Fq "when: \"'branding' in selected_setup_actions\"" site.yml || fail 'branding must remain an explicit setup action'
grep -Fq '/usr/bin/reinstall-kernels' tasks/branding.yml || fail 'branding must rebuild systemd-boot kernel images'
grep -Fq 'yay -S --needed' setup.sh || fail 'AUR package installation must stay interactive'
! grep -Fq -- '--noconfirm' setup.sh || fail 'setup.sh must not pass --noconfirm; pacman and yay prompts stay interactive'
grep -Fq 'kill -0 "$$" 2>/dev/null || exit 0' setup.sh || fail 'the sudo keepalive must stop once setup.sh exits'
while read -r register_name; do
  (($(grep -ow -- "$register_name" tasks/branding.yml | wc -l) > 1)) || fail "unused branding register: $register_name"
done < <(sed -n 's/^ *register: //p' tasks/branding.yml)
grep -Fq 'excludes: [watermark.png]' tasks/branding.yml || fail 'branding must never copy the stock spinner watermark over the branded logo'
grep -Fq 'update icon_sha256 in vars.yml' tasks/chrome_web_apps.yml || fail 'a changed vendor icon must explain how to review and update its pin'
! grep -Fqi hyprland docs/og-image.svg || fail 'the guide preview image must describe the GNOME setup'
grep -Fq 'linux-desktop.sh' setup.sh || fail 'dotfiles must use the dedicated desktop entry point'
grep -Fq 'status --porcelain' setup.sh || fail 'dotfiles must fail closed on dirty checkouts'
grep -Fq 'sshd.service' setup.sh || fail 'setup must preflight sshd before package changes'
grep -Fq 'sshd.service' site.yml || fail 'Ansible must check that sshd remains inactive and disabled'

# Read the lists from their sources so an added or dropped package cannot slip past its notice.
read -ra aur_packages <<<"$(sed -n 's/^AUR_PACKAGES=(\(.*\))$/\1/p' setup.sh)"
((${#aur_packages[@]})) || fail 'could not read AUR_PACKAGES from setup.sh'
[[ "${aur_packages[*]}" == 'google-chrome visual-studio-code-bin facetimehd-dkms facetimehd-firmware gnome-shell-extension-dash-to-dock oh-my-posh-bin 1password' ]] \
  || fail 'AUR_PACKAGES changed; review each package and update THIRD-PARTY-NOTICES.md and this list together'
for package in "${aur_packages[@]}"; do
  grep -Fq "\`$package\`" THIRD-PARTY-NOTICES.md || fail "missing AUR notice: $package"
done
grep -Fq 'community.general' THIRD-PARTY-NOTICES.md || fail 'the pinned Ansible collection needs notice coverage'
grep -Fq 'ttf-cascadia-code-nerd' THIRD-PARTY-NOTICES.md || fail 'the configured Ghostty Nerd Font needs third-party notice coverage'
grep -Fq 'linux-headers' vars.yml || fail 'camera DKMS needs matching kernel headers'
grep -Fq 'camera_diagnostics' setup.sh || fail 'setup must provide the post-reboot camera check'
grep -Fq 'id="cmd-camera"' docs/index.html || fail 'the public guide must include the camera check command'
for action in display-manager branding profile-picture gnome-dock remove-hyprland chatgpt-app cleanup-legacy cleanup-terminals; do
  grep -Fq "id=\"cmd-$action\"" docs/index.html || fail "the public guide must include the $action repair command"
done

mapfile -t flatpak_ids < <(awk '/^core_flatpak_packages:/{inside=1; next} inside && /^[^ ]/{exit} inside && sub(/^  - /, ""){print}' vars.yml)
[[ "${flatpak_ids[*]}" == 'org.telegram.desktop org.upscayl.Upscayl sh.cider.Cider tv.plex.PlexDesktop' ]] \
  || fail 'core_flatpak_packages changed; review each app and update THIRD-PARTY-NOTICES.md and this list together'
for app_id in "${flatpak_ids[@]}"; do
  grep -Fq "\`$app_id\`" THIRD-PARTY-NOTICES.md || fail "missing Flatpak notice: $app_id"
done

grep -Fq 'not ansible_check_mode' tasks/flatpak_apps.yml || fail 'Flatpak mutations need a check-mode guard'
grep -Fq 'argv: [flatpak, remotes, --system, "--columns=name,url"]' tasks/flatpak_apps.yml || fail 'Flatpak remote columns must remain one command argument'
grep -Fq 'argv: [flatpak, remotes, --system, "--columns=name,url"]' verify.yml || fail 'Flatpak verification remote columns must remain one command argument'
grep -Fq 'checksum: "sha256:{{ librepods.sha256 }}"' tasks/librepods.yml || fail 'LibrePods download needs checksum validation'
[[ -f templates/librepods-autostart.desktop.j2 ]] || fail 'LibrePods needs a user-local GNOME autostart entry'
grep -Fq -- '--hide' templates/librepods-autostart.desktop.j2 || fail 'LibrePods must autostart minimized with its --hide option'
! grep -Fq -- '--start-minimized' templates/librepods-autostart.desktop.j2 || fail 'LibrePods ignores --start-minimized; use --hide'
grep -Fq 'librepods-autostart-legacy.desktop.j2' tasks/librepods.yml || fail 'LibrePods must recognize and replace the earlier --start-minimized autostart entry'
grep -Fq "checksum | default('') == librepods.sha256" verify.yml || fail 'verification must check the reviewed LibrePods AppImage checksum'
grep -Fq 'X-GNOME-Autostart-Delay=30' templates/librepods-autostart.desktop.j2 || fail 'LibrePods must wait for GNOME to settle before autostart'
grep -Fq 'Refuse unknown LibrePods autostart content' tasks/librepods.yml || fail 'LibrePods autostart must refuse unknown existing content'
grep -Fq '0569ba9a15aa58e660ec3ccb4d2d39ffd8800d6a5da3741802aefd86fd4b55a6' vars.yml || fail 'LibrePods version pin must match the reviewed AppImage checksum'
grep -Fq '0569ba9a15aa58e660ec3ccb4d2d39ffd8800d6a5da3741802aefd86fd4b55a6' THIRD-PARTY-NOTICES.md || fail 'LibrePods pin needs notice coverage'
grep -Fq '1013a6ddaed8fafad60250efbce931c6a2c2d0706264558b542107126dc75840' THIRD-PARTY-NOTICES.md || fail 'wallpaper pin needs notice coverage'
grep -Fq '22903bf7891d144cf729cef04f3838567f1f9bc994e7c35dd65aeccbbeaac7f0' THIRD-PARTY-NOTICES.md || fail 'Plymouth logo pin needs notice coverage'
grep -Fq '1920f8b51754209286ce867c760993ea5e751eb81ebd6d343796dfcfc36ca673' THIRD-PARTY-NOTICES.md || fail 'profile image pin needs notice coverage'
grep -Fq 'cc3daf6176c3c7797b436fd446daacbd14640984cc4d7517fb99a1ec037134d3' THIRD-PARTY-NOTICES.md || fail 'AccountsService profile PNG pin needs notice coverage'

bash -n scripts/sudo-session.sh
grep -Fq -- '--become-password-file -' scripts/sudo-session.sh || fail "Ansible must receive authentication through stdin"

# Check uncommitted, staged, and committed files: the container runs these checks on a fresh
# one-commit snapshot, where a plain git diff --check has nothing to compare.
git diff --check || fail 'unstaged changes contain whitespace errors or conflict markers'
git diff --cached --check || fail 'staged changes contain whitespace errors or conflict markers'
git diff --check "$(git hash-object -t tree /dev/null)" HEAD || fail 'committed files contain whitespace errors or conflict markers'
printf 'Setup checks passed.\n'
