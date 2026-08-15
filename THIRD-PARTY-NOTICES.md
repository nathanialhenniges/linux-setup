# Third-party notices and credits

This repository installs or configures third-party software but does not claim
ownership of it. Each project remains governed by its own license and vendor
terms. This file records provenance and does not replace those terms. The
original code and documentation in this repository are licensed separately
under the [MIT License](LICENSE).

Last reviewed: **2026-08-14**

## Reviewed immutable pins

The canonical SHA-256 values live beside the install logic in `vars.yml` for
downloaded artifacts and `setup.sh` for Git source trees. Change a pin and its
digest together, then run the repository checks.

| Component | Reviewed pin | How it is verified | Upstream credit and license |
|---|---|---|---|
| Oh My Posh | `v30.5.0` Linux AMD64 binary | Release URL and SHA-256 in `vars.yml` | [Release](https://github.com/JanDeDobbeleer/oh-my-posh/releases/tag/v30.5.0) · [MIT license at the pin](https://github.com/JanDeDobbeleer/oh-my-posh/blob/v30.5.0/COPYING) |
| CaskaydiaCove Nerd Font | Nerd Fonts `v3.5.0` Cascadia Code archive | Release URL and SHA-256 in `vars.yml` | [Release](https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.0) · [Cascadia Code SIL Open Font License 1.1 at the pin](https://github.com/ryanoasis/nerd-fonts/blob/v3.5.0/patched-fonts/CascadiaCode/LICENSE) · [Nerd Fonts license details](https://github.com/ryanoasis/nerd-fonts/blob/v3.5.0/LICENSE) and [license audit](https://github.com/ryanoasis/nerd-fonts/blob/v3.5.0/license-audit.md) |
| LibrePods | `linux-v0.1.0` x86-64 AppImage | Release URL and SHA-256 in `vars.yml` | [Release](https://github.com/librepods-org/librepods/releases/tag/linux-v0.1.0) · [AGPL-3.0 license at the pin](https://github.com/librepods-org/librepods/blob/linux-v0.1.0/LICENSE) |
| Toshy | `Toshy_v26.08.0`, commit `c39ee06d8d7fa299a082034d75275e6da97e0275` | Commit plus source-tree SHA-256 in `setup.sh` | [Release](https://github.com/RedBearAK/toshy/releases/tag/Toshy_v26.08.0) · [GPL-3.0 license at the pin](https://github.com/RedBearAK/toshy/blob/Toshy_v26.08.0/LICENSE) |
| xwaykeyz | Commit `7d6904cf64dee3bb52f1cea75040ae943bc8fe32` | Commit plus source-tree SHA-256 in `setup.sh` | [Pinned source](https://github.com/RedBearAK/xwaykeyz/tree/7d6904cf64dee3bb52f1cea75040ae943bc8fe32) · [GPL-3.0-or-later license at the pin](https://github.com/RedBearAK/xwaykeyz/blob/7d6904cf64dee3bb52f1cea75040ae943bc8fe32/LICENSE) |

These are reviewed pins, not claims that they are each upstream's newest
release. Reproducibility and on-device compatibility take priority over an
automatic version chase.

## Reviewed non-pinned routes

| Component | Route used here | Upstream credit or terms |
|---|---|---|
| ChatGPT desktop | Official mutable `latest` Linux preview `.deb`, gated by reviewed version `26.803.81509` and SHA-256; package-created key, source, and defaults are byte-verified before APT refresh | [Official Linux install](https://learn.chatgpt.com/docs/linux/linux-app) · OpenAI terms apply |
| Focused Window D-Bus | Pinned GNOME extension required by Toshy | [Pinned source](https://github.com/flexagoon/focused-window-dbus/tree/5ff336fac73b34deaf83f32772e8478885fa4925) · [MIT license](https://github.com/flexagoon/focused-window-dbus/blob/main/LICENSE) · [GNOME Extensions listing](https://extensions.gnome.org/extension/5592/focused-window-d-bus/) |
| Upscayl | Exact app ID `org.upscayl.Upscayl` from the verified system Flathub remote | [Flathub listing](https://flathub.org/apps/org.upscayl.Upscayl) · [Source](https://github.com/upscayl/upscayl) · [AGPL-3.0 license](https://github.com/upscayl/upscayl/blob/main/LICENSE) |
| Telegram Desktop | Exact app ID `org.telegram.desktop` from the verified system Flathub remote | [Official Linux download](https://telegram.org/desktop/linux) · [Flathub listing](https://flathub.org/apps/org.telegram.desktop) · [GPL-3.0 license](https://github.com/telegramdesktop/tdesktop/blob/dev/LICENSE) |
| Plex Desktop | Exact x86-64 app ID `tv.plex.PlexDesktop` from the verified system Flathub remote | [Flathub listing](https://flathub.org/apps/tv.plex.PlexDesktop) · Plex terms apply |
| Cider | Exact x86-64 app ID `sh.cider.Cider` from the reviewed system Flathub remote; proprietary license required | [Flathub listing](https://flathub.org/apps/sh.cider.Cider) · [Project](https://cider.sh/) · Cider terms apply |
| GitHub CLI | GitHub's signed APT repository | [Official Linux install](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) · [Source](https://github.com/cli/cli) · [MIT license](https://github.com/cli/cli/blob/trunk/LICENSE) |
| Visual Studio Code | Microsoft's signed APT repository | [Official Linux install](https://code.visualstudio.com/docs/setup/linux) · [Microsoft binary license](https://code.visualstudio.com/license) |
| Claude Desktop | Anthropic's signed Ubuntu/Debian APT repository with its documented package-repository opt-out; setup keeps one verified deb822 source and refuses unknown alternatives | [Official Linux install](https://code.claude.com/docs/en/desktop-linux) · [Help Center](https://support.claude.com/en/articles/10065433-install-claude-desktop) · Anthropic terms apply |
| Cloudflare WARP | Cloudflare's signed APT repository | [Official Linux install](https://developers.cloudflare.com/warp-client/get-started/linux/) · Cloudflare terms apply |
| Postman | Publisher-verified Snap named `postman` | [Official Linux install](https://learning.postman.com/docs/getting-started/installation/install-app/) · [Postman terms](https://www.postman.com/legal/terms/) |
| Google Docs, Sheets, and Slides launcher icons | Product favicons downloaded from official `docs.google.com` or `ssl.gstatic.com` URLs and gated by reviewed SHA-256 values | [Google product icon guidance](https://about.google/brand-resource-center/products-and-services/) · Google terms apply |
| Notion launcher icon | Product favicon downloaded from Notion's official site and gated by its reviewed SHA-256 | [Notion for desktop and web](https://www.notion.com/help/notion-for-desktop) · Notion terms apply |
| Quo launcher icon | Product icon downloaded from `my.quo.com` and gated by its reviewed SHA-256 | [Quo](https://www.quo.com/) · Quo terms apply |
| Ubuntu packages | Ubuntu 26.04 archives, including Ansible, Ghostty, OBS Studio, Flatpak, and CLI tools | [Ubuntu package index](https://packages.ubuntu.com/resolute/allpackages); installed copyright and license metadata is under `/usr/share/doc/<package>/copyright` |

Codex is reference-only here: `./setup.sh codex` points to the
[official OpenAI Codex repository](https://github.com/openai/codex) and does
not install it.
