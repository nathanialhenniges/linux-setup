# AGENTS.md

## Scope

This repository bootstraps an Ubuntu 26.04 AMD64 **desktop workstation**. Keep it small, auditable, idempotent, and safe for a public repository.

## Frozen boundary

Never configure or invoke server/devbox behavior. Do not add `openssh-server`, Docker, tunnel creation, credentials, SSH keys, Git identity, or calls into dotfiles `server.sh`, `server-dev.sh`, `install.sh`, `config/server/**`, or `config/agent/**`.

Dotfiles may flow one way only: `linux-setup` may clone/update the expected repository and run its dedicated `linux-desktop.sh`. Fail closed if that file, origin, or clean checkout check fails.

After that dedicated desktop profile succeeds, `linux-setup` may make the packaged `/usr/bin/zsh` the current desktop user's login shell. Validate it against `/etc/shells`; never change root's shell or global shell configuration.

## Package rules

- Prefer Ubuntu packages.
- For vendor APT repos, use deb822 `.sources`, isolated `/etc/apt/keyrings` files, `Signed-By`, and a full documented fingerprint check.
- Never use `apt-key`, `trusted=yes`, PPAs, or `curl | sh`.
- Keep account authentication and Cloudflare enrollment manual.
- Keep `--dry-run` free of sudo, network, and writes.

## Checks

Run before every commit:

```bash
./tests/test_setup.sh
git diff --check
```

Review every tracked file for secrets and absolute personal paths before the first public push.
