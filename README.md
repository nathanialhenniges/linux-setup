# Ubuntu desktop setup

A small, repeatable bootstrap for an Intel MacBook Air running **Ubuntu Desktop 26.04 LTS (AMD64)**.

> [!IMPORTANT]
> This is a **desktop workstation** setup. It never configures a server or devbox and never invokes the dotfiles `server.sh`, `server-dev.sh`, `install.sh`, `config/server/**`, or `config/agent/**` paths.

## Fast path: do the whole setup

On an already-bootstrapped MBA, preview everything and then run it:

```bash
./setup.sh --dry-run all
./setup.sh all
```

The real run bootstraps Ansible, then runs `base`, `apps`, `tools`, `terminal`, `dotfiles`, `gnome`, and `keybinds` in that order. It stops on the first failure and finishes with strict `verify`. Keybinds stays last because it is interactive and may ask for a reboot.

The preview skips bootstrap so it never uses the network or `sudo`, previews all seven workstation actions, and finishes with the non-strict status board. If it finds a Claude entry outside the managed deb822 source, it previews the guarded source check and stops before APT-backed checks; run `./setup.sh sources`, then preview again. Run `./setup.sh bootstrap` first if Ansible is not installed yet.

## One box at a time: focused repair

- [ ] 1. Install the small Ansible runtime: `./setup.sh bootstrap`
- [ ] 2. See what is already ready: `./setup.sh status`
- [ ] 3. Preview/install the base: `./setup.sh --dry-run base`, then `./setup.sh base`
- [ ] 4. Preview/install the approved desktop apps: `./setup.sh --dry-run apps`, then `./setup.sh apps`
- [ ] 5. Preview/install the eight selected Ubuntu APT tools: `./setup.sh --dry-run tools`, then `./setup.sh tools`
- [ ] 6. After Ghostty launch-tests successfully: `./setup.sh terminal`
- [ ] 7. Show the reviewed Codex CLI route: `./setup.sh codex`, then follow the official page
- [ ] 8. Apply desktop-only dotfiles and make Zsh the login shell: `./setup.sh --dry-run dotfiles`, then `./setup.sh dotfiles`
- [ ] 9. Apply the GNOME look and always-visible bottom dock: `./setup.sh --dry-run gnome`, then `./setup.sh gnome`
- [ ] 10. Set up Mac mode: enable Focused Window D-Bus, run `./setup.sh --dry-run keybinds` and `./setup.sh keybinds`, reboot only if Toshy says so, then rerun `keybinds`
- [ ] 11. Confirm the core workstation: `./setup.sh verify`
- [ ] 12. Manually add Discord's official `.deb` and the Plex Chrome app

## If you only see VS Code and Ghostty

That was the complete result of the early `apps` action: GitHub CLI has no launcher, so it produced only those two visible apps. Pull the expanded manifest and rerun the same action:

```bash
cd ~/linux-setup
git switch main
git pull --ff-only
./setup.sh --dry-run apps
./setup.sh apps
```

The updated action adds Extension Manager, Claude Desktop, Cloudflare WARP, OBS Studio, Postman, Upscayl, and LibrePods. Launch Extension Manager with `extension-manager` if GNOME's app grid has not refreshed yet.

Upscayl needs a working Vulkan driver. The `apps` action installs Ubuntu's Mesa Vulkan driver and `vulkaninfo`; run `vulkaninfo --summary` before expecting it to upscale anything.

Discord remains a manual official `.deb` because its download URL changes without a stable published checksum. Plex remains a manual Chrome site app. The action prints both steps when it finishes.

Stop after any failed box. Do not keep stacking fixes.

Real actions validate your Ubuntu login password with `/usr/bin/sudo.ws` before Ansible needs administrator access, so a mistype gets the native retry prompt instead of stopping the playbook. Ubuntu 26.04 defaults to `sudo-rs`, whose different prompt is not handled by the packaged Ansible release, so this repo scopes Ansible to Ubuntu's supported `/usr/bin/sudo.ws`. It does not change the system-wide `sudo` default, store your password, or add passwordless access. The dotfiles action never changes root and never prompts during a dry run. Sign out and back in once after it changes your login shell.

