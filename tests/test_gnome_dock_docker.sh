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
docker cp "$repo_dir/vars.yml" "$container:/tmp/vars.yml"

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
  ca-certificates curl dbus-daemon dconf-cli dconf-service desktop-file-utils fuse3 \
  libglib2.0-bin rclone systemd \
  >>/tmp/apt.log

awk '
  /^google_drive_service_content: \|$/ { capture=1; next }
  capture && /^[^ ]/ { exit }
  capture { sub(/^  /, ""); print }
' /tmp/vars.yml >/tmp/linux-setup-google-drive.service
systemd-analyze verify /tmp/linux-setup-google-drive.service
grep -Fq -- '--vfs-cache-mode=writes' /tmp/linux-setup-google-drive.service
grep -Fq 'ExecStop=/usr/bin/fusermount3' /tmp/linux-setup-google-drive.service

install -d /tmp/.local/share/icons
while IFS='|' read -r name id url icon_file icon_url icon_sha256 categories; do
  curl --fail --location --silent --show-error \
    --output "/tmp/.local/share/icons/$icon_file" "$icon_url"
  test "$(sha256sum "/tmp/.local/share/icons/$icon_file" | awk '{print $1}')" = "$icon_sha256"
  sed \
    -e "s#{{ chrome_web_app.name }}#$name#g" \
    -e "s#{{ chrome_web_app.wm_class }}#$id#g" \
    -e "s#{{ chrome_web_app.url }}#$url#g" \
    -e "s#{{ workstation_home }}#/tmp#g" \
    -e "s#{{ chrome_web_app.icon_file }}#$icon_file#g" \
    -e "s#{{ chrome_web_app.categories }}#$categories#g" \
    /tmp/chrome-web-app.desktop.j2 >"/tmp/$id.desktop"
  desktop-file-validate "/tmp/$id.desktop"
done <<'WEB_APPS'
Google Docs|linux-setup-google-docs|https://docs.google.com/document/|linux-setup-google-docs.ico|https://docs.google.com/favicon.ico|16640c06f6249fdafd7828fd8425753abc360864dfd88f66704a32c38943c805|Office;
Google Sheets|linux-setup-google-sheets|https://docs.google.com/spreadsheets/|linux-setup-google-sheets.ico|https://ssl.gstatic.com/docs/spreadsheets/favicon3.ico|b4407478dcd25903b7e3719cbd1a3ff42e1f51ae74d690be7a7af11e1964ef57|Office;
Google Slides|linux-setup-google-slides|https://docs.google.com/presentation/|linux-setup-google-slides.ico|https://ssl.gstatic.com/docs/presentations/images/favicon5.ico|f6458a567e44809e5e02a8585183c693be0c092aea8b7359669e56b761dcb820|Office;
Notion|linux-setup-notion|https://www.notion.so/|linux-setup-notion.ico|https://www.notion.so/front-static/favicon.ico|541fc85f92e348bcf46f70944b95fd558d16adbc5a0698eaa1239dccd8c9e455|Office;
Quo|linux-setup-quo|https://my.quo.com/|linux-setup-quo.png|https://my.quo.com/assets/icons/192x192.png|a79a03300b8080dcff87cb65a398b4353560497f214a4257c0469cdee121f2a4|Network;
WEB_APPS
test ! -e /tmp/linux-setup-google-drive.desktop

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
  "['org.gnome.Nautilus.desktop', 'google-chrome.desktop', 'discord.desktop', 'linux-setup-notion.desktop', 'com.anthropic.Claude.desktop', 'chatgpt.desktop', 'sh.cider.Cider.desktop', 'com.mitchellh.ghostty.desktop', 'code.desktop', 'postman_postman.desktop', 'existing.desktop']"
test "$(gsettings get org.gnome.shell favorite-apps)" = \
  "['org.gnome.Nautilus.desktop', 'google-chrome.desktop', 'discord.desktop', 'linux-setup-notion.desktop', 'com.anthropic.Claude.desktop', 'chatgpt.desktop', 'sh.cider.Cider.desktop', 'com.mitchellh.ghostty.desktop', 'code.desktop', 'postman_postman.desktop', 'existing.desktop']"
test "$(DCONF_PROFILE=/etc/dconf/profile/gdm dconf read /org/gnome/login-screen/logo)" = \
  "'/usr/local/share/linux-setup/branding/mrdemonwolf-logo.png'"
test "$(DCONF_PROFILE=/etc/dconf/profile/gdm dconf read /org/gnome/login-screen/banner-message-enable)" = true
test "$(DCONF_PROFILE=/etc/dconf/profile/gdm dconf read /org/gnome/login-screen/banner-message-text)" = \
  "'Managed by MrDemonWolf, Inc.'"
SESSION

printf '%s\n' 'PASS: Ubuntu 26.04 AMD64 validates the rclone unit, official web icons, Chrome launchers, Dock settings, GDM logo, and enterprise banner'
CONTAINER
