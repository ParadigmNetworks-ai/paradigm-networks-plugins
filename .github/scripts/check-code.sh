#!/bin/bash
# Checks that the files which check a release before it runs, start that
# check (the trust chain), or tell the agent what to load and run, are
# exactly the code this workflow pins, apart from the three things a release
# may set: the release keys, the "require a signature" switch and the
# version.
#
# Usage: LAUNCHER_CODE="<path>=<sha256> ..." .github/scripts/check-code.sh <tree>
#        .github/scripts/check-code.sh --print <tree>
#
# The files (files= below):
#   - the checks: claude/bin/pn-plugin, cursor/bin/pn-plugin,
#     cursor/bin/verify.ps1 and cursor/scripts/run-hook.cmd;
#   - what starts them or the build: claude/hooks/hooks.json,
#     cursor/hooks/hooks.json, claude/scripts/*.sh, cursor/scripts/*.sh and
#     cursor/scripts/{login,logout,check-configured}.ps1;
#   - the manifests, which say which hooks file, MCP/LSP servers, commands
#     and agents the plugin brings: claude/.claude-plugin/plugin.json,
#     cursor/.cursor-plugin/plugin.json, and the marketplaces
#     .claude-plugin/marketplace.json and .cursor-plugin/marketplace.json
#     (which say where each plugin comes from);
#   - what the agent loads as instructions, outside the tool-call hook (a
#     Claude skill can run shell commands as it loads): every
#     skills/<name>/SKILL.md and cursor/rules/pn-login-check.mdc.
# Each is hashed (SHA-256) in a normalized form. The checks are the file
# with, in place:
#   - its pn-release-signing keys block, from the "# BEGIN pn-release-signing
#     keys" line to the "# END pn-release-signing keys" line, replaced by one
#     placeholder line (run-hook.cmd has no block). check-signatures.sh checks
#     the block holds only the key assignments, and only pinned keys;
#   - its one require-signature line (require_signature=0|1,
#     $RequireSignature = $false|$true, set "PN_REQUIRE_SIGNATURE=0|1")
#     replaced by another placeholder line.
# A plugin.json must have exactly one top-level version line,
# '  "version": "X.Y.Z"' (two-space indent, optional trailing comma); its
# X.Y.Z is replaced by a placeholder. In a marketplace.json every
# '"version": "X.Y.Z"' line (any indent, possibly none) is normalized the
# same way. So a version bump keeps its pins; any other change doesn't.
# The hooks, scripts, skills and rules are hashed as they are.
# The placeholders keep the block and the switch where they are, so neither
# can be moved to after the check that reads it. Every other byte is pinned:
# a launcher that checks differently (a function named openssl, a key set
# outside the block, a changed HexBytes, a hook that runs something else, a
# plugin.json pointing "hooks" elsewhere or adding mcpServers, a
# .gitattributes that checks a launcher out with CRLF on Windows, ...) fails
# here, whatever it looks like.
#
# Nothing else may ship in claude/, cursor/, .claude-plugin/ or
# .cursor-plugin/ but the allowed kinds below (allowed()): LICENSE,
# README.md, SECURITY.md, cursor/.gitignore, assets/*.png,
# and the six builds and the signed lists in bin/. So a .mcp.json, .lsp.json,
# settings.json, commands/, agents/, a new skill or rule, an extra hooks file
# or script, ... fails here, even though the signed list names it.
#
# Every file must be a regular file (no symlink on its way from the tree),
# end with a newline and have LF line endings: no carriage return anywhere.
# The pins are of the LF form git stores, which the Linux runners check out;
# a CRLF checkout (core.autocrlf on Windows) fails here instead of giving
# other values.
#
# The check needs the released form: the switch must be on. --print accepts
# either form and prints one pin per file, so the same command gives the same
# values on the source repository (switch off) and on a release (switch on):
#   release/public/.github/scripts/check-code.sh --print .     (source repo)
#   .github/scripts/check-code.sh --print .                    (public repo)
#
# LAUNCHER_CODE may pin a file more than once; the file passes if its hash is
# any of its pins. Every file needs at least one pin. That is how a change to
# any of these files gets in, since the release App can't change
# .github/workflows/verify-builds.yml:
#   1. a reviewed public CI PR adds the new pins next to the old ones (the
#      current release still passes on the old pins);
#   2. the release with the changed files passes on the new pins, and is
#      promoted to main;
#   3. once that release is on main, another reviewed public CI PR removes
#      the old pins.
# Don't remove an old pin before step 3: a release still on its way to main
# would fail.
#
# A pin for a path that isn't one of this script's files is a warning, and
# ignored. That is how a new file gets pinned: a pull request's checks run
# the script from the branch it targets, with the pull request's
# LAUNCHER_CODE, so
#   1. first a reviewed public CI PR adds the pins for the new file(s) to
#      LAUNCHER_CODE (the script on the base branch warns about them);
#   2. then a reviewed public CI PR (it may be the same one) brings the
#      check-code.sh that adds them to files=.
# Never the other way round: a script that requires a file with no pin
# fails every run. (Public develop has no check-code.sh yet, so the PR that
# first brings it in runs its own copy: that one PR brings the script and
# all its pins together.)

