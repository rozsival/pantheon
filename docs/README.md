# 📚 Pantheon Documentation

> Entry point to the Pantheon documentation. Each page covers **one domain**, opens with a one-paragraph summary,
> links its related pages, and ends with an FAQ where one is useful.

New here? Start with [Installation](installation.md). The project overview and quick start live in the
[root README](../README.md).

---

## 🗂️ Document index

| Document                        | Read when you want to…                          | Key topics                                                   |
| ------------------------------- | ----------------------------------------------- | ------------------------------------------------------------ |
| [Installation](installation.md) | Take a fresh Ubuntu Server to the baseline      | OS install, installer, `setup` steps, extras, host Tailscale |
| [Security](security.md)         | Understand what is exposed and how it is locked | SSH hardening, UFW, Docker and the firewall, fail2ban        |
| [CLI reference](cli.md)         | Look up a `./bin/pantheon` command              | Command tree, flags, env vars, `update`, maintainer workflow |
| [Development](development.md)   | Contribute, run checks or cut a release         | Toolchain, checks, commit rules, releases, agent skills      |

## ✍️ Documentation conventions

| Rule            | Detail                                                                                                      |
| --------------- | ----------------------------------------------------------------------------------------------------------- |
| Location        | All user and maintainer docs live in `docs/`, one domain per file, kebab-case names                         |
| Page shape      | `# Title` → summary quote → **Related** line → sections → `## ❓ FAQ` (when useful)                         |
| Source of truth | `cli/` wins; docs explain it                                                                                |
| Scope           | Only the baseline. Whatever runs on top of it (an AI stack, a dev environment) documents itself elsewhere   |
| Agent context   | `AGENTS.md` and `.agents/skills/*/SKILL.md` stay where their tools look                                     |
| Formatting      | Prettier (`printWidth: 120`) via `pnpm run fix`; GitHub-flavored Markdown with alerts                       |
| Versions        | Docs carry no release tag: the README installs `releases/latest`; the `release` skill bumps versioned files |
