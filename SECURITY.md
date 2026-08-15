# Security policy

## Scope

This repository configures one Ubuntu desktop workstation. Server, devbox, SSH-server, tunnel, and credential provisioning are out of scope.

## Reporting

Use GitHub's private vulnerability reporting for security issues. Do not open a public issue containing a token, key, private hostname, IP address, SSID, account detail, or log with personal data.

## Repository rules

- Never commit `.env` files, credentials, private keys, tokens, recovery codes, device identifiers, logs, or backups.
- Never embed personal email, Git identity, SSH hosts, Wi-Fi networks, 1Password URLs, or Cloudflare enrollment data.
- Use official Ubuntu packages or documented vendor repositories with isolated keyrings and full fingerprint checks.
- Never use `apt-key`, `trusted=yes`, or an unreviewed PPA.
- Never print, overwrite, or delete unrecognized APT source content. A shared source file may lose only an exact reviewed vendor line; all other bytes must remain unchanged. Refusals may report only its path, line count, and SHA-256 digest.
- Treat `/etc/default/claude-desktop` as root-executed input: read it only as data, accept only an empty file or the exact documented repository opt-out, require root ownership and mode `0644`, then write exact canonical content before package installation.
- Keep third-party provenance and license links in `THIRD-PARTY-NOTICES.md` current when an install source changes.
- `--dry-run` must remain free of `sudo`, downloads, and managed-state writes; only Ansible's ignored local temporary directory is allowed.
- Ansible must stay locked to the local workstation. Do not add remote inventory, server roles, or a catch-all action.
- Dotfiles integration may invoke only the dedicated `linux-desktop.sh` entry point.
- Never add calls to server/devbox scripts or `config/server/**` / `config/agent/**`.

The `codex` command makes no change. It points to OpenAI's official instructions because this repository does not execute an unpinned remote installer.
