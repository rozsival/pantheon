# Puts back everything the hardening step moved or overwrote: the drop-ins it
# emptied out of PANTHEON_SSHD_CONFIG_DIR, then the pre-change sshd_config if a
# candidate had already been committed. 'previous' only exists after the commit,
# so an early failure restores drop-ins alone.
pantheon_ssh_restore() {
  local stage="$1"

  local saved=()
  shopt -s nullglob
  saved=("${stage}/dropins/"*.conf)
  shopt -u nullglob

  if ((${#saved[@]} > 0)); then
    mkdir -p "$PANTHEON_SSHD_CONFIG_DIR"
    mv -f "${saved[@]}" "${PANTHEON_SSHD_CONFIG_DIR}/"
  fi

  if [[ -f "${stage}/previous" ]]; then
    cat "${stage}/previous" >"$PANTHEON_SSHD_CONFIG"
  fi
}

# Abort before anything under /etc/ssh was committed: restore and exit. The
# running daemon still serves the configuration it started with, so there is
# nothing to restart.
# Keeps the drop-ins a successful run moved out of PANTHEON_SSHD_CONFIG_DIR: they
# must stay out of sshd's way, but they may hold settings the operator wants
# back. Kept next to the directory, under a name sshd never reads.
pantheon_ssh_keep_dropins() {
  local stage="$1"
  local backup
  local saved=()
  shopt -s nullglob
  saved=("${stage}/dropins/"*.conf)
  shopt -u nullglob

  ((${#saved[@]} > 0)) || return 0
  backup="${PANTHEON_SSHD_CONFIG_DIR}.pantheon-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup"
  mv -f "${saved[@]}" "${backup}/"
  pantheon_log_info "Moved ${#saved[@]} drop-in(s) that would override the hardening to ${backup}."
}

pantheon_ssh_abort() {
  local stage="$1"
  shift

  pantheon_ssh_restore "$stage"
  rm -rf "$stage"
  pantheon_log_error "$*"
}

# Abort after the candidate was committed and the daemon restarted: the previous
# configuration has to be put back *and* served again, otherwise the step exits
# leaving sshd on the configuration that just failed to come up.
pantheon_ssh_abort_running() {
  local stage="$1"
  local unit="$2"
  shift 2

  pantheon_ssh_restore "$stage"
  systemctl daemon-reload
  systemctl restart "$unit" || pantheon_log_warn "Could not restart ${unit} after rollback -- run 'systemctl restart ${unit}' from the console."
  rm -rf "$stage"
  pantheon_log_error "$*"
}

pantheon_setup_ssh() {
  # Resolved up front because bash expands ${PANTHEON_SSH_PORT} at the call site
  # below - before pantheon_prepare_setup_step could resolve it - so a standalone
  # 'setup ssh' on a fresh host died on 'unbound variable'. Resolution is
  # idempotent, so prepare doing it again is free.
  pantheon_resolve_setup_context
  pantheon_prepare_setup_step "Harden SSH configuration (port ${PANTHEON_SSH_PORT}, key-only auth)."

  # UsePAM no (below) makes sshd check the account itself, and it refuses every
  # login to a locked account, keys included: a password field starting with '!'.
  # Installers that create a key-only user (cloud images, autoinstall) leave it
  # exactly like that, so hardening would lock the operator out on the next
  # login. '*' is not locked for sshd, so it unlocks the account for keys alone.
  local password_field
  password_field="$(getent shadow "$PANTHEON_ALLOWED_USER" | cut -d: -f2)"
  if [[ "$password_field" == '!'* ]]; then
    pantheon_log_error "The account '${PANTHEON_ALLOWED_USER}' is locked (no usable password). With the hardened config sshd refuses every login to a locked account, keys included, and you would be locked out. Set a password (sudo passwd ${PANTHEON_ALLOWED_USER}) or allow key logins only (sudo usermod -p '*' ${PANTHEON_ALLOWED_USER}), then re-run."
  fi

  pantheon_log_info "Configuring SSH (${PANTHEON_SSHD_CONFIG})..."

  if [[ ! -f "${PANTHEON_SSHD_CONFIG}.orig" ]]; then
    cp "$PANTHEON_SSHD_CONFIG" "${PANTHEON_SSHD_CONFIG}.orig"
    pantheon_log_info "Original sshd_config backed up to ${PANTHEON_SSHD_CONFIG}.orig"
  fi

  # Nothing under /etc/ssh is committed until a complete candidate has passed
  # 'sshd -t'. The earlier version edited the live file and validated afterwards,
  # so a keyword sshd rejected stayed on disk: the daemon then failed to start on
  # the next boot and the host answered on no port at all - recoverable only with
  # physical access. Augeas edits the staged copy instead, because 'augtool -r'
  # resolves the lens path /files/etc/ssh/sshd_config inside the staging root.
  local stage candidate
  stage="$(mktemp -d)"
  candidate="${stage}/etc/ssh/sshd_config"
  mkdir -p "${stage}/dropins"
  install -D -m 0600 "$PANTHEON_SSHD_CONFIG" "$candidate"

  # The Include line in sshd_config points at an absolute path, so a staged
  # candidate is still validated against the live drop-in directory - and on
  # Ubuntu those drop-ins win, since sshd takes the first value it sees and the
  # Include sits at the top of the file. Empty the directory first so 'sshd -t'
  # sees exactly what the daemon will see. Moved rather than deleted, so a failed
  # validation puts them back.
  local dropins=()
  shopt -s nullglob
  dropins=("${PANTHEON_SSHD_CONFIG_DIR}"/*.conf)
  shopt -u nullglob

  if ((${#dropins[@]} > 0)); then
    pantheon_log_info "Moving ${#dropins[@]} sshd_config.d drop-in(s) aside (backed up on success, restored on failure)..."
    mv -f "${dropins[@]}" "${stage}/dropins/"
  fi

  # ChallengeResponseAuthentication is deliberately absent: OpenSSH 8.7 made it a
  # deprecated alias of KbdInteractiveAuthentication (servconf.h SSHCONF_ALIAS),
  # which is set two lines down, so writing both only duplicated one setting.
  #
  # augtool's exit status is checked because '-s' reports a failed set or save
  # through it, and the sshd lens refuses to save new global keys into a file that
  # already has a Match block. Unchecked, that silently produced a config missing
  # every hardening directive.
  pantheon_log_info 'Applying SSH hardening to a staged copy via Augeas...'
  augtool -s -r "$stage" <<AUGEOF || pantheon_ssh_abort "$stage" 'augtool could not write the staged sshd_config -- /etc/ssh left untouched.'
set /files/etc/ssh/sshd_config/Port "$PANTHEON_SSH_PORT"
set /files/etc/ssh/sshd_config/PasswordAuthentication no
set /files/etc/ssh/sshd_config/KbdInteractiveAuthentication no
set /files/etc/ssh/sshd_config/PubkeyAuthentication yes
set /files/etc/ssh/sshd_config/AuthenticationMethods publickey
set /files/etc/ssh/sshd_config/UsePAM no
set /files/etc/ssh/sshd_config/PermitRootLogin no
set /files/etc/ssh/sshd_config/MaxAuthTries 3
set /files/etc/ssh/sshd_config/LoginGraceTime 30
set /files/etc/ssh/sshd_config/X11Forwarding no
set /files/etc/ssh/sshd_config/AllowTcpForwarding no
set /files/etc/ssh/sshd_config/AllowUsers/1 "$PANTHEON_ALLOWED_USER"
AUGEOF

  pantheon_log_info 'Validating the staged configuration...'
  sshd -t -f "$candidate" || pantheon_ssh_abort "$stage" 'Staged sshd configuration is invalid -- /etc/ssh left untouched and SSH keeps serving the current config.'

  # Only now does the live file change. Content is copied into the existing inode
  # rather than moved over it, which keeps the file's mode and owner.
  cp "$PANTHEON_SSHD_CONFIG" "${stage}/previous"
  cat "$candidate" >"$PANTHEON_SSHD_CONFIG"

  # Ubuntu ships socket-activated SSH: 'ssh.socket' owns the listening port and
  # its shipped unit hardcodes 22, while 'ssh.service' is RequiredBy that socket
  # and inherits the socket's file descriptor. Restarting the service alone
  # therefore keeps serving port 22 whatever sshd_config says. Ubuntu's
  # 'sshd-socket-generator' turns the sshd_config Port into an ssh.socket
  # drop-in, but generators only re-run on a daemon-reload.
  pantheon_log_info 'Reloading systemd units so the SSH socket adopts the new port...'
  systemctl daemon-reload

  local unit='ssh'
  if systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
    unit='ssh.socket'
  fi

  pantheon_log_info "Restarting ${unit}..."
  systemctl restart "$unit" || pantheon_ssh_abort_running "$stage" "$unit" "Restarting ${unit} failed -- rolled back to the previous SSH configuration."

  # The listening socket is observed directly instead of parsing sshd -T or unit
  # properties: whether the next login connects is decided here and nowhere else.
  # UFW runs after this step and opens only PANTHEON_SSH_PORT, so a daemon left on
  # 22 is unreachable. The retries cover ssh.service, which binds shortly after
  # systemctl returns; ssh.socket is already listening once restart completes.
  for _ in 1 2 3 4 5; do
    if ss -Htln "sport = :${PANTHEON_SSH_PORT}" 2>/dev/null | grep -q .; then
      pantheon_ssh_keep_dropins "$stage"
      rm -rf "$stage"
      pantheon_log_success "SSH hardened on port ${PANTHEON_SSH_PORT}. AllowUsers: ${PANTHEON_ALLOWED_USER}"
      pantheon_register_action "Open a second session on port ${PANTHEON_SSH_PORT} before closing this one."
      return 0
    fi
    sleep 1
  done

  pantheon_ssh_abort_running "$stage" "$unit" "Nothing is listening on port ${PANTHEON_SSH_PORT} after restarting ${unit} -- rolled back to the previous SSH configuration."
}

pantheon_setup_ssh
