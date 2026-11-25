#!/bin/bash
# Checks each plugin's runtime/SHA256SUMS in an assembled release tree (from
# release/release.sh): the list the release key signs.
#
# Usage: .github/scripts/check-lists.sh <tree> <version>
#
# Each list must name exactly the six builds of <version>
# (pn-plugin-<version>-<os>-<arch>, the names the launchers look up and the
# GitHub Release gives them), the same in both lists, and every other file the
# plugin ships, by path, with nothing missing or extra; every file's hash must
# match. The builds aren't in the tree: check-release.sh checks them against
# the GitHub Release. The plugin folder may hold only regular files and
# folders (no symlinks), so nothing ships outside the list. The public CI
# (release/public/.github/workflows/verify-builds.yml) does the same check on
# the released tree.

set -euo pipefail

die() {
  echo "::error::$*" >&2
  exit 1
}

[[ $# -eq 2 ]] || die "usage: $0 <tree> <version>"
if command -v sha256sum >/dev/null; then
  sum=(sha256sum)
else
  sum=(shasum -a 256)
fi

# check reads "<sha256>  <path>" lines and fails on the first file that
# doesn't match.
check() {
  local want path
  while read -r want path; do
    [[ -f "$path" ]] || die "$plugin: $path is listed but missing"
    [[ "$("${sum[@]}" "$path" | cut -c1-64)" == "$want" ]] || die "$plugin: $path doesn't match its list"
  done
}
tree="${1%/}"
version="$2"
[[ -n "$tree" ]] || tree=/

# cd follows a symlink, and find then starts inside it: so the tree, each
# plugin folder and its runtime folder must be real folders, not symlinks, for
# the check below to see what ships.
[[ -d "$tree" && ! -L "$tree" ]] || die "$tree isn't a folder, or is a symlink"

# The six builds' names, as the launchers look them up.
want_builds="$(for t in darwin-amd64 darwin-arm64 linux-amd64 linux-arm64 windows-amd64.exe windows-arm64.exe; do
  echo "pn-plugin-$version-$t"
done | LC_ALL=C sort)"

for plugin in claude cursor; do
  dir="$tree/$plugin"
  for d in "$dir" "$dir/runtime"; do
    [[ -d "$d" && ! -L "$d" ]] || die "${d#"$tree"/}/ is missing, or is a symlink: a plugin folder must be a real folder"
  done
  list="$dir/runtime/SHA256SUMS"
  [[ -f "$list" && ! -L "$list" ]] || die "$plugin/runtime/SHA256SUMS is missing or isn't a regular file"
  (
    cd "$dir"
    # Only regular files and folders: a symlink (or anything else) would be
    # shipped without being in the list, or make a listed path read another
    # file.
    other="$(find . ! -type f ! -type d)"
    if [[ -n "$other" ]]; then
      echo "$other" >&2
      die "$plugin/ has something that isn't a regular file or folder (above): a symlink can't be listed and checked"
    fi
    awk '$1 !~ /^[0-9a-f]{64}$/ || NF != 2 { bad = 1 } END { exit bad }' runtime/SHA256SUMS ||
      die "$plugin/runtime/SHA256SUMS has a line that isn't \"<sha256>  <name>\""

    # The builds: exactly the six, by name. They're on the GitHub Release,
    # not here.
    builds="$(awk -v v="pn-plugin-$version-" 'index($2, v) == 1 { print $2 }' runtime/SHA256SUMS | LC_ALL=C sort)"
    [[ "$builds" == "$want_builds" ]] || die "$plugin/runtime/SHA256SUMS doesn't list exactly the six builds of $version"

    # Every other file, by path.
    files="$(awk -v v="pn-plugin-$version-" 'index($2, v) != 1' runtime/SHA256SUMS)"
    check <<<"$files"
    listed="$(awk '{ print $2 }' <<<"$files" | LC_ALL=C sort)"
    present="$(find . -type f ! -path './runtime/SHA256SUMS*' | sed 's#^\./##' | LC_ALL=C sort)"
    if [[ "$listed" != "$present" ]]; then
      diff <(echo "$listed") <(echo "$present") >&2 || true
      die "$plugin/runtime/SHA256SUMS doesn't list exactly the files in $plugin/ (< listed only, > present only)"
    fi
  )
  echo "$plugin: its list names the six builds of $version and every file it ships, and all match."
done

builds() { awk -v v="pn-plugin-$version-" 'index($2, v) == 1' "$tree/$1/runtime/SHA256SUMS" | LC_ALL=C sort; }
[[ "$(builds claude)" == "$(builds cursor)" ]] || die "claude/runtime/SHA256SUMS and cursor/runtime/SHA256SUMS list different builds"
echo "Both lists name the same builds."
