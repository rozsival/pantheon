# `pantheon` by name: a symlink in ~/.local/bin onto this install's bin/pantheon, plus bash completion where
# bash-completion's lazy loader looks for it
# (~/.local/share/bash-completion/completions/<command>), so it costs nothing
# until the first <TAB> after `pantheon`.

pantheon_install_link() { printf '%s\n' "$HOME/.local/bin/pantheon"; }
pantheon_install_completion_file() {
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/pantheon"
}

# The completion file's exact content. The bashly script only forwards each
# <TAB> to `pantheon __complete`, so it holds no command list and a re-run
# is needed only when bashly's own completion function changes.
pantheon_install_completion_script() {
  # shellcheck disable=SC2016 # literal backticks
  printf '# Written by `pantheon install` from `pantheon completions bash`: re-run it, never edit.\n'
  send_completions bash
}

# How a fresh login shell sees `pantheon` - what a new SSH session gets,
# independent of the PATH this process inherited (`setup all` runs install
# through sudo, whose PATH has no ~/.local/bin). Prints `path=<resolved>` and,
# for a bash login shell, `loader=yes` when bash-completion's lazy loader is
# defined.
pantheon_install_fresh_shell() {
  local shell="${SHELL:-/bin/bash}"
  # shellcheck disable=SC2016 # expands in the probed shell
  env -i HOME="$HOME" USER="${USER:-}" LOGNAME="${LOGNAME:-${USER:-}}" SHELL="$shell" TERM=dumb \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin "$shell" -lic \
    'printf "path=%s\n" "$(command -v pantheon)"
     [ -n "${BASH_VERSION:-}" ] && declare -F _comp_load __load_completion >/dev/null && echo loader=yes
     exit 0' </dev/null 2>/dev/null || true
}

pantheon_install_completion_hint() {
  if [[ "$(uname -s)" == Darwin ]]; then
    # shellcheck disable=SC2016 # a command for the user to run
    echo 'brew install bash-completion@2, then source "$(brew --prefix)/etc/profile.d/bash_completion.sh" from ~/.bashrc'
  else
    echo "sudo apt-get install -y bash-completion, then source /usr/share/bash-completion/bash_completion from ~/.bashrc (Ubuntu's default ~/.bashrc does)"
  fi
}

# Reports every check before failing, so one run lists every fix.
pantheon_install_checks() {
  local link file probe resolved
  local failures=0
  link="$(pantheon_install_link)"
  file="$(pantheon_install_completion_file)"

  if [[ -L "$link" && "$(readlink "$link")" == "$PANTHEON_CLI_BIN" ]]; then
    pantheon_log_success "$link -> $PANTHEON_CLI_BIN"
  else
    pantheon_log_warn "$link is not a symlink onto $PANTHEON_CLI_BIN."
    failures=$((failures + 1))
  fi

  if [[ -f "$file" ]] && cmp -s "$file" <(pantheon_install_completion_script); then
    pantheon_log_success "Bash completion at $file."
  else
    pantheon_log_warn "Bash completion at $file is missing or stale."
    failures=$((failures + 1))
  fi

  probe="$(pantheon_install_fresh_shell)"
  resolved="$(sed -n 's/^path=//p' <<<"$probe")"
  if [[ "$resolved" == "$link" ]]; then
    pantheon_log_success "A login shell (${SHELL:-/bin/bash}) resolves pantheon to $link."
  elif [[ -z "$resolved" ]]; then
    # shellcheck disable=SC2016 # literal $HOME/$PATH in the hint
    pantheon_log_warn "A login shell (${SHELL:-/bin/bash}) does not find pantheon - add ~/.local/bin to its PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
    failures=$((failures + 1))
  else
    pantheon_log_warn "A login shell resolves pantheon to $resolved, ahead of $link - remove it or put ~/.local/bin first on the PATH."
    failures=$((failures + 1))
  fi

  if [[ "${SHELL:-/bin/bash}" != */bash ]]; then
    pantheon_log_info "Login shell $SHELL is not bash: completion is installed for bash only - for zsh, put 'source <(pantheon completions zsh)' in ~/.zshrc after compinit."
  elif grep -qx 'loader=yes' <<<"$probe"; then
    pantheon_log_success 'A login shell loads bash-completion, which lazy-loads pantheon completion.'
  else
    pantheon_log_warn "A login shell does not load bash-completion, so pantheon completion never loads - $(pantheon_install_completion_hint)."
    failures=$((failures + 1))
  fi

  ((failures == 0)) || pantheon_log_error "$failures check(s) failed: fix them, then re-run $PANTHEON_CLI_BIN install."
}
