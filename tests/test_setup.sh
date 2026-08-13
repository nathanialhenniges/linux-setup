#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
setup="$repo_dir/setup.sh"
notices="$repo_dir/THIRD-PARTY-NOTICES.md"
readme="$repo_dir/README.md"
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

if [[ -f "$notices" ]] &&
   grep -Fq 'v30.5.0' "$notices" &&
   grep -Fq 'v3.5.0' "$notices" &&
   grep -Fq 'linux-v0.1.0' "$notices" &&
   grep -Fq 'Toshy_v26.08.0' "$notices" &&
   grep -Fq '7d6904cf64dee3bb52f1cea75040ae943bc8fe32' "$notices" &&
   grep -Fq 'focused-window-dbus' "$notices" &&
   grep -Fq 'org.telegram.desktop' "$notices" &&
   grep -Fq 'sh.cider.Cider' "$notices" &&
   grep -Fq 'tv.plex.PlexDesktop' "$notices"; then
  pass 'third-party notices cover reviewed artifacts and sources'
else
  fail 'third-party notices coverage'
fi

# shellcheck disable=SC2016 # Assert literal Markdown commands in the guide.
if grep -Fq 'cd ~/Developer/nathanialhenniges/linux-setup' "$readme" &&
   grep -Fq './setup.sh bootstrap' "$readme" &&
   grep -Fq './setup.sh --dry-run all' "$readme" &&
   grep -Fq './setup.sh keybinds && ./setup.sh verify' "$readme" &&
   grep -Fq 'Resume after a stopped action' "$readme" &&
   grep -Fq 'Manual acceptance checklist' "$readme" &&
   grep -Fq '240 x 240 px' "$readme" &&
   grep -Fq 'WatermarkVerticalAlignment=.34' "$readme" &&
   grep -Fq 'paste the complete error output' "$readme" &&
   grep -Fq 'Do not manually delete or edit APT source files' "$readme"; then
  pass 'README is the complete MBA setup and recovery guide'
else
  fail 'README MBA how-to coverage'
fi

if "$setup" --help | grep -Fq 'Ubuntu Desktop 26.04 local Ansible setup'; then
  pass 'help works without target checks'
else
  fail 'help output'
fi

if "$setup" --help | grep -Fq './setup.sh [--dry-run] all' &&
   "$setup" --help | grep -Fq 'all        Bootstrap, run seven workstation actions in order, then verify'; then
  pass 'help advertises the all command'
else
  fail 'all command help'
fi

if "$setup" | grep -Fq './setup.sh [--dry-run] bootstrap'; then
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

if grep -Fq 'Toshy_v26.08.0' "$setup" &&
   grep -Fq 'c39ee06d8d7fa299a082034d75275e6da97e0275' "$setup" &&
   grep -Fq 'dfa142bd53177d038098b9b6919c50f4904d3c37f4cbd33c6bad5e969c85ed57' "$setup" &&
   grep -Fq '7d6904cf64dee3bb52f1cea75040ae943bc8fe32' "$setup" &&
   grep -Fq 'ff312b70705b9bd63524223f4b48755605b6f0970c77c8e35303ce1f20841cab' "$setup" &&
   grep -Fq 'focused-window-dbus@flexagoon.com' "$setup" &&
   grep -Fq '5ff336fac73b34deaf83f32772e8478885fa4925' "$setup" &&
   grep -Fq '8fe40d9eecee1e6ed8b998d04832b7bb8faa410233509346a30a4b17e5037c7f' "$setup" &&
   grep -Fq 'gnome-extensions pack' "$setup" &&
   grep -Fq 'gnome-extensions install --force' "$setup" &&
   grep -Fq "gnome-extensions enable \"\$focus_extension\"" "$setup" &&
   grep -Fq 'gnome-extensions list --active' "$setup" &&
   grep -Fq 'resume: ./setup.sh keybinds && ./setup.sh verify' "$setup" &&
   grep -Fq '  - gnome-shell-extension-manager' "$repo_dir/vars.yml" &&
   ! grep -Eq 'sudo[[:space:]].*setup_toshy' "$setup"; then
  pass 'Toshy and its keymapper are pinned outside Ansible become'
else
  fail 'guarded Toshy source boundary'
fi

if grep -Fq 'start_toshy_services' "$setup" &&
   grep -Fq 'require_live_gnome_session' "$setup" &&
   grep -Fq 'refuse_competing_keymappers' "$setup" &&
   grep -Fq 'SSH_CONNECTION' "$setup" &&
   grep -Fq 'SSH_TTY' "$setup" &&
   grep -Fq 'DBUS_SESSION_BUS_ADDRESS' "$setup" &&
   grep -Fq "\$HOME/.Xmodmap" "$setup" &&
   grep -A15 -F 'refuse_competing_keymappers() {' "$setup" | grep -Fq '  return 0' &&
   grep -Fq 'XDG_SESSION_TYPE:-}" == wayland' "$setup" &&
   grep -Fq 'toshy-services-enable' "$setup" &&
   grep -Fq 'toshy-services-restart' "$setup" &&
   grep -Fq 'for unit in toshy-config.service toshy-session-monitor.service' "$setup" &&
   grep -Fq "systemctl --user is-enabled --quiet \"\$unit\"" "$setup" &&
   grep -Fq "systemctl --user is-active --quiet \"\$unit\"" "$setup" &&
   grep -Fq 'MAC MODE MANUAL CHECKLIST' "$setup" &&
   grep -Fq 'toshy-config.service' "$repo_dir/verify.yml" &&
   grep -Fq 'toshy-session-monitor.service' "$repo_dir/verify.yml" &&
   grep -Fq 'verified_toshy_config.stat.isreg' "$repo_dir/verify.yml" &&
   grep -Fq 'verified_toshy_active.results' "$repo_dir/verify.yml" &&
   grep -Fq 'verified_toshy_enabled.results' "$repo_dir/verify.yml" &&
   grep -Fq 'ansible_facts.env.WAYLAND_DISPLAY' "$repo_dir/verify.yml" &&
   grep -Fq 'MACOS KEY SERVICES' "$repo_dir/verify.yml" &&
   grep -A18 -F 'Require the completed core workstation state' "$repo_dir/verify.yml" | grep -Fq 'macos_keys_ready'; then
  pass 'macOS key services are repaired, checked, and required'
