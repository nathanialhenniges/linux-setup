# Ubuntu desktop setup

A small, repeatable bootstrap for an Intel MacBook Air running **Ubuntu Desktop 26.04 LTS (AMD64)**.

> [!IMPORTANT]
> This is a **desktop workstation** setup. It never configures a server or devbox and never invokes the dotfiles `server.sh`, `server-dev.sh`, `install.sh`, `config/server/**`, or `config/agent/**` paths.

[Dotfiles PR #24](https://github.com/nathanialhenniges/dotfiles/pull/24) is merged. The `dotfiles` command still refuses to run unless its dedicated entry point exists on the verified `main` branch.

## Do one box at a time

- [ ] 1. Preview the base setup: `./setup.sh --dry-run base`
- [ ] 2. Install the base: `./setup.sh base`
- [ ] 3. Preview/install core apps: `./setup.sh --dry-run apps`, then `./setup.sh apps`
- [ ] 4. After Ghostty launch-tests successfully: `./setup.sh terminal`
- [ ] 5. Show the reviewed Codex CLI route: `./setup.sh codex`, then follow the official page
- [ ] 6. Apply desktop-only dotfiles and make Zsh the login shell: `./setup.sh --dry-run dotfiles`, then `./setup.sh dotfiles`
- [ ] 7. Apply the GNOME look: `./setup.sh --dry-run gnome`, then `./setup.sh gnome`
- [ ] 8. Decide later: `./setup.sh --dry-run optional`

Stop after any failed box. Do not keep stacking fixes.

The real dotfiles step may ask for your Ubuntu account password while `chsh` makes Zsh the login shell. It never uses `sudo` for this change. Sign out and back in once afterward; the dry run never prompts or changes the shell.

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
./setup.sh status
./setup.sh --dry-run base
```

`--dry-run` never uses `sudo`, downloads a key, installs a package, or changes a file.

## What each command does

| Command | Installs or changes | Does **not** do |
|---|---|---|
| `status` | Nothing; shows a short table | No network or `sudo` |
| `base` | Git, SSH client, curl, GnuPG, jq, rsync, zip tools, Zsh, fzf, eza, direnv, Zsh plugins, Cascadia Code | No SSH server, Docker, runtimes, upgrade, or login |
| `apps` | GitHub CLI and VS Code from signed vendor APT repos; Ghostty from Ubuntu | Does not replace the default terminal |
| `terminal` | Places Ghostty first in Ubuntu's default-terminal list and backs up an existing list | No `sudo`; does not uninstall Ubuntu's terminal |
| `codex` | Shows OpenAI's official Linux install page; makes no change | No unpinned installer, unofficial desktop port, or Wine |
| `dotfiles` | Pulls `nathanialhenniges/dotfiles`, runs only `linux-desktop.sh`, then makes packaged Zsh the current user's login shell | Never calls generic, server, devbox, agent, or root shell setup |
| `gnome` | Dark mode, battery percent, no hot corners, bottom auto-hiding dock | No extensions or keyboard interception |
| `optional` | Official Claude Desktop beta and Cloudflare WARP packages | No Claude Cowork, WARP enrollment, DNS/routing change, or tunnel |

Chrome and 1Password are already installed on the target laptop. `status` detects them; this repo does not replace their working repositories or sign-ins.

## Safety boundary

The script fails closed unless it sees Ubuntu 26.04, AMD64, and an Ubuntu desktop installation. Third-party APT keys are downloaded to a temporary directory and checked against the vendors' documented full fingerprints before their isolated `Signed-By` sources are installed.

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

Press **Super/Command** to open GNOME Overview search; it is the built-in Spotlight-style launcher, so another launcher is unnecessary.

For app-aware macOS shortcuts such as Command-C/V/W/Q, use [Toshy](https://github.com/RedBearAK/toshy) only after the base laptop is stable. Ubuntu 26.04 uses GNOME Wayland, where Toshy also needs a compatible GNOME Shell extension. Review Toshy's environment first, install from its downloaded source, and keep these rollback commands handy:

```bash
toshy-services-status
toshy-services-stop
./setup_toshy.py uninstall
```

Toshy is intentionally not auto-installed: it has its own package installer, user services, input permissions, and desktop-extension requirements.

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
