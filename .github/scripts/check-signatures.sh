#!/bin/bash
# Checks a release tree's signatures against the release keys this workflow
# pins (RELEASE_KEYS: SHA-256 fingerprints of each key's DER public key,
# space-separated), not against whatever key the release itself carries.
#
# Usage: RELEASE_KEYS="<sha256> ..." .github/scripts/check-signatures.sh <tree>
#
# Fails unless:
#   - every key in claude/bin/pn-plugin, cursor/bin/pn-plugin and
#     cursor/bin/verify.ps1 is a pinned key, so no release can ship a key of
#     its own;
#   - each plugin's bin/SHA256SUMS.sig verifies with a pinned key in that
#     plugin's launcher.
# A new key is pinned by a reviewed change to this repository's workflows,
# which the release App can't make.

set -euo pipefail

die() {
  echo "::error::$*" >&2
  exit 1
}

[[ $# -eq 1 ]] || die "usage: $0 <tree>"
[[ -n "${RELEASE_KEYS:-}" ]] || die "RELEASE_KEYS (the pinned key fingerprints) isn't set"
tree="$1"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# DER SubjectPublicKeyInfo header for an uncompressed P-256 point.
spki_header=3059301306072a8648ce3d020106082a8648ce3d030107034200

pinned() {
  local k
  for k in $RELEASE_KEYS; do
    [[ "$k" == "$1" ]] && return 0
  done
  return 1
}

fingerprint() { openssl dgst -sha256 "$1" | awk '{ print $NF }'; }

for plugin in claude cursor; do
  launcher="$tree/$plugin/bin/pn-plugin"
  signed=0
  for n in 1 2; do
    # release_key_<n>='<PEM>', over several lines; empty when unused.
    awk -v n="$n" -v q="'" '
      index($0, "release_key_" n "=" q) == 1 { on = 1; sub("^[^" q "]*" q, "") }
      on { if (index($0, q)) { sub(q ".*", ""); if ($0 != "") print; exit } print }' \
      "$launcher" >"$tmp/key.pem"
    [[ -s "$tmp/key.pem" ]] || continue
    openssl pkey -pubin -in "$tmp/key.pem" -outform DER -out "$tmp/key.der" 2>/dev/null ||
      die "$plugin/bin/pn-plugin: release_key_$n isn't a public key"
    fp="$(fingerprint "$tmp/key.der")"
    pinned "$fp" || die "$plugin/bin/pn-plugin carries a release key that isn't pinned (release_key_$n, SHA-256 $fp)"
    if openssl dgst -sha256 -verify "$tmp/key.pem" -signature "$tree/$plugin/bin/SHA256SUMS.sig" \
      "$tree/$plugin/bin/SHA256SUMS" >/dev/null 2>&1; then
      signed=1
    fi
  done
  [[ "$signed" == 1 ]] || die "$plugin/bin/SHA256SUMS isn't signed with a pinned release key"
  echo "$plugin: signed with a pinned release key."
done

# verify.ps1 carries the same keys as X and Y coordinates.
pairs="$(grep -oE 'X = "[0-9a-f]{64}"; Y = "[0-9a-f]{64}"' "$tree/cursor/bin/verify.ps1" | sed -E 's/X = "([0-9a-f]+)"; Y = "([0-9a-f]+)"/\1\2/')" ||
  die "cursor/bin/verify.ps1 carries no release key"
while read -r xy; do
  printf '%s04%s' "$spki_header" "$xy" | xxd -r -p >"$tmp/key.der"
  fp="$(fingerprint "$tmp/key.der")"
  pinned "$fp" || die "cursor/bin/verify.ps1 carries a release key that isn't pinned (SHA-256 $fp)"
done <<<"$pairs"
echo "Every key the launchers carry is pinned."