## Update an installed machine later

Run these from the existing MBA checkout whenever this setup changes:

```bash
cd ~/linux-setup
git pull --ff-only
./setup.sh --dry-run all
./setup.sh all
```

The Git pull updates this trusted setup first. The preview shows the full
reconciliation, and the real run applies package, app, tool, terminal,
dotfiles, GNOME, and keybinding changes before strict verification. It is safe
to rerun and stops on the first failure.

For a dotfiles-only change, use the guarded updater inside that checkout:

```bash
cd ~/.local/share/dotfiles
./update.sh --dry-run
./update.sh
```

That updater also works from the normal dotfiles checkout on macOS. It requires the expected origin, `main`, and a clean worktree; fetches and merges only with `--ff-only`; applies only the current platform's reviewed desktop profile; and never commits or pushes.

## Start here

Check for Git first:

```bash
git --version
```

If Ubuntu says `git: command not found`, bootstrap only Git:

```bash
sudo apt update
sudo apt install --yes git
```

Then clone the setup:

```bash
git clone https://github.com/nathanialhenniges/linux-setup.git
cd linux-setup
./setup.sh all
```

That one command includes bootstrap and strict verification. To preview first, run `./setup.sh bootstrap`, which installs prerequisites and can repair the exact reviewed Claude source conflict when Ansible is already present, followed by the no-change `./setup.sh --dry-run all`.

`--dry-run` never uses `sudo`, downloads a key, installs a package, or changes managed state. Ansible actions use check mode; wrapper and interactive actions use explicit read-only previews; `status` and `verify` are already read-only. Ansible may create its ignored `.ansible/` temporary directory inside this checkout.
If any Claude entry exists outside the managed `.sources` file, `--dry-run all` previews the source check and stops before any APT-backed action. When Ansible is already present, a normal `./setup.sh all` runs that check automatically before bootstrap refreshes APT. Exact Anthropic `.list` lines are migrated; an unreviewed `.sources` file or unknown content is refused unchanged.

## What each command does

| Command | Installs or changes | Does **not** do |
|---|---|---|
| `bootstrap` | When Ansible is already present, guarded repair of the exact reviewed Claude APT duplicate; then minimal `ansible-core`, Python APT bindings, and Ubuntu's supported classic `sudo.ws` provider | No full Ansible collection bundle, global `sudo` switch, or seven workstation actions |
| `all` | Bootstraps and runs the seven reviewed setup actions in order, then strict verification | No Codex installer, server/devbox setup, credentials, account sign-ins, Discord download, or Plex PWA |
| `status` | Nothing; shows a short table | No network or `sudo` |
| `verify` | Nothing; checks the required workstation state and fails if incomplete | No repair or hidden install |
| `sources` | Verifies and repairs reviewed vendor keys and APT source files without refreshing APT | No package refresh, package install, account change, or unreviewed source deletion |
| `base` | Git, SSH client, curl, GnuPG, jq, rsync, zip tools, Snap, Flatpak, Zsh, fzf, eza, direnv, Zsh plugins, and the pinned Oh My Posh + CaskaydiaCove prompt stack | No SSH server, Docker, developer language runtimes, upgrade, or login |
| `apps` | GitHub CLI, VS Code, Claude Desktop, and WARP from signed vendor APT repos; Ghostty, Extension Manager, OBS, BlueZ, Mesa/Vulkan, and LibrePods' FUSE runtime from Ubuntu; Postman's publisher-supported Snap; Upscayl from the verified Flathub remote; pinned LibrePods AppImage | No sign-ins, WARP enrollment, automatic Upscayl GPU claims, LibrePods autostart or Bluetooth spoofing, Discord download, Plex PWA, or default-terminal change |
| `tools` | Eight Ubuntu APT packages; removes matching local command shadows and verifies APT wins in `PATH` | No backups of replaced tools, Twitch CLI, account setup, credentials, scans, mirrors, SMART tests, or tokens |
| `terminal` | Places Ghostty first in Ubuntu's default-terminal list and backs up an existing list | No `sudo`; does not uninstall Ubuntu's terminal |
| `codex` | Shows OpenAI's official Linux install page; makes no change | No unpinned installer, unofficial desktop port, or Wine |
| `dotfiles` | Pulls `nathanialhenniges/dotfiles`, runs only `linux-desktop.sh`, then makes packaged Zsh the current user's login shell | Never calls generic, server, devbox, agent, or root shell setup |
| `gnome` | Dark mode, battery percent, no hot corners, bottom always-visible dock | No extensions or keyboard interception |
| `keybinds` | Installs or repairs pinned Toshy, starts its user services, and prints the Mac-mode check board | Requires live GNOME; refuses competing remappers and unverified sources |

