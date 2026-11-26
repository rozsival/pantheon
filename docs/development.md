# 🧪 Development

> How to work on Pantheon itself: toolchain, quality checks, commit rules, CI, releases, and the agent assets that
> automate recurring maintenance.

**Related:** [CLI reference](cli.md#-maintainer-workflow) · [Documentation index](README.md)

---

## 🧰 Toolchain

| Tool       | Version / config                                                                              | Role                                                                                    |
| ---------- | --------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Node.js    | `26.x` (`engines`)                                                                            | Runs the tooling below; nothing on the server needs it                                  |
| pnpm       | `packageManager` in `package.json`                                                            | Package manager and script runner                                                       |
| Prettier   | `prettier.config.js` (`printWidth: 120`)                                                      | Markdown, YAML, JSON, TOML and shell (`*.sh`, via `prettier-plugin-sh` as `shfmt -i 2`) |
| ShellCheck | System binary on `PATH` (`brew install shellcheck`); CI pins `SHELLCHECK_VERSION` in `ci.yml` | Lints `bin/pantheon` (which holds every `cli/` source) and `release/*.sh`               |
| Bashly     | `bashly-settings.yml` (`gem install bashly` or `brew install bashly`)                         | Generates `bin/pantheon` from `cli/`                                                    |
| Lefthook   | `lefthook.yml`                                                                                | Git hooks                                                                               |
| commitlint | `commitlint.config.js`                                                                        | Conventional Commits enforcement                                                        |
| Renovate   | `renovate.json`                                                                               | Dependency updates                                                                      |

```bash
pnpm install   # also installs the Git hooks outside CI
```

## ✅ Quality checks

| Task                       | Command              |
| -------------------------- | -------------------- |
| Check formatting and shell | `pnpm run check`     |
| Auto-fix formatting        | `pnpm run fix`       |
| Regenerate the CLI         | `pnpm run build:cli` |

There are no automated tests of the setup steps: they change a whole host. Test a change on a throwaway Ubuntu Server
26.04 VM (or, for steps that need no systemd, an `ubuntu:26.04` container) before releasing it.

### Git hooks

| Hook         | Runs                                                                                                       |
| ------------ | ---------------------------------------------------------------------------------------------------------- |
| `commit-msg` | `commitlint`                                                                                               |
| `pre-commit` | Prettier, then `build:cli`, then ShellCheck on shell changes; Prettier on everything else; fixes re-staged |

## 📝 Rules

1. **Scope** — only a generic server baseline. Anything a specific workload needs belongs to that workload's project.
2. **Packages** — `apt-get` only in scripts, never `apt`.
3. **Commits** — [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/), lowercase, no final
   punctuation, ≤ 100 characters.
4. **CLI** — follow the [maintainer workflow](cli.md#-maintainer-workflow).
5. **Docs** — follow the [documentation conventions](README.md#-documentation-conventions).

## 🔁 CI and releases

| Workflow                        | Trigger                        | Jobs                                                                                                                                                      |
| ------------------------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/workflows/ci.yml`      | Push / PR to `main`            | `qa`: commitlint, `prettier --check`, ShellCheck                                                                                                          |
| `.github/workflows/release.yml` | Push to `main` or tag `v*.*.*` | On a `chore(release): vX.Y.Z` commit: tags it, publishes a GitHub release with a commit changelog, the runtime archive `pantheon.tar.gz` and `install.sh` |

Releases go through a `release/vX.Y.Z` branch: bump every version-carrying file (`cli/bashly.yml`, `package.json`),
commit as `chore(release): vX.Y.Z` and open a PR. Rebase-merging it is the release: `release.yml` creates the tag on
the merged commit, since a tag pushed with `GITHUB_TOKEN` would not trigger a workflow. A missed release is recovered
by pushing the `vX.Y.Z` tag onto its release commit yourself. The `release` agent skill prepares the PR, stops for your
merge, then watches the release run and verifies the tag.

### Runtime archive

Servers never get a Git checkout. `release/package.sh` defines what an install holds (`bin/pantheon`, `terminfo/`,
`LICENSE`) and writes it with a `.manifest` (the shipped files) and `.release` (channel, ref, commit). The release
workflow tars that tree as `pantheon.tar.gz`; `release/install.sh`, uploaded next to it, is the curl installer.
`pantheon update <branch>` runs the branch's own `package.sh` on its source tarball.

> [!IMPORTANT]
> A new file a setup step reads at runtime must be added to `runtime_paths` in `release/package.sh`, or installs and
> updates silently lack it. Check with `release/package.sh . /tmp/pt release v0.0.0 HEAD && cat /tmp/pt/.manifest`.

## 🤖 Agent assets

| Asset                         | Purpose                                            |
| ----------------------------- | -------------------------------------------------- |
| `AGENTS.md`                   | Project context and rules for AI assistants        |
| `.agents/plans/`              | Feature plans, `YYYY-MM-DD-<short-description>.md` |
| `.agents/skills/cli-command/` | Add or change Bashly CLI commands and flags        |
| `.agents/skills/release/`     | Version bump on a release branch and PR to `main`  |
