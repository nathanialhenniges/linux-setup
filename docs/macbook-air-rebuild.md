# MacBook Air rebuild guide

Use this checklist to rebuild `Nathanials Air` as an Ubuntu 26.04 AMD64 desktop. Run actions in order and stop at the first failure. Do not start with `all`; staged actions make failures easier to isolate.

## Safety boundaries

- Keep the hardware model and Ubuntu identity authentic. The managed device name is `Nathanials Air`.
- Never copy a whole home directory, browser profile, OAuth token, SSH key, rclone configuration, or application database into Git.
- Keep sign-ins, Chrome Remote Desktop registration, 1Password enrollment, and Google OAuth interactive.
- Never paste a Chrome Remote Desktop registration command, OAuth token, client secret, or `rclone.conf` into an issue or chat.
- Docker is not required for workstation setup.

## Update an existing checkout

```bash
cd ~/Developer/nathanialhenniges/linux-setup
git switch main
git pull --ff-only
./setup.sh status
```

## Start from a fresh Ubuntu install

```bash
sudo apt update
sudo apt install -y git
mkdir -p ~/Developer/nathanialhenniges
cd ~/Developer/nathanialhenniges
git clone https://github.com/nathanialhenniges/linux-setup.git
cd linux-setup
./setup.sh --dry-run bootstrap
./setup.sh bootstrap
```

## Apply managed workstation state

Repair and verify package sources first:

```bash
./setup.sh --dry-run sources
./setup.sh sources
ANSIBLE_FORCE_COLOR=0 ./setup.sh state
```

Apply each remaining layer. Review every dry run before its real run:

```bash
./setup.sh --dry-run base
./setup.sh base

./setup.sh --dry-run apps
./setup.sh apps

./setup.sh --dry-run tools
./setup.sh tools

./setup.sh --dry-run terminal
./setup.sh terminal

./setup.sh --dry-run codex
./setup.sh codex

./setup.sh --dry-run dotfiles
./setup.sh dotfiles

./setup.sh --dry-run gnome
./setup.sh gnome

./setup.sh --dry-run keybinds
./setup.sh keybinds
```

Log out and back in after GNOME, Toshy, launcher, or Chrome Remote Desktop host changes.

## Dotfiles source capture

On the finished source desktop, capture only the supported desktop profile:

```bash
cd ~/dotfiles
./sync.sh --profile linux-desktop
```

Review before committing. Do not capture secrets, browser state, tokens, keys, or application databases.

## Google Drive

The current playbook mounts one rclone remote named exactly `google-drive` at `~/Google Drive`. Configure that base remote as My Drive, not one Shared Drive. Workspace Shared Drives are not yet combined by this playbook.

```bash
rclone config
rclone listremotes
cd ~/Developer/nathanialhenniges/linux-setup
sudo -v
./setup.sh --dry-run drive
./setup.sh drive
```

For business use, prefer the company-owned Google OAuth desktop client. Keep its client secret and rclone token private. Do not select a Shared Drive while creating the base `google-drive` remote.

## AirPods and LibrePods

Pair AirPods through Ubuntu **Settings > Bluetooth** using Apple's normal pairing mode. LibrePods may display battery and device information after Bluetooth pairing. Never install Android root managers, Magisk modules, or phone-only components on Ubuntu.

## Chrome Remote Desktop

Chrome Remote Desktop has two independent directions. Configure only the host needed for each direction.

### Ubuntu MBA connects to MacBook Pro

The MacBook Pro is the host. The Ubuntu MBA is only a web client and needs no Linux host package.

On macOS:

```bash
cd ~/Developer/nathanialhenniges/dotfiles
git switch main
git pull --ff-only
brew bundle
```

Log out of macOS and back in. Open `https://remotedesktop.google.com/access`, install Google's official Chrome Remote Desktop extension, turn on remote access, name the Mac, set a strong PIN, and grant Accessibility and Screen Recording permissions.

On Ubuntu, open the same site in Chrome, select the MacBook Pro, and enter its PIN. Remember the PIN only on a trusted device.

### MacBook Pro connects to Ubuntu MBA

The Ubuntu MBA must also become a host. Open `https://remotedesktop.google.com/access` on Ubuntu, download Google's current 64-bit Debian host package, then install it:

```bash
sudo apt install ~/Downloads/chrome-remote-desktop_current_amd64.deb
```

If the site does not show **Turn On**, open `https://remotedesktop.google.com/headless`, authorize the same Google account, select Debian Linux, and run its generated command on Ubuntu. Ubuntu uses Debian packages; this page only registers the Ubuntu Desktop host and does not convert it into a headless server. That command contains a temporary authorization code; never share or save it. Name the host `Nathanials Air` and create a unique PIN.

On macOS, open `https://remotedesktop.google.com/access`, select `Nathanials Air`, and enter its PIN.

Linux unattended access creates a separate virtual desktop instead of mirroring the locally visible Ubuntu session. Log out of the local GNOME session if the remote session immediately closes. Use `https://remotedesktop.google.com/support` and a temporary code when the currently visible local session must be shared.

### Workspace hardening

- Register hosts with a standard Workspace user, not a Super Admin account.
- Enforce a passkey or 2-Step Verification.
- Use a unique PIN of at least eight digits and store it in 1Password.
- Remember a PIN only on an encrypted, trusted device.
- Enable automatic screen locking on both computers.
- Remove stale hosts from the Chrome Remote Desktop dashboard.
- In Google Admin, allow Chrome Remote Desktop only for the required user or organizational unit.

Workspace adds admin controls; it is not safer by account type alone.

## Manual acceptance

