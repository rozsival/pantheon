pantheon_setup_ufw() {
  local reset="${args['--reset']:-}"

  if [[ -n "$reset" ]]; then
    pantheon_prepare_setup_step 'Configure the UFW firewall: RESET first, deleting every existing rule, then deny incoming and allow SSH.'
  else
    pantheon_prepare_setup_step 'Configure the UFW firewall: deny incoming, allow SSH; existing rules are kept.'
  fi

  # Preinstalled on Ubuntu Server, but not on minimal or cloud images.
  apt-get install -y ufw

  pantheon_log_info 'Configuring UFW...'
  # Additive by default: a server runs more than this baseline, and other
  # services add rules of their own that a reset would silently delete.
  if [[ -n "$reset" ]]; then
    ufw --force reset
  fi
  ufw default deny incoming
  ufw default allow outgoing

  # 'ufw allow' skips a rule that already exists, so a re-run adds nothing.
  ufw allow "${PANTHEON_SSH_PORT}/tcp" comment 'SSH'

  ufw --force enable

  if [[ -n "$reset" ]]; then
    pantheon_log_success "UFW reset and enabled: incoming traffic denied except SSH (${PANTHEON_SSH_PORT})."
  else
    pantheon_log_success "UFW enabled: incoming traffic denied except SSH (${PANTHEON_SSH_PORT}) and the rules that were already there."
  fi
  # A rule for an earlier SSH port is not removed: only the operator knows
  # whether something else still listens there.
  pantheon_log_info "Review the rules with 'sudo ufw status numbered'; remove a stale one with 'sudo ufw delete <number>'."
}

pantheon_setup_ufw
