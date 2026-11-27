<div align="center">

# 🏛️ Pantheon

### A minimal, configurable baseline for a headless Ubuntu Server

![Platform](https://img.shields.io/badge/Platform-Ubuntu%20Server%2026.04%2B-E95420)
![Language](https://img.shields.io/badge/Language-Bash-4EAA25)

One CLI that takes a fresh Ubuntu Server install to a hardened, Docker-ready host: storage, packages, unattended
upgrades, Docker, Tailscale, key-only SSH, a firewall and fail2ban. Nothing else: what runs on the server is up to you.

**[📚 Documentation](docs/README.md)** · [Installation](docs/installation.md) · [Security](docs/security.md) ·
[CLI](docs/cli.md)

</div>

---

## ✨ Highlights

| Feature                   | What it gives you                                                                                 |
| ------------------------- | ------------------------------------------------------------------------------------------------- |
| **Hardened access**       | Key-only SSH on a port of your choice (default `2222`), `AllowUsers`, fail2ban, deny-incoming UFW |
| **Docker-ready**          | Docker Engine and Compose from Docker's repository, your user in the `docker` group               |
| **Tailnet-ready**         | The Tailscale agent for SSH over your tailnet                                                     |
| **Kept up to date**       | Unattended upgrades                                                                               |
| **Configurable defaults** | Every value comes from a prompt, a flag or an env var; re-runs keep the values you chose          |
| **Opt-in extras**         | Homebrew with `bottom`, the Starship prompt and Ghostty terminfo, only if you want them           |

## 🚀 Quick start

**Requires** a fresh [Ubuntu Server](https://ubuntu.com/download/server) 26.04 LTS or newer, with a non-root `sudo`
user, OpenSSH and your SSH key on that user.

```bash
# 1. Install the latest release into ~/pantheon
curl -fsSL https://github.com/rozsival/pantheon/releases/latest/download/install.sh | bash

# 2. Run the setup: it prompts for every value, pre-filled with the defaults
cd ~/pantheon
sudo ./bin/pantheon setup

# 3. Before closing this session, connect a second one on the new port
ssh -p 2222 <user>@<server-ip>
```

> [!WARNING]
> After `setup`, SSH accepts **keys only, on the port you chose**. Keep your current session open until a second one
> connects.

## 🧭 The stack

Pantheon is also the name of the author's own home server, and this repository is its baseline. The projects around
it each document only their own part:

| Project                                                    | Runs on                   | Role                                                                              |
| ---------------------------------------------------------- | ------------------------- | --------------------------------------------------------------------------------- |
| **Pantheon**                                               | The home server           | This baseline: hardened SSH, a firewall, Docker and Tailscale                     |
| [Panther Minor](https://github.com/rozsival/panther-minor) | Pantheon                  | The AI inference stack: AMD GPU drivers, ROCm, LLMs, image generation, monitoring |
| [Devbox](https://github.com/rozsival/devbox)               | Pantheon                  | The containerised development environment where coding agents run                 |
| [Dotfiles](https://github.com/rozsival/dotfiles)           | The macOS laptop          | The laptop that drives Devbox: tools, agents, keys in 1Password                   |
| [Janus](https://github.com/rozsival/janus)                 | A Raspberry Pi next to it | Power control for Pantheon: on, off and reset from a dashboard or an API          |

None of them is required: Pantheon is a general baseline, and none of them requires Pantheon either.

## 📚 Documentation

Installation, the setup steps, the security model, the CLI and development live in **[docs/](docs/README.md)**.

## 👤 Ownership

| Item       | Details                                                                   |
| ---------- | ------------------------------------------------------------------------- |
| Maintainer | [@rozsival](https://github.com/rozsival) (see [`CODEOWNERS`](CODEOWNERS)) |
| Issues     | [GitHub Issues](https://github.com/rozsival/pantheon/issues)              |
| License    | [MIT](LICENSE)                                                            |
