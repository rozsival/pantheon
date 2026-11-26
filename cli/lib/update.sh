# `update` replaces the installed runtime files (release/package.sh) with another
# version's. Releases ship them as the pantheon.tar.gz asset; a branch has no
# asset, so its source tarball is packaged by the branch's own release/package.sh.
# .manifest lists the shipped files, so files a version drops are deleted and
# anything else in the install directory is never touched.

# Calls the GitHub REST API and stores the response body in PANTHEON_UPDATE_API_BODY.
# Returns 1 on 404, so a caller can probe; any other failure is fatal. Runs in the
# current shell, not $(...), so a fatal error exits the command, not a subshell.
pantheon_update_api() {
  local path="$1"
  local body status message

  body="$(mktemp)"
  if ! status="$(curl -sSL -o "$body" -w '%{http_code}' \
    -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$PANTHEON_GITHUB_REPO/$path")"; then
    rm -f "$body"
    pantheon_log_error "Cannot reach the GitHub API."
  fi

  case "$status" in
  200)
    PANTHEON_UPDATE_API_BODY="$(<"$body")"
    rm -f "$body"
    ;;
  404)
    rm -f "$body"
    return 1
    ;;
  *)
    message="$(jq -r '.message? // empty' "$body" 2>/dev/null || true)"
    rm -f "$body"
    pantheon_log_error "GitHub API /$path returned HTTP $status${message:+: $message}."
    ;;
  esac
}

# Sets PANTHEON_UPDATE_TARGET_{CHANNEL,REF,COMMIT,URL} for a version argument:
# `latest`, a release tag (the `v` is optional), or a branch name.
pantheon_update_resolve() {
  local version="$1"
  local tag

  if [[ "$version" == latest ]]; then
    pantheon_update_api releases/latest || pantheon_log_error "$PANTHEON_GITHUB_REPO has no published release."
    pantheon_update_resolve_release
    return
  fi

  # Characters valid in tags and branch names that need no URL encoding; anything
  # else cannot name a release or branch this command can fetch.
  [[ "$version" =~ ^[A-Za-z0-9._/-]+$ ]] || pantheon_log_error "No release or branch named '$version' in $PANTHEON_GITHUB_REPO."

  tag="$version"
  [[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] && tag="v$tag"
  if pantheon_update_api "releases/tags/$tag"; then
    pantheon_update_resolve_release
    return
  fi

  if pantheon_update_api "branches/$version"; then
    PANTHEON_UPDATE_TARGET_CHANNEL=branch
    PANTHEON_UPDATE_TARGET_REF="$(jq -r '.name' <<<"$PANTHEON_UPDATE_API_BODY")"
    PANTHEON_UPDATE_TARGET_COMMIT="$(jq -r '.commit.sha' <<<"$PANTHEON_UPDATE_API_BODY")"
    # Checked before any prompt: such a branch has nothing to package.
    pantheon_update_api "contents/release/package.sh?ref=$PANTHEON_UPDATE_TARGET_COMMIT" ||
      pantheon_log_error "Branch $PANTHEON_UPDATE_TARGET_REF has no release/package.sh: it cannot be installed by update."
    # The resolved commit, not the branch: a push during the update cannot change what is installed.
    PANTHEON_UPDATE_TARGET_URL="https://github.com/$PANTHEON_GITHUB_REPO/archive/$PANTHEON_UPDATE_TARGET_COMMIT.tar.gz"
    return
  fi

  pantheon_log_error "No release or branch named '$version' in $PANTHEON_GITHUB_REPO."
}

pantheon_update_resolve_release() {
  PANTHEON_UPDATE_TARGET_CHANNEL=release
  PANTHEON_UPDATE_TARGET_REF="$(jq -r '.tag_name' <<<"$PANTHEON_UPDATE_API_BODY")"
  PANTHEON_UPDATE_TARGET_COMMIT=''
  PANTHEON_UPDATE_TARGET_URL="$(jq -r --arg name "$PANTHEON_RELEASE_ASSET" \
    '.assets[] | select(.name == $name) | .browser_download_url' <<<"$PANTHEON_UPDATE_API_BODY")"
  [[ -n "$PANTHEON_UPDATE_TARGET_URL" ]] ||
    pantheon_log_error "Release $PANTHEON_UPDATE_TARGET_REF has no $PANTHEON_RELEASE_ASSET: it cannot be installed by update."
}

# Sets PANTHEON_UPDATE_INSTALLED_{CHANNEL,REF,COMMIT} from .release.
pantheon_update_read_installed() {
  local root="$1"

  if [[ -f "$root/.release" ]]; then
    PANTHEON_UPDATE_INSTALLED_CHANNEL="$(sed -n 's/^channel=//p' "$root/.release")"
    PANTHEON_UPDATE_INSTALLED_REF="$(sed -n 's/^ref=//p' "$root/.release")"
    PANTHEON_UPDATE_INSTALLED_COMMIT="$(sed -n 's/^commit=//p' "$root/.release")"
  else
    pantheon_log_error "$root has no .release file: reinstall with $PANTHEON_INSTALL_COMMAND"
  fi
}

# Human-readable version: `v1.2.0`, `feat/x@1a2b3c4`.
pantheon_update_describe() {
  local channel="$1" ref="$2" commit="$3"

  case "$channel" in
  branch) printf 'branch %s@%s\n' "$ref" "${commit:0:7}" ;;
  *) printf '%s\n' "$ref" ;;
  esac
}

