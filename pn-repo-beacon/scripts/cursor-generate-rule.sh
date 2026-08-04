#!/bin/bash
# pn-plugin: Cursor beforeSubmitPrompt hook
#
# What this replaces from the original extension:
#   - the live vscode.workspace.createFileSystemWatcher on .git/HEAD
#   - the reactive rewrite of .cursor/rules/pn-plugin.mdc in the extension host
#
# Trade-off (documented, agreed with user): no instant-on-checkout update.
# Instead this re-scans right before every prompt, which is the closest
# equivalent a plugin (no persistent process) can offer.
#
# WRITE TARGET: the rule file is written into THIS WORKSPACE's own
# <workspace>/.cursor/rules/pn-plugin.mdc — not the plugin's shared global
# folder. This avoids the collision where two Cursor windows on two
# different projects would otherwise stomp on the same shared file.
# Same pattern the Hindsight plugin uses for the same reason.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/git-utils.sh"

# Fail-open safety net: Cursor's hook contract expects a JSON response on
# every invocation, and this hook must never block prompt submission just
# because a write failed for one workspace root (disk full, permissions,
# unexpected input, etc). Whatever happens below, always emit "continue"
# exactly once before the process exits.
CONTINUE_EMITTED=0
emit_continue() {
    if [ "$CONTINUE_EMITTED" -eq 0 ]; then
        echo '{"continue": true}'
        CONTINUE_EMITTED=1
    fi
    # Force success even if we got here because an earlier command failed
    # under `set -e` — a hook runner that treats a non-zero exit as a hard
    # failure (ignoring stdout) must not end up blocking prompt submission.
    exit 0
}
trap emit_continue EXIT

# is_safe_workspace_root <root>
# Defense-in-depth check on the workspace_roots the hook payload claims are
# active. We still trust the Cursor IPC channel this arrives on, but this
# guards against ever mkdir -p / writing a rule file + appending .gitignore
# into a root-level system directory if a malformed/unexpected path shows up.
is_safe_workspace_root() {
    local root="$1"
    case "$root" in
        /|/etc|/etc/*|/usr|/usr/*|/bin|/bin/*|/sbin|/sbin/*|/var|/var/*|/System|/System/*|/Library|/Library/*|/root|/root/*)
            return 1
            ;;
    esac
    [[ "$root" == /* ]] || return 1
    return 0
}

# ensure_gitignored <workspace_root> <relative_path>
# Adds the given path to the workspace's .gitignore if not already covered,
# so the generated rule file never risks being accidentally committed.
ensure_gitignored() {
    local workspace_root="$1"
    local rel_path="$2"
    local gitignore="$workspace_root/.gitignore"

    if [ -f "$gitignore" ] && grep -qxF "$rel_path" "$gitignore" 2>/dev/null; then
        return 0
    fi

    {
        echo ""
        echo "# Added by pn-plugin — generated, workspace-local agent context"
        echo "$rel_path"
    } >> "$gitignore"
}

# Read the hook payload from stdin. Cursor hooks receive JSON on stdin;
# workspace_roots is the field we need (see hooks reference / TrueFoundry docs).
INPUT=$(cat)
WORKSPACE_ROOTS=$(echo "$INPUT" | jq -r '.workspace_roots[]?' 2>/dev/null || true)

if [ -z "$WORKSPACE_ROOTS" ]; then
    # No workspace context available — leave the existing rule file alone,
    # allow the prompt to continue.
    exit 0
fi

# Write one rule file PER workspace root, scoped to that root's own repos.
# This is what actually prevents the multi-window collision: each project
# gets its own <root>/.cursor/rules/pn-plugin.mdc, not one shared file.
while IFS= read -r root; do
    [ -z "$root" ] && continue
    [ -d "$root" ] || continue
    if ! is_safe_workspace_root "$root"; then
        echo "Skipping unsafe/unexpected workspace root: $root" >&2
        continue
    fi
    # Canonicalize so a relative segment or symlink in the reported root
    # can't redirect writes outside the intended workspace directory.
    root="$(cd "$root" 2>/dev/null && pwd -P)" || continue
    is_safe_workspace_root "$root" || continue

    FOUND_REPOS=$(find_git_repos "$root")
    UNIQUE_REPOS=$(echo "$FOUND_REPOS" | grep -v '^$' | dedupe_lines || true)

    # Build the rule body — same <GIT>url|branch<GIT> format as the original
    # extension's generateRepoBeaconRule(), so downstream agent behavior is unchanged.
    if [ -z "$UNIQUE_REPOS" ]; then
        REPO_LIST="- No git repositories detected in this workspace."
    else
        REPO_LIST=""
        i=1
        while IFS= read -r repo_path; do
            [ -z "$repo_path" ] && continue
            remote=$(get_remote_url "$repo_path")
            branch=$(get_current_branch "$repo_path")
            REPO_LIST="${REPO_LIST}${i}. <GIT>${remote}|${branch}<GIT>"$'\n'
            i=$((i + 1))
        done <<< "$UNIQUE_REPOS"
    fi

    RULE_DIR="$root/.cursor/rules"
    RULE_FILE="$RULE_DIR/pn-plugin.mdc"
    mkdir -p "$RULE_DIR"

    cat > "$RULE_FILE" << EOF
---
alwaysApply: true
---

### Available Repositories:
${REPO_LIST}
EOF

    ensure_gitignored "$root" ".cursor/rules/pn-plugin.mdc"
done <<< "$WORKSPACE_ROOTS"

exit 0
