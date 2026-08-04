#!/bin/bash
# repo-beacon: PreToolUse hook
#
# NOTE: this hook is context-injection ONLY. It always returns
# "permissionDecision": "allow" — it does not inspect tool input for
# anything dangerous and must not be relied on as a security/permission
# gate. Its only job is attaching <GIT> repo context to the tool call.
#
# It also fails OPEN: any unexpected error (missing jq, malformed stdin,
# git failures) is logged and results in the tool call being allowed
# without extra context, never in the tool call being blocked.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/git-utils.sh"

LOG_DIR="$HOME/.cache/pn-plugin"
LOG_FILE="$LOG_DIR/pretooluse-hook.log"
LOG_MAX_BYTES=$((5 * 1024 * 1024))

log() {
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    mkdir -p "$LOG_DIR" 2>/dev/null
    # Refuse to write through a symlink planted at the log path.
    [ -L "$LOG_FILE" ] && return 0
    if [ -f "$LOG_FILE" ]; then
        local size
        size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
        [ "$size" -gt "$LOG_MAX_BYTES" ] && : > "$LOG_FILE"
    fi
    echo "[$timestamp] $1" >> "$LOG_FILE" 2>/dev/null || true
}

if ! command -v jq &>/dev/null; then
    log "ERROR: jq is not installed — allowing without context"
    cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
    exit 0
fi

INPUT=$(cat)

if ! echo "$INPUT" | jq empty 2>/dev/null; then
    log "ERROR: received invalid JSON on stdin — failing open"
    cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
    exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
BASH_CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

log "PreToolUse fired | Tool: $TOOL_NAME"

# Function to find git root
find_git_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    echo ""
}

# Extract a usable path depending on the tool
extract_path() {
    case "$TOOL_NAME" in
        Write|Edit|Read)
            echo "$FILE_PATH"
            ;;
        Bash)
            # Try to extract a path from the bash command
            # Look for absolute paths in the command first
            local found
            found=$(echo "$BASH_CMD" | grep -oE '/[a-zA-Z0-9/_.-]+' | head -1)
            if [ -n "$found" ]; then
                echo "$found"
            else
                # Fall back to the current working directory so we still
                # inject repo context for cwd-relative commands like
                # `find . -name foo` or `ls`
                pwd
            fi
            ;;
        Glob|Grep)
            echo "$( echo "$INPUT" | jq -r '.tool_input.path // ""' )"
            ;;
        *)
            echo ""
            ;;
    esac
}

TARGET_PATH=$(extract_path)
log "Extracted path: ${TARGET_PATH:-none}"

# Only proceed if we have a path
if [ -z "$TARGET_PATH" ]; then
    log "No path found for tool: $TOOL_NAME — allowing without context"
    cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
    log "----------------------------------------"
    exit 0
fi

# Find git root from the extracted path
GIT_ROOT=$(find_git_root "$(dirname "$TARGET_PATH")")

if [ -z "$GIT_ROOT" ]; then
    log "No git repo found for path: $TARGET_PATH — allowing without context"
    cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
    log "----------------------------------------"
    exit 0
fi

log "Found repo: $(basename "$GIT_ROOT")"

# Build repo context
cd "$GIT_ROOT" 2>/dev/null || exit 0

BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
URL=$(git config --get remote.origin.url 2>/dev/null || echo "No remote")

if [[ $URL == git@github.com:* ]]; then
    URL="https://github.com/${URL#git@github.com:}"
    URL="${URL%.git}"
elif [[ $URL == *.git ]]; then
    URL="${URL%.git}"
fi

URL=$(sanitize_git_value "$URL")
BRANCH=$(sanitize_git_value "$BRANCH")

CONTEXT="<GIT>${URL}|${BRANCH}</GIT>"

log "Injecting context for: $(basename "$GIT_ROOT")"
log "=== CONTEXT ==="
log "$CONTEXT"
log "=== END CONTEXT ==="

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "additionalContext": $(echo "$CONTEXT" | jq -Rs . 2>/dev/null || echo "\"$CONTEXT\"")
  }
}
EOF

log "----------------------------------------"
exit 0