Chrome and 1Password are already installed on the target laptop. `status` detects them; this repo does not replace their working repositories or sign-ins.

## Eight selected Ubuntu APT tools

| Tool | Install route | Purpose |
|---|---|---|
| `btop` | Ubuntu APT | Friendly CPU, memory, disk, and process monitor |
| `fastfetch` | Ubuntu APT | Quick hardware and Ubuntu summary |
| `httrack` | Ubuntu APT | Copy an allowed website for offline review |
| `aws` | Ubuntu `awscli` package | AWS command-line client; sign-in remains manual |
| `nmap` | Ubuntu APT | Inspect only networks and systems you are authorized to test |
| `smartctl` | Ubuntu `smartmontools` package | Read available SSD health data; device access may need `sudo` |
| `rclone` | Ubuntu APT | Cloud-file transfers; no remote is configured |
| `yt-dlp` | Ubuntu APT | Video downloader; FFmpeg is not silently added |

Twitch CLI is not available from Ubuntu 26.04 APT, so the APT-only action leaves it out. Add FFmpeg later only if yt-dlp merging or post-processing actually needs it.

Before changing anything, `tools` checks all eight command names in `~/.local/bin`, `~/bin`, and `/usr/local/bin`. A missing directory such as `~/bin` is normal and silently skipped; an existing path that is not a real directory is refused. It installs and verifies the Ubuntu packages first. It then permanently removes exact matching files or symlinks from all three directories, plus matching `.pre-linux-setup-apt-*` files or symlinks left by the older backup policy. Directories are refused. Finally, it resolves every command to its canonical `/usr/bin` or `/usr/sbin` APT path.

The action does not run another package manager's uninstall command. If Linuxbrew, Snap, Cargo, npm, mise, asdf, or another provider elsewhere still wins in `PATH`, the action stops and prints that path so it can be removed with its own package manager.

## Safety boundary

The script fails closed unless it sees Ubuntu 26.04, AMD64, and an Ubuntu desktop installation. Third-party APT keys are downloaded to a temporary directory and checked against the vendors' documented full fingerprints before their isolated `Signed-By` sources are installed. Oh My Posh and the CaskaydiaCove Nerd Font come from versioned upstream release assets and must pass reviewed SHA-256 values before installation. Selected CLI tools come only from Ubuntu APT, and command resolution must point to an APT-owned path. Postman is the one reviewed Snap: the exact package documented by Postman and published by its verified Snap Store account. Upscayl is the one reviewed Flatpak: Flathub verifies `org.upscayl.Upscayl` against `upscayl.org`, its Snap Store publisher is unverified, and the action refuses to run if a `flathub` remote already points somewhere other than Flathub's repository.

It never creates or uploads credentials, SSH keys, Git identity, email, hostnames, IP addresses, Wi-Fi details, 1Password references, Cloudflare team data, or tokens.

The dependency direction is one-way:

```text
linux-setup -> dotfiles/linux-desktop.sh -> home-directory files only
```

The desktop entry point must exist as a regular file. An existing dotfiles checkout must be clean, on `main`, have the expected GitHub origin, and exactly match `origin/main` before anything executes.

