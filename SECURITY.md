# Security policy

Report vulnerabilities through GitHub's private vulnerability reporting. Do not open a public issue containing credentials, keys, tokens, private hostnames, Wi-Fi details, or logs with personal data.

Repository rules:

- Keep Ansible local and limited to the `workstation` inventory group.
- Never store credentials, SSH keys, browser profiles, OAuth tokens, or Git identity.
- Do not install or configure Docker, `sshd`, tunnels, or server/devbox tooling on the target workstation. Development and CI container tests run separately with no host credentials or devices mounted.
- `--dry-run` must not use sudo, network access, or write managed state.
- Verify checksums for pinned downloaded artifacts and exact Flathub origins.
- Update [third-party notices](THIRD-PARTY-NOTICES.md) when package or artifact sources change.
