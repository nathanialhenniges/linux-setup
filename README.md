# Ubuntu desktop setup

A small, repeatable bootstrap for an Intel MacBook Air running **Ubuntu Desktop 26.04 LTS (AMD64)**.

> [!IMPORTANT]
> This is a **desktop workstation** setup. It never configures a server or devbox and never invokes the dotfiles `server.sh`, `server-dev.sh`, `install.sh`, `config/server/**`, or `config/agent/**` paths.

## MBA setup guide

Run every command from a terminal inside the logged-in Ubuntu desktop—not over SSH and not from a text console. Commands that need administrator access ask for the Ubuntu login password through Ansible. Never run `setup.sh` itself with `sudo`.

### Fresh installation

Install Git if Ubuntu does not already have it, clone the repository into the standard workstation path, bootstrap the small Ansible runtime, preview the setup, and then apply it:

```bash
sudo apt update
sudo apt install --yes git

mkdir -p ~/Developer/nathanialhenniges
cd ~/Developer/nathanialhenniges
git clone https://github.com/nathanialhenniges/linux-setup.git
cd linux-setup

./setup.sh bootstrap
./setup.sh status
./setup.sh state
./setup.sh --dry-run all
./setup.sh all
```

`all` runs `base`, `apps`, `tools`, `terminal`, `dotfiles`, `gnome`, and `keybinds` in that order, stops on the first failure, and finishes with strict `verify`. It deliberately excludes the optional boot logo, Codex installation, sign-ins, Discord, browser-managed PWA installation, LocalWP, and Raspberry Pi Imager.

The preview never uses `sudo`, downloads packages, or changes managed state. It skips bootstrap and ends with the non-strict status board. Run `./setup.sh bootstrap` first when Ansible is absent.

### Update the existing MBA checkout

Pull only a fast-forwarded `main`, inspect current state, preview the complete reconciliation, and apply it:

```bash
cd ~/Developer/nathanialhenniges/linux-setup
git switch main
git pull --ff-only
./setup.sh status
./setup.sh --dry-run all
./setup.sh all
```

To apply only the current app and desktop-personalization update without repeating every action:

```bash
cd ~/Developer/nathanialhenniges/linux-setup
git switch main
git pull --ff-only
./setup.sh --dry-run apps
./setup.sh apps
./setup.sh --dry-run gnome
./setup.sh gnome
./setup.sh status
./setup.sh verify
```

### One action at a time

- [ ] Bootstrap Ansible: `./setup.sh bootstrap`
- [ ] Inspect current state: `./setup.sh status`
- [ ] Inspect exact failed-check details when needed: `./setup.sh state`
- [ ] Repair reviewed vendor sources if requested: `./setup.sh --dry-run sources`, then `./setup.sh sources`
- [ ] Install the workstation base: `./setup.sh --dry-run base`, then `./setup.sh base`
- [ ] Install approved desktop apps: `./setup.sh --dry-run apps`, then `./setup.sh apps`
- [ ] Install selected Ubuntu CLI tools: `./setup.sh --dry-run tools`, then `./setup.sh tools`
- [ ] Optional: mount Google Drive in Files: `./setup.sh --dry-run drive`, then `./setup.sh drive`
- [ ] Make launch-tested Ghostty the default: `./setup.sh terminal`
- [ ] Show the reviewed Codex route: `./setup.sh codex`
- [ ] Apply desktop-only dotfiles and Zsh: `./setup.sh --dry-run dotfiles`, then `./setup.sh dotfiles`
- [ ] Apply wallpaper, account photo, GNOME preferences, and Dock pins: `./setup.sh --dry-run gnome`, then `./setup.sh gnome`
- [ ] Install or repair Toshy Mac shortcuts: `./setup.sh --dry-run keybinds`, then `./setup.sh keybinds`
- [ ] Confirm the required workstation state: `./setup.sh verify`

### Resume after a stopped action

Stop at the first error and fix only the reported problem.

- If `all` stops during `base`, `apps`, `tools`, `terminal`, `dotfiles`, or `gnome`, correct the reported cause and rerun `./setup.sh all`; completed actions are designed to converge safely.
- If `keybinds` installs Focused Window D-Bus for the next session, sign out and back in, then run `./setup.sh keybinds && ./setup.sh verify`. The completed setup actions do not run again.
- If a focused action fails, rerun only that action, then use `./setup.sh status` and `./setup.sh verify`.
- If anything remains unclear, paste the complete error output. Do not manually delete or edit APT source files, keyrings, or `/etc/default/claude-desktop`.

