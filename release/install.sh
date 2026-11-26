#!/usr/bin/env bash
# Installs the latest Pantheon release:
#
#   curl -fsSL https://github.com/rozsival/pantheon/releases/latest/download/install.sh | bash
#
# Downloads the release's runtime archive (see release/package.sh) into $PANTHEON_DIR (default
# ~/pantheon). Installation only: host setup is `sudo ./bin/pantheon setup`, later versions come from
# `pantheon update`.
set -euo pipefail

# Everything runs from main, so a download cut short by the network executes nothing.
main() {
  local repo='rozsival/pantheon'
  local dir="${PANTHEON_DIR:-$HOME/pantheon}"
  local url="https://github.com/$repo/releases/latest/download/pantheon.tar.gz"
  local stage ref

  info() { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
  fail() {
    printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2
    exit 1
  }

  [[ $EUID -ne 0 ]] || fail "Run the installer as the user who administers the server, not as root: it installs into $dir."
  command -v curl >/dev/null || fail 'curl is required.'
  command -v tar >/dev/null || fail 'tar is required.'

  if [[ -f "$dir/.manifest" ]]; then
    fail "Pantheon is already installed in $dir: run '$dir/bin/pantheon update' instead."
  fi
  if [[ -e "$dir" && -n "$(ls -A "$dir")" ]]; then
    fail "$dir exists and is not empty: remove it or set PANTHEON_DIR to another directory."
  fi

  mkdir -p "$dir"
  stage="$(mktemp -d "$dir/.install.XXXXXX")"
  # shellcheck disable=SC2064 # expand now: the local is gone when the trap fires
  trap "rm -rf '$stage'" EXIT

  info "Downloading the latest release from $url..."
  curl -fsSL "$url" | tar -xzf - -C "$stage" --strip-components=1
  [[ -f "$stage/.manifest" && -f "$stage/bin/pantheon" ]] || fail "The archive from $url is not a Pantheon release."

  shopt -s dotglob
  mv "$stage"/* "$dir"/
  shopt -u dotglob

  ref="$(sed -n 's/^ref=//p' "$dir/.release")"
  printf '\033[0;32m[OK]\033[0m    Installed Pantheon %s into %s.\n' "$ref" "$dir"
  info "Next: cd $dir && sudo ./bin/pantheon setup"
}

main "$@"
