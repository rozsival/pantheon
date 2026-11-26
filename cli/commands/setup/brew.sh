pantheon_setup_brew() {
  pantheon_prepare_setup_step 'Install Homebrew and bottom.'

  pantheon_log_info "Installing Homebrew (as ${PANTHEON_ALLOWED_USER})..."
  mkdir -p /home/linuxbrew/.linuxbrew
  chown -R "${PANTHEON_ALLOWED_USER}:${PANTHEON_ALLOWED_USER}" /home/linuxbrew

  sudo -u "${PANTHEON_ALLOWED_USER}" bash -c 'NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

  local brew_prefix
  brew_prefix=$(sudo -u "${PANTHEON_ALLOWED_USER}" bash -c '
		if [ -d ~/.linuxbrew ]; then
			echo "$HOME/.linuxbrew"
		elif [ -d /home/linuxbrew/.linuxbrew ]; then
			echo "/home/linuxbrew/.linuxbrew"
		fi
	')

  if [[ -n "$brew_prefix" ]]; then
    pantheon_register_bashrc_entry 'Homebrew' "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
    pantheon_log_success "Homebrew installed and configured for ${PANTHEON_ALLOWED_USER}."

    # No 'eval "$(brew shellenv)"' here: brew derives HOMEBREW_PREFIX from its
    # own path, every call below is absolute and runs through 'sudo -u', and
    # exported vars would die with this process anyway. The .bashrc entry above
    # is what puts brew on the user's PATH.
    # '--no-ask' because upstream made ask-mode the default for 'brew install':
    # it prompts for confirmation before downloading, and only skips the prompt
    # when there is no TTY. Setup runs on a console, so without this every
    # formula below stops and waits for a keypress.
    pantheon_log_info "Installing bottom via Homebrew..."
    sudo -u "${PANTHEON_ALLOWED_USER}" bash -c "${brew_prefix}/bin/brew install --no-ask bottom"
    pantheon_log_success "bottom installed via Homebrew for user ${PANTHEON_ALLOWED_USER}."
  else
    pantheon_log_error 'Homebrew installation failed.'
  fi
}

pantheon_setup_brew
