# 🛠️ Installation

> From a fresh Ubuntu Server install to the baseline: what the OS install needs, the curl installer, one `setup`
> command that prepares and hardens the host, the optional extras, and joining the tailnet.

**Related:** [Security](security.md) · [CLI reference](cli.md)

---

## 🧰 Prerequisites

- 🐧 [Ubuntu Server](https://ubuntu.com/download/server) **26.04 LTS or newer**
- A non-root user with `sudo` privileges, created during the OS install. This is the **allowed user**: the only
  account SSH will accept afterwards
- OpenSSH enabled during the install, with your public key on that user (the installer can fetch it from GitHub).
  `setup ssh` turns password logins off, so a key must already work
- An account that is not locked. The Ubuntu Server installer sets a password, which is enough. A key-only user from
  a cloud image or autoinstall often has a locked password (`!` in `/etc/shadow`), and the hardened sshd refuses every
  login to a locked account, keys included. `setup ssh` stops before changing anything in that case; fix it with
  `sudo passwd <user>`, or `sudo usermod -p '*' <user>` for key logins only
- Optional: a [Tailscale](https://tailscale.com/) tailnet, for SSH over Tailscale

> [!TIP]
> The installer's default LVM layout leaves most of the disk unallocated; `setup init` claims it. A disk installed
> without LVM works too: the storage step is skipped.

## 📦 Install

SSH into the server as the allowed user (not `root`) and run:

```bash
curl -fsSL https://github.com/rozsival/pantheon/releases/latest/download/install.sh | bash
```

The installer downloads the latest release's runtime archive (`pantheon.tar.gz`) into `~/pantheon`. Set `PANTHEON_DIR`
to install elsewhere (`curl … | PANTHEON_DIR=/srv/pantheon bash`). It needs only `curl` and `tar`, refuses a non-empty
directory, and changes nothing on the host: that is the next step.

The archive holds only `bin/pantheon`, `terminfo/` and `LICENSE`, plus a `.manifest` (the shipped files) and a
`.release` (the installed version), both read by [`update`](cli.md#update).

## 🚀 Run the setup

```bash
cd ~/pantheon
sudo ./bin/pantheon setup
```

`setup` defaults to `setup all`. It prompts for each value, pre-filled from flags, `pantheon_*` environment variables
or the defaults below, asks whether to install the extras, shows a summary and asks for confirmation. Then it runs the
core steps, then the extras if you said yes, puts `pantheon` on the allowed user's `PATH` ([`install`](cli.md#install))
and ends with an **ACTIONS REQUIRED** list.

| Setting      | Default                                 | Flag             | Env var                 |
| ------------ | --------------------------------------- | ---------------- | ----------------------- |
| Server name  | Host name                               | `--server-name`  | `pantheon_server_name`  |
| Allowed user | The user running `sudo`                 | `--allowed-user` | `pantheon_allowed_user` |
| SSH port     | `2222`                                  | `--ssh-port`     | `pantheon_ssh_port`     |
| Timezone     | The host's current one (left unchanged) | `--timezone`     | `pantheon_timezone`     |
| LVM device   | `/dev/ubuntu-vg/ubuntu-lv`              | `--lvm-device`   | `pantheon_lvm_device`   |
| Extras       | Asked (no)                              | `--extras`       | `pantheon_extras=1`     |

`2222` is a recommendation, not a requirement: any free port works, and moving SSH off `22` mostly keeps scanner noise
out of the logs.

### Core steps

| #   | Step        | What it does                                                                                                     |
| --- | ----------- | ---------------------------------------------------------------------------------------------------------------- |
| 1   | `init`      | Extends the LVM root volume to the whole disk (skipped without one); sets the timezone if it differs             |
| 2   | `packages`  | Upgrades the system; installs `build-essential`, `jq`, `htop`, `augeas-tools` and more, plus unattended upgrades |
| 3   | `docker`    | Docker Engine, Buildx and Compose from Docker's repository; adds the allowed user to `docker`                    |
| 4   | `tailscale` | The Tailscale agent for the host (SSH over the tailnet)                                                          |
| 5   | `ssh`       | Hardened `sshd_config`: the chosen port, key-only auth, `AllowUsers` restricted; rolls back on failure           |
| 6   | `ufw`       | Denies incoming traffic, allows the SSH port; keeps rules other services added                                   |
| 7   | `fail2ban`  | Bans brute-force attempts on the SSH port; tailnet addresses are never banned                                    |

### Extras

| Step    | What it does                                                                                                                             |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `brew`  | Homebrew for the allowed user, and [`bottom`](https://github.com/ClementTsang/bottom) (a system monitor)                                 |
| `shell` | The [Starship](https://starship.rs/) prompt, `xterm-ghostty` terminfo in `/etc/terminfo`, linger for the allowed user's systemd services |

> [!TIP]
> Every step can be run on its own, e.g. `sudo ./bin/pantheon setup ssh --ssh-port 2200`, and every step is safe to
> re-run. Flags per step are in the [CLI reference](cli.md#setup).

### After the setup

The **ACTIONS REQUIRED** list names what is left. Typically:

1. Open a second SSH session on the new port before closing the current one: `ssh -p 2222 <user>@<server-ip>`.
2. Log out and back in, so the `docker` group applies to your session.
3. Join the tailnet (below).

## 🔐 Connect the host to Tailscale

```bash
sudo tailscale up
```

Follow the printed link to authenticate, then reconnect through Tailscale: `ssh -p 2222 <user>@<server-name>`.

> [!TIP]
> [Disable key expiry](https://login.tailscale.com/admin/machines) for the server in Tailscale, so you never lose
> access when the node key expires.

If something on the server runs its own Tailscale node in a container (a sidecar), give the host a different name, or
the sidecar comes up as `<name>-1`. Renaming the host:

```bash
sudo hostnamectl set-hostname <name>
sudo sed -i 's/\b<old-name>\b/<name>/g' /etc/hosts   # the 127.0.1.1 line, or sudo cannot resolve the host
sudo tailscale set --hostname=<name>                 # if the host is on the tailnet
```

## 🔄 Updating

```bash
pantheon update            # the latest release; or a tag, or a branch
```

`update` replaces the installed files only. Nothing on the host changes until you re-run a setup step. See
[CLI reference](cli.md#update).

---

## ❓ FAQ

### I lost SSH access after `setup ssh`. What happened?

SSH moved to the chosen port with key-only auth and an `AllowUsers` list. Always open a second session on the new port
before closing the current one. `setup ssh` validates the new configuration and rolls back when `sshd` rejects it or
nothing listens on the port, but it cannot know whether your key works. From the console, restore the original
configuration and open its port again:

```bash
sudo cp /etc/ssh/sshd_config.orig /etc/ssh/sshd_config
sudo systemctl daemon-reload        # Ubuntu's ssh.socket takes the port from sshd_config only on a reload
sudo systemctl restart ssh.socket
sudo ufw allow 22/tcp
```

The drop-ins `setup ssh` moved out of `/etc/ssh/sshd_config.d/` stay in `/etc/ssh/sshd_config.d.pantheon-<timestamp>/`;
move them back if you need them.

### Can I use it on a server that already runs things?

Yes, with three things to know. `ufw` adds its rules next to the existing ones (`--reset` is opt-in). `ssh` keeps
every `sshd_config` setting it does not manage, but **moves the drop-ins out of `/etc/ssh/sshd_config.d/`** (into
`/etc/ssh/sshd_config.d.pantheon-<timestamp>/`), since they would override the hardening (a cloud image's
`50-cloud-init.conf` turns password logins back on, for example).
`packages` upgrades the system.

### Why does a re-run not change my timezone?

The default is the zone the host already has. Pass `--timezone <zone>` (or type it at the prompt) to change it.

### Can I skip a step?

Run the steps you want one by one instead of `setup all`. The order in [Core steps](#core-steps) is the dependency
order: `packages` installs `augeas-tools`, which `ssh` needs.

### Do I need the extras?

No. They are conveniences for an interactive operator. Run `sudo ./bin/pantheon setup brew` or `setup shell` later if
you change your mind.