else
  fail 'macOS key runtime boundary'
fi

if grep -Fq 'ansible_become_exe=/usr/bin/sudo.ws' "$repo_dir/inventory.ini" &&
   grep -Fq '[[ -x /usr/bin/sudo.ws ]]' "$setup" &&
   grep -Fq 'command+=(--ask-become-pass)' "$setup" &&
   ! grep -Fq '/usr/bin/sudo.ws -n /usr/bin/true' "$setup" &&
   ! grep -Eq 'update-alternatives|NOPASSWD' "$setup" "$repo_dir/inventory.ini"; then
  pass 'Ansible always prompts through scoped Ubuntu classic sudo'
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

if grep -Fxq 'readonly -a all_actions=(base apps tools terminal dotfiles gnome keybinds)' "$setup" &&
   grep -Fq 'bootstrap | all | status | verify | sources | base | apps | tools | terminal | codex | dotfiles | gnome | keybinds | boot | boot-reset)' "$setup" &&
   grep -Fq "\"\$repo_dir/setup.sh\" bootstrap || die \"all stopped at bootstrap" "$setup" &&
   grep -Fq "[[ \"\$dry_run\" == false ]] || command+=(--dry-run)" "$setup" &&
   grep -Fq 'final_step="status"' "$setup" &&
   grep -Fq "\"\$repo_dir/setup.sh\" \"\$final_step\" ||" "$setup" &&
   grep -Fq 'all) run_all ;;' "$setup"; then
  pass 'all sequences only reviewed actions and preserves dry-run safety'
else
  fail 'all action orchestration'
fi

# shellcheck disable=SC2016 # Assert the wrapper contains the literal mode expansion.
if grep -A24 -F 'run_boot() {' "$setup" | grep -Fq -- '--tags boot' &&
   grep -A24 -F 'run_boot() {' "$setup" | grep -Fq -- '-e setup_action=boot' &&
   grep -A24 -F 'run_boot() {' "$setup" | grep -Fq -- '-e "boot_branding_mode=$mode"' &&
   grep -A24 -F 'run_boot() {' "$setup" | grep -Fq 'require_classic_sudo' &&
   grep -Fq 'boot) run_boot apply ;;' "$setup" &&
   grep -Fq 'boot-reset) run_boot rollback ;;' "$setup" &&
   grep -Fq "when: setup_action == 'boot'" "$repo_dir/site.yml" &&
   grep -Fq 'file: tasks/boot_branding.yml' "$repo_dir/site.yml" &&
   grep -Fxq '  - boot' "$repo_dir/vars.yml" &&
   [[ "$(shasum -a 256 "$repo_dir/assets/boot-branding/mrdemonwolf-logo.png" | awk '{print $1}')" == '860899736ae436938660c24cf1b58a477286afd15d3d6dc4ec8d40b85131b406' ]] &&
   file "$repo_dir/assets/boot-branding/mrdemonwolf-logo.png" | grep -Fq 'PNG image data, 240 x 240' &&
   grep -Fq "boot_branding_watermark_horizontal_alignment: '.5'" "$repo_dir/tasks/boot_branding.yml" &&
   grep -Fq "boot_branding_watermark_vertical_alignment: '.34'" "$repo_dir/tasks/boot_branding.yml" &&
   grep -Fq "boot_branding_dialog_vertical_alignment: '.64'" "$repo_dir/tasks/boot_branding.yml" &&
   grep -Fq 'boot_branding_requested_mode in' "$repo_dir/tasks/boot_branding.yml" &&
   grep -Fq 'Skipping boot branding on an unsupported TPM-backed FDE or UKI layout' "$repo_dir/tasks/boot_branding.yml" &&
   grep -Fq 'Refusing unmanaged Plymouth theme directory' "$repo_dir/tasks/boot_branding.yml" &&
   [[ -x "$repo_dir/tests/test-boot-branding-docker.sh" ]]; then
  pass 'Plymouth branding is opt-in, reversible, checksum-pinned, and excluded from all'
else
  fail 'Plymouth boot-branding boundary'
fi

claude_preflight_call_line="$(grep -n -m1 -F '  repair_known_claude_source_conflict' "$setup" | cut -d: -f1 || true)"
bootstrap_apt_update_line="$(grep -n -m1 -F '  sudo apt-get update' "$setup" | cut -d: -f1 || true)"
dry_run_source_preview_line="$(grep -n -m1 -F "\"\$repo_dir/setup.sh\" --dry-run sources" "$setup" | cut -d: -f1 || true)"
all_step_loop_line="$(grep -n -m1 -F "  for step in \"\${all_actions[@]}\"" "$setup" | cut -d: -f1 || true)"
if [[ -n "$claude_preflight_call_line" && -n "$bootstrap_apt_update_line" ]] &&
   (( claude_preflight_call_line < bootstrap_apt_update_line )) &&
   [[ -n "$dry_run_source_preview_line" && -n "$all_step_loop_line" ]] &&
   (( dry_run_source_preview_line < all_step_loop_line )) &&
   grep -Fq 'readonly claude_managed_source=/etc/apt/sources.list.d/claude-desktop.sources' "$setup" &&
   grep -Fq 'claude_unmanaged_source_present() {' "$setup" &&
   grep -Fq '/etc/apt/sources.list.d/*.sources' "$setup" &&
   grep -Fq "\"\$repo_dir/setup.sh\" sources ||" "$setup" &&
   grep -Fq 'dry-run all stopped before APT' "$setup" &&
   grep -Fq "setup_action in ['sources', 'apps']" "$repo_dir/site.yml" &&
   grep -Fq "['!all', '!min', 'architecture', 'distribution', 'env', 'hardware', 'user']" "$repo_dir/site.yml" &&
   grep -A4 -F 'Read installed package state without using the network' "$repo_dir/site.yml" | grep -Fq "when: setup_action != 'sources'" &&
   ! grep -A18 -F 'Configure verified core vendor repositories' "$repo_dir/site.yml" | grep -Fq 'update_cache:'; then
  pass 'Claude Signed-By repair runs before bootstrap parses APT sources'
