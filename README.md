# Nathanial’s MacBook Air

Reinstall and setup guide for the **2015 MacBook Air (`MacBookAir7,2`)**. This repository configures EndeavourOS with a light Hyprland desktop for Chrome, Google Workspace, ChatGPT, Discord, Ghostty, VS Code Remote SSH, remote desktops, Plex Desktop, and LibrePods.

Follow the checkboxes from top to bottom. Stop when a step fails; fix that issue, then continue.

For a larger, copy-friendly version with checkboxes saved in your browser, open the [interactive install guide](https://nathanialhenniges.github.io/linux-setup/).

## 1. Get ready

- [ ] Confirm you want a fresh install. The installer erases the Mac’s internal disk.
- [ ] Have the Mac’s power adapter connected.
- [ ] Prepare an EndeavourOS installer USB drive (8 GB or larger) and a data-capable USB-A-to-Lightning cable for the iPhone.
- [ ] Plan internet access for the installer. This Mac’s Broadcom Wi-Fi may need its driver after installation.
- [ ] Download EndeavourOS from the [official EndeavourOS site](https://endeavouros.com/) and verify its published checksum or signature.
- [ ] Write the ISO to a USB drive with [balenaEtcher](https://etcher.balena.io/). This erases the USB drive.

## 2. Install EndeavourOS

- [ ] Insert the installer USB. Start the Mac while holding **Option (⌥)** and choose the EFI USB entry.
- [ ] Open the installer and choose **Online install**.
- [ ] Choose **No desktop environment** if the installer offers it. This repository installs Hyprland; do not add GNOME or KDE Plasma.
- [ ] Keep the default `linux` kernel.
- [ ] Choose the internal disk. Select **Erase disk** only after checking that you selected the MacBook Air’s internal disk.
- [ ] Create your normal user account and password. Do not use root for setup.
- [ ] Finish installation, remove the USB, and log in at the text console.

Before opening the installer, test the iPhone connection in the live desktop:

- [ ] Connect the iPhone by USB, unlock it, then turn on **Settings → Personal Hotspot → Allow Others to Join**. Tap **Trust** if prompted.
- [ ] Open the live desktop’s browser and load a webpage.
- [ ] If the iPhone connection does not appear or the page will not load, stop before choosing **Erase disk**. Linux may need iPhone-tethering packages that are not present in the live USB. Use USB Ethernet or another known-working network connection first.

The Mac’s internal Wi-Fi driver is installed by the setup steps below, after the initial install has internet access.

## 3. Set up the laptop

If `git` is missing, install it first:

```bash
sudo pacman -Syu --needed git
```

Clone this repository and run the setup in order:

```bash
mkdir -p ~/Developer
cd ~/Developer
git clone https://github.com/nathanialhenniges/linux-setup.git
cd linux-setup
./setup.sh bootstrap
./setup.sh status
./setup.sh --dry-run all
./setup.sh all
```

- [ ] Read the dry-run plan before continuing. It makes no changes and does not use sudo or the network.
- [ ] Review the AUR build prompts from `yay`. Setup does not auto-approve them. Chrome, VS Code, and the FaceTime HD camera support use AUR packages.
- [ ] When setup finishes, reboot:

```bash
reboot
```

- [ ] At the login screen, choose **Hyprland** and sign in.
- [ ] Run `./setup.sh verify` from `~/Developer/linux-setup`.

If setup stops, fix the displayed issue and rerun `./setup.sh all`. Finished actions are safe to repeat.

## 4. First login

- [ ] Connect to Wi-Fi using the network icon in the top bar. If internal Wi-Fi is missing, use USB Ethernet or phone tethering, then reboot once after setup installed the Broadcom driver.
- [ ] Press **Super + Enter** to open Ghostty. On this Mac’s keyboard, Super is the Command (⌘) key.
- [ ] Press **Super + Space** to open the app launcher.
- [ ] Open Chrome and sign in to Google. Docs, Sheets, Slides, Notion, Quo, and ChatGPT shortcuts appear in the launcher.
- [ ] Open Google Drive at [drive.google.com](https://drive.google.com/). Drive stays browser-only.
- [ ] Sign in to Discord. Open Plex Desktop and Cider as needed; Cider activation and Apple sign-in are manual.
- [ ] Pair AirPods manually in Bluetooth settings, then open LibrePods if wanted.
- [ ] Test the built-in camera in a Google Meet preview. Also check audio, brightness keys, trackpad, suspend, and wake.
- [ ] Leave **Power Saver** selected for normal battery use. Click the **Power** item in the top bar to change profiles when plugged in or when you need more performance.

## 5. Connect to a Mac with Chrome Remote Desktop

This MacBook uses Chrome Remote Desktop as a **client** in Chrome. The setup does not install or configure the Chrome Remote Desktop host here. Google supports accessing another computer, including a Mac, from the web client at [remotedesktop.google.com/access](https://remotedesktop.google.com/access).

Hyprland normally uses Super shortcuts for local actions. Remote Mac mode pauses those local shortcuts so they do not consume Command-key combinations intended for the Mac.

- [ ] Open Chrome and go to [remotedesktop.google.com/access](https://remotedesktop.google.com/access).
- [ ] Before connecting, press **Super + R**. The top bar should show **REMOTE MAC**.
- [ ] Connect to the Mac and use Chrome Remote Desktop’s full-screen control so Chrome is less likely to capture remote shortcuts.
- [ ] Test the Mac’s **Command + C** and **Command + V** in a safe text field. Test any other shortcuts you rely on before doing real work.
- [ ] If a shortcut stays local or arrives as the wrong modifier, check Chrome Remote Desktop’s key-mapping controls and retest. Modifier translation can depend on the CRD client; the Hyprland mode prevents local Hyprland binds from taking the keys, but cannot guarantee CRD’s translation for every shortcut.
- [ ] Disconnect, then press **Escape** to leave Remote Mac mode. The **REMOTE MAC** label should disappear.

Google’s [Chrome Remote Desktop help](https://support.google.com/chrome/answer/1649523?hl=en) covers connecting to another computer. Hyprland’s [submap documentation](https://wiki.hypr.land/Configuring/Basics/Binds/) explains the temporary key-binding mode used here.

## 6. Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Super + Enter | Open Ghostty |
| Super + Space | Open the app launcher |
| Super + E | Open the file manager |
| Super + Q | Close the active window |
| Super + L | Lock the screen |
| Super + F | Toggle fullscreen |
| Super + 1–4 | Switch workspace |
| Super + Shift + 1–4 | Move window to workspace |
| Super + R | Enter Remote Mac mode before a CRD session |
| Escape | Leave Remote Mac mode |
| Print Screen | Copy a full screenshot |
| Super + Shift + S | Select an area and copy a screenshot |

Brightness and media keys work directly. Run `./setup.sh keybinds` or `./setup.sh terminal` to print the shortcuts from the setup tool.

## 7. Useful setup commands

Run these inside `~/Developer/linux-setup` as your normal user, never as root:

| Command | What it does |
| --- | --- |
| `./setup.sh status` | Show a short readiness summary |
| `./setup.sh state` | Show missing packages, Flatpak origins, and service state |
| `./setup.sh verify` | Check that reviewed workstation setup is present |
| `./setup.sh --dry-run all` | Preview the full plan without sudo or network access |
| `./setup.sh base` | Install base packages and power profiles |
| `./setup.sh apps` | Install Hyprland, laptop apps, Wi-Fi support, Flatpaks, and LibrePods |
| `./setup.sh tools` | Install selected command-line tools |
| `./setup.sh desktop` | Install Hyprland starter settings, wallpaper, and app shortcuts |
| `./setup.sh dotfiles` | Run only dotfiles’ dedicated `linux-desktop.sh` profile |
| `./setup.sh drive` | Show browser-only Google Drive steps |

`all` runs base, apps, tools, desktop, dotfiles, and verification in that order. Each action can be rerun.

## What this setup does

- Uses pacman, interactive `yay` builds, system Flathub apps, checksum-checked downloads, and local Ansible.
- Installs the SSH **client** for VS Code Remote SSH. `sshd` stays disabled and untouched.
- Keeps Google sign-in, Cider activation, Bluetooth pairing, and remote-computer access manual.
- Does not install Docker, the Chrome Remote Desktop host, or server/devbox software. It does not create tunnels, credentials, or Git identity.
- Targets only EndeavourOS/Arch x86-64 on `MacBookAir7,2`; run setup as your normal user, never as root.

See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for reviewed upstreams and licenses, and [SECURITY.md](SECURITY.md) for repository safety boundaries.
