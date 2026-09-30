# Repository instructions

## Scope

Configure an EndeavourOS or Arch Linux GNOME workstation on x86-64, specifically the 2015 MacBook Air `MacBookAir7,2`. Keep the repository small, local-only, auditable, idempotent, and safe for public use.

## Safety boundary

- `setup.sh` is the only supported entry point. Ansible inventory stays locked to `localhost` in the `workstation` group.
- Never install or configure Docker, an SSH server, tunnels, credentials, SSH keys, Git identity, or server/devbox tooling.
- `openssh` is installed only to provide the `ssh` client for VS Code Remote SSH. Never enable, start, configure, or otherwise manage `sshd`.
- Dotfiles flow one way only: clone/update the expected repository, require a clean checkout and exact origin, then run only its `linux-desktop.sh` entry point. After that profile succeeds, `setup.sh` may make `/usr/bin/zsh` the current non-root desktop user's login shell if it is listed in `/etc/shells`.
- Keep account sign-ins, Google OAuth, Cloudflare enrollment, AirPods pairing, and LibrePods pairing manual. Never copy browser profiles, OAuth tokens, SSH keys, or application data.
- Keep `--dry-run` free of sudo, network, and managed-state writes. It prints the reviewed plan only.

## Platform and package rules

- The intended target is EndeavourOS or Arch Linux on x86-64 MacBookAir7,2. Before changing anything, check the OS identity and firmware model. If either value is missing or different, show what was detected and ask the user to accept the warning: the interactive prompt requires `CONTINUE`, while `--accept-target-warning` is the explicit choice for non-interactive runs. Never let this choice bypass the non-root, x86-64, pacman, or SSH safety checks. Apply GNOME session preferences only from the user's active GNOME session.
- Prefer pacman packages. Use the installed EndeavourOS `yay` helper interactively for only the reviewed AUR packages in `setup.sh`; do not pass `--noconfirm` or install an AUR helper automatically.
- Keep Flatpak system-scoped and use only the exact IDs in `vars.yml`. Before adding or using `flathub`, verify its URL is exactly Flathub's system repository. Verify each installed app reports origin `flathub`.
- Keep the default `linux` kernel headers installed before interactively building the reviewed `facetimehd-dkms` driver. The paired AUR firmware package uses Apple's camera firmware; disclose its `LicenseRef-Apple` terms. If the selected kernel changes, install matching headers before rebuilding DKMS.
- Keep Google Drive browser-only at `https://drive.google.com/`; sign in manually. Do not add a sync client, file-manager plugin, or store OAuth data in this repository.
- Keep LibrePods on the reviewed immutable x86-64 AppImage with its SHA-256 and user-local launcher. Do not add autostart, Bluetooth VendorID spoofing, Bluetooth configuration edits, or audio-service restarts.
- Install ChatGPT from OpenAI’s signed Arch repository. Remove the retired Chrome launcher only if it matches the template maintained here.
- Keep the reviewed wallpaper and profile photo checksum-pinned in `assets/`, copied only into the workstation user's `~/Pictures`. Apply the wallpaper through GNOME's user settings. Do not change distribution branding or firmware artwork.
- Keep GDM enabled and configure GNOME as the normal session. Use the reviewed Dash to Dock extension and pin only app launchers that exist. The optional `remove-hyprland` action may uninstall only the explicit legacy package list, must let pacman show and confirm dependency removals, and must leave personal configuration files untouched.
- Do not add TLP alongside `power-profiles-daemon`.
- Keep each Ansible mutation in a focused task selected by an explicit `setup.sh` action. `all` is wrapper-only, runs reviewed leaf actions in order, and stops on first failure. Never create an Ansible `all` tag.
- Keep `THIRD-PARTY-NOTICES.md` synchronized with package sources, AUR packages, checksummed artifacts, and license references. Call immutable pins reviewed pins, not upstream latest.

## Checks

Run `./tests/test_setup.sh` and `git diff --check` before commits. Keep validation local.