else
  fail 'Claude pre-bootstrap source repair ordering'
fi

tool_package_manifest="$(awk '
  /^tool_packages:/ { capture=1; next }
  capture && /^[[:alnum:]_]+:/ { exit }
  capture && /^  - / { sub(/^  - /, ""); print }
' "$repo_dir/vars.yml")"
expected_tool_packages=$'awscli\nbtop\nfastfetch\nhttrack\nnmap\nrclone\nsmartmontools\nyt-dlp'
if [[ "$tool_package_manifest" == "$expected_tool_packages" ]]; then
  pass 'selected Ubuntu CLI package manifest is exact'
else
  fail 'selected Ubuntu CLI package manifest'
fi

app_package_manifest="$(awk '
  /^core_app_packages:/ { capture=1; next }
  capture && /^[[:alnum:]_]+:/ { exit }
  capture && /^  - / { sub(/^  - /, ""); print }
' "$repo_dir/vars.yml")"
expected_app_packages=$'bluez\nchatgpt\nclaude-desktop\ncloudflare-warp\ncode\ngh\nghostty\ngnome-shell-extension-manager\nlibfuse2t64\nmesa-vulkan-drivers\nobs-studio\nvulkan-tools'
flatpak_package_manifest="$(awk '
  /^core_flatpak_packages:/ { capture=1; next }
  capture && /^[[:alnum:]_]+:/ { exit }
  capture && /^  - / { sub(/^  - /, ""); print }
' "$repo_dir/vars.yml")"
if [[ "$app_package_manifest" == "$expected_app_packages" ]] &&
   grep -A1 -F 'core_snap_packages:' "$repo_dir/vars.yml" | grep -Fq '  - postman' &&
   [[ "$flatpak_package_manifest" == $'org.telegram.desktop\norg.upscayl.Upscayl\nsh.cider.Cider\ntv.plex.PlexDesktop' ]] &&
   ! grep -Eq '^  - (dbeaver|localwp|rpi-imager)$' "$repo_dir/vars.yml" &&
   ! grep -Fq '  - optional' "$repo_dir/vars.yml" &&
   ! grep -Fq 'keybinds | optional' "$setup"; then
  pass 'approved desktop application manifests are exact'
else
  fail 'approved desktop application manifests'
fi

if grep -Fq 'Check whether Telegram is installed from Flathub' "$repo_dir/verify.yml" &&
   grep -Fq 'Check whether Plex Desktop is installed from Flathub' "$repo_dir/verify.yml" &&
   grep -Fq 'Verify every approved Flatpak application origin' "$repo_dir/site.yml" &&
   grep -Fq 'Require every approved Flatpak application from Flathub' "$repo_dir/site.yml" &&
   grep -A16 -F 'Require every approved Flatpak application from Flathub' "$repo_dir/site.yml" | grep -Fq "rejectattr('stdout', 'equalto', core_flatpak_remote.name)" &&
   grep -Fq 'telegram_ready:' "$repo_dir/verify.yml" &&
   grep -Fq 'plex_ready:' "$repo_dir/verify.yml" &&
   grep -Fq '          - telegram_ready' "$repo_dir/verify.yml" &&
   grep -Fq '          - plex_ready' "$repo_dir/verify.yml" &&
   grep -Fq 'TELEGRAM           ' "$repo_dir/verify.yml" &&
   grep -Fq 'PLEX DESKTOP       ' "$repo_dir/verify.yml" &&
   grep -Fq 'flatpak run org.telegram.desktop' "$repo_dir/README.md" &&
   grep -Fq 'flatpak run tv.plex.PlexDesktop' "$repo_dir/README.md" &&
   grep -Fq 'Check whether Cider is installed from Flathub' "$repo_dir/verify.yml" &&
   grep -Fq 'cider_ready:' "$repo_dir/verify.yml" &&
   grep -Fq 'CIDER              ' "$repo_dir/verify.yml" &&
   grep -Fq '          - cider_ready' "$repo_dir/verify.yml" &&
   grep -Fq 'sudo apt install rpi-imager' "$repo_dir/README.md" &&
   grep -Fq 'one site at a time' "$repo_dir/README.md"; then
  pass 'selected desktop app routes are explicit and verifiable'
else
  fail 'selected desktop app route policy'
fi