### Password prompts

Enter the Ubuntu login password carefully at the Ansible `BECOME password` prompt. A rejected password ends that run; rerun the same command and enter it again. Ubuntu 26.04 defaults to `sudo-rs`, so this repository scopes Ansible to Ubuntu's packaged `/usr/bin/sudo.ws`. It never changes the system-wide `sudo` alternative, stores a password, or grants passwordless access.

Sign out and back in after `dotfiles` changes the login shell. Reboot only when Toshy explicitly requests it or after a reviewed boot-logo action.

### Dotfiles-only updates

Use the guarded updater in the managed dotfiles checkout:

```bash
cd ~/.local/share/dotfiles
./update.sh --dry-run
./update.sh
```

It requires the expected origin, `main`, and a clean worktree; fast-forwards only; applies the current platform's reviewed desktop profile; and never commits or pushes.

## What each command does

| Command | Installs or changes | Does **not** do |
|---|---|---|
| `bootstrap` | When Ansible is already present, guarded repair of the exact reviewed Claude APT duplicate; then minimal `ansible-core`, Python APT bindings, and Ubuntu's supported classic `sudo.ws` provider | No full Ansible collection bundle, global `sudo` switch, or seven workstation actions |
| `all` | Bootstraps and runs the seven reviewed setup actions in order, then strict verification | No Codex installer, server/devbox setup, credentials, account sign-ins, Discord download, LocalWP, Raspberry Pi Imager, or browser-profile PWA installation |
| `status` | Nothing; shows a short table | No network or `sudo` |
| `state` | Nothing; shows safe file metadata, checksum results, and GNOME values behind failed checks | No repair, secrets, network, or `sudo` |
| `verify` | Nothing; checks the required workstation state and fails if incomplete | No repair or hidden install |
| `sources` | Verifies and repairs reviewed vendor keys and APT source files without refreshing APT | No package refresh, package install, account change, or unreviewed source deletion |
| `base` | Git, SSH client, curl, GnuPG, jq, rsync, zip tools, Snap, Flatpak, Zsh, fzf, eza, direnv, Zsh plugins, and the pinned Oh My Posh + CaskaydiaCove prompt stack | No SSH server, Docker, developer language runtimes, upgrade, or login |
| `apps` | Official pinned ChatGPT Linux preview bootstrap plus its signed OpenAI APT repo; GitHub CLI, VS Code, Claude Desktop, and WARP from signed vendor APT repos; Ghostty, Extension Manager, OBS, BlueZ, Mesa/Vulkan, and LibrePods' FUSE runtime from Ubuntu; Postman's publisher-supported Snap; RustDesk, Telegram, Cider, Upscayl, and Plex Desktop from reviewed Flathub; pinned LibrePods AppImage | No sign-ins, license activation, autostart, WARP enrollment, automatic GPU claims, LibrePods Bluetooth spoofing, Discord download, LocalWP, Raspberry Pi Imager, PWA creation, or default-terminal change |
| `tools` | Eight Ubuntu APT packages; removes matching local command shadows and verifies APT wins in `PATH` | No backups of replaced tools, Twitch CLI, account setup, credentials, scans, mirrors, SMART tests, or tokens |
| `drive` | Runs rclone's interactive Google OAuth flow when needed, installs Ubuntu `fuse3`, and enables a private user mount at `~/Google Drive` with `--vfs-cache-mode writes` | Never runs from `all`; no credentials enter the repository or logs; no unattended bisync |
| `terminal` | Places Ghostty first in Ubuntu's default-terminal list and backs up an existing list | No `sudo`; does not uninstall Ubuntu's terminal |
| `codex` | Shows OpenAI's official Linux install page; makes no change | No unpinned installer, unofficial desktop port, or Wine |
| `dotfiles` | Pulls `nathanialhenniges/dotfiles`, runs only `linux-desktop.sh`, then makes packaged Zsh the current user's login shell | Never calls generic, server, devbox, agent, or root shell setup |
| `gnome` | Dark mode, battery percent, no hot corners, reviewed wallpaper and profile picture, **Nathanials Air** Device Name and GDM logo, five local Chrome app-mode launchers, and the bottom always-visible 32 px Dock | No browser policy/profile edits, OEM/SMBIOS spoofing, Ubuntu renaming, placeholder pins, extensions, or keyboard interception |
| `keybinds` | Installs or repairs pinned Toshy, starts its user services, and prints the Mac-mode check board | Requires live GNOME; refuses competing remappers and unverified sources |
| `boot` | Opt-in clone of Ubuntu's packaged two-step Plymouth theme with the checksum-pinned MrDemonWolf logo; records the exact prior selection and rebuilds existing initramfs images | Cannot replace Apple's firmware logo; skips TPM-backed FDE and UKI layouts; never runs from `all` |
| `boot-reset` | Restores the exact prior Plymouth selection and mode, rebuilds existing initramfs images, then removes only the managed theme and state | Refuses unknown theme or state content |

