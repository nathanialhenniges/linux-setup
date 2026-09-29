# Nathanial’s MacBook Air

Reinstall and setup guide for the **2015 MacBook Air (`MacBookAir7,2`)**. Install EndeavourOS with GNOME, then use this repository to add the laptop apps, a Mac-inspired dock, and MrDemonWolf branding. GNOME is the desktop this setup configures.

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
- [ ] Choose **GNOME** and leave its EndeavourOS settings enabled. This repository keeps GNOME as the only configured desktop session.
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

Wi-Fi works from the live USB, but the installed system needs its own driver. `./setup.sh apps` installs Arch's `broadcom-wl-dkms` package for this Mac's Broadcom card. Keep another way to get online available until setup finishes. If Wi-Fi is missing after reboot, run `./setup.sh apps` again, then reboot once more.

The setup installs headers for both the regular and LTS kernels so DKMS can build the Wi-Fi and FaceTime camera drivers for either boot option.

Setup keeps GDM enabled and gives GNOME a bottom dock with the apps installed for this Mac. If an earlier setup added Hyprland, open a terminal in the desktop you are using and run `./setup.sh remove-hyprland`. Save open work first. The action turns on GDM, shows pacman’s removal list, and waits for your approval. It leaves personal configuration files in place. Reboot afterward and choose GNOME at sign-in.

Use the supplied `assets/mrdemonwolf-logo.svg` and the existing wolf wallpaper for MrDemonWolf, Inc. branding. `./setup.sh all` copies the logo into `~/Pictures`, applies the wallpaper when its desktop session is active, sets the supplied profile photo as your account/login picture, and installs the separate Plymouth startup theme. You can rerun only `./setup.sh profile-picture` to set the photo, `./setup.sh display-manager` to restore GDM as the login manager, or `./setup.sh branding` to rebuild the branded splash. The splash keeps the LUKS passphrase prompt visible and leaves EndeavourOS’s packaged theme files intact. With systemd-boot selected, setup preserves the existing root and LUKS options, adds `quiet splash`, and rebuilds the boot entries and initrds for installed kernels. The systemd-boot menu stays text-only and the Mac firmware picker is unchanged.

## 3. Set up the laptop

If `git` is missing, install it first:

```bash
sudo pacman -Syu --needed git
```

Clone this repository and run setup from a GNOME terminal. Before it starts, setup checks which Linux system and Mac model it can identify. If either is missing or differs from EndeavourOS/Arch on a MacBookAir7,2, it shows the detected values and pauses. Type `CONTINUE` only if you recognize the mismatch. If no one can answer the prompt, pass `--accept-target-warning` to acknowledge it. That option does not skip the non-root, x86-64, pacman, or SSH safety checks.

The bootstrap step installs the pinned `community.general` collection that Ansible needs for pacman package actions.

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
- [ ] Review the AUR build prompts from `yay`. Setup does not auto-approve them. Chrome, VS Code, Dash to Dock, and the FaceTime HD camera support use AUR packages.
- [ ] At the end of `./setup.sh all`, choose whether to uninstall Firefox and erase its local data. Chrome installs before this prompt. Confirming removes Firefox bookmarks, saved logins, cookies, extensions, settings, and cache; Google Chrome and its profile data are left alone. Close Firefox first. If you skip it, you can later review `./setup.sh --dry-run purge-firefox` and run `./setup.sh purge-firefox`.
- [ ] When setup finishes, reboot:

```bash
reboot
```

- [ ] At the GDM login screen, choose **GNOME**.
- [ ] Run `./setup.sh verify` from `~/Developer/linux-setup`.

If a step needs repair, rerun that action only. For example, `./setup.sh gnome-dock`, `./setup.sh profile-picture`, `./setup.sh display-manager`, and `./setup.sh branding` do not rerun the full setup. Finished actions are safe to repeat.

## 4. First login