if grep -Fq 'version: "26.803.81509"' "$repo_dir/vars.yml" &&
   grep -Fq 'https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb' "$repo_dir/vars.yml" &&
   grep -Fq 'a9bf91a368f9f7c4eea38082a9fb8fb46b8d005b719a6d7715d2e5a1982c38eb' "$repo_dir/vars.yml" &&
   grep -Fq '23e2cfbdef6afe95505f9e95a2cb63585da7ffe9b06a51ec08a32407c847d596' "$repo_dir/vars.yml" &&
   grep -Fq '9ff8ae7b9e2e73b9fa1a31383c4cde964e159bab39aee762aef4918d1a4f2cfd' "$repo_dir/vars.yml" &&
   grep -A7 -F 'Download the pinned official ChatGPT package' "$repo_dir/site.yml" | grep -Fq 'checksum: "sha256:{{ chatgpt.sha256 }}"' &&
   grep -A6 -F 'Install the pinned official ChatGPT package' "$repo_dir/site.yml" | grep -Fq 'deb: "{{ chatgpt_package.path }}"' &&
   grep -Fq 'CHATGPT DESKTOP    {{' "$repo_dir/verify.yml" &&
   grep -Fq 'https://learn.chatgpt.com/docs/linux/linux-app' "$repo_dir/README.md"; then
  pass 'ChatGPT Linux preview uses the pinned official Ubuntu package and repository'
else
  fail 'official ChatGPT Linux preview boundary'
fi

if grep -Fq '  name: flathub' "$repo_dir/vars.yml" &&
   grep -Fq '  url: https://dl.flathub.org/repo/flathub.flatpakrepo' "$repo_dir/vars.yml" &&
   grep -Fq '    - name: Refuse a Flathub remote pointing somewhere else' "$repo_dir/site.yml" &&
   grep -Fq '          - --if-not-exists' "$repo_dir/site.yml" &&
   grep -Fq '      loop: "{{ core_flatpak_packages }}"' "$repo_dir/site.yml" &&
   ! grep -A14 -F 'Add the reviewed Flathub remote' "$repo_dir/site.yml" | grep -Fq -- '- --user' &&
   ! grep -A20 -F 'Install missing approved Flatpak applications' "$repo_dir/site.yml" | grep -Fq -- '- --user'; then
  pass 'Flatpak stays on the reviewed system Flathub remote'
else
  fail 'Flatpak remote policy'
fi

upscayl_install_line="$(grep -n -m1 -F 'Install missing approved Flatpak applications' "$repo_dir/site.yml" | cut -d: -f1 || true)"
upscayl_verify_line="$(grep -n -m1 -F 'Verify the reviewed Upscayl Flatpak before migration cleanup' "$repo_dir/site.yml" | cut -d: -f1 || true)"
upscayl_deb_cleanup_line="$(grep -n -m1 -F 'Remove the legacy Upscayl Debian package' "$repo_dir/site.yml" | cut -d: -f1 || true)"
upscayl_snap_cleanup_line="$(grep -n -m1 -F 'Remove the legacy Upscayl Snap' "$repo_dir/site.yml" | cut -d: -f1 || true)"
upscayl_user_flatpak_cleanup_line="$(grep -n -m1 -F 'Remove the legacy user-scoped Upscayl Flatpak' "$repo_dir/site.yml" | cut -d: -f1 || true)"
if [[ -n "$upscayl_install_line" && -n "$upscayl_verify_line" &&
      -n "$upscayl_deb_cleanup_line" && -n "$upscayl_snap_cleanup_line" &&
      -n "$upscayl_user_flatpak_cleanup_line" ]] &&
   (( upscayl_verify_line > upscayl_install_line )) &&
   (( upscayl_deb_cleanup_line > upscayl_verify_line )) &&
   (( upscayl_snap_cleanup_line > upscayl_verify_line )) &&
   (( upscayl_user_flatpak_cleanup_line > upscayl_verify_line )) &&
   grep -A8 -F 'Verify the reviewed Upscayl Flatpak before migration cleanup' "$repo_dir/site.yml" | grep -Fq -- '- --show-origin' &&
   grep -A8 -F 'Require the reviewed Upscayl Flatpak before migration cleanup' "$repo_dir/site.yml" | grep -Fq 'migrated_upscayl_flatpak.stdout | trim == core_flatpak_remote.name' &&
   grep -A18 -F 'Remove the legacy Upscayl Debian package' "$repo_dir/site.yml" | grep -Fq 'migrated_upscayl_flatpak.stdout | trim == core_flatpak_remote.name' &&
   grep -A16 -F 'Remove the legacy Upscayl Snap' "$repo_dir/site.yml" | grep -Fq 'migrated_upscayl_flatpak.stdout | trim == core_flatpak_remote.name' &&
   grep -A14 -F 'Remove the legacy user-scoped Upscayl Flatpak' "$repo_dir/site.yml" | grep -Fq 'migrated_upscayl_flatpak.stdout | trim == core_flatpak_remote.name' &&
   grep -Fq 'argv: [/usr/bin/snap, list]' "$repo_dir/site.yml" &&
   grep -Fq 'argv: [/usr/bin/flatpak, list, --user, --app, --columns=application]' "$repo_dir/site.yml" &&
   grep -A8 -F 'Require readable legacy package state before migration' "$repo_dir/site.yml" | grep -Fq 'legacy_upscayl_snaps.rc == 0' &&
   grep -A8 -F 'Require readable legacy package state before migration' "$repo_dir/site.yml" | grep -Fq 'legacy_upscayl_user_flatpaks.rc == 0' &&
   grep -A8 -F 'upscayl_ready:' "$repo_dir/verify.yml" | grep -Fq "verified_upscayl_flatpak.stdout | default('') | trim == core_flatpak_remote.name" &&
   grep -A10 -F 'upscayl_legacy_routes_ready:' "$repo_dir/verify.yml" | grep -Fq 'verified_legacy_upscayl_snaps.rc | default(1) == 0' &&
   grep -Fq 'User-owned' "$repo_dir/README.md" &&
   grep -Fq 'AppImage files are left alone' "$repo_dir/README.md"; then
  pass 'Upscayl verifies Flatpak before removing recognized legacy packages'
else
  fail 'Upscayl legacy migration ordering and safety'
fi