Chrome and 1Password are already installed on the target laptop. `status` detects them; this repo does not replace their working repositories or sign-ins.

## Selected app routes and limits

The `apps` action already covered 1Password and Chrome detection; Claude Desktop, Cloudflare WARP, Ghostty, OBS, Postman, Upscayl, and VS Code installation; and manual Discord detection. It also installs Telegram as `org.telegram.desktop` and x86-64 Plex Desktop as `tv.plex.PlexDesktop` from the reviewed system Flathub remote. Every managed Flatpak must report `flathub` as its exact origin. Launch them with `flatpak run org.telegram.desktop` or `flatpak run tv.plex.PlexDesktop`; sign-in and launch tests stay manual, and autostart stays off.

### Chrome Remote Desktop

Chrome Remote Desktop remains a manual setup on Ubuntu because Google distributes it as a rolling `.deb`, not a versioned and checksum-verified package. It is intentionally excluded from `apps` and `all`.

To make the MBA an unattended host, open Chrome on the MBA, visit `https://remotedesktop.google.com/access`, sign in, and download Google's 64-bit Debian host package. Install the downloaded package with `sudo apt install ~/Downloads/chrome-remote-desktop_current_amd64.deb`, return to the site, enable remote access, name the host `Nathanials Air`, and set a strong device PIN. On the connecting computer, open the same site, select `Nathanials Air`, enter the PIN, and remember it only on a trusted device.

The Linux host creates a separate virtual desktop rather than mirroring the session visible on the MBA. Running the same GNOME environment locally and remotely can conflict, so log out of the local MBA session before starting an unattended remote session. Use `https://remotedesktop.google.com/support` with a temporary support code when access to the currently visible local session is required.

### Recreate a personal Ubuntu desktop

Do not clone the whole home directory. On the source Ubuntu desktop, capture the supported shell, Git, and editor settings with `cd ~/dotfiles && ./sync.sh --profile linux-desktop`, review the diff, then commit and push the safe changes. On a fresh Ubuntu desktop, run `./setup.sh apps`, `./setup.sh gnome`, and `./setup.sh dotfiles` from this repository. Sign in to 1Password and Chrome manually, then configure Chrome Remote Desktop at `https://remotedesktop.google.com/access`. Browser profiles, OAuth tokens, SSH keys, and application data do not move between machines.

LocalWP stays manual and on-demand. Its publisher provides a Debian package and tests Ubuntu, but it has no signed APT repository and publishes only SHA-1 checksums. Download the reviewed release from `https://localwp.com/releases/` only when a local WordPress task needs it, run one site at a time, stop it afterward, and prefer the existing devbox for sustained work.

Raspberry Pi Imager is available directly from Ubuntu 26.04 as `rpi-imager`, but it is intentionally outside the default manifest. Install it only when imaging media is needed with `sudo apt install rpi-imager`, then launch it on demand.

The `gnome` action creates local `.desktop` launchers for Docs, Sheets, Slides, Notion, and Quo. Each uses packaged Chrome's app-window mode, the product's canonical HTTPS URL, and a checksum-pinned icon downloaded from that product's official site. This gives them their own app-grid entries without writing Chrome's signed-in profile or marking Chrome as enterprise-managed. Google Drive is intentionally browser-only and its exact retired managed launcher is removed. Notion does not publish a Linux desktop app, so the reviewed Chrome window stays preferred over unofficial wrappers. Sign-ins remain manual. Before relying on Quo, allow its microphone and notification permissions and complete a real call.

