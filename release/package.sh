#!/usr/bin/env bash
# Builds the runtime tree of a Pantheon install: only what a host needs to run the CLI. The CLI is the
# generated bin/pantheon, so its sources, docs, schemas, tooling configs and package.json stay out.
#
# Usage: release/package.sh <source-dir> <dest-dir> <channel> <ref> <commit>
#   channel  release | branch
#   ref      release tag (vX.Y.Z) or branch name
#
# Called by .github/workflows/release.yml for the release archive, and by `pantheon update` on a
# branch's source tarball, so a branch is packaged by its own rules.
#
# <dest-dir> receives the files plus:
#   .manifest  every shipped file, one relative path per line; `update` deletes what a new version drops
#   .release   channel, ref and commit of the install
set -euo pipefail

if (($# != 5)); then
  echo "Usage: $0 <source-dir> <dest-dir> <channel> <ref> <commit>" >&2
  exit 1
fi

src="$1"
dest="$2"
channel="$3"
ref="$4"
commit="$5"

case "$channel" in
release | branch) ;;
*)
  echo "Unknown channel '$channel': expected release or branch." >&2
  exit 1
  ;;
esac

# Directories ship whole; files are named explicitly.
runtime_paths=(
  LICENSE
  bin/pantheon
  terminfo
)

mkdir -p "$dest"
manifest="$dest/.manifest"
(cd "$src" && find "${runtime_paths[@]}" -type f -print | LC_ALL=C sort) >"$manifest"
tar -C "$src" -cf - -T "$manifest" | tar -C "$dest" -xf -
printf 'channel=%s\nref=%s\ncommit=%s\n' "$channel" "$ref" "$commit" >"$dest/.release"