set -euo pipefail

die() {
  echo "::error::$*" >&2
  exit 1
}

print=0
if [[ "${1:-}" == --print ]]; then
  print=1
  shift
fi
[[ $# -eq 1 ]] || die "usage: $0 [--print] <tree>"
tree="${1%/}"
[[ -n "$tree" ]] || tree=/
if command -v sha256sum >/dev/null; then
  sum=(sha256sum)
else
  sum=(shasum -a 256)
fi

# The checks, with a keys block (but run-hook.cmd) and a require-signature
# switch; the files hashed as they are; the manifests, with their version.
checks=(claude/bin/pn-plugin cursor/bin/pn-plugin cursor/bin/verify.ps1 cursor/scripts/run-hook.cmd)
plain=(
  .gitattributes
  claude/.gitattributes
  cursor/.gitattributes
  claude/hooks/hooks.json
  claude/scripts/check-configured.sh
  claude/scripts/login.sh
  claude/scripts/logout.sh
  cursor/hooks/hooks.json
  cursor/scripts/check-configured.ps1
  cursor/scripts/check-configured.sh
  cursor/scripts/login.ps1
  cursor/scripts/login.sh
  cursor/scripts/logout.ps1
  cursor/scripts/logout.sh
  claude/skills/paradigmnetworks-login/SKILL.md
  claude/skills/paradigmnetworks-logout/SKILL.md
  cursor/skills/paradigmnetworks-login/SKILL.md
  cursor/skills/paradigmnetworks-logout/SKILL.md
  cursor/rules/pn-login-check.mdc
)
manifests=(claude/.claude-plugin/plugin.json cursor/.cursor-plugin/plugin.json)
marketplaces=(.claude-plugin/marketplace.json .cursor-plugin/marketplace.json)
files=("${checks[@]}" "${plain[@]}" "${manifests[@]}" "${marketplaces[@]}")
begin='# BEGIN pn-release-signing keys'
end='# END pn-release-signing keys'
keys_placeholder='@@pn-check-code: pn-release-signing keys block@@'
switch_placeholder='@@pn-check-code: require-signature switch@@'
version_placeholder='@@pn-check-code: version@@'
semver='(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'

# The switch's off and on lines, exactly as release/release.sh flips them.
# shellcheck disable=SC2016 # PowerShell's $, literally
switch() {
  case "$1" in
    claude/bin/pn-plugin | cursor/bin/pn-plugin) off='require_signature=0' on='require_signature=1' ;;
    cursor/bin/verify.ps1) off='$RequireSignature = $false' on='$RequireSignature = $true' ;;
    cursor/scripts/run-hook.cmd) off='set "PN_REQUIRE_SIGNATURE=0"' on='set "PN_REQUIRE_SIGNATURE=1"' ;;
    *) die "no require-signature switch known for $1" ;;
  esac
}

