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

docker start --attach --interactive "$container" <<'CONTAINER'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update >/tmp/apt.log
apt-get install --yes --no-install-recommends \
  dbus-daemon dconf-cli dconf-service libglib2.0-bin >>/tmp/apt.log

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
  >/etc/dconf/db/gdm.d/01-linux-setup-branding
dconf update
test "$(sha256sum /usr/local/share/linux-setup/branding/mrdemonwolf-logo.png | awk '{print $1}')" = \
  860899736ae436938660c24cf1b58a477286afd15d3d6dc4ec8d40b85131b406

env HOME=/tmp GSETTINGS_SCHEMA_DIR=/tmp/schemas dbus-run-session -- bash -s <<'SESSION'
set -Eeuo pipefail
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32
test "$(gsettings get org.gnome.shell.extensions.dash-to-dock dash-max-icon-size)" = 32
gsettings set org.gnome.shell favorite-apps \
  "['org.gnome.Nautilus.desktop', 'sh.cider.Cider.desktop', 'existing.desktop']"
test "$(gsettings get org.gnome.shell favorite-apps)" = \
  "['org.gnome.Nautilus.desktop', 'sh.cider.Cider.desktop', 'existing.desktop']"
test "$(DCONF_PROFILE=/etc/dconf/profile/gdm dconf read /org/gnome/login-screen/logo)" = \
  "'/usr/local/share/linux-setup/branding/mrdemonwolf-logo.png'"
SESSION

printf '%s\n' 'PASS: Ubuntu 26.04 AMD64 stores Dock settings and the supported GDM logo'
CONTAINER
