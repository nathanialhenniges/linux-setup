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
- Keep Toshy in the explicit interactive `keybinds` action: pin and verify Toshy plus xwaykeyz, require a live GNOME session and the Wayland focus extension, refuse competing global keymappers, and verify its user services. Toshy's full default config is the macOS mapping source of truth; do not duplicate it in Ghostty, Ansible, or dotfiles. Never run its installer through Ansible or as root.
- Keep the selected CLI utilities in the explicit `tools` action and install all of them from Ubuntu APT. Skip absent local command directories without warnings; refuse an existing path that is not a real directory. Only after APT ownership and executable health pass, remove exact matching command shadows and obsolete `.pre-linux-setup-apt-*` backups from `~/.local/bin`, `~/bin`, and `/usr/local/bin`. Refuse directories, then verify each command resolves to its canonical APT path. Do not run another package manager's uninstall command. Twitch CLI is unavailable in Ubuntu 26.04, so do not install it automatically or add a non-APT exception. Never configure AWS, rclone, scans, mirrors, credentials, or tokens.
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
