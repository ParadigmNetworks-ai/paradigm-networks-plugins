#!/bin/bash
# Prints the GitHub Release notes for v<version>: its CHANGELOG.md section,
# what the attached files are, and where the builds came from (BUILD).
#
# Usage: .github/scripts/release-notes.sh <tree> <version>

set -euo pipefail

[[ $# -eq 2 ]] || {
  echo "usage: $0 <tree> <version>" >&2
  exit 2
}
tree="$1"
tag="v$2"

# The section "## v<version>, <date>" up to the next "## ". No section, no
# notes: a release without one fails here rather than going out without them.
awk -v h="## $tag, " '
  index($0, h) == 1 { on = 1; found = 1; next }
  on && /^## / { exit }
  on
  END { if (!found) exit 1 }' "$tree/CHANGELOG.md" || {
  echo "::error::$tree/CHANGELOG.md has no \"## $tag, <date>\" section." >&2
  exit 1
}
cat <<'EOF'

### Builds

Each plugin already contains these builds and checks them before every run; you don't need to download them.
`claude-SHA256SUMS` and `cursor-SHA256SUMS` are the lists the Paradigm Networks release key signs (each plugin's `bin/SHA256SUMS`): the six builds attached here, plus every other file that plugin ships. `sha256sum --check --ignore-missing claude-SHA256SUMS` checks downloaded builds.
`<plugin>-SHA256SUMS.sig` is the list's signature (DER, for openssl) and `<plugin>-SHA256SUMS.sig.p1363` the same signature in IEEE P1363 form (for Windows PowerShell). See the README.

```
EOF
sed -n '/^source_/p; /^version:/p; /^go:/p' "$tree/BUILD"
echo '```'
