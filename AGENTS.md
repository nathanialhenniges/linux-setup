# AGENTS.md

## Scope

This repository bootstraps an Ubuntu 26.04 AMD64 **desktop workstation**. Keep it small, auditable, idempotent, and safe for a public repository.

## Frozen boundary

Never configure or invoke server/devbox behavior. Do not add `openssh-server`, Docker, tunnel creation, credentials, SSH keys, Git identity, or calls into dotfiles `server.sh`, `server-dev.sh`, `install.sh`, `config/server/**`, or `config/agent/**`.

Dotfiles may flow one way only: `linux-setup` may clone/update the expected repository and run its dedicated `linux-desktop.sh`. Fail closed if that file, origin, or clean checkout check fails.

After that dedicated desktop profile succeeds, `linux-setup` may make the packaged `/usr/bin/zsh` the current desktop user's login shell. Validate it against `/etc/shells`; never change root's shell or global shell configuration.

## Package rules

- Prefer Ubuntu packages.
- Keep Postman as the exact `postman` Snap documented by Postman and published by its verified Snap Store account. Read local Snap state before installation; do not add other Snaps without an explicit reviewed decision.
- Keep Flatpak to the reviewed system `flathub` remote and the exact application IDs in `core_flatpak_packages`. Read the configured remotes first and refuse a `flathub` name that points anywhere but Flathub's own repository; never add a second remote, a user-scope remote, or an unverified publisher. Upscayl is the reviewed entry: Flathub verifies `org.upscayl.Upscayl` against `upscayl.org`, which its Snap Store publisher does not match, so it is installed as a Flatpak and not a Snap. Install Ubuntu's Mesa Vulkan runtime and diagnostic tool, keep the Intel HD 6000 launch test manual, and never add Upscayl to a server/devbox path.
- When an approved install route replaces an older package-manager route, verify the replacement and its exact trusted origin first, then remove only the recognized old package. Legacy-state queries fail closed, and check mode previews the migration. Never delete arbitrary user files or unknown binaries.
- For vendor APT repos, use deb822 `.sources`, isolated `/etc/apt/keyrings` files, `Signed-By`, and a full documented fingerprint check. For Claude, scan `/etc/apt/sources.list`, `.list`, and `.sources` files without invoking APT. Accept only Anthropic's two exact official `.list` lines, install the verified managed source first, then remove only those verified lines while preserving every unrelated line. Refuse unmanaged deb822, unsafe, or customized content and leave the unused public keyring alone.
- Keep Anthropic's documented `/etc/default/claude-desktop` repository opt-out as exact root-owned `0644` content before package installation; setup must read it only as data and never preserve extra text because the package sources this file as root. Fail if the package recreates its `.list`. Keep the dedicated `sources` action free of APT refreshes and package installs. Bootstrap must invoke it before `apt-get update` whenever any Claude source exists outside the managed source, even when the managed source is absent.
- Keep source-only fact gathering restricted; it must not run local facts, Facter, Ohai, or APT-backed package facts. A conflicted `--dry-run all` must preview `sources` and stop before the first APT-backed action. The Docker E2E harness may use Docker on the developer machine, but no workstation action may install or configure Docker.
- Never use `apt-key`, `trusted=yes`, PPAs, or `curl | sh`.
- Pin non-APT artifacts to immutable upstream releases, verify reviewed SHA-256 values before installation, and keep them user-local when possible.
- Keep LibrePods on an immutable official x86-64 AppImage release with its published SHA-256 and a user-local launcher. Do not automate temporary nightly artifacts, autostart, Bluetooth VendorID spoofing, `/etc/bluetooth/main.conf`, or audio-service restarts; pair and launch it manually before considering those optional changes.
- Keep account authentication and Cloudflare enrollment manual.
- Use local `ansible-core` playbooks with builtin modules and task-level `become`; never add remote inventory or host management.
- Keep Toshy in the explicit interactive `keybinds` action: pin and verify Toshy plus xwaykeyz, require a live GNOME session and the Wayland focus extension, refuse competing global keymappers, and verify its user services. Toshy's full default config is the macOS mapping source of truth; do not duplicate it in Ghostty, Ansible, or dotfiles. Never run its installer through Ansible or as root.
- Keep the selected CLI utilities in the explicit `tools` action and install all of them from Ubuntu APT. Skip absent local command directories without warnings; refuse an existing path that is not a real directory. Only after APT ownership and executable health pass, remove exact matching command shadows and obsolete `.pre-linux-setup-apt-*` backups from `~/.local/bin`, `~/bin`, and `/usr/local/bin`. Refuse directories, then verify each command resolves to its canonical APT path. Do not run another package manager's uninstall command. Twitch CLI is unavailable in Ubuntu 26.04, so do not install it automatically or add a non-APT exception. Never configure AWS, rclone, scans, mirrors, credentials, or tokens.
- Scope Ansible privilege escalation to `/usr/bin/sudo.ws` on Ubuntu 26.04; never switch the system-wide `sudo` alternative, store a password, or add `NOPASSWD` to a workstation. The isolated disposable Docker test user may use `NOPASSWD` because emulated x86 PTYs are unavailable under Colima.
- Keep every mutating Ansible action explicitly tagged and selected through `setup.sh`. The wrapper-only `all` command may sequence only the reviewed leaf actions in their documented order, propagate `--dry-run`, stop on the first failure, and never create an Ansible `all` tag or bypass a leaf action's guards.
- Keep `--dry-run` free of sudo, network, and managed-state writes. Ansible's ignored local temporary directory is the only allowed side effect.
- Keep `THIRD-PARTY-NOTICES.md` synchronized with every pinned download, upstream-source install, and license reference. Describe immutable pins as reviewed, never as the upstream "latest" release.

## Checks

Run before every commit:

```bash
./tests/test_setup.sh
git diff --check
```

The tests must cover playbook syntax, the localhost lock, explicit action selection, check-mode mutation gates, vendor checksum/fingerprint gates, third-party notice coverage, and the dedicated dotfiles entry point.
Run `./tests/test_apt_source_recovery_docker.sh` whenever Claude/APT preflight behavior changes.

Review every tracked file for secrets and absolute personal paths before the first public push.
