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

The preview skips bootstrap so it never uses the network or `sudo`, forwards check mode to every setup action, and finishes with the non-strict status board. Run `./setup.sh bootstrap` first if Ansible is not installed yet.

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

The updated action adds Extension Manager, Claude Desktop, Cloudflare WARP, OBS Studio, Postman, RustDesk, and Upscayl. Launch Extension Manager with `extension-manager` if GNOME's app grid has not refreshed yet.

Upscayl needs a working Vulkan driver, which the base action does not install. Run `vulkaninfo --summary` before expecting it to upscale anything; on Intel graphics that means Mesa's Vulkan driver package.

Discord remains a manual official `.deb` because its download URL changes without a stable published checksum. Plex remains a manual Chrome site app. The action prints both steps when it finishes.

Stop after any failed box. Do not keep stacking fixes.

Real actions ask for your Ubuntu login password only when Ansible needs administrator access. Ubuntu 26.04 defaults to `sudo-rs`, whose different prompt is not handled by the packaged Ansible release, so this repo scopes Ansible to Ubuntu's supported `/usr/bin/sudo.ws`. It does not change the system-wide `sudo` default, store your password, or add passwordless access. The dotfiles action never changes root and never prompts during a dry run. Sign out and back in once after it changes your login shell.

## Update an installed machine later

Run these from the existing MBA checkout whenever this setup or the desktop
dotfiles change:

```bash
cd ~/linux-setup
git pull --ff-only
./setup.sh dotfiles
./setup.sh status
```

The Git pull updates this trusted setup first. The `dotfiles` command then
verifies and fast-forwards the managed `~/.local/share/dotfiles` checkout,
backs up replaced home files, and reapplies only `linux-desktop.sh`. It stops
instead of overwriting local Git changes or an unexpected origin.

