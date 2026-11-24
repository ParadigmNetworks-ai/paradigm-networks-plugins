#!/bin/bash
# Checks a release tree's signatures against the release keys this workflow
# pins (RELEASE_KEYS: SHA-256 fingerprints of each key's DER public key,
# space-separated), not against whatever key the release itself carries.
#
# Usage: RELEASE_KEYS="<sha256> ..." .github/scripts/check-signatures.sh <tree>
#
# Fails unless:
#   - every key in claude/runtime/pn-plugin, cursor/runtime/pn-plugin and
#     cursor/runtime/verify.ps1 is a pinned key, so no release can ship a key of
#     its own;
#   - each plugin's runtime/SHA256SUMS.sig verifies with a pinned key in that
#     plugin's launcher.
# A new key is pinned by a reviewed change to this repository's workflows,
# which the release App can't make.
#
# The keys are read only from the "pn-release-signing keys" block, which must
# hold exactly release_key_1='…' and release_key_2='…' (a PEM public key, or
# empty), in that order, and nothing else; verify.ps1's block must be only
# $ReleaseKeys = @( , one @{ X = "…"; Y = "…" } line per key, and ). Everything
# outside the blocks is pinned byte for byte by check-code.sh (LAUNCHER_CODE),
# so a launcher can't read a key from anywhere else: run check-code.sh first.

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
begin='# BEGIN pn-release-signing keys'
end='# END pn-release-signing keys'

pinned() {
  local k
  for k in $RELEASE_KEYS; do
    [[ "$k" == "$1" ]] && return 0
  done
  return 1
}

fingerprint() { openssl dgst -sha256 "$1" | awk '{ print $NF }'; }

# split <file> <name>: writes the key block (between the markers) to
# $tmp/<name>.block and every other line to $tmp/<name>.rest. Each marker
# must be there exactly once, BEGIN first.
split() {
  local file="$1" name="$2" b e
  [[ -f "$file" && ! -L "$file" ]] || die "${file#"$tree"/} is missing or isn't a regular file"
  [[ "$(grep -cxF -- "$begin" "$file" || true)" == 1 && "$(grep -cxF -- "$end" "$file" || true)" == 1 ]] ||
    die "${file#"$tree"/} must have exactly one pn-release-signing keys block"
  b="$(grep -nxF -- "$begin" "$file" | cut -d: -f1)"
  e="$(grep -nxF -- "$end" "$file" | cut -d: -f1)"
  ((b < e)) || die "${file#"$tree"/}: the pn-release-signing keys block ends before it begins"
  awk -v b="$b" -v e="$e" 'NR > b && NR < e' "$file" >"$tmp/$name.block"
  awk -v b="$b" -v e="$e" 'NR < b || NR > e' "$file" >"$tmp/$name.rest"
}

for plugin in claude cursor; do
  launcher="$tree/$plugin/runtime/pn-plugin"
  split "$launcher" "$plugin"

  # The block: release_key_1 then release_key_2, each exactly once, each
  # empty ('') or a PEM public key over several lines; nothing else.
  rm -f "$tmp"/key[12].pem
  awk -v q="'" -v dir="$tmp" '
    function bad(why) { print "line " NR " of the block: " why; err = 1; exit 1 }
    state == 0 {
      if ($0 !~ ("^release_key_[12]=" q)) bad("only release_key_1=" q "…" q " and release_key_2=" q "…" q " may be here")
      n = substr($0, 13, 1)
      if (n != slot + 1) bad("release_key_" n " out of order, or repeated")
      slot = n
      rest = substr($0, 16)
      if (rest == q) next
      if (rest != "-----BEGIN PUBLIC KEY-----") bad("release_key_" n " is neither empty nor a PEM public key")
      out = dir "/key" n ".pem"
      print rest > out
      state = 1
      next
    }
    state == 1 {
      if ($0 == "-----END PUBLIC KEY-----" q) { print substr($0, 1, length($0) - 1) > out; close(out); state = 0; next }
      if ($0 !~ /^[A-Za-z0-9+\/=]+$/) bad("release_key_" slot " has a line that isn'"'"'t base64")
      print > out
    }
    END { if (err) exit 1; if (state != 0) { print "release_key_" slot " isn'"'"'t closed"; exit 1 }
          if (slot != 2) { print "release_key_1 and release_key_2 must both be there"; exit 1 } }' \
    "$tmp/$plugin.block" >"$tmp/why" || die "$plugin/runtime/pn-plugin: $(cat "$tmp/why")"

  signed=0
  for n in 1 2; do
    [[ -s "$tmp/key$n.pem" ]] || continue
    openssl pkey -pubin -in "$tmp/key$n.pem" -outform DER -out "$tmp/key.der" 2>/dev/null ||
      die "$plugin/runtime/pn-plugin: release_key_$n isn't a public key"
    fp="$(fingerprint "$tmp/key.der")"
    pinned "$fp" || die "$plugin/runtime/pn-plugin carries a release key that isn't pinned (release_key_$n, SHA-256 $fp)"
    if openssl dgst -sha256 -verify "$tmp/key$n.pem" -signature "$tree/$plugin/runtime/SHA256SUMS.sig" \
      "$tree/$plugin/runtime/SHA256SUMS" >/dev/null 2>&1; then
      signed=1
    fi
  done
  [[ "$signed" == 1 ]] || die "$plugin/runtime/SHA256SUMS isn't signed with a pinned release key"
  echo "$plugin: signed with a pinned release key."
done

# verify.ps1 carries the same keys as X and Y coordinates, in its block.
ps1="$tree/cursor/runtime/verify.ps1"
split "$ps1" ps1
# The block is exactly: $ReleaseKeys = @( , one @{ X = "…"; Y = "…" } line per
# key, and ).
awk -v pair='^[[:space:]]*@\\{[[:space:]]*X[[:space:]]*=[[:space:]]*"[0-9a-fA-F]{64}"[[:space:]]*;[[:space:]]*Y[[:space:]]*=[[:space:]]*"[0-9a-fA-F]{64}"[[:space:]]*}[[:space:]]*,?[[:space:]]*$' '
  { sub(/\r$/, "") }
  NR == 1 { if ($0 !~ /^\$ReleaseKeys[[:space:]]*=[[:space:]]*@\([[:space:]]*$/) exit 1; next }
  closed { exit 1 }
  /^[[:space:]]*\)[[:space:]]*$/ { closed = 1; next }
  $0 !~ pair { exit 1 }
  END { if (!closed) exit 1 }' "$tmp/ps1.block" ||
  die "cursor/runtime/verify.ps1: its pn-release-signing keys block must be only \$ReleaseKeys = @( , one @{ X = \"…\"; Y = \"…\" } line per key, and )"
pairs="$(grep -oiE 'X[[:space:]]*=[[:space:]]*"[0-9a-f]{64}"[[:space:]]*;[[:space:]]*Y[[:space:]]*=[[:space:]]*"[0-9a-f]{64}"' "$tmp/ps1.block" |
  sed -E 's/[^"]*"([0-9a-fA-F]{64})"[^"]*"([0-9a-fA-F]{64})"/\1\2/' | tr 'A-F' 'a-f')" || true
[[ -n "$pairs" ]] || die "cursor/runtime/verify.ps1 carries no release key"
while read -r xy; do
  printf '%s04%s' "$spki_header" "$xy" | xxd -r -p >"$tmp/key.der"
  fp="$(fingerprint "$tmp/key.der")"
  pinned "$fp" || die "cursor/runtime/verify.ps1 carries a release key that isn't pinned (SHA-256 $fp)"
done <<<"$pairs"
echo "Every key the launchers carry is pinned."