if grep -Fq '    - name: Refresh APT metadata for approved applications' "$repo_dir/site.yml" &&
   grep -Fq '        update_cache_retries: 5' "$repo_dir/site.yml" &&
   grep -Fq '        lock_timeout: 300' "$repo_dir/site.yml" &&
   grep -Fq '    - name: Install each approved APT application' "$repo_dir/site.yml" &&
   grep -Fq '        name: "{{ item }}"' "$repo_dir/site.yml" &&
   grep -Fq '      loop: "{{ core_app_packages }}"' "$repo_dir/site.yml" &&
   grep -Fq '      until: approved_app_install is succeeded' "$repo_dir/site.yml" &&
   ! grep -Fq '        name: "{{ core_app_packages }}"' "$repo_dir/site.yml"; then
  pass 'desktop APT apps install independently with bounded retries'
else
  fail 'desktop APT app isolation and retry policy'
fi

if grep -A1 -F 'key: dock-fixed' "$repo_dir/vars.yml" | grep -Fq 'value: "true"'; then
  pass 'Ubuntu Dock stays visible'
else
  fail 'Ubuntu Dock visibility preference'
fi

dock_favorite_manifest="$(awk '
  /^gnome_dock_favorite_candidates:/ { capture=1; next }
  capture && /^[[:alnum:]_]+:/ { exit }
  capture && /desktop_id:/ {
    sub(/^.*desktop_id: /, "")
    sub(/,.*/, "")
    print
  }
' "$repo_dir/vars.yml")"
expected_dock_favorites=$'org.gnome.Nautilus.desktop\ngoogle-chrome.desktop\ndiscord.desktop\n1password.desktop\ncom.anthropic.Claude.desktop\nchatgpt.desktop\nsh.cider.Cider.desktop\norg.telegram.desktop.desktop\ncom.mitchellh.ghostty.desktop\nlibrepods.desktop\ntv.plex.PlexDesktop.desktop\ncode.desktop\npostman_postman.desktop'
if grep -A1 -F 'key: dash-max-icon-size' "$repo_dir/vars.yml" | grep -Fq 'value: "32"' &&
   [[ "$dock_favorite_manifest" == "$expected_dock_favorites" ]] &&
   grep -Fq 'gnome_dock_favorite_candidates:' "$repo_dir/vars.yml" &&
   grep -Fq 'Inspect reviewed Dock launcher candidates' "$repo_dir/site.yml" &&
   grep -Fq 'Build additive GNOME Dock favorites' "$repo_dir/site.yml" &&
   grep -Fq 'Pin installed reviewed applications to the GNOME Dock' "$repo_dir/site.yml" &&
   grep -A10 -F 'Parse current GNOME Dock favorites' "$repo_dir/site.yml" | grep -Fq 'current_gnome_dock_favorites.stdout' &&
   grep -A16 -F 'Build additive GNOME Dock favorites' "$repo_dir/site.yml" | grep -Fq '| unique' &&
   grep -Fq 'Require applied GNOME Dock favorites' "$repo_dir/site.yml" &&
   grep -Fq 'gnome_dock_ready:' "$repo_dir/verify.yml" &&
   grep -A8 -F 'gnome_dock_ready:' "$repo_dir/verify.yml" | grep -Fq '[0:verified_installed_gnome_dock_favorites | length]' &&
   grep -Fq 'GNOME DOCK         ' "$repo_dir/verify.yml" &&
   grep -Fq '          - gnome_dock_ready' "$repo_dir/verify.yml" &&
   grep -Fq '32 px' "$repo_dir/README.md"; then
  pass 'GNOME Dock pins installed reviewed apps additively at the MBP-sized icon setting'
else
  fail 'GNOME Dock favorites and icon-size policy'
fi

if [[ "$(shasum -a 256 "$repo_dir/assets/mrdemonwolf-desktop-wallpaper.png" | awk '{print $1}')" == '1013a6ddaed8fafad60250efbce931c6a2c2d0706264558b542107126dc75840' ]] &&
   [[ "$(shasum -a 256 "$repo_dir/assets/nathanial-henniges-profile-picture.jpg" | awk '{print $1}')" == '1920f8b51754209286ce867c760993ea5e751eb81ebd6d343796dfcfc36ca673' ]] &&
   grep -Fq 'Install and apply reviewed personal desktop images' "$repo_dir/site.yml" &&
   grep -Fq 'file: tasks/desktop_personalization.yml' "$repo_dir/site.yml" &&
   grep -Fq 'picture-uri-dark' "$repo_dir/tasks/desktop_personalization.yml" &&
   grep -Fq 'SetIconFile' "$repo_dir/tasks/desktop_personalization.yml" &&
   grep -Fq 'desktop_images_ready:' "$repo_dir/verify.yml" &&
   grep -Fq 'DESKTOP IMAGES     ' "$repo_dir/verify.yml" &&
   grep -Fq '          - desktop_images_ready' "$repo_dir/verify.yml" &&
   grep -Fq '/org/freedesktop/Accounts/User{{ ansible_facts.user_uid }}' "$repo_dir/tasks/desktop_personalization.yml" &&
   grep -A18 -F 'Set current Ubuntu user profile picture through AccountsService' "$repo_dir/tasks/desktop_personalization.yml" | grep -Fq 'become: true' &&
   grep -A24 -F 'Set current Ubuntu user profile picture through AccountsService' "$repo_dir/tasks/desktop_personalization.yml" | grep -Fq 'not ansible_check_mode'; then
  pass 'reviewed wallpaper and Ubuntu profile picture apply safely'
else
  fail 'desktop image personalization policy'
fi

