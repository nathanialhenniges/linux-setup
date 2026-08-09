# Ubuntu desktop setup

A small, repeatable bootstrap for an Intel MacBook Air running **Ubuntu Desktop 26.04 LTS (AMD64)**.

> [!IMPORTANT]
> This is a **desktop workstation** setup. It never configures a server or devbox and never invokes the dotfiles `server.sh`, `server-dev.sh`, `install.sh`, `config/server/**`, or `config/agent/**` paths.

## Do one box at a time

- [ ] 1. Install the small Ansible runtime: `./setup.sh bootstrap`
- [ ] 2. See what is already ready: `./setup.sh status`
- [ ] 3. Preview/install the base: `./setup.sh --dry-run base`, then `./setup.sh base`
- [ ] 4. Preview/install core apps: `./setup.sh --dry-run apps`, then `./setup.sh apps`
- [ ] 5. After Ghostty launch-tests successfully: `./setup.sh terminal`
- [ ] 6. Show the reviewed Codex CLI route: `./setup.sh codex`, then follow the official page
- [ ] 7. Apply desktop-only dotfiles and make Zsh the login shell: `./setup.sh --dry-run dotfiles`, then `./setup.sh dotfiles`
- [ ] 8. Apply the GNOME look and always-visible bottom dock: `./setup.sh --dry-run gnome`, then `./setup.sh gnome`
- [ ] 9. Set up macOS keys: enable Focused Window D-Bus, then `./setup.sh --dry-run keybinds` and `./setup.sh keybinds`
- [ ] 10. Confirm the core workstation: `./setup.sh verify`
- [ ] 11. Decide later: `./setup.sh --dry-run optional`

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
| `terminal` | Places Ghostty first in Ubuntu's default-terminal list and backs up an existing list | No `sudo`; does not uninstall Ubuntu's terminal |
| `codex` | Shows OpenAI's official Linux install page; makes no change | No unpinned installer, unofficial desktop port, or Wine |
| `dotfiles` | Pulls `nathanialhenniges/dotfiles`, runs only `linux-desktop.sh`, then makes packaged Zsh the current user's login shell | Never calls generic, server, devbox, agent, or root shell setup |
| `gnome` | Dark mode, battery percent, no hot corners, bottom always-visible dock | No extensions or keyboard interception |
| `keybinds` | Verifies and runs pinned Toshy + xwaykeyz sources interactively after Focused Window D-Bus is enabled | Never runs Toshy through Ansible, as root, or from an unverified checkout |
| `optional` | Official Claude Desktop beta and Cloudflare WARP packages | No Claude Cowork, WARP enrollment, DNS/routing change, or tunnel |

Chrome and 1Password are already installed on the target laptop. `status` detects them; this repo does not replace their working repositories or sign-ins.

## Safety boundary

The script fails closed unless it sees Ubuntu 26.04, AMD64, and an Ubuntu desktop installation. Third-party APT keys are downloaded to a temporary directory and checked against the vendors' documented full fingerprints before their isolated `Signed-By` sources are installed. Oh My Posh and its CaskaydiaCove Nerd Font come from pinned immutable upstream releases and must pass reviewed SHA-256 values before their user-local files are installed.

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

Before Toshy, press **Super** to open GNOME Overview search. After Toshy, use **Command-Space**, matching macOS.

On the MBA keyboard, the physical key beside Space is **Command** even though Linux calls it Super/Meta. Toshy maps physical **Command-C/V** to copy/paste while leaving physical **Option/Alt** as Option/Alt. Mapping literal Option/Alt-C/V would not match macOS and would break normal Alt shortcuts.

The `base` action installs Ubuntu's native Extension Manager. Open it, find and enable [Focused Window D-Bus](https://extensions.gnome.org/extension/5592/focused-window-d-bus/), then run `./setup.sh keybinds`. The action pins Toshy v26.08.0 and xwaykeyz to exact commits, verifies their reviewed tree SHA-256 values, then invokes Toshy's interactive user installer. Toshy's tested matrix currently stops at Ubuntu 25.10, so Ubuntu 26.04 remains a guarded on-device acceptance test rather than an unattended Ansible task. Toshy's own Python dependency installation is not hermetic, so read its prompt before continuing.

After signing out and back in, check:

- Chrome or Files: Command-C/V/X/Z/A/F/W/Q.
- Ghostty: Command-C/V copies and pastes; physical Control-C still interrupts.
- GNOME: Command-Space opens search.

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

No license has been selected. Public visibility permits review, not automatic reuse.
