# AGENTS.md

## Scope

This repository bootstraps an Ubuntu 26.04 AMD64 **desktop workstation**. Keep it small, auditable, idempotent, and safe for a public repository.

## Frozen boundary

Never configure or invoke server/devbox behavior. Do not add `openssh-server`, Docker, tunnel creation, credentials, SSH keys, Git identity, or calls into dotfiles `server.sh`, `server-dev.sh`, `install.sh`, `config/server/**`, or `config/agent/**`.

Dotfiles may flow one way only: `linux-setup` may clone/update the expected repository and run its dedicated `linux-desktop.sh`. Fail closed if that file, origin, or clean checkout check fails.

After that dedicated desktop profile succeeds, `linux-setup` may make the packaged `/usr/bin/zsh` the current desktop user's login shell. Validate it against `/etc/shells`; never change root's shell or global shell configuration.

## Package rules

- Prefer Ubuntu packages.
- For vendor APT repos, use deb822 `.sources`, isolated `/etc/apt/keyrings` files, `Signed-By`, and a full documented fingerprint check.
- Never use `apt-key`, `trusted=yes`, PPAs, or `curl | sh`.
- Pin non-APT artifacts to immutable upstream releases, verify reviewed SHA-256 values before installation, and keep them user-local when possible.
- Keep account authentication and Cloudflare enrollment manual.
- Use local `ansible-core` playbooks with builtin modules and task-level `become`; never add remote inventory or host management.
- Keep Toshy in the explicit interactive `keybinds` action: pin and verify Toshy plus xwaykeyz, require the GNOME Wayland focus extension, and never run its installer through Ansible or as root.
- Keep the selected CLI utilities in the explicit `tools` action. Use Ubuntu APT for the stable package set; pin, checksum, and install rclone, yt-dlp, and Twitch CLI user-locally. Never configure AWS, rclone, Twitch, scans, mirrors, credentials, or tokens.
- Scope Ansible privilege escalation to `/usr/bin/sudo.ws` on Ubuntu 26.04; never switch the system-wide `sudo` alternative, store a password, or add `NOPASSWD`.
- Keep every mutating action explicitly tagged and selected through `setup.sh`; never add a catch-all action.
- Keep `--dry-run` free of sudo, network, and managed-state writes. Ansible's ignored local temporary directory is the only allowed side effect.

## Checks

Run before every commit:

```bash
./tests/test_setup.sh
git diff --check
```

The tests must cover playbook syntax, the localhost lock, explicit action selection, check-mode mutation gates, vendor checksum/fingerprint gates, and the dedicated dotfiles entry point.

Review every tracked file for secrets and absolute personal paths before the first public push.