## Codex and Claude on Linux

- **Codex:** `./setup.sh codex` points to the official Linux instructions without executing remote code. The supported Linux experience is Codex CLI or the official VS Code extension. The macOS/Windows Codex desktop app is not installed through Wine or an unofficial port.
- **Claude:** Anthropic publishes an official Ubuntu/Debian desktop beta; `apps` installs its APT package without signing in. Before installation, setup replaces an absent or already-canonical `/etc/default/claude-desktop` with Anthropic's documented `CLAUDE_DESKTOP_ADD_REPO="false"` opt-out so the package cannot recreate a second repository beside the verified managed deb822 source. Because Claude's package sources that file as root, setup never executes it and refuses unexpected content, non-root ownership, symlinks, or any mode other than `0644`. The preflight scans `/etc/apt/sources.list`, `.list`, and `.sources` files without invoking APT. It recognizes Anthropic's exact one-line instructions plus the exact current and historic package-managed comment templates, then removes that verified file only after the managed source is installed. Unreviewed deb822 sources and unknown content stay untouched and are reported only by path, line count, and SHA-256. `apps` asserts the package did not recreate its `.list`, and `verify` checks the exact opt-out plus every source location again.
- **Remote Codex on the MBP:** keep that as a separate remote-access workflow. This repo does not alter the existing devbox or Cloudflare tunnel setup.

If Claude failed with a keyring or `Signed-By` conflict, pull the repair, run the focused source action, then resume everything:

```bash
cd ~/linux-setup
git pull --ff-only
./setup.sh --dry-run sources
./setup.sh sources
sudo apt update
./setup.sh all
```

Do not manually delete source or keyring files. If `sources` prints `Refusing ...`, stop and paste that complete safe message; the guarded migration left the file unchanged. If Claude still fails after `sudo apt update` succeeds, check its candidate and dependency plan, then keep the exact first `E:` line:

```bash
apt-cache policy claude-desktop
sudo apt install --simulate claude-desktop
df -h /
```

## Upscayl on the MBA

`apps` installs `org.upscayl.Upscayl` from the reviewed system Flathub remote.
It also installs Ubuntu's `mesa-vulkan-drivers` and `vulkan-tools`; no PPA,
unverified Snap, extra Flatpak remote, or `curl | sh` is used.

If an older `upscayl` Debian package, Snap, or user-scoped Flatpak is present,
`apps` installs and verifies the reviewed system Flatpak first, then removes
that recognized legacy package. Dry-run previews the migration. User-owned
AppImage files are left alone because their path and provenance cannot be
inferred safely.

The 2015 Air's Intel HD 6000 is not on Upscayl's published compatibility list.
Installation can be automated; hardware compatibility cannot. After `apps`
finishes, run `vulkaninfo --summary`, then
`flatpak run org.upscayl.Upscayl` and test one small image.
Keep large batches on the MacBook Pro if the Air is slow or reports a Vulkan
error.

The current devboxes are headless Ampere ARM64 systems without Vulkan GPUs, so
Upscayl cannot run there and is deliberately absent from server setup. Upscale
locally, then copy only the output to a devbox. A future graphical AMD64 machine
with a real or passed-through Vulkan GPU should be reviewed as a workstation,
not silently added to the server role.

## AirPods on Linux

`apps` installs LibrePods' reviewed `linux-v0.1.0` x86-64 AppImage in `~/.local/bin`, verifies the release-asset SHA-256 digest, and adds a user-local application launcher. The versioned asset is pinned by that digest, but the binary has no separate upstream signature. Review architecture, packaging, signatures or checksums, and Ubuntu compatibility before changing this pin. Upstream does not certify Ubuntu 26.04 specifically, so the MBA launch is an acceptance test.

Pair the AirPods normally in GNOME Bluetooth, then open LibrePods. The project lists listening-mode control, ear detection, battery status, conversational awareness, and automatic connection as working Linux features. Autostart remains off until the app passes a real launch and suspend test on the MBA. The setup does not impersonate an Apple Bluetooth VendorID, edit `/etc/bluetooth/main.conf`, or restart Bluetooth/audio services.

