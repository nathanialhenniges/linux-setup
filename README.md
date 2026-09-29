# Nathanial’s MacBook Air

Reinstall and setup guide for the **2015 MacBook Air (`MacBookAir7,2`)**. Install EndeavourOS with GNOME for the familiar desktop, then use this repository to add its light Hyprland session for Chrome, Google Workspace, ChatGPT, Discord, Ghostty, VS Code Remote SSH, remote desktops, Plex Desktop, and LibrePods.

Follow the checkboxes from top to bottom. Stop when a step fails; fix that issue, then continue.

For a larger, copy-friendly version with checkboxes saved in your browser, open the [interactive install guide](https://nathanialhenniges.github.io/linux-setup/).

## 1. Get ready

- [ ] Confirm you want a fresh install. The installer erases the Mac’s internal disk.
- [ ] Have the Mac’s power adapter connected.
- [ ] Prepare an EndeavourOS installer USB drive (8 GB or larger) and a known-working backup internet route in case live-session Wi-Fi fails.
- [ ] Download EndeavourOS from the [official EndeavourOS site](https://endeavouros.com/) and verify its published checksum or signature.
- [ ] Write the ISO to a USB drive with [balenaEtcher](https://etcher.balena.io/). This erases the USB drive.

## 2. Install EndeavourOS

- [ ] Insert the installer USB. Start the Mac while holding **Option (⌥)** and choose the EFI USB entry.
- [ ] Open the installer and choose **Online install**.
- [ ] Choose **GNOME** and leave its EndeavourOS settings enabled. This repository adds Hyprland as a separate session.
- [ ] On the package screen, keep **Desktop-Base + Common packages** and the installer’s recommended defaults selected. Keep **Firefox** selected temporarily so the guide is available on first boot. The setup installs Google Chrome early, then asks whether to remove Firefox at the end. Keep Spell Checker, Firewall, and Intel microcode selected if shown.
- [ ] Keep the regular `linux` kernel and select **LTS kernel in addition** as a fallback.
- [ ] Select **Printing support (CUPS)** for office printers. Leave **HP printer/scanner support** off until you know the printer make.
- [ ] Select the internal **Apple SSD · about 465.92 GiB · /dev/sda**, choose **Erase disk**, and turn on **Encrypt System**. Set and safely save the encryption passphrase; you will need it each time the Mac starts.
- [ ] Keep EndeavourOS’s default **systemd-boot**. Use the automatic disk setup; do not create partitions or a volume group manually. If the Mac shows its startup picker after installation, hold **Option (⌥)** and choose **EFI Boot**.
- [ ] Do not create a separate swap partition. After installation, add an encrypted swapfile and configure and test hibernation. See the [simple install guide](https://nathanialhenniges.github.io/linux-setup/#install).
- [ ] Create your normal user account and password. Do not use root for setup.
- [ ] Finish installation and remove the USB. Log in to GNOME if you selected it; otherwise log in at the text console.

Before starting the online installer, test the Mac’s built-in Wi-Fi in the live desktop:

- [ ] If EndeavourOS offers to install Wi-Fi drivers, accept the prompt. On this Mac, that enabled the internal Broadcom Wi-Fi in the live session.
- [ ] Connect to Wi-Fi and load a webpage before continuing with **Online install**.
- [ ] If Wi-Fi still does not work, stop before partitioning and use USB Ethernet or another known-working network route. iPhone USB tethering may need packages that are not present in the live USB.

The live-session driver may not carry into the installed system. The `./setup.sh apps` action installs the reviewed Broadcom Wi-Fi package. Keep backup internet available until setup finishes; if Wi-Fi is missing afterward, rerun that action and reboot.

When setup enables SDDM, it disables GDM if present. GNOME stays installed and remains available at the login screen alongside Hyprland.

Use the supplied `assets/mrdemonwolf-logo.svg` and the existing wolf wallpaper for MrDemonWolf, Inc. branding. `./setup.sh all` copies the SVG into `~/Pictures`, applies the wolf wallpaper in GNOME when setup runs from its desktop session (and in the configured Hyprland session), then installs a separate Plymouth theme for the startup splash. The theme keeps the LUKS passphrase prompt visible and leaves EndeavourOS’s packaged theme files intact. With systemd-boot selected, setup preserves the existing root and LUKS options, adds `quiet splash`, and rebuilds the boot entries and initrds for installed kernels. The systemd-boot menu stays text-only and the Mac firmware picker is unchanged. If you enable SDDM auto-login later, the LUKS passphrase is still required at startup, then SDDM skips its login screen.

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
./setup.sh --dry-run chrome
./setup.sh chrome
google-chrome-stable 'https://nathanialhenniges.github.io/linux-setup/' >/dev/null 2>&1 &
./setup.sh --dry-run all
./setup.sh all
```

- [ ] Chrome is installed and the guide is open in Chrome on the Mac. The later `all` action safely skips Chrome if it is already installed.
- [ ] Read the full setup dry-run before continuing. It makes no changes and does not use sudo or the network.
- [ ] Review the AUR build prompts from `yay`. Setup does not auto-approve them. Chrome, VS Code, and the FaceTime HD camera support use AUR packages.
- [ ] At the end of `./setup.sh all`, choose whether to uninstall Firefox and erase its local data. Chrome installs before this prompt. Confirming removes Firefox bookmarks, saved logins, cookies, extensions, settings, and cache; Google Chrome and its profile data are left alone. Close Firefox first. If you skip it, you can later review `./setup.sh --dry-run purge-firefox` and run `./setup.sh purge-firefox`.
- [ ] When setup finishes, reboot:

```bash
reboot
```

- [ ] At the SDDM login screen, choose **GNOME** for the familiar desktop or **Hyprland** for this repository’s configured Wayland desktop.
- [ ] Run `./setup.sh verify` from `~/Developer/linux-setup`.

If setup stops, fix the displayed issue and rerun `./setup.sh all`. Finished actions are safe to repeat.

## 4. First login

- [ ] Check Wi-Fi from the top bar after setup and reboot. If it is missing, use USB Ethernet or another working network route, rerun `./setup.sh apps`, then reboot.
- [ ] If using GNOME, open Terminal from the app grid. If using Hyprland, press **Super + Enter** for Ghostty; on this Mac, Super is the Command (⌘) key.
- [ ] If using Hyprland, press **Super + Space** to open its app launcher.
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
| `./setup.sh chrome` | Install Chrome early so the guide can stay open on the Mac |
| `./setup.sh state` | Show missing packages, Flatpak origins, and service state |
| `./setup.sh verify` | Check that reviewed workstation setup is present |
| `./setup.sh --dry-run all` | Preview the full plan without sudo or network access |
| `./setup.sh base` | Install base packages and power profiles |
| `./setup.sh apps` | Install Hyprland, laptop apps, Wi-Fi support, Flatpaks, and LibrePods |
| `./setup.sh tools` | Install selected command-line tools |
| `./setup.sh desktop` | Install Hyprland starter settings, wallpaper, and app shortcuts |
| `./setup.sh branding` | Install the MrDemonWolf Plymouth boot splash (run `apps` first) |
| `./setup.sh purge-firefox` | Uninstall Firefox and erase its local data; leave Chrome and its profile untouched |
| `./setup.sh dotfiles` | Run only dotfiles’ dedicated `linux-desktop.sh` profile |
| `./setup.sh drive` | Show browser-only Google Drive steps |

`all` runs base, apps, tools, desktop, branding, dotfiles, and verification in that order. Each action can be rerun.

## What this setup does

- Uses pacman, interactive `yay` builds, system Flathub apps, checksum-checked downloads, and local Ansible.
- Installs the SSH **client** for VS Code Remote SSH. `sshd` stays disabled and untouched.
- Keeps Google sign-in, Cider activation, Bluetooth pairing, and remote-computer access manual.
- Does not install Docker, the Chrome Remote Desktop host, or server/devbox software. It does not create tunnels, credentials, or Git identity.
- Targets only EndeavourOS/Arch x86-64 on `MacBookAir7,2`; run setup as your normal user, never as root.

See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for reviewed upstreams and licenses, and [SECURITY.md](SECURITY.md) for repository safety boundaries.
