# 🔒 Security

> After setup, the only way in from the network is SSH: one port, keys only, one allowed user, brute-force attempts
> banned. Everything else is denied by UFW, with one well-known exception, Docker-published ports, which services
> should publish on loopback or reach through a tailnet node instead.

**Related:** [Installation](installation.md) · [CLI reference](cli.md)

---

## 🔐 Security model

| Layer     | Behavior                                                                                                   |
| --------- | ---------------------------------------------------------------------------------------------------------- |
| SSH       | The chosen port (default `2222`), public keys only, `AllowUsers` restricted to the allowed user, no root   |
| UFW       | Denies incoming traffic except the SSH port; allows outgoing                                               |
| fail2ban  | Bans an address for 1 hour after 3 failed SSH logins within 10 minutes; loopback and tailnet ranges exempt |
| Tailscale | Optional: SSH over the tailnet, so the SSH port need not be reachable from the internet at all             |
| Updates   | Unattended upgrades install security updates automatically                                                 |

### SSH hardening

`setup ssh` edits `/etc/ssh/sshd_config` with Augeas and sets:

| Setting                                                  | Value            |
| -------------------------------------------------------- | ---------------- |
| `Port`                                                   | The chosen port  |
| `PasswordAuthentication`, `KbdInteractiveAuthentication` | `no`             |
| `PubkeyAuthentication`                                   | `yes`            |
| `AuthenticationMethods`                                  | `publickey`      |
| `UsePAM`                                                 | `no`             |
| `PermitRootLogin`                                        | `no`             |
| `MaxAuthTries`                                           | `3`              |
| `LoginGraceTime`                                         | `30`             |
| `X11Forwarding`, `AllowTcpForwarding`                    | `no`             |
| `AllowUsers`                                             | The allowed user |

Before anything changes, the step refuses an allowed user whose account is locked (a password field starting with
`!`): with `UsePAM no`, sshd checks the account itself and refuses every login to a locked one, keys included.

The edit is made to a staged copy, validated with `sshd -t`, and only then installed. Drop-ins in
`/etc/ssh/sshd_config.d/` are moved to `/etc/ssh/sshd_config.d.pantheon-<timestamp>/`, because they would override
these settings: copy anything you need from there into `sshd_config` itself. If restarting SSH fails, or nothing listens on the new port afterwards, the previous
configuration and the drop-ins are restored. The
untouched original is kept as `/etc/ssh/sshd_config.orig`.

> [!NOTE]
> `AllowTcpForwarding no` also blocks `ssh -L` tunnels. If you reach services on the server's loopback through SSH
> tunnels, set it back to `yes` in `/etc/ssh/sshd_config`, or reach them over the tailnet.

### Firewall

`setup ufw` sets the defaults (deny incoming, allow outgoing), allows the SSH port and enables UFW. It **adds** to the
existing rules, so rules other services added survive a re-run. `setup ufw --reset` deletes every rule first, for a
clean slate. A rule for an earlier SSH port is never removed automatically: check `sudo ufw status numbered` and
`sudo ufw delete <number>` after changing the port.

### Why Docker ports bypass UFW

Docker publishes ports with `nat/PREROUTING` DNAT, so packets for a container are _forwarded_, not delivered locally.
They never traverse the `INPUT` chain UFW manages, and `ufw deny 8000` cannot block a published port
([moby/moby#17496](https://github.com/moby/moby/issues/17496)). Two reliable alternatives:

- **Publish on loopback** (`127.0.0.1:8000:8000`): the DNAT rule itself only matches loopback, so the exposure does
  not exist.
- **A Tailscale sidecar** in the Compose project: the service gets its own tailnet node and needs no published port at
  all.

### fail2ban

`setup fail2ban` writes `/etc/fail2ban/jail.local` with one `sshd` jail on the SSH port (systemd backend). `ignoreip`
covers loopback and the Tailscale ranges (`100.64.0.0/10`, `fd7a:115c:a1e0::/48`), so a typo over the tailnet never
locks you out.

## 🛠️ Where it is defined

| File                             | Responsibility                              |
| -------------------------------- | ------------------------------------------- |
| `cli/commands/setup/ssh.sh`      | SSH settings, staging, validation, rollback |
| `cli/commands/setup/ufw.sh`      | Firewall defaults and the SSH rule          |
| `cli/commands/setup/fail2ban.sh` | The `sshd` jail                             |
| `cli/commands/setup/packages.sh` | Unattended upgrades                         |

---

## ❓ FAQ

### Can I keep SSH on port 22?

Yes: `--ssh-port 22`. A non-standard port is no protection by itself; it only keeps automated scanners out of the logs.

### How do I unban an address?

`sudo fail2ban-client set sshd unbanip <ip>`. `sudo fail2ban-client status sshd` lists the banned ones.

### Should the SSH port be reachable from the internet at all?

Only if you need it without Tailscale. With the host on the tailnet, you can keep the port closed at the router and
SSH over Tailscale only.
