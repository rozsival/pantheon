pantheon_setup_shell() {
  # Resolved before the message below expands it: see setup/ssh.sh.
  pantheon_resolve_setup_context
  pantheon_prepare_setup_step "Set up the shell for ${PANTHEON_ALLOWED_USER}: Starship prompt, Ghostty terminfo, linger."

  pantheon_log_info "Setting up shell with Starship prompt for ${PANTHEON_ALLOWED_USER}..."
  apt-get install -y starship

  # Lets the user's systemd services run without an open session, and keeps
  # them running after logout.
  pantheon_log_info "Enabling linger for ${PANTHEON_ALLOWED_USER}..."
  loginctl enable-linger "$PANTHEON_ALLOWED_USER"

  # shellcheck disable=SC2016 # We want to register the literal command, not its output
  pantheon_register_bashrc_entry 'Starship' 'eval "$(starship init bash)"'

  # Ghostty's ssh-terminfo installs xterm-ghostty into ~/.terminfo, which ncurses
  # ignores for root and for setcap binaries (such as nvtop with cap_perfmon).
  pantheon_log_info "Installing xterm-ghostty terminfo into /etc/terminfo..."
  tic -x -o /etc/terminfo "$PANTHEON_REPO_ROOT/terminfo/xterm-ghostty.terminfo"
  pantheon_log_success "Shell set up for ${PANTHEON_ALLOWED_USER}."
}

pantheon_setup_shell
