#!/bin/bash
# Checks each plugin's bin/SHA256SUMS in an assembled release tree (from
# release/release.sh): the list the release key signs.
#
# Usage: .github/scripts/check-lists.sh <tree> <version>
#
# Each list must name exactly the six builds of <version>
# (pn-plugin-<version>-<os>-<arch>, the names the launchers look up) and every
# other file the plugin ships, by path, with nothing missing or extra; every
# hash must match. The public CI (release/public/.github/workflows/verify-builds.yml)
# does the same check on the released tree.

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
tree="$1"
version="$2"

for plugin in claude cursor; do
  dir="$tree/$plugin"
  list="$dir/bin/SHA256SUMS"
  [[ -f "$list" ]] || die "$plugin/bin/SHA256SUMS is missing"
  (
    cd "$dir"
    awk '$1 !~ /^[0-9a-f]{64}$/ || NF != 2 { bad = 1 } END { exit bad }' bin/SHA256SUMS ||
      die "$plugin/bin/SHA256SUMS has a line that isn't \"<sha256>  <name>\""

    # The builds, listed by the name the launchers look up.
    builds="$(awk -v v="pn-plugin-$version-" 'index($2, v) == 1 { f = $2; sub(v, "bin/pn-plugin-", f); print $1 "  " f }' bin/SHA256SUMS)"
    [[ "$(grep -c . <<<"$builds")" -eq 6 ]] || die "$plugin/bin/SHA256SUMS doesn't list six builds of $version"
    check <<<"$builds"

    # Every other file, by path.
    files="$(awk -v v="pn-plugin-$version-" 'index($2, v) != 1' bin/SHA256SUMS)"
    check <<<"$files"
    listed="$( (awk '{ print $2 }' <<<"$files"; awk '{ print $2 }' <<<"$builds") | LC_ALL=C sort)"
    present="$(find . -type f ! -path './bin/SHA256SUMS*' | sed 's#^\./##' | LC_ALL=C sort)"
    if [[ "$listed" != "$present" ]]; then
      diff <(echo "$listed") <(echo "$present") >&2 || true
      die "$plugin/bin/SHA256SUMS doesn't list exactly the files in $plugin/ (< listed only, > present only)"
    fi
  )
  echo "$plugin: its list names the six builds of $version and every file it ships, and all match."
done
