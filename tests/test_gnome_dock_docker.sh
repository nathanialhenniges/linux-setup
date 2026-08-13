#!/usr/bin/env bash
set -Eeuo pipefail

docker run --rm --env QEMU_CPU=max --platform linux/amd64 --interactive ubuntu:26.04 bash -s <<'CONTAINER'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update >/tmp/apt.log
apt-get install --yes --no-install-recommends \
  dbus-daemon dconf-service libglib2.0-bin >>/tmp/apt.log

cd /tmp
apt-get download gnome-shell-common gnome-shell-ubuntu-extensions >/dev/null
mkdir schemas
dpkg-deb --fsys-tarfile gnome-shell-common_*.deb |
  tar -xOf - ./usr/share/glib-2.0/schemas/org.gnome.shell.gschema.xml \
  >schemas/org.gnome.shell.gschema.xml
dpkg-deb --fsys-tarfile gnome-shell-ubuntu-extensions_*.deb |
  tar -xOf - ./usr/share/glib-2.0/schemas/org.gnome.shell.extensions.dash-to-dock.gschema.xml \
  >schemas/org.gnome.shell.extensions.dash-to-dock.gschema.xml
glib-compile-schemas schemas

useradd --create-home tester
runuser -u tester -- env GSETTINGS_SCHEMA_DIR=/tmp/schemas dbus-run-session -- bash -s <<'SESSION'
set -Eeuo pipefail
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32
test "$(gsettings get org.gnome.shell.extensions.dash-to-dock dash-max-icon-size)" = 32
gsettings set org.gnome.shell favorite-apps \
  "['org.gnome.Nautilus.desktop', 'sh.cider.Cider.desktop', 'existing.desktop']"
test "$(gsettings get org.gnome.shell favorite-apps)" = \
  "['org.gnome.Nautilus.desktop', 'sh.cider.Cider.desktop', 'existing.desktop']"
SESSION

printf '%s\n' 'PASS: Ubuntu 26.04 AMD64 stores 32px Dock size and ordered additive favorites'
CONTAINER
