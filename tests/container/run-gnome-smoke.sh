#!/usr/bin/env bash
set -euo pipefail

existing_path=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/keep-existing/
terminal_path=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/linux-setup-terminal/

gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$existing_path']"
gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$existing_path" name "'Keep existing shortcut'"
gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$existing_path" command "'true'"
gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$existing_path" binding "'<Super><Alt>e'"

# The package is represented by an isolated launcher fixture, so the supported
# setup.sh action skips yay and runs its real GNOME Ansible tasks only.
stub_dir="$(mktemp -d)"
trap 'rm -rf -- "$stub_dir"' EXIT
cat > "$stub_dir/pacman" <<'PACMAN'
#!/usr/bin/env bash
if [[ "${1:-}" == -Qq && "${2:-}" == gnome-shell-extension-dash-to-dock ]]; then
  exit 0
fi
exec /usr/bin/pacman "$@"
PACMAN
chmod 0755 "$stub_dir/pacman"
export PATH="$stub_dir:$PATH"

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/linux-setup-notion.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Notion test fixture
Type=Application
Exec=/usr/bin/true
DESKTOP

./setup.sh --accept-target-warning gnome-dock

registered_paths="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"
[[ "$registered_paths" == *"$existing_path"* ]]
[[ "$registered_paths" == *"$terminal_path"* ]]
[[ "$(gsettings get "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$existing_path" name)" == "'Keep existing shortcut'" ]]
[[ "$(gsettings get "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$terminal_path" name)" == "'Open Terminal'" ]]
[[ "$(gsettings get "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$terminal_path" command)" == "'ghostty'" ]]
[[ "$(gsettings get "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$terminal_path" binding)" == "'<Super>Return'" ]]
favorites="$(gsettings get org.gnome.shell favorite-apps)"
[[ "$favorites" == *com.onepassword.OnePassword.desktop* ]]

second_run="$(./setup.sh --accept-target-warning gnome-dock 2>&1)"
printf '%s\n' "$second_run"
grep -Eq 'changed=0.*failed=0|failed=0.*changed=0' <<<"$second_run"

printf '%s\n' 'GNOME custom shortcut was preserved, Open Terminal was configured, 1Password was available to pin, and the second run made no changes.'