count() { grep -cxF -- "$1" "$2" || true; }

# one_of <path> <list...>: whether <path> is one of the list.
one_of() {
  local x="$1" f
  shift
  for f in "$@"; do [[ "$f" == "$x" ]] && return 0; done
  return 1
}

# allowed <relative path>: whether a file that isn't pinned may ship there.
# These kinds start nothing: text, images, the builds (each checked against
# the signed list by its launcher) and the lists with their signatures.
allowed() {
  local p='(claude|cursor)/'
  [[ "$1" =~ ^${p}(LICENSE|README\.md|SECURITY\.md)$ ||
    "$1" == cursor/.gitignore ||
    "$1" =~ ^${p}assets/[A-Za-z0-9._-]+\.png$ ||
    "$1" =~ ^${p}bin/pn-plugin-(darwin|linux)-(amd64|arm64)$ ||
    "$1" =~ ^${p}bin/pn-plugin-windows-(amd64|arm64)\.exe$ ||
    "$1" =~ ^${p}bin/SHA256SUMS(\.sig|\.sig\.p1363)?$ ]] && return 0
  # Only in the source repository: release/release.sh leaves the first out,
  # and the second is the gitignored rule pn-plugin writes in a checkout.
  ((print)) && [[ "$1" == cursor/CONTRIBUTING.md || "$1" == cursor/rules/paradigm-repo-context.mdc ]]
}

