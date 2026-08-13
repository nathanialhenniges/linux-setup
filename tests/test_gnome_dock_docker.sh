#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
container="$(docker create --env QEMU_CPU=max --platform linux/amd64 --interactive ubuntu:26.04 bash -s)"
cleanup() {
  docker rm --force "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker cp "$repo_dir/assets/boot-branding/mrdemonwolf-logo.png" \
  "$container:/tmp/mrdemonwolf-logo.png"
docker cp "$repo_dir/templates/chrome-web-app.desktop.j2" \
  "$container:/tmp/chrome-web-app.desktop.j2"

docker start --attach --interactive "$container" <<'CONTAINER'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
show_failure() {
  status=$?
  for log in /tmp/apt.log; do
    if [[ -f "$log" ]]; then
      printf '\n--- %s ---\n' "$log" >&2
      tail -n 80 "$log" >&2
    fi
  done
  exit "$status"
}
trap show_failure ERR

apt-get update >/tmp/apt.log
apt-get install --yes --no-install-recommends \
  dbus-daemon dconf-cli dconf-service desktop-file-utils libglib2.0-bin \
  >>/tmp/apt.log

while IFS='|' read -r name id url icon categories; do
  sed \
    -e "s#{{ chrome_web_app.name }}#$name#g" \
    -e "s#{{ chrome_web_app.wm_class }}#$id#g" \
    -e "s#{{ chrome_web_app.url }}#$url#g" \
    -e "s#{{ chrome_web_app.icon }}#$icon#g" \
    -e "s#{{ chrome_web_app.categories }}#$categories#g" \
    /tmp/chrome-web-app.desktop.j2 >"/tmp/$id.desktop"
  desktop-file-validate "/tmp/$id.desktop"
done <<'WEB_APPS'
Google Docs|linux-setup-google-docs|https://docs.google.com/document/|x-office-document|Office;
Google Drive|linux-setup-google-drive|https://drive.google.com/|folder-remote|Office;
Google Sheets|linux-setup-google-sheets|https://docs.google.com/spreadsheets/|x-office-spreadsheet|Office;
Google Slides|linux-setup-google-slides|https://docs.google.com/presentation/|x-office-presentation|Office;
Notion|linux-setup-notion|https://www.notion.so/|accessories-text-editor|Office;
Quo|linux-setup-quo|https://my.quo.com/|call-start|Network;
WEB_APPS

cd /tmp
apt-get download gnome-shell-common gnome-shell-ubuntu-extensions libgdm1 >/dev/null
mkdir schemas
dpkg-deb --fsys-tarfile gnome-shell-common_*.deb |
  tar -xOf - ./usr/share/glib-2.0/schemas/org.gnome.shell.gschema.xml \
  >schemas/org.gnome.shell.gschema.xml
dpkg-deb --fsys-tarfile gnome-shell-ubuntu-extensions_*.deb |
  tar -xOf - ./usr/share/glib-2.0/schemas/org.gnome.shell.extensions.dash-to-dock.gschema.xml \
  >schemas/org.gnome.shell.extensions.dash-to-dock.gschema.xml
dpkg-deb --fsys-tarfile libgdm1_*.deb |
  tar -xOf - ./usr/share/glib-2.0/schemas/org.gnome.login-screen.gschema.xml \
  >schemas/org.gnome.login-screen.gschema.xml
glib-compile-schemas schemas

install -d /etc/dconf/profile /etc/dconf/db/gdm.d /usr/local/share/linux-setup/branding \
  /usr/share/gdm /tmp/greeter-defaults.d
dconf compile /usr/share/gdm/greeter-dconf-defaults /tmp/greeter-defaults.d
install -m 0644 /tmp/mrdemonwolf-logo.png \
  /usr/local/share/linux-setup/branding/mrdemonwolf-logo.png
printf '%s\n' \
  'user-db:user' \
  'system-db:gdm' \
  'file-db:/usr/share/gdm/greeter-dconf-defaults' \
  >/etc/dconf/profile/gdm
printf '%s\n' \
  '# Managed by nathanialhenniges/linux-setup.' \
  '[org/gnome/login-screen]' \
  "logo='/usr/local/share/linux-setup/branding/mrdemonwolf-logo.png'" \
  'banner-message-enable=true' \
  "banner-message-text='Managed by MrDemonWolf, Inc.'" \
  >/etc/dconf/db/gdm.d/01-linux-setup-branding
dconf update
test "$(sha256sum /usr/local/share/linux-setup/branding/mrdemonwolf-logo.png | awk '{print $1}')" = \
  860899736ae436938660c24cf1b58a477286afd15d3d6dc4ec8d40b85131b406

env HOME=/tmp GSETTINGS_SCHEMA_DIR=/tmp/schemas dbus-run-session -- bash -s <<'SESSION'
set -Eeuo pipefail
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32
test "$(gsettings get org.gnome.shell.extensions.dash-to-dock dash-max-icon-size)" = 32
gsettings set org.gnome.shell favorite-apps \
  "['org.gnome.Nautilus.desktop', 'google-chrome.desktop', 'org.telegram.desktop.desktop', 'discord.desktop', 'linux-setup-notion.desktop', 'com.anthropic.Claude.desktop', 'chatgpt.desktop', 'sh.cider.Cider.desktop', 'com.mitchellh.ghostty.desktop', 'librepods.desktop', 'tv.plex.PlexDesktop.desktop', 'code.desktop', 'postman_postman.desktop', 'linux-setup-google-docs.desktop', 'linux-setup-google-drive.desktop', 'linux-setup-google-sheets.desktop', 'linux-setup-google-slides.desktop', 'linux-setup-quo.desktop', 'existing.desktop']"
test "$(gsettings get org.gnome.shell favorite-apps)" = \
  "['org.gnome.Nautilus.desktop', 'google-chrome.desktop', 'org.telegram.desktop.desktop', 'discord.desktop', 'linux-setup-notion.desktop', 'com.anthropic.Claude.desktop', 'chatgpt.desktop', 'sh.cider.Cider.desktop', 'com.mitchellh.ghostty.desktop', 'librepods.desktop', 'tv.plex.PlexDesktop.desktop', 'code.desktop', 'postman_postman.desktop', 'linux-setup-google-docs.desktop', 'linux-setup-google-drive.desktop', 'linux-setup-google-sheets.desktop', 'linux-setup-google-slides.desktop', 'linux-setup-quo.desktop', 'existing.desktop']"
test "$(DCONF_PROFILE=/etc/dconf/profile/gdm dconf read /org/gnome/login-screen/logo)" = \
  "'/usr/local/share/linux-setup/branding/mrdemonwolf-logo.png'"
test "$(DCONF_PROFILE=/etc/dconf/profile/gdm dconf read /org/gnome/login-screen/banner-message-enable)" = true
test "$(DCONF_PROFILE=/etc/dconf/profile/gdm dconf read /org/gnome/login-screen/banner-message-text)" = \
  "'Managed by MrDemonWolf, Inc.'"
SESSION

printf '%s\n' 'PASS: Ubuntu 26.04 AMD64 validates Chrome launchers, Dock settings, GDM logo, and enterprise banner'
CONTAINER
