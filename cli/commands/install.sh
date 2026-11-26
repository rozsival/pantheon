pantheon_install() {
  # Everything lands in the caller's home, so root would install it for root.
  [[ $EUID -ne 0 ]] || pantheon_log_error "Run install as the user who uses the CLI, not with sudo: it installs into your home directory. 'setup all' runs it for the allowed user."

  local link file
  link="$(pantheon_install_link)"
  file="$(pantheon_install_completion_file)"

  # Only ever replaces a symlink: a real file there is someone else's command.
  if [[ -e "$link" && ! -L "$link" ]]; then
    pantheon_log_error "$link exists and is not a symlink - move it aside, then re-run."
  fi
  if [[ "$(readlink "$link" 2>/dev/null || true)" != "$PANTHEON_CLI_BIN" ]]; then
    mkdir -p "${link%/*}"
    ln -sfn "$PANTHEON_CLI_BIN" "$link"
    pantheon_log_info "Linked $link -> $PANTHEON_CLI_BIN."
  fi

  if [[ ! -f "$file" ]] || ! cmp -s "$file" <(pantheon_install_completion_script); then
    mkdir -p "${file%/*}"
    pantheon_install_completion_script >"$file.$$"
    mv "$file.$$" "$file"
    pantheon_log_info "Wrote $file."
  fi

  pantheon_install_checks
}

pantheon_install
