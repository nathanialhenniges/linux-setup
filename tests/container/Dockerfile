FROM archlinux:base-devel

ARG LINUX_SETUP_TEST_RUN_ID=unknown
LABEL org.mrdemonwolf.linux-setup-test.run="$LINUX_SETUP_TEST_RUN_ID"

ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections \
    LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1

RUN pacman -Syu --noconfirm --disable-sandbox --needed \
      ansible-core \
      dbus \
      dconf \
      flatpak \
      git \
      systemd \
    && pacman -Scc --noconfirm \
    && useradd --create-home --uid 1000 --shell /bin/bash setup-test \
    && install -d -o setup-test -g setup-test /workspace \
    && install -d /usr/share/ansible/collections \
    && install -d /usr/share/gnome-shell/extensions/appindicatorsupport@rgcjonas.gmail.com \
    && printf '{"uuid":"appindicatorsupport@rgcjonas.gmail.com","name":"Container test fixture"}\n' \
      > /usr/share/gnome-shell/extensions/appindicatorsupport@rgcjonas.gmail.com/metadata.json \
    && install -d /var/lib/flatpak/exports/share/applications \
    && for desktop_id in \
      org.gnome.Nautilus.desktop \
      google-chrome.desktop \
      com.onepassword.OnePassword.desktop \
      discord.desktop \
      chatgpt.desktop \
      code.desktop \
      com.mitchellh.ghostty.desktop \
      org.telegram.desktop.desktop \
      sh.cider.Cider.desktop; do \
        case "$desktop_id" in \
          org.telegram.desktop.desktop|sh.cider.Cider.desktop) desktop_dir=/var/lib/flatpak/exports/share/applications ;; \
          *) desktop_dir=/usr/share/applications ;; \
        esac; \
        printf '[Desktop Entry]\nName=Container test fixture\nType=Application\nExec=/usr/bin/true\n' \
          > "$desktop_dir/$desktop_id"; \
      done \
    && install -d -o setup-test -g setup-test /home/setup-test/.local/share/applications

COPY requirements.yml /tmp/linux-setup-requirements.yml
RUN ansible-galaxy collection install \
      --requirements-file /tmp/linux-setup-requirements.yml \
      --collections-path /usr/share/ansible/collections \
    && rm /tmp/linux-setup-requirements.yml

COPY tests/container/gnome-test.gschema.xml /tmp/gnome-test.gschema.xml
RUN install -d /opt/linux-setup-test/schemas \
    && cp /tmp/gnome-test.gschema.xml /opt/linux-setup-test/schemas/ \
    && glib-compile-schemas /opt/linux-setup-test/schemas \
    && rm /tmp/gnome-test.gschema.xml

COPY tests/container/run-inside.sh /usr/local/bin/linux-setup-container-tests
RUN chmod 0755 /usr/local/bin/linux-setup-container-tests

WORKDIR /workspace
USER setup-test
ENTRYPOINT ["/usr/local/bin/linux-setup-container-tests"]
