pantheon_current_timezone() {
  timedatectl show -p Timezone --value 2>/dev/null || true
}
pantheon_resolve_setup_context() {
  declare -g PANTHEON_SERVER_NAME
  declare -g PANTHEON_ALLOWED_USER
  declare -g PANTHEON_SSH_PORT
  declare -g PANTHEON_TIMEZONE
  declare -g PANTHEON_LVM_DEVICE
  declare -g PANTHEON_ACTIONS_FILE

  PANTHEON_SERVER_NAME="$(pantheon_resolve_option '--server-name' PANTHEON_SERVER_NAME "$HOSTNAME")"
  # Every setup step calls pantheon_require_root, so $USER is always 'root' here
  # and never the human being configured. sudo records the real account in
  # SUDO_USER; a direct root login has no record of it and must pass the flag.
  PANTHEON_ALLOWED_USER="$(pantheon_resolve_option '--allowed-user' PANTHEON_ALLOWED_USER "${SUDO_USER:-}")"
  PANTHEON_SSH_PORT="$(pantheon_resolve_option '--ssh-port' PANTHEON_SSH_PORT '2222')"
  # The zone the host already has, so a re-run never moves the clock elsewhere
  # unless a zone is asked for explicitly.
  PANTHEON_TIMEZONE="$(pantheon_resolve_option '--timezone' PANTHEON_TIMEZONE "$(pantheon_current_timezone)")"
  PANTHEON_LVM_DEVICE="$(pantheon_resolve_option '--lvm-device' PANTHEON_LVM_DEVICE '/dev/ubuntu-vg/ubuntu-lv')"
  PANTHEON_ACTIONS_FILE="/tmp/${PANTHEON_SERVER_NAME}_actions"

  if [[ -z "$PANTHEON_ALLOWED_USER" ]]; then
    pantheon_log_error "Could not detect which user to configure. Run the CLI with 'sudo' from your own account, or pass --allowed-user <name>."
  fi

  # 'setup ssh' writes PermitRootLogin no together with AllowUsers, and 'setup
  # ufw' then closes everything but that port. A wrong name here locks every
  # account out of the host on the next reboot, so both cases fail up front.
  if [[ "$PANTHEON_ALLOWED_USER" == 'root' ]]; then
    pantheon_log_error "'root' cannot be the allowed user: 'setup ssh' sets PermitRootLogin no and AllowUsers root, which would lock you out. Pass --allowed-user <name>."
  fi

  if ! id -u "$PANTHEON_ALLOWED_USER" >/dev/null 2>&1; then
    pantheon_log_error "User '${PANTHEON_ALLOWED_USER}' does not exist on this host: 'setup ssh' would restrict AllowUsers to it and lock you out."
  fi
}
pantheon_ensure_actions_file() {
  mkdir -p "$(dirname "$PANTHEON_ACTIONS_FILE")"
  [[ -f "$PANTHEON_ACTIONS_FILE" ]] || touch "$PANTHEON_ACTIONS_FILE"
}
pantheon_register_action() {
  pantheon_ensure_actions_file
  printf '%s\n' "$*" >>"$PANTHEON_ACTIONS_FILE"
}
pantheon_register_bashrc_entry() {
  local label="$1"
  local command="$2"
  local user_name="${3:-$PANTHEON_ALLOWED_USER}"
  local bashrc="/home/$user_name/.bashrc"

  if ! grep -qF "$command" "$bashrc"; then
    pantheon_log_info "Adding $label to $bashrc..."
    printf '\n# %s\n%s\n' "$label" "$command" >>"$bashrc"
    chown "$user_name:$user_name" "$bashrc"
  fi
}
pantheon_prepare_setup_step() {
  local message="$1"
  pantheon_resolve_setup_context
  pantheon_require_root
  pantheon_confirm "$message"
  pantheon_ensure_actions_file

  # Every setup step runs apt-get unattended. Without this, dpkg conffile
  # prompts and needrestart's DPkg::Post-Invoke hook (a ubuntu-server
  # recommend, which branches on this variable) open dialogs that block the
  # run on a terminal nobody is watching.
  export DEBIAN_FRONTEND=noninteractive
}
pantheon_setup_step_label() {
  case "$1" in
  init) echo 'Storage and timezone' ;;
  packages) echo 'Packages' ;;
  docker) echo 'Docker' ;;
  tailscale) echo 'Tailscale' ;;
  ssh) echo 'SSH' ;;
  ufw) echo 'UFW' ;;
  fail2ban) echo 'fail2ban' ;;
  brew) echo 'Homebrew (extra)' ;;
  shell) echo 'Shell (extra)' ;;
  *) echo "$1" ;;
  esac
}
# Lists the steps that ran, so the summary never claims a step that was skipped.
pantheon_print_setup_summary() {
  local step
  local -i index=1

  echo ''
  echo -e "\033[0;32m🏛️  ${PANTHEON_SERVER_NAME} setup complete\033[0m"
  for step in "$@"; do
    printf "\033[0;32m   %2d. %s\033[0m\n" "$index" "$(pantheon_setup_step_label "$step")"
    index+=1
  done

  if [[ -s "$PANTHEON_ACTIONS_FILE" ]]; then
    echo ''
    pantheon_log_warn '⚠  ACTIONS REQUIRED TO FINISH SETUP:'
    while IFS= read -r line; do
      echo -e "   \033[1;33m•\033[0m $line"
    done <"$PANTHEON_ACTIONS_FILE"
  fi

  echo ''
  pantheon_log_info "Reconnection: ssh -p ${PANTHEON_SSH_PORT} ${PANTHEON_ALLOWED_USER}@<server-ip>"
}
