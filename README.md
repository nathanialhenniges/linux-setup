# EndeavourOS on Nathanial’s MacBook Air

A small, auditable setup for **EndeavourOS or Arch Linux with GNOME** on the 2015 MacBook Air (`MacBookAir7,2`). It installs the selected laptop apps, configures a Mac-inspired GNOME dock, and applies MrDemonWolf branding.

> **Fresh install warning:** the installer erases the Mac’s internal SSD. Back up anything you need before proceeding.

For the full visual, copy-friendly reinstall checklist, use the [interactive install guide](https://nathanialhenniges.github.io/linux-setup/).

## Contents

- [Install EndeavourOS](#install-endeavouros)
- [Run setup](#run-setup)
- [Apps included](#apps-included)
- [Focused repair actions](#focused-repair-actions)
- [GNOME shortcuts](#gnome-shortcuts)
- [Validation and safety](#validation-and-safety)

## Install EndeavourOS

Use the online installer and select **GNOME**. Before erasing the disk, confirm that the selected drive is the internal Apple SSD (about 466 GiB on this Mac).

Recommended choices:

- Keep EndeavourOS’s **Desktop-Base + Common packages** and recommended defaults. Keep Firefox for the initial setup; `./setup.sh all` offers to remove Firefox and its local data at the end.
- Keep the regular `linux` kernel and add the **LTS kernel** as a fallback.
- Select **Printing support (CUPS)**. Wait to select vendor-specific printer support until you know the office printer model.
- Choose **Erase disk** and **Encrypt System**. Save the disk passphrase; you will enter it at startup.
- Keep the automatic **systemd-boot** setup. Do not create partitions or a volume group manually. Skip a separate swap partition; hibernation needs a later encrypted swapfile setup.
- Create a normal user account. Run this repository as that user, never as root.

In the live desktop, accept EndeavourOS’s Broadcom Wi-Fi driver offer if it appears, then load a webpage before starting the online install. If Wi-Fi fails, stop and use another working network connection. The installed system also needs its own Wi-Fi driver, which the `apps` action installs.

If the Mac shows its startup picker after installation, hold **Option (⌥)** and choose **EFI Boot**. At the GDM login screen, choose **GNOME**.

## Run setup

Open Ghostty or another terminal in GNOME. If Git is missing, install it first:

```bash
sudo pacman -Syu --needed git
```

Clone the repository and install its local Ansible prerequisites:

```bash
mkdir -p ~/Developer
cd ~/Developer
git clone https://github.com/nathanialhenniges/linux-setup.git
cd linux-setup
./setup.sh bootstrap
./setup.sh status
```

Chrome can open the guide on the Mac before the rest of setup:

```bash
./setup.sh chrome
google-chrome-stable 'https://nathanialhenniges.github.io/linux-setup/' >/dev/null 2>&1 &
```

Review the no-change plan, then run the full setup:

```bash
./setup.sh --dry-run all
./setup.sh all
```

`all` asks for your sudo password once and refreshes the temporary sudo ticket while it runs. Ansible does not ask for a second BECOME password. Separate approval prompts may still appear for AUR builds, package changes, detected cleanup items, or ChatGPT’s full-system upgrade if ChatGPT needs installation. At the end, choose whether to remove Firefox and its local data. Reboot after setup:

```bash
reboot
```

After logging back in to GNOME, verify:

```bash
cd ~/Developer/linux-setup
./setup.sh verify
```

Setup checks the OS and Mac model before changing the system. If it displays a mismatch, review the detected values and type `CONTINUE` only if you accept the warning. `--accept-target-warning` is the explicit option for non-interactive runs; it does not bypass the architecture, package-manager, non-root, or SSH safety checks.

## Apps included

| App | Where it appears | Install source |
| --- | --- | --- |
| Files | Dock | GNOME |
| Google Chrome | Dock | AUR |
| 1Password | Dock | AUR; setup checks the vendor signing-key fingerprint before import |
| Telegram | Dock | Flathub |
| Discord | Dock | Arch repositories |
| Notion | Dock and app grid | Chrome web-app shortcut |
| ChatGPT | Dock | OpenAI’s signed Arch repository |
| Cider | Dock | Flathub |
| Visual Studio Code | Dock | AUR |
| Ghostty | Dock | Arch repositories |
| Plex Desktop, Upscayl | App grid | Flathub |
| LibrePods | App grid and tray | Checksum-pinned AppImage; starts minimized after login |

Chrome also gets web-app shortcuts for Google Docs, Sheets, Slides, Notion, and Quo. Sign-ins and account setup stay manual. Trash is shown in the dock. Apple Messages and Reminders do not have native Linux apps in this setup.

## Focused repair actions

Run only the step you need. Preview mutating actions with `--dry-run` first.

| Command | Purpose |
| --- | --- |
| `./setup.sh status` / `state` / `verify` | Check readiness, package state, or required setup |
| `./setup.sh camera` | Check FaceTime HD packages, driver build, and video device |
| `./setup.sh apps` | Install laptop apps, Wi-Fi support, Flatpaks, LibrePods, and ChatGPT |
| `./setup.sh desktop` | Apply wallpaper, Chrome shortcuts, and account photo |
| `./setup.sh gnome-dock` | Configure dock favorites, extensions, appearance, and shortcuts |
| `./setup.sh branding` | Rebuild the black Plymouth splash with a static wolf logo and visible disk-unlock prompt, without the spinner animation |
| `./setup.sh display-manager` | Restore GDM as the login manager |
| `./setup.sh profile-picture` | Set the account photo again |
| `./setup.sh chatgpt-app` | Update ChatGPT from OpenAI’s signed Arch repository |
| `./setup.sh cleanup-legacy` | Remove the known old ChatGPT shortcut and optionally remove old Hyprland packages |
| `./setup.sh remove-hyprland` | Review and optionally remove the listed Hyprland packages |
| `./setup.sh cleanup-terminals` | Review and optionally remove extra terminal apps; keep Ghostty |
| `./setup.sh purge-firefox` | Remove Firefox and its local profile data, leaving Chrome untouched |
| `./setup.sh dotfiles` | Run the dedicated dotfiles desktop profile |

`./setup.sh all` groups related Ansible actions to avoid repeating startup checks. Dash to Dock and AppIndicator are configured for the **next GNOME login**. Reboot after removing Hyprland or changing boot branding. The boot splash is separate from the text-only systemd-boot menu and the Mac firmware picker.

## GNOME shortcuts

GNOME uses **dynamic workspaces**: it adds workspaces as windows need them and removes empty ones. Use `Super+Page Up` / `Super+Page Down` or `Ctrl+Alt+←` / `Ctrl+Alt+→` to move between workspaces.

On this Mac, **Command (⌘)** maps to **Super** in Linux:

| Shortcut | Action |
| --- | --- |
| `⌘+Space` or `⌘+A` | App grid |
| `⌘+Return` | Open Ghostty |
| `⌘+E` | Open Files |
| `⌘+Q` | Close window |
| `⌘+F` | Fullscreen |
| `⌘+L` | Lock screen |
| `⌘+Shift+S` | Screenshot options |
| `Ctrl+⌘+Space` | Switch keyboard layout |

The desktop keeps GNOME’s built-in dark style and left-side window buttons. No downloaded theme pack is required.

## Validation and safety

Run the setup and browser checks locally:

`test_setup.sh` needs Ansible and the pinned `community.general` collection installed by `./setup.sh bootstrap`.

```bash
./tests/test_setup.sh
npm ci
npm run build:guide
npm run test:guide
git diff --check
```

The guide test uses Playwright and headless Chromium, checks keyboard and checklist behavior at desktop and mobile widths, and writes screenshots in the system temporary directory. If Chrome or Chromium is not installed, install Playwright Chromium once with `npx playwright install chromium`. You can set `GUIDE_SCREENSHOT_DIR` to choose a different screenshot folder.

Run both test suites in containers on your development machine:

```bash
./tests/run_container.sh
./tests/run_browser_container.sh
```

It requires a running Docker engine (Docker Desktop or Colima on macOS), builds an x86-64 Arch test image, and tests the guide in the official Playwright image. Each runner removes its task container and newly created test images when it exits; existing images and unrelated containers are preserved. Do not install Docker on the target MacBook. Container checks cannot confirm hardware, GNOME session behavior, encrypted boot, or the camera on the actual laptop.

Protected `main` requires the **Arch container** and **Guide and browser** CI checks. GitHub Pages deployment is gated on both checks passing.

The setup is restricted to EndeavourOS or Arch Linux on x86-64 `MacBookAir7,2`, uses a localhost Ansible inventory, and runs as a normal user. `--dry-run` prints a reviewed plan without sudo, network access, or managed-state writes. AUR package builds remain interactive. `sshd` is never enabled or configured; OpenSSH is installed only for its SSH client. Chrome Remote Desktop is used only as a browser client; this setup does not install the remote host.

See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for upstreams and licenses, and [SECURITY.md](SECURITY.md) for the repository safety boundaries.