# Succeeds when release tag $1 is older than release tag $2, by SemVer 2.0.0
# precedence: `v` prefix optional, build metadata ignored, a pre-release is older
# than its release, and pre-release identifiers compare numerically when both
# are numeric, lexically (ASCII) otherwise, numeric before alphanumeric.
pantheon_update_is_older() {
  local a="${1#v}" b="${2#v}"
  local a_pre='' b_pre='' i x y
  local -a a_ids b_ids

  a="${a%%+*}"
  b="${b%%+*}"
  [[ "$a" != *-* ]] || a_pre="${a#*-}"
  [[ "$b" != *-* ]] || b_pre="${b#*-}"

  IFS=. read -ra a_ids <<<"${a%%-*}"
  IFS=. read -ra b_ids <<<"${b%%-*}"
  for i in 0 1 2; do
    x="${a_ids[i]:-0}"
    y="${b_ids[i]:-0}"
    ((10#$x == 10#$y)) || return "$((10#$x < 10#$y ? 0 : 1))"
  done

  [[ -n "$a_pre" ]] || return 1
  [[ -n "$b_pre" ]] || return 0
  IFS=. read -ra a_ids <<<"$a_pre"
  IFS=. read -ra b_ids <<<"$b_pre"
  for ((i = 0; i < ${#a_ids[@]} && i < ${#b_ids[@]}; i++)); do
    x="${a_ids[i]}"
    y="${b_ids[i]}"
    [[ "$x" != "$y" ]] || continue
    if [[ "$x" =~ ^[0-9]+$ && "$y" =~ ^[0-9]+$ ]]; then
      return "$((10#$x < 10#$y ? 0 : 1))"
    fi
    [[ ! "$x" =~ ^[0-9]+$ ]] || return 0
    [[ ! "$y" =~ ^[0-9]+$ ]] || return 1
    [[ "$(printf '%s\n%s\n' "$x" "$y" | LC_ALL=C sort | sed -n 1p)" == "$x" ]]
    return
  done
  ((${#a_ids[@]} < ${#b_ids[@]}))
}

# Downloads the target into <stage> as a runtime tree with .manifest and .release.
pantheon_update_fetch() {
  local stage="$1" work="$2"
  local src="$work/source"

  if [[ "$PANTHEON_UPDATE_TARGET_CHANNEL" == release ]]; then
    curl -fsSL "$PANTHEON_UPDATE_TARGET_URL" | tar -xzf - -C "$stage" --strip-components=1 ||
      pantheon_log_error "Cannot download $PANTHEON_UPDATE_TARGET_URL."
  else
    mkdir -p "$src"
    curl -fsSL "$PANTHEON_UPDATE_TARGET_URL" | tar -xzf - -C "$src" --strip-components=1 ||
      pantheon_log_error "Cannot download $PANTHEON_UPDATE_TARGET_URL."
    bash "$src/release/package.sh" "$src" "$stage" branch "$PANTHEON_UPDATE_TARGET_REF" "$PANTHEON_UPDATE_TARGET_COMMIT" ||
      pantheon_log_error "Packaging branch $PANTHEON_UPDATE_TARGET_REF failed."
  fi

  [[ -f "$stage/.manifest" && -f "$stage/.release" && -f "$stage/bin/pantheon" ]] ||
    pantheon_log_error "$PANTHEON_UPDATE_TARGET_URL is not a Pantheon runtime archive."
}

# Moves the staged files into <root> and deletes the files the installed version
# shipped and the new one does not. Every file is renamed into place, never
# rewritten: the running bin/pantheon keeps reading its old inode. .release
# goes last: until it names the new version, a re-run takes the install for the
# old one and redoes the whole update rather than reporting it already installed.
pantheon_update_apply() {
  local root="$1" stage="$2" old_manifest="$3"
  local file dir

  while IFS= read -r file; do
    mkdir -p "$root/$(dirname "$file")"
    mv -f "$stage/$file" "$root/$file"
  done <"$stage/.manifest"

  while IFS= read -r file; do
    rm -f "$root/$file"
    dir="$(dirname "$file")"
    [[ "$dir" == . ]] || (cd "$root" && rmdir -p --ignore-fail-on-non-empty "$dir" 2>/dev/null) || true
  done < <(LC_ALL=C comm -23 <(LC_ALL=C sort -u "$old_manifest") <(LC_ALL=C sort -u "$stage/.manifest"))

  mv -f "$stage/.manifest" "$root/.manifest"
  mv -f "$stage/.release" "$root/.release"
}