## macOS muscle memory

Use the physical **Command** key beside Space for Mac shortcuts. Linux calls that key Super/Meta; physical **Option** remains Option/Alt. Copy and paste are Command-C/V, not Option-C/V.

Pinned Toshy v26.08.0 is the single Mac-mode keymap. Its default config already recognizes Ghostty and handles GUI, terminal, GNOME, browser, editor, and text-navigation differences. Do not add a second global remapper or duplicate these bindings in Ghostty.

| Muscle memory | Ubuntu result |
|---|---|
| Command-C/V/X/Z/Shift-Z/A/S/F/N/T/W/Q | Normal Mac-style editing and app commands |
| Command-Space | GNOME Overview search, like Spotlight |
| Command-Tab / Command-Shift-Tab | Next or previous application |
| Command-grave | Cycle windows of the current application |
| Control-Left/Right | Previous or next workspace |
| Control-Command-Q | Lock the desktop |
| Option-Left/Right and Option-Delete | Move or delete by word |
| Command-Left/Right/Up/Down | Line or document boundaries |
| Command-Shift-3/4/5 | Full-screen, window, or interactive screenshot |
| Ghostty Command-C/V/T/W/D/Shift-D/K | Copy, paste, tabs, splits, and clear screen |
| Ghostty physical Control-C | Still sends the terminal interrupt; Toshy does not steal it |

One-time setup:

1. Run `./setup.sh gnome` so the built-in dock/search preferences are known.
2. Open Ubuntu's **Extension Manager**, install **Focused Window D-Bus**, and enable it. [Version 11 supports GNOME 49 and 50](https://extensions.gnome.org/extension/5592/focused-window-d-bus/).
3. In Ghostty—not SSH or a text console—run `./setup.sh --dry-run keybinds`, then `./setup.sh keybinds`.
4. If Toshy's installer shows its large **REBOOT** banner, reboot. Then rerun `./setup.sh keybinds` once; it verifies the pinned sources, enables and restarts the user services, and prints the shortcut check board.
5. Run `./setup.sh status`, then `./setup.sh verify`. `MACOS KEY SERVICES ready` means the config, focus extension, autostart, and both Toshy services passed. It cannot prove what a physical key emitted, so finish the printed manual shortcut checklist before calling Mac mode done.

The action refuses SSH/TTY installs, missing GNOME session state, `~/.Xmodmap`, and active keyd, xremap, or Input Remapper services. Toshy's app-specific maps cover known applications; if one unusual app behaves differently, run `toshy-debug` and add only that app class upstream or in Toshy's editable user slice.

Toshy's tested Ubuntu list currently stops at 25.10, so Ubuntu 26.04 remains an on-device acceptance test. Toshy's Python dependency installation is not hermetic; read its prompt before continuing.

Keep these rollback commands handy:

```bash
toshy-services-status
toshy-services-stop
toshy-services-disable
cd ~/.local/src/toshy-Toshy_v26.08.0
./setup_toshy.py uninstall
```

Do not combine Toshy with keyd, Input Remapper, xremap, or global modifier swaps.

## Roll back GNOME preferences

```bash
gsettings reset org.gnome.desktop.interface color-scheme
gsettings reset org.gnome.desktop.interface show-battery-percentage
gsettings reset org.gnome.desktop.interface enable-hot-corners
gsettings reset org.gnome.shell.extensions.dash-to-dock dock-position
gsettings reset org.gnome.shell.extensions.dash-to-dock extend-height
gsettings reset org.gnome.shell.extensions.dash-to-dock dock-fixed
```

To stop using Ghostty as the default, restore the backup path printed by
`./setup.sh terminal`, or edit `~/.config/ubuntu-xdg-terminals.list` and move
another installed terminal above `com.mitchellh.ghostty.desktop`.

## Test before publishing

```bash
./tests/test_setup.sh
```

Changes to APT-source recovery also require the slower Ubuntu 26.04 AMD64 container test:

