#!/usr/bin/env bash

# Core steps in dependency order: init prepares the disk and clock, packages
# installs the tooling (augeas for ssh, jq for update), then docker, tailscale,
# ssh, ufw and fail2ban bring the platform up and lock it down. The extras are
# conveniences for the operator, not part of a minimal server.
declare -ga PANTHEON_CORE_STEPS=(init packages docker tailscale ssh ufw fail2ban)
declare -ga PANTHEON_EXTRA_STEPS=(brew shell)

# These are the same functions './bin/pantheon setup <step>' dispatches to, so
# each step has one implementation.
pantheon_setup_all() {
  local step
  local -a steps=("${PANTHEON_CORE_STEPS[@]}")

  [[ "$PANTHEON_EXTRAS" != 1 ]] || steps+=("${PANTHEON_EXTRA_STEPS[@]}")

  # A fresh list per run: the file lives in /tmp across runs, and the summary
  # must not repeat what an earlier run asked for.
  : >"$PANTHEON_ACTIONS_FILE"

  for step in "${steps[@]}"; do
    "pantheon_setup_${step}_command"
  done

  # As the user, after the steps above, so its login-shell checks see the shell
  # they will get. A failed check is a follow-up, not a reason to abort.
  pantheon_log_info "Putting pantheon on ${PANTHEON_ALLOWED_USER}'s PATH..."
  if ! sudo -u "$PANTHEON_ALLOWED_USER" -H "$PANTHEON_CLI_BIN" install; then
    pantheon_register_action "Fix what 'pantheon install' reported above, then re-run ./bin/pantheon install as ${PANTHEON_ALLOWED_USER}."
  fi

  # Prints the ACTIONS REQUIRED list the steps registered along the way (SSH
  # port confirmation, Tailscale authentication, docker group re-login). Nothing
  # else calls it, so without this a full run ends without ever showing them.
  pantheon_print_setup_summary "${steps[@]}"
}

pantheon_prompt_value() {
  local label="$1" current="$2" reply
  read -r -p "Enter ${label} (default: ${current}): " reply
  printf '%s\n' "${reply:-$current}"
}

# Interactive setup that prompts for every value, pre-filled from flags, env
# vars and defaults.
pantheon_interactive_setup() {
  pantheon_require_root
  pantheon_resolve_setup_context

  # PANTHEON_EXTRAS arrives as the 'pantheon_extras' env var and is normalized
  # to 0 or 1 here.
  declare -g PANTHEON_EXTRAS
  if [[ -n "${args['--extras']:-}" || "${PANTHEON_EXTRAS:-}" == 1 ]]; then
    PANTHEON_EXTRAS=1
  else
    PANTHEON_EXTRAS=0
  fi

  echo ''
  echo '🏛️  Pantheon Setup - Interactive Mode'
  echo '====================================='

  PANTHEON_SERVER_NAME="$(pantheon_prompt_value 'server name' "$PANTHEON_SERVER_NAME")"
  PANTHEON_ALLOWED_USER="$(pantheon_prompt_value 'allowed user' "$PANTHEON_ALLOWED_USER")"
  PANTHEON_SSH_PORT="$(pantheon_prompt_value 'SSH port' "$PANTHEON_SSH_PORT")"
  PANTHEON_TIMEZONE="$(pantheon_prompt_value 'timezone' "$PANTHEON_TIMEZONE")"
  PANTHEON_LVM_DEVICE="$(pantheon_prompt_value 'LVM device' "$PANTHEON_LVM_DEVICE")"

  if [[ "$PANTHEON_EXTRAS" != 1 ]]; then
    local reply
    read -r -p "Install the extras (Homebrew with bottom, Starship, Ghostty terminfo)? (y/N): " reply
    [[ ! "$reply" =~ ^[Yy]$ ]] || PANTHEON_EXTRAS=1
  fi

  # Every step resolves its settings again, and a flag wins over a global there,
  # so the answers go into the flags: otherwise a value typed over a pre-filled
  # flag would be silently replaced by the flag. Resolving once more also runs
  # the user guards on the answer and renames the actions file.
  args['--server-name']="$PANTHEON_SERVER_NAME"
  args['--allowed-user']="$PANTHEON_ALLOWED_USER"
  args['--ssh-port']="$PANTHEON_SSH_PORT"
  args['--timezone']="$PANTHEON_TIMEZONE"
  args['--lvm-device']="$PANTHEON_LVM_DEVICE"
  pantheon_resolve_setup_context
  [[ "$(validate_port "$PANTHEON_SSH_PORT")" == '' ]] || pantheon_log_error "SSH port '$PANTHEON_SSH_PORT' $(validate_port "$PANTHEON_SSH_PORT")."

  echo ''
  echo '📋 Setup Summary:'
  echo "   Server Name: $PANTHEON_SERVER_NAME"
  echo "   Allowed User: $PANTHEON_ALLOWED_USER"
  echo "   SSH Port: $PANTHEON_SSH_PORT"
  echo "   Timezone: ${PANTHEON_TIMEZONE:-unchanged}"
  echo "   LVM Device: $PANTHEON_LVM_DEVICE"
  echo "   Extras: $([[ "$PANTHEON_EXTRAS" == 1 ]] && echo yes || echo no)"
  echo ''

  local confirm
  read -r -p 'Proceed with setup? (y/N): ' confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo 'Setup cancelled.'
    exit 0
  fi

  pantheon_ensure_actions_file
  PANTHEON_CONFIRMED=1 pantheon_setup_all
}

pantheon_interactive_setup