GNOME's built-in screenshot and recording UI replaces Shottr. Files plus SFTP replaces Transmit unless queues or batch transfers prove FileZilla necessary. Color picker and image optimizer selection waits for a real task; test optimizers on copies. DBeaver Community stays absent until a GUI database task exists.

This 8 GB machine should not keep LocalWP, Chrome PWAs, Claude, Discord, Postman, and VS Code open together. Do not run OBS capture, Upscayl processing, and Plex playback together. If Plex cannot discover local servers while WARP is connected, review Cloudflare local-network access or split-tunnel policy before changing Plex.

The `gnome` action uses 32 px Dock icons for the MBA's 1366×768 display. It puts installed reviewed launchers first in the Mac-like order—Files, Chrome, Discord, Notion, Claude, ChatGPT, Cider, Ghostty, VS Code, and Postman—then preserves every unrelated favorite. It explicitly removes 1Password, Telegram, LibrePods, Plex, Docs, Drive, Sheets, Slides, and Quo from favorites. Telegram, LibrePods, Plex, Docs, Sheets, Slides, and Quo remain in the app drawer; Drive is browser-only. Safari was also only running and has no Ubuntu pin. A native or managed launcher must exist before it is pinned.

The remaining MBP-only pins stay intentionally absent: Files already covers Finder and the selected Transmit replacement; no Reminders replacement was selected; Affinity and Xcode have no supported Linux releases; no Pixelmator Pro or Final Cut Pro replacement was selected; and DBeaver remains on-demand instead of replacing TablePro before a real database task exists.

The same action copies the reviewed wallpaper to `~/Pictures/Wallpapers/mrdemonwolf-desktop-wallpaper.png`, the profile photo to `~/Pictures/Profile Pictures/nathanial-henniges-profile-picture.jpg`, applies the wallpaper to light and dark GNOME modes, and sets the Ubuntu account/login avatar through AccountsService. Setup checksum-verifies the source, destination, wallpaper values, and AccountsService cache.