- [ ] Check Wi-Fi from the top bar after setup and reboot. If it is missing, use USB Ethernet or another working network route, rerun `./setup.sh apps`, then reboot.
- [ ] Open Terminal from GNOME’s app grid. Ghostty is pinned in the dock.
- [ ] Check the bottom dock for Files, Chrome, Telegram, Discord, Notion, ChatGPT, Cider, VS Code, Ghostty, Plex, Upscayl, and LibrePods. The script pins apps that are installed; Apple Messages and Reminders do not have native Linux apps in this setup.
- [ ] Open Chrome and sign in to Google. Docs, Sheets, Slides, Notion, Quo, and ChatGPT shortcuts appear in the launcher.
- [ ] Open Google Drive at [drive.google.com](https://drive.google.com/). Drive stays browser-only.
- [ ] Sign in to Discord. Open Plex Desktop and Cider as needed; Cider activation and Apple sign-in are manual.
- [ ] Pair AirPods manually in Bluetooth settings, then open LibrePods if wanted.
- [ ] After reboot, run `./setup.sh camera` to check the FaceTime HD packages, DKMS build, and camera device.
- [ ] Open Google Meet in Chrome and confirm the camera preview shows video. Also check audio, brightness keys, trackpad, suspend, and wake.
- [ ] Leave **Power Saver** selected for normal battery use. Click the **Power** item in the top bar to change profiles when plugged in or when you need more performance.

## 5. Connect to a Mac with Chrome Remote Desktop

This MacBook uses Chrome Remote Desktop as a **client** in Chrome. The setup does not install or configure the Chrome Remote Desktop host here. Google supports accessing another computer, including a Mac, from the web client at [remotedesktop.google.com/access](https://remotedesktop.google.com/access).

- [ ] Open Chrome and go to [remotedesktop.google.com/access](https://remotedesktop.google.com/access).
- [ ] Connect to the Mac and use Chrome Remote Desktop’s full-screen control so Chrome is less likely to capture remote shortcuts.
- [ ] Test the Mac’s **Command + C** and **Command + V** in a safe text field. Test any other shortcuts you rely on before doing real work.
- [ ] If a shortcut arrives incorrectly, adjust Chrome Remote Desktop’s key-mapping controls and test again.

Google’s [Chrome Remote Desktop help](https://support.google.com/chrome/answer/1649523?hl=en) covers connecting to another computer.

## 6. Useful setup commands

Run these inside `~/Developer/linux-setup` as your normal user, never as root:

| Command | What it does |
| --- | --- |
| `./setup.sh status` | Show a short readiness summary |
| `./setup.sh --accept-target-warning <action>` | Explicitly accept a displayed Mac model or OS identity warning for that action |
| `./setup.sh chrome` | Install Chrome early so the guide can stay open on the Mac |
| `./setup.sh state` | Show missing packages, Flatpak origins, and service state |
| `./setup.sh verify` | Check that reviewed workstation setup is present |
| `./setup.sh camera` | Check the FaceTime HD camera driver and detected video device |
| `./setup.sh --dry-run all` | Preview the full plan without sudo or network access |
| `./setup.sh base` | Install base packages and power profiles |
| `./setup.sh apps` | Install laptop apps, Wi-Fi support, Flatpaks, LibrePods, and keep GDM enabled for GNOME |
| `./setup.sh tools` | Install selected command-line tools |
| `./setup.sh desktop` | Set the wallpaper, app shortcuts, and account photo |
| `./setup.sh gnome-dock` | Install and configure the GNOME dock and app favorites |
| `./setup.sh remove-hyprland` | Enable GDM, then review and remove the old Hyprland session packages |
| `./setup.sh branding` | Select the MrDemonWolf Plymouth boot splash and rebuild boot images (run `apps` first) |
| `./setup.sh display-manager` | Enable GDM and disable SDDM at startup; reboot to use the GNOME login screen |
| `./setup.sh profile-picture` | Set the supplied profile photo without rerunning the full setup |
| `./setup.sh purge-firefox` | Uninstall Firefox and erase its local data; leave Chrome and its profile untouched |
| `./setup.sh dotfiles` | Run only dotfiles’ dedicated `linux-desktop.sh` profile |
| `./setup.sh drive` | Show browser-only Google Drive steps |

`all` runs base, apps, tools, desktop, GNOME dock, branding, dotfiles, and verification in that order. Start it from GNOME. If an earlier run installed Hyprland, use the separate `remove-hyprland` action from your current desktop first. Pacman lists the packages and unused dependencies, then waits for your confirmation. Your personal config files stay in place. Reboot after removal. You can rerun any action on its own.

## What this setup does

- Uses pacman, interactive `yay` builds, system Flathub apps, checksum-checked downloads, and local Ansible.
- Installs the SSH **client** for VS Code Remote SSH. `sshd` stays disabled and untouched.
- Keeps Google sign-in, Cider activation, Bluetooth pairing, and remote-computer access manual.
- Does not install Docker, the Chrome Remote Desktop host, or server/devbox software. It does not create tunnels, credentials, or Git identity.
- Targets only EndeavourOS/Arch x86-64 on `MacBookAir7,2`; run setup as your normal user, never as root.

See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for reviewed upstreams and licenses, and [SECURITY.md](SECURITY.md) for repository safety boundaries.
