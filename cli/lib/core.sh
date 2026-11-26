pantheon_repo_root() {
  # From the real file: `install` reaches bin/pantheon through a symlink in
  # ~/.local/bin, and `__complete` runs from any directory.
  (cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
}
pantheon_resolve_option() {
  local flag_name="$1"
  local env_name="$2"
  local default_value="${3:-}"

  if [[ -n ${args[$flag_name]+x} && -n ${args[$flag_name]} ]]; then
    printf '%s\n' "${args[$flag_name]}"
    return 0
  fi

  # Indirect expansion rather than 'printenv': these are plain shell globals set
  # by earlier resolution and by the 'setup all' prompts, and printenv only sees
  # *exported* variables. It returned an empty string for every unexported one,
  # so a resolved value silently erased itself on the next resolution pass.
  # An empty value falls through to the default instead of winning.
  if [[ -n "${!env_name:-}" ]]; then
    printf '%s\n' "${!env_name}"
    return 0
  fi

  printf '%s\n' "$default_value"
}
pantheon_require_root() {
  [[ $EUID -eq 0 ]] || pantheon_log_error "This command must be run as root (use sudo)."
}
pantheon_confirm() {
  [[ "${PANTHEON_CONFIRMED:-0}" == "1" ]] && return 0
  local message="${1:-Are you sure you want to continue?}"
  echo -e "\033[1;33m[CONFIRM]\033[0m $message"
  read -r -p "         Proceed? (y/N): " reply
  [[ "$reply" =~ ^[Yy]$ ]] || {
    pantheon_log_warn "Aborted."
    exit 0
  }
}