Ubuntu-supported machine branding keeps the pretty Device Name at **Nathanials Air** with `hostnamectl` while preserving the static network hostname. It installs the reviewed MrDemonWolf logo and the **Managed by MrDemonWolf, Inc.** banner for GDM through GNOME's documented `org.gnome.login-screen` dconf keys; both appear after the next sign-out or reboot. See GNOME's guides for the [GDM logo](https://help.gnome.org/system-admin-guide/login-logo.html) and [enterprise login banner](https://help.gnome.org/system-admin-guide/login-banner.html).

Ubuntu's OEM mode is a factory installation and first-boot workflow, not a supported post-install manufacturer field. GNOME reads the Hardware Model from Apple's firmware and the operating-system vendor from Ubuntu's `os-release`, so setup leaves both truthful. It never runs `oem-config`, edits `/etc/os-release`, spoofs DMI/SMBIOS data, replaces firmware resources, or overwrites Ubuntu package-owned artwork. See [Ubuntu's Device Name guide](https://help.ubuntu.com/stable/ubuntu-help/about-hostname.html.en) and [Ubuntu's OEM installer overview](https://help.ubuntu.com/community/Ubuntu_OEM_Installer_Overview).

Cider is the selected Apple Music client. `apps` installs `sh.cider.Cider` from the reviewed system Flathub remote and `gnome` pins it when its launcher exists. Cider is proprietary and license-gated; license activation and Apple sign-in stay manual. It is the primary streaming-music app, but setup does not claim local MP3/FLAC MIME types because Cider is not a general local-file player. Keep Apple's supported `https://music.apple.com/` web player as the fallback.

## Optional boot logo

Apple's firmware draws the first Apple logo before Ubuntu starts, so Linux cannot safely replace that image. The supported customization begins at Plymouth after the kernel and initramfs take control. It clones Ubuntu's packaged `two-step` spinner theme, preserving its password and disk-unlock assets, and replaces only the watermark with the reviewed transparent 240 x 240 px logo. The managed descriptor pins `WatermarkHorizontalAlignment=.5` and `WatermarkVerticalAlignment=.34`; on the MBA's 1366×768 display this centers the logo above Ubuntu's native spinner with a clear gap. `DialogVerticalAlignment=.64` moves only the encrypted-drive unlock row below the logo instead of covering its face.

Pull `main`, preview, and apply the boot logo separately from `all`:

```bash
cd ~/Developer/nathanialhenniges/linux-setup
git switch main
git pull --ff-only
./setup.sh --dry-run boot
./setup.sh boot
sudo reboot
```

The action skips Ubuntu TPM-backed full-disk-encryption and UKI layouts unchanged. Normal password-based LUKS remains supported. To restore the exact prior Plymouth alternative, remove only the managed files, and inspect the restored splash:

```bash
./setup.sh --dry-run boot-reset
./setup.sh boot-reset
sudo reboot
```

Docker verifies package setup, the cloned password assets, exact activation, idempotence, rollback, unsafe-content refusal, unsupported-layout skipping, and dry-run behavior. A Docker container cannot display the real splash because it does not boot its own kernel or own a DRM/framebuffer device; the final visual acceptance test requires QEMU or a reboot on the MBA.

## Manual acceptance checklist

Automation verifies package origin and managed state. Finish these user-session and hardware checks on the MBA:

- [ ] Run `./setup.sh status`, resolve every required action, then make `./setup.sh verify` pass.
- [ ] Confirm the MrDemonWolf wallpaper, Ubuntu account photo, always-visible 32 px Dock, and ten managed pins appear correctly. Confirm Telegram, LibrePods, Plex, Docs, Sheets, Slides, Notion, and Quo remain available from the app drawer and Google Drive does not.
- [ ] Launch Ghostty from the Dock and confirm Ubuntu opens it as the default terminal. Confirm Chrome and 1Password still use their existing profiles; 1Password should be installed but not pinned.
- [ ] Open ChatGPT and Claude Desktop and complete their sign-ins.
- [ ] Open Cider, activate its license, sign in to Apple Music, and play one track. Keep `https://music.apple.com/` as the fallback.
- [ ] Enroll Cloudflare WARP manually. With WARP connected, confirm Plex can still discover the local server; review local-network or split-tunnel policy if it cannot.
- [ ] Sign in to Plex Desktop and play one short video without also running OBS or Upscayl.
- [ ] Sign in to Telegram and Postman if those apps are needed.
- [ ] Record and play back a short OBS test, then close OBS before testing Upscayl or Plex.
- [ ] Pair AirPods in GNOME Bluetooth, open LibrePods, test battery data and listening-mode controls, suspend the MBA, resume it, and confirm reconnection. Leave autostart disabled until all checks pass.
- [ ] Run `vulkaninfo --summary`, launch Upscayl, and upscale a copy of one small image. Never use the only copy of an original for acceptance testing.
- [ ] Complete the Toshy shortcut board printed by `./setup.sh keybinds`, including Command-C/V, Command-Space, Command-Tab, Command-grave, and Ghostty Control-C.
- [ ] Open the managed Docs, Sheets, Slides, and Notion launchers, sign in, and confirm each opens in its own Chrome app window with its real product icon. Open Google Drive in Chrome.
- [ ] In the managed Quo launcher, allow the microphone and notifications, then complete a real inbound and outbound call before treating the web route as ready.
- [ ] Install Discord only from its official `.deb`. Keep LocalWP and Raspberry Pi Imager on-demand.
- [ ] Keep autostart disabled for heavy apps. On this 8 GB MBA, do not leave LocalWP, Chrome PWAs, Claude, Discord, Postman, and VS Code open together.

## Troubleshooting

Start with the read-only board:

```bash
cd ~/Developer/nathanialhenniges/linux-setup
./setup.sh status
```

- `needs apps action` means preview and rerun `apps`; it does not mean manually repairing APT.
- `installed; ... manual` means installation passed and the named acceptance check remains. It is not an automation failure.
- A `BECOME password` or `sudo: a password is required` failure means rerun the same setup action and carefully enter the Ubuntu login password. Do not prefix `setup.sh` with `sudo`.
- If keybinds says Focused Window D-Bus is ready for the next GNOME session, sign out and back in. Then run `./setup.sh keybinds && ./setup.sh verify` instead of repeating `all`.
- Run `gnome` and `keybinds` only from a terminal inside the live logged-in desktop. SSH, a virtual console, or a missing D-Bus session is refused.
- If a newly installed launcher is missing from the app grid or Dock, sign out and back in once, rerun `./setup.sh gnome`, and check again.
- If `sources` refuses unknown content, leave it untouched and paste the complete error output. Do not manually delete or edit APT source files, signing keys, or Claude defaults.
- If `verify` fails, use the exact action named by `status`; `verify` never repairs or installs anything.
- If the short status line is not specific enough, run `./setup.sh state` and paste its complete output. It is read-only and does not print rclone credentials or managed file contents.

## Eight selected Ubuntu APT tools

| Tool | Install route | Purpose |
|---|---|---|
| `btop` | Ubuntu APT | Friendly CPU, memory, disk, and process monitor |
| `fastfetch` | Ubuntu APT | Quick hardware and Ubuntu summary |
| `httrack` | Ubuntu APT | Copy an allowed website for offline review |
| `aws` | Ubuntu `awscli` package | AWS command-line client; sign-in remains manual |
| `nmap` | Ubuntu APT | Inspect only networks and systems you are authorized to test |
| `smartctl` | Ubuntu `smartmontools` package | Read available SSD health data; device access may need `sudo` |
| `rclone` | Ubuntu APT | Optional Google Drive mount; authentication is a separate `drive` action |
| `yt-dlp` | Ubuntu APT | Video downloader; FFmpeg is not silently added |

Twitch CLI is not available from Ubuntu 26.04 APT, so the APT-only action leaves it out. Add FFmpeg later only if yt-dlp merging or post-processing actually needs it.

Before changing anything, `tools` checks all eight command names in `~/.local/bin`, `~/bin`, and `/usr/local/bin`. A missing directory such as `~/bin` is normal and silently skipped; an existing path that is not a real directory is refused. It installs and verifies the Ubuntu packages first. It then permanently removes exact matching files or symlinks from all three directories, plus matching `.pre-linux-setup-apt-*` files or symlinks left by the older backup policy. Directories are refused. Finally, it resolves every command to its canonical `/usr/bin` or `/usr/sbin` APT path.

The action does not run another package manager's uninstall command. If Linuxbrew, Snap, Cargo, npm, mise, asdf, or another provider elsewhere still wins in `PATH`, the action stops and prints that path so it can be removed with its own package manager.

### Google Drive in Files

Run `./setup.sh --dry-run drive`, then `./setup.sh drive`. If the `google-drive` remote does not exist, the wrapper opens rclone's own interactive configuration and tells you the exact remote name and provider to choose. Browser OAuth stays on the MBA. The action then creates a user-only `~/Google Drive` mount, limits its write cache to 2 GB, enables it at login, and verifies the user service. It never runs from `all`.

The mount provides normal on-demand access in Files; `--vfs-cache-mode writes` buffers changed files locally before upload. It is not an offline mirror. Do not automate `rclone bisync` yet: Ubuntu 26.04's packaged rclone is 1.60, and rclone documents bisync as an advanced command where a wrong initial `--resync` can overwrite or delete data. Add bisync only after naming the exact local and Drive folders, testing `--dry-run`, and deciding which side wins conflicts.

## Safety boundary

The script fails closed unless it sees Ubuntu 26.04, AMD64, and an Ubuntu desktop installation. Third-party APT keys are downloaded to a temporary directory and checked against the vendors' documented full fingerprints before their isolated `Signed-By` sources are installed. Oh My Posh and the CaskaydiaCove Nerd Font come from versioned upstream release assets and must pass reviewed SHA-256 values before installation. Selected CLI tools come only from Ubuntu APT, and command resolution must point to an APT-owned path. Postman is the one reviewed Snap: the exact package documented by Postman and published by its verified Snap Store account. Telegram, proprietary Cider, Upscayl, and x86-64 Plex Desktop are the four reviewed Flatpaks. The action refuses a `flathub` remote that points anywhere but Flathub's repository and requires each installed app to report that exact origin. Chrome Remote Desktop stays manual because its Google host package is rolling and therefore outside this bootstrap's verified-artifact policy.

Except for invoking rclone's own user-local OAuth flow in the optional `drive` action, repository logic never creates or uploads credentials, SSH keys, Git identity, email, hostnames, IP addresses, Wi-Fi details, 1Password references, Cloudflare team data, or tokens. It never reads the rclone token into output or commits its config.

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
cd ~/Developer/nathanialhenniges/linux-setup
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
2. In Ghostty—not SSH or a text console—run `./setup.sh --dry-run keybinds`, then `./setup.sh keybinds`. It installs the pinned **Focused Window D-Bus** source when needed; [the reviewed GNOME Extensions version supports GNOME 49 and 50](https://extensions.gnome.org/extension/5592/focused-window-d-bus/).
3. If setup says the extension is installed for the next GNOME session, sign out and back in, then run `./setup.sh keybinds && ./setup.sh verify`; the completed setup actions do not run again.
4. If Toshy's installer shows its large **REBOOT** banner, reboot. Then rerun `./setup.sh keybinds` once; it verifies the pinned sources, enables and restarts the user services, and prints the shortcut check board.
5. Run `./setup.sh status`, then `./setup.sh verify`. `MACOS KEY SERVICES ready` means the config, focus extension, autostart, and both Toshy services passed. It cannot prove what a physical key emitted, so finish the printed manual shortcut checklist before calling Mac mode done.

The action pins and verifies Focused Window D-Bus before installing it with GNOME's native extension tool. It refuses SSH/TTY installs, missing GNOME session state, `~/.Xmodmap`, and active keyd, xremap, or Input Remapper services. Toshy's app-specific maps cover known applications; if one unusual app behaves differently, run `toshy-debug` and add only that app class upstream or in Toshy's editable user slice.

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
gsettings reset org.gnome.shell.extensions.dash-to-dock dash-max-icon-size
```

The additive Dock favorites are deliberately not included in the reset block: resetting `favorite-apps` would replace the user's list with GNOME defaults. Remove individual pins from the Dock normally if desired.

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

Changes to sudo or Ansible privilege handling require its focused Ubuntu 26.04 AMD64 container test:

```bash
./tests/test_sudo_become_docker.sh
```

Dock and boot-branding changes have focused Ubuntu 26.04 AMD64 checks:

```bash
./tests/test_gnome_dock_docker.sh
./tests/test-boot-branding-docker.sh
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
- [Telegram Desktop for Linux](https://telegram.org/desktop/linux)
- [Telegram on Flathub](https://flathub.org/apps/org.telegram.desktop)
- [Plex Desktop on Flathub](https://flathub.org/apps/tv.plex.PlexDesktop)
- [Cider on Flathub](https://flathub.org/apps/sh.cider.Cider)
- [Apple Music on the web](https://support.apple.com/guide/music-web/welcome/web)
- [LocalWP Linux installation](https://localwp.com/help-docs/getting-started/installing-local/)
- [LocalWP releases](https://localwp.com/releases/)
- [Ubuntu 26.04 Raspberry Pi Imager package](https://packages.ubuntu.com/resolute/rpi-imager)
- [Discord's official Linux installation](https://support.discord.com/hc/en-us/articles/360034561191-Desktop-Installation-Guide)
- [Claude Desktop for Linux and repository opt-out](https://code.claude.com/docs/en/desktop-linux)
- [Claude Desktop for Linux](https://support.claude.com/en/articles/10065433-install-claude-desktop)
- [ChatGPT desktop app for Linux](https://learn.chatgpt.com/docs/linux/linux-app)
- [Debian APT source-list rules](https://manpages.debian.org/unstable/apt/sources.list.5.en.html)
- [Cloudflare WARP for Linux](https://developers.cloudflare.com/warp-client/get-started/linux/)
- [LibrePods](https://github.com/librepods-org/librepods)
- [LibrePods Linux installation notes](https://github.com/librepods-org/librepods/blob/main/linux/README.md)
- [LibrePods Linux v0.1.0 release](https://github.com/librepods-org/librepods/releases/tag/linux-v0.1.0)
- [OpenAI Codex](https://github.com/openai/codex)
- [Toshy](https://github.com/RedBearAK/toshy)
- [Chrome web apps on Linux](https://support.google.com/chrome/answer/9658361)
- [Notion desktop support](https://www.notion.com/help/notion-for-desktop)
- [Ubuntu 26.04 rclone package](https://packages.ubuntu.com/resolute/rclone)
- [rclone Google Drive configuration](https://rclone.org/drive/)
- [rclone mount and VFS cache modes](https://rclone.org/commands/rclone_mount/)
- [rclone bisync safety documentation](https://rclone.org/commands/rclone_bisync/)
- [Ubuntu 26.04 yt-dlp package](https://packages.ubuntu.com/resolute/yt-dlp)
- [Ubuntu 26.04 package index](https://packages.ubuntu.com/resolute/allpackages)

This repository is available under the [MIT License](LICENSE). Installed and
referenced third-party software remains under its own license or vendor terms;
see [Third-party notices and credits](THIRD-PARTY-NOTICES.md).