```bash
./tests/test_apt_source_recovery_docker.sh
```

It requires a running Docker-compatible engine plus network access to its image registry, Ubuntu mirrors, the four reviewed vendor key URLs, and the configured vendor APT repositories. It deliberately breaks APT, runs the exact bootstrap preflight used by `all`, simulates Claude package reinstallation, and proves the conflict cannot return. Other fixtures cover a verified Claude line at `/etc/apt/sources.list:41`, a missing managed source, an unmanaged deb822 source, and unsafe root-sourced opt-out content. Preserved files are checked by SHA-256; refusals must not delete or leak their contents.

After the MBA is configured, `./setup.sh verify` must pass. A second dry run of each action should finish with `changed=0`; stop and review any reported drift before applying it.

## Official references

Artifact provenance, reviewed pins, and upstream license links are recorded in [Third-party notices and credits](THIRD-PARTY-NOTICES.md).

- [Ubuntu 26.04 release notes](https://documentation.ubuntu.com/release-notes/26.04/)
- [Ubuntu 26.04 `sudo-rs` and `sudo.ws` differences](https://documentation.ubuntu.com/server/reference/other-tools/sudo-rs/)
- [Ansible privilege escalation](https://docs.ansible.com/projects/ansible-core/devel/playbook_guide/playbooks_privilege_escalation.html)
- [Ubuntu third-party repository safety](https://documentation.ubuntu.com/server/explanation/software/third-party-repository-usage/)
- [GitHub CLI Linux packages](https://github.com/cli/cli/blob/trunk/docs/install_linux.md)
- [VS Code on Linux](https://code.visualstudio.com/docs/setup/linux)
- [Ghostty in Ubuntu 26.04](https://packages.ubuntu.com/resolute/ghostty)
- [GNOME Extension Manager in Ubuntu 26.04](https://packages.ubuntu.com/resolute/gnome-shell-extension-manager)
- [OBS Studio in Ubuntu 26.04](https://packages.ubuntu.com/resolute/obs-studio)
- [Postman on Linux](https://learning.postman.com/docs/getting-started/installation/install-app/)
- [Upscayl repository](https://github.com/upscayl/upscayl)
- [Upscayl compatibility list](https://github.com/upscayl/upscayl/wiki/Compatibility-List)
- [Upscayl troubleshooting](https://github.com/upscayl/upscayl/wiki/Troubleshooting)
- [Upscayl on Flathub](https://flathub.org/apps/org.upscayl.Upscayl)
- [Discord's official Linux installation](https://support.discord.com/hc/en-us/articles/360034561191-Desktop-Installation-Guide)
- [Claude Desktop for Linux and repository opt-out](https://code.claude.com/docs/en/desktop-linux)
- [Claude Desktop for Linux](https://support.claude.com/en/articles/10065433-install-claude-desktop)
- [Debian APT source-list rules](https://manpages.debian.org/unstable/apt/sources.list.5.en.html)
- [Cloudflare WARP for Linux](https://developers.cloudflare.com/warp-client/get-started/linux/)
- [LibrePods](https://github.com/librepods-org/librepods)
- [LibrePods Linux installation notes](https://github.com/librepods-org/librepods/blob/main/linux/README.md)
- [LibrePods Linux v0.1.0 release](https://github.com/librepods-org/librepods/releases/tag/linux-v0.1.0)
- [OpenAI Codex](https://github.com/openai/codex)
- [Toshy](https://github.com/RedBearAK/toshy)
- [Ubuntu 26.04 rclone package](https://packages.ubuntu.com/resolute/rclone)
- [Ubuntu 26.04 yt-dlp package](https://packages.ubuntu.com/resolute/yt-dlp)
- [Ubuntu 26.04 package index](https://packages.ubuntu.com/resolute/allpackages)

This repository is available under the [MIT License](LICENSE). Installed and
referenced third-party software remains under its own license or vendor terms;
see [Third-party notices and credits](THIRD-PARTY-NOTICES.md).