# normalize <relative path>: prints the normalized file.
normalize() {
  local rel="$1" file="$tree/$1" b=0 e=0 dir
  # Neither the file nor a folder on its way from the tree may be a symlink.
  dir="$tree"
  for part in ${rel//\// }; do
    dir="$dir/$part"
    [[ ! -L "$dir" ]] || die "$rel: ${dir#"$tree"/} is a symlink"
  done
  [[ -f "$file" ]] || die "$rel is missing or isn't a regular file"
  [[ -s "$file" && "$(tail -c1 "$file" | od -An -c | tr -d ' ')" == '\n' ]] || die "$rel doesn't end with a newline"
  ! LC_ALL=C grep -q $'\r' "$file" || die "$rel has a carriage return (CRLF line endings?): the pins are of the LF form"
  if grep -qF -e "$keys_placeholder" -e "$switch_placeholder" -e "$version_placeholder" "$file"; then
    die "$rel contains a check-code placeholder"
  fi
  if one_of "$rel" "${plain[@]}"; then
    cat -- "$file"
    return
  fi
  if one_of "$rel" "${manifests[@]}"; then
    # Exactly one top-level version line, and it is X.Y.Z.
    local n
    n="$(grep -c '^  "version":' "$file" || true)"
    [[ "$n" == 1 ]] || die "$rel must have exactly one top-level \"version\" line (two-space indent); it has $n"
    grep -qE "^  \"version\": \"$semver\",?\$" "$file" ||
      die "$rel: its version line isn't '  \"version\": \"X.Y.Z\"' (optionally followed by a comma)"
    sed -E "s/^  \"version\": \"$semver\"(,?)\$/  \"version\": \"$version_placeholder\"\\4/" "$file"
    return
  fi
  if one_of "$rel" "${marketplaces[@]}"; then
    sed -E "s/^( *)\"version\": \"$semver\"(,?)\$/\\1\"version\": \"$version_placeholder\"\\5/" "$file"
    return
  fi

  switch "$rel"
  local n_on n_off
  n_on="$(count "$on" "$file")"
  n_off="$(count "$off" "$file")"
  [[ $((n_on + n_off)) -eq 1 ]] ||
    die "$rel must have exactly one require-signature line ($off or $on); it has $((n_on + n_off))"
  if ((!print)) && [[ "$n_on" != 1 ]]; then
    die "$rel doesn't require a signature ($on)"
  fi

  if [[ "$rel" != cursor/scripts/run-hook.cmd ]]; then
    [[ "$(count "$begin" "$file")" == 1 && "$(count "$end" "$file")" == 1 ]] ||
      die "$rel must have exactly one pn-release-signing keys block"
    b="$(grep -nxF -- "$begin" "$file" | cut -d: -f1)"
    e="$(grep -nxF -- "$end" "$file" | cut -d: -f1)"
    ((b < e)) || die "$rel: the pn-release-signing keys block ends before it begins"
  elif grep -qF 'pn-release-signing keys' "$file"; then
    die "$rel must not have a pn-release-signing keys block"
  fi

  awk -v b="$b" -v e="$e" -v on="$on" -v off="$off" -v kp="$keys_placeholder" -v sp="$switch_placeholder" '
    NR == b { print kp; next }
    b && NR > b && NR <= e { next }
    $0 == on || $0 == off { print sp; next }
    { print }' "$file"
}

hash_of() { normalize "$1" | "${sum[@]}" | cut -c1-64; }

# A hook, script, manifest, server config or launcher added without a pin
# would load or run unchecked: everything in the plugin folders and the
# marketplace folders must be one of the files, or an allowed kind.
for d in claude cursor .claude-plugin .cursor-plugin; do
  [[ -d "$tree/$d" && ! -L "$tree/$d" ]] || die "$d/ is missing, or isn't a real folder"
done
while IFS= read -r -d '' f; do
  rel="${f#"$tree"/}"
  [[ -f "$f" && ! -L "$f" ]] || die "$rel isn't a regular file or folder"
  one_of "$rel" "${files[@]}" && continue
  allowed "$rel" && continue
  die "$rel isn't one of the files check-code.sh pins, nor a kind of file a plugin may ship (a .mcp.json, .lsp.json, settings.json, command, agent, hook or script would load or run unchecked): if it's needed, add it to files= and LAUNCHER_CODE"
done < <(find "$tree/claude" "$tree/cursor" "$tree/.claude-plugin" "$tree/.cursor-plugin" ! -type d -print0)

if ((print)); then
  echo "  LAUNCHER_CODE: >-"
  for rel in "${files[@]}"; do
    h="$(hash_of "$rel")" || exit 1
    echo "    $rel=$h"
  done
  exit 0
fi

[[ -n "${LAUNCHER_CODE:-}" ]] || die "LAUNCHER_CODE (the pinned launcher code) isn't set"
# Every pin names a path with a SHA-256; a file may have several pins (see
# the top), and every file has at least one. A pin for a path that isn't one
# of the files is ignored, with a warning (see the top).
# (No associative arrays: macOS's bash 3.2 runs this too.)
pins=""
for entry in $LAUNCHER_CODE; do
  rel="${entry%%=*}"
  h="${entry#*=}"
  [[ "$entry" == *=* && "$h" =~ ^[0-9a-f]{64}$ ]] || die "LAUNCHER_CODE: \"$entry\" isn't <path>=<sha256>"
  [[ " $pins " != *" $entry "* ]] || die "LAUNCHER_CODE has $entry twice"
  if ! one_of "$rel" "${files[@]}"; then
    echo "::warning::LAUNCHER_CODE pins $rel, which this check-code.sh doesn't check (yet): ignored."
    continue
  fi
  pins="$pins $entry"
done

for rel in "${files[@]}"; do
  n=0
  ok=0
  h="$(hash_of "$rel")" || exit 1
  for entry in $pins; do
    [[ "${entry%%=*}" == "$rel" ]] || continue
    n=$((n + 1))
    [[ "${entry#*=}" == "$h" ]] && ok=1
  done
  ((n)) || die "LAUNCHER_CODE has no pin for $rel"
  ((ok)) ||
    die "$rel isn't the code this workflow pins (LAUNCHER_CODE, $n pin(s); normalized SHA-256 $h): a change to it needs its new pin in a reviewed public CI change first."
  echo "$rel: pinned code."
done
echo "The launchers, verify.ps1, run-hook.cmd, the hooks, the login scripts, the skills and rules, and the plugin and marketplace manifests are the pinned code, apart from their keys, require-signature switch and version; nothing else in the plugins can load or run."