Launch and sign into the apps you use. Confirm at least Chrome, 1Password, Claude Desktop, ChatGPT, Cider, Ghostty, VS Code, Postman, Telegram, Plex, Upscayl, LibrePods, Toshy, and Chrome Remote Desktop. RustDesk is intentionally not managed.

Test:

- AirPods connect and play audio.
- Toshy shortcuts work after login.
- Google Drive appears in Files when configured.
- Ubuntu can connect to the MacBook Pro.
- MacBook Pro can connect to `Nathanials Air` when the Ubuntu host is configured.
- GNOME login branding and device name remain correct.

## SSH access to devboxes

Generate both keypairs on `Nathanials Air`. The private files are `~/.ssh/id_ed25519` and `~/.ssh/kommitai`; their shareable public files end in `.pub`.

First create the directory and confirm none of the four names already exists:

```bash
install -d -m 700 ~/.ssh
ls -l ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub ~/.ssh/kommitai ~/.ssh/kommitai.pub 2>/dev/null
```

If that command prints any existing file, stop and inspect it. Never overwrite an unknown key. If it prints nothing, generate the keys:

```bash
ssh-keygen -t ed25519 -a 100 \
  -f ~/.ssh/id_ed25519 \
  -C "nathanial@Nathanials-Air"

ssh-keygen -t ed25519 -a 100 \
  -f ~/.ssh/kommitai \
  -C "nathanial@Nathanials-Air-kommit"

chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519 ~/.ssh/kommitai
chmod 644 ~/.ssh/id_ed25519.pub ~/.ssh/kommitai.pub
```

Use strong passphrases. Load both keys into the current SSH agent and confirm their fingerprints:

```bash
ssh-add ~/.ssh/id_ed25519 ~/.ssh/kommitai
ssh-add -l
ssh-keygen -lf ~/.ssh/id_ed25519.pub
ssh-keygen -lf ~/.ssh/kommitai.pub
```

If `ssh-add` reports that it cannot connect to an agent, start a shell-local agent and repeat it:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519 ~/.ssh/kommitai
```

Only these two public-key commands are safe to copy or email:

```bash
cat ~/.ssh/id_ed25519.pub
cat ~/.ssh/kommitai.pub
```

Never email, upload, or paste `~/.ssh/id_ed25519` or `~/.ssh/kommitai`. Those are private keys.

### Authorize the MBA keys from the MacBook Pro

Use the MacBook Pro's existing SSH access. For each devbox, connect normally and append the corresponding single public-key line to `~/.ssh/authorized_keys`:

```bash
ssh REMOTE_USER@DEVBOX 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'
```

Paste one public-key line, press Enter, then press Control-D. Run the command once per key and destination. Replace `REMOTE_USER@DEVBOX` with the real user and host. Confirm remote permissions:

```bash
ssh REMOTE_USER@DEVBOX 'chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys'
```

### Configure Ubuntu SSH aliases

Edit `~/.ssh/config` without overwriting existing entries:

```bash
nano ~/.ssh/config
```

Add entries using the real usernames and hostnames:

```sshconfig
Host mrdemonwolf-dev
  HostName MRDEMONWOLF_HOST_OR_IP
  User REMOTE_USER
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes

Host kommit-dev
  HostName KOMMIT_HOST_OR_IP
  User REMOTE_USER
  IdentityFile ~/.ssh/kommitai
  IdentitiesOnly yes
```

Then lock permissions and test both aliases:

```bash
chmod 600 ~/.ssh/config
ssh mrdemonwolf-dev
ssh kommit-dev
```

Accept a new host fingerprint only after comparing it with a trusted value from the server or existing MacBook Pro configuration.

### VS Code, Claude Code, and Codex

`~/.ssh/config` is the source of truth. Do not paste private keys into editor or AI settings.

VS Code uses the same aliases through Remote - SSH:

```bash
code --install-extension ms-vscode-remote.remote-ssh
```

Open VS Code, run **Remote-SSH: Connect to Host**, then choose `mrdemonwolf-dev` or `kommit-dev`. A separate `remote.SSH.configFile` setting is unnecessary while using the default `~/.ssh/config`.

Claude Code needs no local SSH-key setting. Connect first, then start Claude Code on the devbox:

```bash
ssh mrdemonwolf-dev
cd /path/to/project
claude
```

Codex CLI follows the same pattern:

```bash
ssh kommit-dev
cd /path/to/project
codex
```

Codex desktop automatically detects remote hosts from `~/.ssh/config`. Restart Codex after adding aliases, select the remote host, then add the project from that host. No private key belongs in `~/.codex/config.toml`.

## Final state check

If Google Drive is configured, refresh sudo first because its package check uses privilege escalation:

```bash
cd ~/Developer/nathanialhenniges/linux-setup
sudo -v
ANSIBLE_FORCE_COLOR=0 ./setup.sh state
ANSIBLE_FORCE_COLOR=0 ./setup.sh verify
```

Expected result: no failed or unreachable tasks. Review any changed count before running another action.

## Common recovery

- `sudo: a password is required`: run `sudo -v`, then rerun only the failed action. Never run the entire setup script with `sudo`.
- Toshy source checkout not clean: inspect it with `git status`; move personal or generated files outside the checkout. Never delete unknown files automatically.
- Chrome Remote Desktop Linux session closes: log out of the local GNOME session, then reconnect to the virtual session.
- Chrome Remote Desktop host missing: use the headless registration page again; keep its generated command private.
- Google Drive remote wrong: use `rclone config`; keep the required name `google-drive` and My Drive as its root. Never hand-edit or publish `rclone.conf`.