For a dotfiles-only refresh, use the guarded updater inside that checkout:

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
sudo apt-get update
sudo apt-get install --yes git
```

Then clone the setup:

```bash
git clone https://github.com/nathanialhenniges/linux-setup.git
cd linux-setup
./setup.sh all
```

That one command includes bootstrap and strict verification. If you want a no-change preview first, run `./setup.sh bootstrap` followed by `./setup.sh --dry-run all`.

`--dry-run` uses Ansible check mode. It never uses `sudo`, downloads a key, installs a package, or changes managed state. Ansible may create its ignored `.ansible/` temporary directory inside this checkout.

## What each command does

| Command | Installs or changes | Does **not** do |
|---|---|---|
| `bootstrap` | Minimal `ansible-core`, Python APT bindings, and Ubuntu's supported classic `sudo.ws` provider | No full Ansible collection bundle, global `sudo` switch, or workstation changes |
| `all` | Bootstraps and runs the seven reviewed setup actions in order, then strict verification | No Codex installer, server/devbox setup, credentials, account sign-ins, Discord download, or Plex PWA |
| `status` | Nothing; shows a short table | No network or `sudo` |
| `verify` | Nothing; checks the required workstation state and fails if incomplete | No repair or hidden install |
| `base` | Git, SSH client, curl, GnuPG, jq, rsync, zip tools, Snap, Zsh, fzf, eza, direnv, Zsh plugins, and the pinned Oh My Posh + CaskaydiaCove prompt stack | No SSH server, Docker, runtimes, upgrade, or login |
| `apps` | GitHub CLI, VS Code, Claude Desktop, and WARP from signed vendor APT repos; Ghostty, Extension Manager, OBS, BlueZ, and LibrePods' FUSE runtime from Ubuntu; Postman's publisher-supported Snap; RustDesk and Upscayl from the verified Flathub remote; pinned LibrePods AppImage | No sign-ins, WARP enrollment, LibrePods autostart or Bluetooth spoofing, Discord download, Plex PWA, or default-terminal change |
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

The script fails closed unless it sees Ubuntu 26.04, AMD64, and an Ubuntu desktop installation. Third-party APT keys are downloaded to a temporary directory and checked against the vendors' documented full fingerprints before their isolated `Signed-By` sources are installed. Oh My Posh and the CaskaydiaCove Nerd Font come from pinned immutable upstream releases and must pass reviewed SHA-256 values before installation. Selected CLI tools come only from Ubuntu APT, and command resolution must point to an APT-owned path. Postman is the one reviewed Snap: the exact package documented by Postman and published by its verified Snap Store account. RustDesk and Upscayl are reviewed Flatpaks: Flathub verifies `com.rustdesk.RustDesk` against `rustdesk.com` and `org.upscayl.Upscayl` against `upscayl.org`; the action refuses to run if a `flathub` remote already points somewhere other than Flathub's repository.

It never creates or uploads credentials, SSH keys, Git identity, email, hostnames, IP addresses, Wi-Fi details, 1Password references, Cloudflare team data, or tokens.

The dependency direction is one-way:

```text
linux-setup -> dotfiles/linux-desktop.sh -> home-directory files only
```

The desktop entry point must exist as a regular file. An existing dotfiles checkout must be clean, on `main`, have the expected GitHub origin, and exactly match `origin/main` before anything executes.

## Codex and Claude on Linux

- **Codex:** `./setup.sh codex` points to the official Linux instructions without executing remote code. The supported Linux experience is Codex CLI or the official VS Code extension. The macOS/Windows Codex desktop app is not installed through Wine or an unofficial port.
- **Claude:** Anthropic publishes an official Ubuntu/Debian desktop beta; `apps` installs its APT package without signing in. The action refreshes APT once, waits for fresh-Ubuntu package locks, and installs each approved app in a labeled transaction with bounded retries so a Claude error cannot be confused with another package. If Anthropic's official `.list` already exists, the action accepts only its exact documented content, installs the verified managed deb822 source, and then removes the duplicate definition that would make APT reject two different `Signed-By` paths. It leaves Anthropic's unused public key file in place.
- **Remote Codex on the MBP:** keep that as a separate remote-access workflow. This repo does not alter the existing devbox or Cloudflare tunnel setup.

If Claude failed with a keyring or `Signed-By` conflict, pull the repair and rerun only the app action:

```bash
cd ~/linux-setup
git pull --ff-only
./setup.sh --dry-run apps
./setup.sh apps
```

Do not manually delete source or keyring files. The guarded migration refuses an unexpected file instead of overwriting it. If Claude still fails, check its candidate and dependency plan, then keep the exact first `E:` line:

```bash
apt-cache policy claude-desktop
sudo apt install --simulate claude-desktop
df -h /
```

## AirPods on Linux

`apps` installs LibrePods' immutable official `linux-v0.1.0` x86-64 AppImage in `~/.local/bin`, verifies GitHub's release-asset SHA-256 digest, and adds a user-local application launcher. The release tag is verified, but the binary has no separate upstream signature. This is the latest durable Linux release; the project's newer rewrite is distributed as temporary nightly workflow artifacts, so it is not safe or reproducible enough for unattended setup yet. Upstream does not certify Ubuntu 26.04 specifically, so the MBA launch is an acceptance test.

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

After the MBA is configured, `./setup.sh verify` must pass. A second dry run of each action should finish with `changed=0`; stop and review any reported drift before applying it.

## Official references

- [Ubuntu 26.04 release notes](https://documentation.ubuntu.com/release-notes/26.04/)
- [Ubuntu third-party repository safety](https://documentation.ubuntu.com/server/explanation/software/third-party-repository-usage/)
- [GitHub CLI Linux packages](https://github.com/cli/cli/blob/trunk/docs/install_linux.md)
- [VS Code on Linux](https://code.visualstudio.com/docs/setup/linux)
- [Ghostty in Ubuntu 26.04](https://packages.ubuntu.com/resolute/ghostty)
- [GNOME Extension Manager in Ubuntu 26.04](https://packages.ubuntu.com/resolute/gnome-shell-extension-manager)
- [OBS Studio in Ubuntu 26.04](https://packages.ubuntu.com/resolute/obs-studio)
- [Postman on Linux](https://learning.postman.com/docs/getting-started/installation/install-app/)
- [Upscayl on Flathub](https://flathub.org/apps/org.upscayl.Upscayl)
- [Discord's official Linux installation](https://support.discord.com/hc/en-us/articles/360034561191-Desktop-Installation-Guide)
- [Claude Desktop for Linux](https://support.claude.com/en/articles/10065433-install-claude-desktop)
- [Cloudflare WARP for Linux](https://developers.cloudflare.com/warp-client/get-started/linux/)
- [LibrePods](https://github.com/librepods-org/librepods)
- [LibrePods Linux installation notes](https://github.com/librepods-org/librepods/blob/main/linux/README.md)
- [LibrePods Linux v0.1.0 release](https://github.com/librepods-org/librepods/releases/tag/linux-v0.1.0)
- [OpenAI Codex](https://github.com/openai/codex)
- [Toshy](https://github.com/RedBearAK/toshy)
- [Ubuntu 26.04 rclone package](https://packages.ubuntu.com/resolute/rclone)
- [Ubuntu 26.04 yt-dlp package](https://packages.ubuntu.com/resolute/yt-dlp)
- [Ubuntu 26.04 package index](https://packages.ubuntu.com/resolute/allpackages)

No license has been selected. Public visibility permits review, not automatic reuse.
