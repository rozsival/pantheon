---
name: cli-command
description: >
  Add, edit, or regenerate subcommands and flags on the Bashly-powered `./bin/pantheon`. Use when the user
  says "add a CLI command", "add a flag to ./bin/pantheon", "change the CLI", "regenerate the CLI", or "add a
  bashly subcommand".
---

You are the CLI maintainer for the Pantheon Bashly CLI. `./bin/pantheon` is powered by
[Bashly](https://bashly.dev/) and built from authored sources under `cli/`. Follow this workflow
precisely — see `docs/cli.md` for the human-facing summary of the same rules.

## The one rule that matters

> [!IMPORTANT]
> Never edit `./bin/pantheon` directly. It is a generated artifact — **roughly 3k lines**, including the
> inlined Bashly completion engine — built from `cli/*` by `bashly generate`. Reading it burns tens of
> thousands of tokens for no benefit, and any hand
> edit is silently discarded the next time someone runs `pnpm run build:cli`. Edit the authored sources
> in `cli/` instead, then regenerate.

## Files you edit

| Path                                | Responsibility                                                                                          |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `cli/bashly.yml`                    | Schema source of truth: command tree, flags, args, examples, env vars, `version`                        |
| `cli/commands/<group>/<cmd>.sh`     | Command entrypoint (the function Bashly calls for that leaf command); path = command name, spaces → `/` |
| `cli/lib/*.sh`                      | Shared helper logic (`logging.sh`, `core.sh`, `setup.sh`, `install.sh`, `update.sh`)                    |
| `cli/lib/validations/validate_*.sh` | Custom argument validators referenced from `bashly.yml` via `validate: <name>`                          |
| `cli/initialize.sh`                 | Globals set before any command runs                                                                     |
| `bashly-settings.yml`               | Bashly settings (`completions: full` enables the native bash/zsh completion engine)                     |

Existing validators — reuse one of these instead of inventing a new one if the argument shape already
fits:

| Validator            | Checks                                  |
| -------------------- | --------------------------------------- |
| `validate_not_empty` | Value is non-blank                      |
| `validate_port`      | Value is an integer between 1 and 65535 |

A validator function prints nothing on success and an error message to stdout (via `echo`) on failure —
Bashly captures that string and reports it as the flag/arg error. Look at
`cli/lib/validations/validate_port.sh` for the exact shape before
writing a new one.

## Workflow

1. **Edit `cli/bashly.yml` first.** Add the command/flag/arg/env var under the right `commands:`
   nesting. Nested subcommands (e.g. `setup ufw`) are nested `commands:` blocks — match the
   existing indentation and structure exactly. Reuse `validate:`, `completions:`, and `examples:` keys
   the way sibling entries already do.
2. **Add or edit the authored command file.** A new leaf command named `<group> <subgroup> <cmd>` needs
   `cli/commands/<group>/<subgroup>/<cmd>.sh` (Bashly maps spaces to `/` and keeps hyphens, e.g.
   `setup ufw` → `cli/commands/setup/ufw.sh`) defining a `pantheon_<group>_<cmd>()`
   function (follow the naming pattern already used by sibling files, e.g. `cli/commands/setup/ufw.sh` defines and calls
   `pantheon_setup_ufw`). Put shared logic used by more than one command in `cli/lib/*.sh`, not
   duplicated across command files. Quote `args` keys with a hyphen inside the name:
   `${args['--lvm-device']}`, never `${args[--lvm-device]}` — the shell formatter reads an unquoted subscript as
   arithmetic and rewrites it to `--lvm - device`, a different key, so the flag silently stops working.
3. **Add a validator only if none of the existing ones fit**, in
   `cli/lib/validations/validate_<name>.sh`, then reference it from `bashly.yml` with
   `validate: <name>`.
4. **Regenerate:**
   ```bash
   pnpm run build:cli
   ```
   This runs `bashly generate` from the repo root, configured by `bashly-settings.yml` (`source_dir: cli`,
   `commands_dir: commands`, `target_dir: bin`, `env: production`) — do not run bare `bashly generate --force` yourself. `--force`
   recreates placeholder command files and silently overwrites the authored bodies you just wrote. The
   project's `build:cli` script intentionally omits `--force`.
5. **Validate the result:**
   ```bash
   pnpm run check   # Prettier (shell included) and ShellCheck on bin/pantheon
   bash -n ./bin/pantheon
   ./bin/pantheon --help
   ./bin/pantheon <group> --help
   ./bin/pantheon <group> <cmd> --help
   ```
   Then actually invoke the new/changed command (with real or representative arguments) and confirm the
   output and exit code are correct.

## Conventions to enforce

- **Status output** goes through `pantheon_log_info`, `pantheon_log_success`, `pantheon_log_warn`, and
  `pantheon_log_error` (defined in `cli/lib/logging.sh`) — never bare `echo` for user-facing status.
  `pantheon_log_error` prints to stderr and exits `1`; use it for fatal validation failures inside a
  command body.
- **Env var support is declared per command** under `environment_variables:` in `bashly.yml`, not
  assumed. Bashly exposes `pantheon_ssh_port` as `PANTHEON_SSH_PORT`. Resolve flag-vs-env-vs-default
  precedence with `pantheon_resolve_option '--flag' ENV_VAR 'default'` from `cli/lib/core.sh` (flag wins,
  then the env var, then the default) — see `pantheon_resolve_setup_context` in `cli/lib/setup.sh`.
- **Defaults are configurable and re-runs are safe.** Every new setting gets a flag and an env var, and a
  step run a second time must keep the operator's values. Anything destructive (a reset, a deleted file) is
  documented, and opt-in where that is possible.
- **Follow-ups** the operator must do (reboot, re-login, a second SSH session) go through
  `pantheon_register_action`, so `setup all` lists them at the end.
- **Completions** are generated natively by Bashly 2 (`completions: full` in `bashly-settings.yml`; no
  `send_completions.sh` lib file) and exposed by `./bin/pantheon completions [bash|zsh]`
  (`cli/commands/completions.sh`); `./bin/pantheon install` writes the bash script where
  bash-completion lazy-loads it. Smoke-test with `./bin/pantheon __complete <words...> ""` from outside the
  repository.

## Checklist: what else to update when the command tree changes

- `docs/cli.md` — the command reference (`## 📖 Command reference`) for any added/changed command or flag, and
  the command-group table (`## 🗂️ Command groups`) if you added/removed a top-level group.
- `AGENTS.md`, `docs/installation.md` and `docs/security.md` — if the new/changed command is user-facing
  and those pages describe it.
- Shell completions — nothing to do: every `<TAB>` asks `bin/pantheon __complete`, so
  `pnpm run build:cli` is enough.

## Error handling

- **`./bin/pantheon` behaves differently than `cli/` suggests it should.** The generated artifact is out
  of sync with its sources. Run `pnpm run build:cli` and re-test; never hand-patch `./bin/pantheon` to paper
  over the mismatch.
- **`bash -n ./bin/pantheon` reports a syntax error.** The line number is inside the generated file, but the
  bug is almost always in the authored `cli/commands/**/*.sh` or `cli/lib/*.sh` file that was
  spliced in at that point — find the corresponding authored file and fix it there, then regenerate.
- **A validator "fails silently" (bad input is accepted, or a good input is rejected with no clear
  reason).** Validator functions communicate failure purely by printing a non-empty string to stdout;
  a validator that does `return 1` without echoing anything looks like success to Bashly. Check that
  every failure path in the `validate_*.sh` file emits an `echo` message before returning.
