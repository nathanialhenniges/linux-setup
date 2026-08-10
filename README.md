# Ubuntu desktop setup

A small, repeatable bootstrap for an Intel MacBook Air running **Ubuntu Desktop 26.04 LTS (AMD64)**.

> [!IMPORTANT]
> This is a **desktop workstation** setup. It never configures a server or devbox and never invokes the dotfiles `server.sh`, `server-dev.sh`, `install.sh`, `config/server/**`, or `config/agent/**` paths.

## Do one box at a time

- [ ] 1. Install the small Ansible runtime: `./setup.sh bootstrap`
- [ ] 2. See what is already ready: `./setup.sh status`
- [ ] 3. Preview/install the base: `./setup.sh --dry-run base`, then `./setup.sh base`
- [ ] 4. Preview/install core apps: `./setup.sh --dry-run apps`, then `./setup.sh apps`
- [ ] 5. Preview/install the eight selected Ubuntu APT tools: `./setup.sh --dry-run tools`, then `./setup.sh tools`
- [ ] 6. After Ghostty launch-tests successfully: `./setup.sh terminal`
- [ ] 7. Show the reviewed Codex CLI route: `./setup.sh codex`, then follow the official page
- [ ] 8. Apply desktop-only dotfiles and make Zsh the login shell: `./setup.sh --dry-run dotfiles`, then `./setup.sh dotfiles`
- [ ] 9. Apply the GNOME look and always-visible bottom dock: `./setup.sh --dry-run gnome`, then `./setup.sh gnome`
- [ ] 10. Set up Mac mode: enable Focused Window D-Bus, run `./setup.sh --dry-run keybinds` and `./setup.sh keybinds`, reboot only if Toshy says so, then rerun `keybinds`
- [ ] 11. Confirm the core workstation: `./setup.sh verify`
- [ ] 12. Decide later: `./setup.sh --dry-run optional`

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
./setup.sh bootstrap
./setup.sh status
./setup.sh --dry-run base
```

`--dry-run` uses Ansible check mode. It never uses `sudo`, downloads a key, installs a package, or changes managed state. Ansible may create its ignored `.ansible/` temporary directory inside this checkout.

## What each command does

| Command | Installs or changes | Does **not** do |
|---|---|---|
| `bootstrap` | Minimal `ansible-core`, Python APT bindings, and Ubuntu's supported classic `sudo.ws` provider | No full Ansible collection bundle, global `sudo` switch, or workstation changes |
| `status` | Nothing; shows a short table | No network or `sudo` |
| `verify` | Nothing; checks the required workstation state and fails if incomplete | No repair or hidden install |
| `base` | Git, SSH client, curl, GnuPG, jq, rsync, zip tools, Zsh, fzf, eza, direnv, Zsh plugins, and the pinned Oh My Posh + CaskaydiaCove prompt stack | No SSH server, Docker, runtimes, upgrade, or login |
| `apps` | GitHub CLI and VS Code from signed vendor APT repos; Ghostty from Ubuntu | Does not replace the default terminal |
| `tools` | Eight Ubuntu APT packages; safely removes only the old reviewed rclone/yt-dlp files that would shadow APT | No Twitch CLI, account setup, credentials, scans, mirrors, SMART tests, or tokens |
| `terminal` | Places Ghostty first in Ubuntu's default-terminal list and backs up an existing list | No `sudo`; does not uninstall Ubuntu's terminal |
| `codex` | Shows OpenAI's official Linux install page; makes no change | No unpinned installer, unofficial desktop port, or Wine |
| `dotfiles` | Pulls `nathanialhenniges/dotfiles`, runs only `linux-desktop.sh`, then makes packaged Zsh the current user's login shell | Never calls generic, server, devbox, agent, or root shell setup |
| `gnome` | Dark mode, battery percent, no hot corners, bottom always-visible dock | No extensions or keyboard interception |
| `keybinds` | Installs or repairs pinned Toshy, starts its user services, and prints the Mac-mode check board | Requires live GNOME; refuses competing remappers and unverified sources |
| `optional` | Official Claude Desktop beta and Cloudflare WARP packages | No Claude Cowork, WARP enrollment, DNS/routing change, or tunnel |

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

## Safety boundary

The script fails closed unless it sees Ubuntu 26.04, AMD64, and an Ubuntu desktop installation. Third-party APT keys are downloaded to a temporary directory and checked against the vendors' documented full fingerprints before their isolated `Signed-By` sources are installed. Oh My Posh and the CaskaydiaCove Nerd Font come from pinned immutable upstream releases and must pass reviewed SHA-256 values before installation. Selected CLI tools come only from Ubuntu APT.

It never creates or uploads credentials, SSH keys, Git identity, email, hostnames, IP addresses, Wi-Fi details, 1Password references, Cloudflare team data, or tokens.

The dependency direction is one-way:

```text
linux-setup -> dotfiles/linux-desktop.sh -> home-directory files only
```

The desktop entry point must exist as a regular file. An existing dotfiles checkout must be clean, on `main`, have the expected GitHub origin, and exactly match `origin/main` before anything executes.

## Codex and Claude on Linux

- **Codex:** `./setup.sh codex` points to the official Linux instructions without executing remote code. The supported Linux experience is Codex CLI or the official VS Code extension. The macOS/Windows Codex desktop app is not installed through Wine or an unofficial port.
- **Claude:** Anthropic publishes an official Ubuntu/Debian desktop beta, installed only by `optional`.
- **Remote Codex on the MBP:** keep that as a separate remote-access workflow. This repo does not alter the existing devbox or Cloudflare tunnel setup.

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
- [Claude Desktop for Linux](https://support.claude.com/en/articles/10065433-install-claude-desktop)
- [Cloudflare WARP for Linux](https://developers.cloudflare.com/warp-client/get-started/linux/)
- [OpenAI Codex](https://github.com/openai/codex)
- [Toshy](https://github.com/RedBearAK/toshy)
- [Ubuntu 26.04 rclone package](https://packages.ubuntu.com/resolute/rclone)
- [Ubuntu 26.04 yt-dlp package](https://packages.ubuntu.com/resolute/yt-dlp)
- [Ubuntu 26.04 package index](https://packages.ubuntu.com/resolute/allpackages)

No license has been selected. Public visibility permits review, not automatic reuse.
