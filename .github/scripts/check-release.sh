#!/bin/bash
# Checks the GitHub Release for v<version> against the signed lists in a
# release tree: it must hold exactly the files users and QA download, each the
# one the release key signed.
#
# Usage: GH_REPO=<owner>/<repo> GH_TOKEN=… .github/scripts/check-release.sh <tree> <version>
#
# The release (draft or published; exactly one for the tag) must have exactly
# these files, all fully uploaded:
#   - the six builds, under the names both plugins' bin/SHA256SUMS give them
#     (pn-plugin-<version>-<os>-<arch>[.exe]); each build's SHA-256 must be
#     its line in both lists;
#   - claude-SHA256SUMS, claude-SHA256SUMS.sig, claude-SHA256SUMS.sig.p1363
#     and the same for cursor: byte for byte the tree's
#     <plugin>/bin/SHA256SUMS{,.sig,.sig.p1363}, which check-lists.sh and
#     check-signatures.sh check.
# Run those two (and check-code.sh) on the tree first.
#
# On success, writes the release's id, draft, prerelease and immutable flags
# to $GITHUB_OUTPUT (when set) and prints them.

set -euo pipefail

die() {
  echo "::error::$*" >&2
  exit 1
}

[[ $# -eq 2 ]] || die "usage: $0 <tree> <version>"
[[ -n "${GH_REPO:-}" ]] || die "GH_REPO isn't set"
tree="$1"
version="$2"
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || die "\"$version\" isn't a plain release version (X.Y.Z)"
tag="v$version"
if command -v sha256sum >/dev/null; then
  sum=(sha256sum)
else
  sum=(shasum -a 256)
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The release: exactly one with this tag, drafts included (the REST "by tag"
# lookup skips drafts). $tag is a checked vX.Y.Z, so it's safe in the filter.
gh api --paginate "repos/$GH_REPO/releases?per_page=100" \
  --jq ".[] | select(.tag_name == \"$tag\") | \"\(.id) \(.draft) \(.prerelease) \(.immutable)\"" >"$tmp/release"
case "$(grep -c . "$tmp/release" || true)" in
  1) ;;
  0) die "There's no GitHub Release for $tag, not even a draft. The source repository's release job creates the draft with the builds and signed lists; re-run it, or create the draft the same way." ;;
  *) die "There's more than one GitHub Release for $tag. Delete the extra drafts." ;;
esac
read -r id draft prerelease immutable <"$tmp/release"
[[ "$id" =~ ^[0-9]+$ ]] || die "unexpected release id \"$id\""

# What the release must hold. The two lists name the same builds.
builds() { awk -v v="pn-plugin-$version-" 'index($2, v) == 1' "$tree/$1/bin/SHA256SUMS"; }
cmp -s <(builds claude) <(builds cursor) || die "The two plugins' lists name different builds."
builds claude >"$tmp/builds"
[[ "$(grep -c . "$tmp/builds")" -eq 6 ]] || die "The lists don't name six builds of $version."
{
  awk '{ print $2 }' "$tmp/builds"
  for plugin in claude cursor; do
    for f in SHA256SUMS SHA256SUMS.sig SHA256SUMS.sig.p1363; do echo "$plugin-$f"; done
  done
} | LC_ALL=C sort >"$tmp/want"
grep -qvE '^[A-Za-z0-9._-]+$' "$tmp/want" && die "a list names a build with an unexpected name"

gh api --paginate "repos/$GH_REPO/releases/$id/assets?per_page=100" \
  --jq '.[] | "\(.id) \(.state) \(.name)"' >"$tmp/assets"
awk '{ print $3 }' "$tmp/assets" | LC_ALL=C sort >"$tmp/have"
if ! cmp -s "$tmp/want" "$tmp/have"; then
  diff "$tmp/want" "$tmp/have" >&2 || true
  die "The GitHub Release for $tag doesn't have exactly the six builds and both signed lists with their signatures (< missing, > not expected)."
fi
awk '$2 != "uploaded" || NF != 3 { bad = 1 } END { exit bad }' "$tmp/assets" ||
  die "A file of the GitHub Release for $tag isn't fully uploaded."

# Download each file by its id (names were checked above, so they're safe as
# file names here) and compare.
mkdir "$tmp/dl"
while read -r aid _ name; do
  gh api -H 'Accept: application/octet-stream' "repos/$GH_REPO/releases/assets/$aid" >"$tmp/dl/$name" ||
    die "can't download $name from the GitHub Release for $tag"
done <"$tmp/assets"
while read -r _ name; do
  have="$("${sum[@]}" "$tmp/dl/$name" | cut -c1-64)"
  for plugin in claude cursor; do
    want="$(awk -v n="$name" '$2 == n { print $1 }' "$tree/$plugin/bin/SHA256SUMS")"
    [[ "$have" == "$want" ]] || die "$name in the GitHub Release for $tag doesn't match its line in $plugin/bin/SHA256SUMS."
  done
done <"$tmp/builds"
for plugin in claude cursor; do
  for f in SHA256SUMS SHA256SUMS.sig SHA256SUMS.sig.p1363; do
    cmp -s "$tmp/dl/$plugin-$f" "$tree/$plugin/bin/$f" ||
      die "$plugin-$f in the GitHub Release for $tag isn't this commit's $plugin/bin/$f."
  done
done

echo "The GitHub Release for $tag has exactly the six signed builds and both signed lists (draft: $draft, pre-release: $prerelease, immutable: $immutable)."
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "id=$id"
    echo "draft=$draft"
    echo "prerelease=$prerelease"
    echo "immutable=$immutable"
  } >>"$GITHUB_OUTPUT"
fi