if grep -Fq 'Install supported Ubuntu machine branding' "$repo_dir/site.yml" &&
   grep -Fq 'file: tasks/desktop_branding.yml' "$repo_dir/site.yml" &&
   grep -Fq "desktop_branding_pretty_hostname: 'Nathanials Air'" "$repo_dir/tasks/desktop_branding.yml" &&
   grep -Fq 'Set the supported pretty device name' "$repo_dir/tasks/desktop_branding.yml" &&
   grep -Fq 'org/gnome/login-screen' "$repo_dir/tasks/desktop_branding.yml" &&
   grep -Fq "logo='/usr/local/share/linux-setup/branding/mrdemonwolf-logo.png'" "$repo_dir/tasks/desktop_branding.yml" &&
   grep -Fq "verified_desktop_branding_values.results[0].stdout | default('') | trim == 'Nathanials Air'" "$repo_dir/verify.yml" &&
   grep -Fq "verified_desktop_branding_values.results[1].stdout | default('') | trim ==" "$repo_dir/verify.yml" &&
   grep -Fq "verified_gdm_branding_key.content | default('') | b64decode | trim ==" "$repo_dir/verify.yml" &&
   grep -Fq 'MACHINE BRANDING   ' "$repo_dir/verify.yml" &&
   grep -Fq '          - desktop_branding_ready' "$repo_dir/verify.yml" &&
   grep -Fq 'sources | base | apps | tools | gnome)' "$setup"; then
  pass 'Ubuntu-supported device name and GDM branding are managed with prompted sudo'
else
  fail 'Ubuntu-supported machine branding policy'
fi

if grep -A5 -F 'Make Ghostty the Ubuntu default terminal' "$repo_dir/site.yml" |
     grep -Fq 'com.mitchellh.ghostty.desktop' &&
   ! grep -Fq "join('\\n')" "$repo_dir/site.yml"; then
  pass 'Ghostty default uses a real newline-delimited terminal entry'
else
  fail 'Ghostty default terminal content'
fi

if grep -A5 -F 'Inspect verified core repository sources' "$repo_dir/verify.yml" |
     grep -Fq 'checksum_algorithm: sha256' &&
   grep -Fq "item.source_content | hash('sha256')" "$repo_dir/verify.yml" &&
   grep -Fq "(claude_repository_opt_out_line ~ '\\n') | hash('sha256')" "$repo_dir/verify.yml" &&
   grep -Fq 'verified_claude_unmanaged_sources.stdout_lines | length == 0' "$repo_dir/verify.yml" &&
   ! grep -Fq 'not (verified_claude_official_source.stat.exists | default(false))' "$repo_dir/verify.yml" &&
   grep -Fq 'core_repository_files_ready: true' "$repo_dir/verify.yml" &&
   grep -Fq 'core_repository_files_ready: false' "$repo_dir/verify.yml" &&
   ! grep -Fq '{{ core_sources_ready and' "$repo_dir/verify.yml"; then
  pass 'core repository verification compares exact SHA-256 bytes'
else
  fail 'core repository byte verification'
fi

