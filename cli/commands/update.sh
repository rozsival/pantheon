pantheon_update() {
  local root="$PANTHEON_REPO_ROOT"
  local installed target work stage old_manifest lock_fd

  # The install lives in the operator's home; root would leave root-owned files behind.
  [[ $EUID -ne 0 ]] || pantheon_log_error "Run update as the user who owns $root, not with sudo."
  # jq reads the GitHub API answers; 'setup packages' installs it, but update may run before setup did.
  command -v jq >/dev/null || pantheon_log_error "update needs jq: sudo apt-get install -y jq (or sudo $PANTHEON_CLI_BIN setup packages)."

  # One update per install, held until exit: two runs would interleave their renames
  # into a mix of versions. Failing fast, not waiting, means no run acts on state
  # read before another one changed it.
  exec {lock_fd}<"$root"
  flock -n "$lock_fd" || pantheon_log_error "Another update is already running in $root."

  pantheon_update_read_installed "$root"
  pantheon_log_info "Resolving '${args[version]}' on GitHub..."
  pantheon_update_resolve "${args[version]}"

  installed="$(pantheon_update_describe "$PANTHEON_UPDATE_INSTALLED_CHANNEL" "$PANTHEON_UPDATE_INSTALLED_REF" "$PANTHEON_UPDATE_INSTALLED_COMMIT")"
  target="$(pantheon_update_describe "$PANTHEON_UPDATE_TARGET_CHANNEL" "$PANTHEON_UPDATE_TARGET_REF" "$PANTHEON_UPDATE_TARGET_COMMIT")"

  # A release tag names one build; a branch moves, so only its commit identifies it.
  if [[ "$PANTHEON_UPDATE_INSTALLED_CHANNEL" == "$PANTHEON_UPDATE_TARGET_CHANNEL" &&
    "$PANTHEON_UPDATE_INSTALLED_REF" == "$PANTHEON_UPDATE_TARGET_REF" &&
    ("$PANTHEON_UPDATE_TARGET_CHANNEL" == release || "$PANTHEON_UPDATE_INSTALLED_COMMIT" == "$PANTHEON_UPDATE_TARGET_COMMIT") ]]; then
    pantheon_log_success "Pantheon $installed is already installed."
    return 0
  fi

  pantheon_confirm "Update Pantheon in $root from $installed to $target?"

  if [[ "$PANTHEON_UPDATE_TARGET_CHANNEL" == branch ]]; then
    pantheon_log_warn "$target is not a release: it is unstable, may be broken, and may change the host incompatibly."
    pantheon_confirm "Install the unstable $target anyway?"
  elif [[ "$PANTHEON_UPDATE_INSTALLED_REF" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+ && "$PANTHEON_UPDATE_INSTALLED_CHANNEL" != branch ]] &&
    pantheon_update_is_older "$PANTHEON_UPDATE_TARGET_REF" "$PANTHEON_UPDATE_INSTALLED_REF"; then
    pantheon_log_warn "$target is older than the installed $installed: its setup steps may not expect what a newer version configured."
    pantheon_confirm "Downgrade to $target anyway?"
  fi

  work="$(mktemp -d)"
  # Staged inside the install, on its filesystem, so files move into place by rename.
  stage="$(mktemp -d "$root/.update.XXXXXX")"
  # shellcheck disable=SC2064 # expand now: the locals are gone when the trap fires
  trap "rm -rf '$work' '$stage'" EXIT

  pantheon_log_info "Downloading $target..."
  pantheon_update_fetch "$stage" "$work"

  old_manifest="$work/installed.manifest"
  cp "$root/.manifest" "$old_manifest"

  pantheon_update_apply "$root" "$stage" "$old_manifest"
  pantheon_log_success "Pantheon $target installed in $root."
  pantheon_log_info "Nothing on the host changed: re-run a setup step to apply what $target does differently (sudo $root/bin/pantheon setup <step>)."
}

pantheon_update