scan_files=(
  "$setup"
  "$repo_dir/site.yml"
  "$repo_dir/verify.yml"
  "$repo_dir/vars.yml"
  "$repo_dir/tasks/cleanup_legacy_apt_backups.yml"
  "$repo_dir/tasks/inspect_apt_shadow_dirs.yml"
  "$repo_dir/tasks/remove_apt_shadow.yml"
  "$repo_dir/tasks/cli_tools.yml"
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

tool_command_mappings=(
  '{ package: awscli, command: aws, apt_path: /usr/bin/aws }'
  '{ package: btop, command: btop, apt_path: /usr/bin/btop }'
  '{ package: fastfetch, command: fastfetch, apt_path: /usr/bin/fastfetch }'
  '{ package: httrack, command: httrack, apt_path: /usr/bin/httrack }'
  '{ package: nmap, command: nmap, apt_path: /usr/bin/nmap }'
  '{ package: rclone, command: rclone, apt_path: /usr/bin/rclone }'
  '{ package: smartmontools, command: smartctl, apt_path: /usr/sbin/smartctl }'
  '{ package: yt-dlp, command: yt-dlp, apt_path: /usr/bin/yt-dlp }'
)

tool_command_manifest_ok=true
for mapping in "${tool_command_mappings[@]}"; do
  if ! grep -Fq -- "$mapping" "$repo_dir/vars.yml"; then
    tool_command_manifest_ok=false
  fi
done

if [[ "$tool_command_manifest_ok" == true ]] &&
   grep -Fq 'ansible.builtin.apt:' "$repo_dir/tasks/cli_tools.yml" &&
   grep -Fq 'name: "{{ tool_packages }}"' "$repo_dir/tasks/cli_tools.yml" &&
   grep -Fq 'HOME }}/.local/bin", privileged: false' "$repo_dir/vars.yml" &&
   grep -Fq 'HOME }}/bin", privileged: false' "$repo_dir/vars.yml" &&
   grep -Fq '/usr/local/bin, privileged: true }' "$repo_dir/vars.yml" &&
   grep -Fq -- '- /bin/rm' "$repo_dir/tasks/remove_apt_shadow.yml" &&
   grep -Fq -- '- -f' "$repo_dir/tasks/remove_apt_shadow.yml" &&
   ! grep -Eq '/bin/mv|migration:[[:space:]]*(backup|remove)' "$repo_dir/tasks/cli_tools.yml" "$repo_dir/tasks/remove_apt_shadow.yml" "$repo_dir/vars.yml" &&
   grep -Fq '.pre-linux-setup-apt-*' "$repo_dir/tasks/cleanup_legacy_apt_backups.yml" &&
   grep -Fq 'file_type: any' "$repo_dir/tasks/cleanup_legacy_apt_backups.yml" &&
   grep -Fq 'item.1.isreg | default(false) or item.1.islnk | default(false)' "$repo_dir/tasks/cleanup_legacy_apt_backups.yml" &&
   grep -Fq 'Clean obsolete local backups from the previous migration policy' "$repo_dir/tasks/cli_tools.yml" &&
   grep -Fq 'product(existing_apt_tool_shadow_dirs)' "$repo_dir/tasks/cli_tools.yml" &&
   grep -Fq 'product(existing_apt_tool_shadow_dirs)' "$repo_dir/tasks/cleanup_legacy_apt_backups.yml" &&
   grep -Fq 'existing_apt_tool_shadow_dirs: []' "$repo_dir/tasks/inspect_apt_shadow_dirs.yml" &&
   grep -Fq 'not (item.stat.exists | default(false))' "$repo_dir/tasks/inspect_apt_shadow_dirs.yml" &&
   grep -Fq 'tasks/inspect_apt_shadow_dirs.yml' "$repo_dir/verify.yml" &&
   grep -Fq 'realpath --canonicalize-existing' "$repo_dir/tasks/cli_tools.yml" &&
   grep -Fq '/usr/bin/dpkg-query' "$repo_dir/tasks/cli_tools.yml" &&
   grep -Fq 'apt_tool_path_owners.results' "$repo_dir/tasks/cli_tools.yml" &&
   grep -Fq 'apt_tool_path_files.results' "$repo_dir/tasks/cli_tools.yml" &&
   grep -Fq 'item.stat.executable | default(false)' "$repo_dir/tasks/cli_tools.yml" &&
   grep -Fq 'verified_apt_tool_shadows.results' "$repo_dir/verify.yml" &&
   grep -Fq 'selected_tool_resolution_errors' "$repo_dir/verify.yml" &&
   grep -Fq 'selected_tool_ownership_errors' "$repo_dir/verify.yml" &&
   grep -Fq 'Twitch CLI is unavailable from Ubuntu APT' "$repo_dir/tasks/cli_tools.yml" &&
   grep -Fq 'install_recommends: false' "$repo_dir/tasks/cli_tools.yml" &&
   ! grep -Fq 'state: absent' "$repo_dir/tasks/cli_tools.yml" &&
   ! grep -Eq 'ansible\.builtin\.(get_url|unarchive)|legacy_user_tool_files|rclone_cli|yt_dlp_cli|twitch_cli|aws[[:space:]]+configure|rclone[[:space:]]+config|twitch[[:space:]]+configure' "$repo_dir/tasks/cli_tools.yml" "$repo_dir/verify.yml" "$repo_dir/vars.yml"; then
  pass 'selected CLI tools use Ubuntu APT with explicit local-shadow policies'
else
  fail 'selected CLI APT boundary'
fi

if grep -Fq 'checksum: "sha256:{{ item.key_sha256 }}"' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'Read every primary signing-key fingerprint' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'Preview vendor repository drift' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'content: "{{ item.source_content }}"' "$repo_dir/tasks/vendor_repositories.yml"; then
  pass 'vendor keys and sources require integrity checks'
else
  fail 'vendor key verification gates'
fi

vendor_install_line="$(grep -n -m1 -F 'Install isolated deb822 vendor sources' "$repo_dir/tasks/vendor_repositories.yml" | cut -d: -f1 || true)"
claude_cleanup_line="$(grep -n -m1 -F "Remove Anthropic's exact duplicate Claude source" "$repo_dir/tasks/vendor_repositories.yml" | cut -d: -f1 || true)"
claude_additional_cleanup_line="$(grep -n -m1 -F 'Remove only verified Claude entries from additional APT list files' "$repo_dir/tasks/vendor_repositories.yml" | cut -d: -f1 || true)"
if grep -A20 -F '  - name: claude-desktop' "$repo_dir/vars.yml" | grep -Fq 'key_sha256: bd70a5e4a268002704024ceba7f8446024114e94f3f0bdd11c23a9e592be81c6' &&
   grep -A20 -F '  - name: claude-desktop' "$repo_dir/vars.yml" | grep -Fq '31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE' &&
   grep -A20 -F '  - name: claude-desktop' "$repo_dir/vars.yml" | grep -Fq 'Signed-By: /etc/apt/keyrings/claude-desktop.asc' &&
   grep -Fq 'claude_official_source_path: /etc/apt/sources.list.d/claude-desktop.list' "$repo_dir/vars.yml" &&
   grep -Fq 'claude_repository_opt_out_path: /etc/default/claude-desktop' "$repo_dir/vars.yml" &&
   grep -Fq "Refuse unsafe content in Claude's repository opt-out file" "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'Install Claude package repository opt-out as exact content' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'CLAUDE_DESKTOP_ADD_REPO="false"' "$repo_dir/vars.yml" &&
   grep -Fq 'deb [signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main' "$repo_dir/vars.yml" &&
   grep -Fq 'deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main' "$repo_dir/vars.yml" &&
   grep -Fq 'claude_official_source_file_contents:' "$repo_dir/vars.yml" &&
   grep -Fq '### Managed by the claude-desktop package.' "$repo_dir/vars.yml" &&
   grep -Fq 'in claude_official_source_file_contents' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq "Inspect Anthropic's alternate Claude source" "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq "Refuse an unsafe alternate Claude source path" "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq "Require Anthropic's exact alternate Claude source" "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq "Preview removal of Anthropic's duplicate Claude source" "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'Discover active Claude entries in other APT list files' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'Discover Claude entries in unmanaged deb822 sources' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'Refuse unmanaged Claude deb822 sources' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq "Remove Anthropic's exact duplicate Claude source" "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -Fq 'Remove only verified Claude entries from additional APT list files' "$repo_dir/tasks/vendor_repositories.yml" &&
   grep -A8 -F "Remove Anthropic's exact duplicate Claude source" "$repo_dir/tasks/vendor_repositories.yml" | grep -Fq 'not ansible_check_mode' &&
   [[ -n "$vendor_install_line" && -n "$claude_cleanup_line" && -n "$claude_additional_cleanup_line" ]] &&
   (( claude_cleanup_line > vendor_install_line )) &&
   (( claude_additional_cleanup_line > vendor_install_line )) &&
   grep -Fq 'Require Claude package installation to honor the repository opt-out' "$repo_dir/site.yml" &&
   ! grep -Fq 'verified_claude_official_source' "$repo_dir/verify.yml" &&
   grep -Fq "Inspect Claude's package repository opt-out" "$repo_dir/verify.yml" &&
   grep -Fq 'Detect Claude entries outside the managed APT source' "$repo_dir/verify.yml"; then
  pass 'Claude duplicate Signed-By source is migrated safely'
else
  fail 'Claude duplicate Signed-By migration'
fi

if grep -A3 -F 'librepods:' "$repo_dir/vars.yml" | grep -Fq 'version: linux-v0.1.0' &&
   grep -A3 -F 'librepods:' "$repo_dir/vars.yml" | grep -Fq 'sha256: 0569ba9a15aa58e660ec3ccb4d2d39ffd8800d6a5da3741802aefd86fd4b55a6' &&
   grep -Fq 'releases/download/linux-v0.1.0/librepods-x86_64.AppImage' "$repo_dir/vars.yml" &&
   grep -Fq 'Refuse unsafe LibrePods paths' "$repo_dir/site.yml" &&
   grep -A12 -F 'Install the pinned LibrePods AppImage' "$repo_dir/site.yml" | grep -Fq 'checksum: "sha256:{{ librepods.sha256 }}"' &&
   grep -A12 -F 'Install the pinned LibrePods AppImage' "$repo_dir/site.yml" | grep -Fq 'not ansible_check_mode' &&
   grep -Fq 'librepods_ready:' "$repo_dir/verify.yml" &&
   ! grep -Eiq 'nightly-|DeviceID[[:space:]]*=|/etc/bluetooth/main\.conf|X-GNOME-Autostart-enabled[[:space:]]*=[[:space:]]*true' "$repo_dir/site.yml" "$repo_dir/verify.yml" "$repo_dir/vars.yml"; then
  pass 'LibrePods uses a pinned user-local release without Bluetooth spoofing'
else
  fail 'LibrePods artifact and Bluetooth safety boundary'
fi

if grep -Fq 'not ansible_check_mode' "$repo_dir/site.yml" &&
   grep -A16 -F 'Install missing approved Snap applications' "$repo_dir/site.yml" | grep -Fq 'not ansible_check_mode' &&
   grep -A16 -F 'Install missing approved Snap applications' "$repo_dir/site.yml" | grep -Fq 'become: true' &&
   grep -A16 -F 'Read installed approved Snap applications' "$repo_dir/site.yml" | grep -Fq 'check_mode: false' &&
   grep -A8 -F 'Read installed approved Snap applications' "$repo_dir/site.yml" | grep -Fq -- '- list' &&
   grep -A8 -F 'Install missing approved Snap applications' "$repo_dir/site.yml" | grep -Fq -- '- install' &&
   grep -Fq '"Previewed selected CLI tools only" if ansible_check_mode' "$repo_dir/tasks/cli_tools.yml" &&
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
  if (cd "$repo_dir" &&
      ansible-playbook site.yml --list-tasks --tags dotfiles -e setup_action=dotfiles >/dev/null &&
      ansible-playbook site.yml --list-tasks --tags apps -e setup_action=apps >/dev/null &&
      ansible-playbook site.yml --list-tasks --tags tools -e setup_action=tools >/dev/null &&
      ansible-playbook site.yml --list-tasks --tags boot -e setup_action=boot >/dev/null); then
    pass 'tagged task graph resolves'
  else
    fail 'tagged task graph'
  fi

  shadow_test_root="$(mktemp -d "${TMPDIR:-/tmp}/linux-setup-shadow.XXXXXX")"
  trap 'rm -rf -- "$shadow_test_root"' EXIT

  mkdir -p "$shadow_test_root/remove" "$shadow_test_root/check"
  printf 'old local command\n' > "$shadow_test_root/remove/demo-tool"
  printf 'obsolete backup\n' > "$shadow_test_root/remove/demo-tool.pre-linux-setup-apt-old"
  printf 'old local command\n' > "$shadow_test_root/check/demo-tool"
  printf 'obsolete backup\n' > "$shadow_test_root/check/demo-tool.pre-linux-setup-apt-old"
  chmod 0755 "$shadow_test_root/remove/demo-tool" "$shadow_test_root/remove/demo-tool.pre-linux-setup-apt-old" \
    "$shadow_test_root/check/demo-tool" "$shadow_test_root/check/demo-tool.pre-linux-setup-apt-old"

  if removal_output="$(APT_SHADOW_TEST_DIR="$shadow_test_root/remove" \
       ansible-playbook "$repo_dir/tests/apt_shadow_removal.yml" 2>&1)" &&
     ! grep -Fq 'not a directory' <<< "$removal_output"; then
    pass 'local command shadow and obsolete backup are removed after the APT gate'
  else
    printf '%s\n' "$removal_output" >&2
    fail 'local command shadow removal'
  fi

  if check_output="$(APT_SHADOW_TEST_DIR="$shadow_test_root/check" \
       ansible-playbook --check "$repo_dir/tests/apt_shadow_removal.yml" 2>&1)" &&
     ! grep -Fq 'not a directory' <<< "$check_output"; then
    pass 'check mode leaves local command shadows untouched'
  else
    printf '%s\n' "$check_output" >&2
    fail 'check-mode local shadow safety'
  fi
else
  printf 'SKIP: ansible-playbook is not installed; run ./setup.sh bootstrap on Ubuntu\n'
fi

if [[ "$failures" -ne 0 ]]; then
  printf '%d check(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'All Ansible setup safety checks passed.\n'
