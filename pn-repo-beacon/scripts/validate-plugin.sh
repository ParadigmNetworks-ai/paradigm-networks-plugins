#!/bin/bash
# pn-plugin: Diagnostic and validation script
#
# Tests that the plugin is properly installed and all dependencies are met.
# Run this if the plugin isn't injecting context as expected.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}pn-plugin Diagnostic Tool${NC}"
echo -e "${BLUE}===========================${NC}\n"

# Test 1: Check if jq is installed
echo -e "${BLUE}Test 1: Checking jq installation...${NC}"
if command -v jq &>/dev/null; then
    echo -e "${GREEN}✓ jq is installed${NC}"
    JQ_VERSION=$(jq --version)
    echo "  Version: $JQ_VERSION"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ jq is NOT installed${NC}"
    echo "  Install with:"
    echo "    macOS: brew install jq"
    echo "    Ubuntu/Debian: sudo apt-get install jq"
    echo "    Fedora/RHEL: sudo dnf install jq"
    echo "    Windows: choco install jq (or download from https://stedolan.github.io/jq/)"
    ((TESTS_FAILED++))
fi
echo ""

# Test 2: Check if scripts are executable
echo -e "${BLUE}Test 2: Checking script permissions...${NC}"
SCRIPTS_OK=true

for script in claude-userpromptsubmit.sh claude-pretooluse.sh; do
    script_path="$SCRIPT_DIR/$script"
    if [ -f "$script_path" ]; then
        if [ -x "$script_path" ]; then
            echo -e "${GREEN}✓ $script is executable${NC}"
        else
            echo -e "${RED}✗ $script is NOT executable${NC}"
            echo "  Fix with: chmod +x $script_path"
            SCRIPTS_OK=false
        fi
    else
        echo -e "${RED}✗ $script not found${NC}"
        SCRIPTS_OK=false
    fi
done

if [ "$SCRIPTS_OK" = true ]; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi
echo ""

# Test 3: Check plugin.json exists and is valid
echo -e "${BLUE}Test 3: Checking plugin.json...${NC}"
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
if [ -f "$PLUGIN_JSON" ]; then
    if jq empty "$PLUGIN_JSON" 2>/dev/null; then
        echo -e "${GREEN}✓ plugin.json exists and is valid JSON${NC}"
        PLUGIN_NAME=$(jq -r '.name' "$PLUGIN_JSON")
        PLUGIN_VERSION=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null || echo "unknown")
        echo "  Name: $PLUGIN_NAME"
        echo "  Version: $PLUGIN_VERSION"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ plugin.json exists but is invalid JSON${NC}"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${RED}✗ plugin.json not found at $PLUGIN_JSON${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Test 4: Check hooks.json exists and is valid
echo -e "${BLUE}Test 4: Checking hooks.json...${NC}"
HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
if [ -f "$HOOKS_JSON" ]; then
    if jq empty "$HOOKS_JSON" 2>/dev/null; then
        echo -e "${GREEN}✓ hooks.json exists and is valid JSON${NC}"
        HOOK_EVENTS=$(jq -r '.hooks | keys[]' "$HOOKS_JSON" 2>/dev/null)
        echo "  Configured hooks:"
        echo "$HOOK_EVENTS" | sed 's/^/    - /'
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ hooks.json exists but is invalid JSON${NC}"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${RED}✗ hooks.json not found at $HOOKS_JSON${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Test 5: Check script syntax
echo -e "${BLUE}Test 5: Checking script syntax...${NC}"
SYNTAX_OK=true

for script in claude-userpromptsubmit.sh claude-pretooluse.sh lib/git-utils.sh; do
    script_path="$SCRIPT_DIR/$script"
    if [ -f "$script_path" ]; then
        if bash -n "$script_path" 2>/dev/null; then
            echo -e "${GREEN}✓ $script syntax OK${NC}"
        else
            echo -e "${RED}✗ $script has syntax errors${NC}"
            bash -n "$script_path" 2>&1 | sed 's/^/  /'
            SYNTAX_OK=false
        fi
    fi
done

if [ "$SYNTAX_OK" = true ]; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi
echo ""

# Test 6: Test UserPromptSubmit hook
echo -e "${BLUE}Test 6: Testing UserPromptSubmit hook...${NC}"
if command -v jq &>/dev/null; then
    TEST_INPUT='{"cwd": "'"$(pwd)"'"}'
    TEST_OUTPUT=$(echo "$TEST_INPUT" | bash "$SCRIPT_DIR/claude-userpromptsubmit.sh" 2>/dev/null)

    if echo "$TEST_OUTPUT" | jq empty 2>/dev/null; then
        echo -e "${GREEN}✓ UserPromptSubmit hook produces valid JSON${NC}"
        HAS_CONTEXT=$(echo "$TEST_OUTPUT" | jq 'has("hookSpecificOutput")' 2>/dev/null)
        if [ "$HAS_CONTEXT" = "true" ]; then
            echo -e "${GREEN}✓ Output has hookSpecificOutput field${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Output missing hookSpecificOutput field${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}✗ UserPromptSubmit hook output is invalid JSON${NC}"
        echo "  Output: $TEST_OUTPUT"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${YELLOW}⊘ Skipped (jq not installed)${NC}"
fi
echo ""

# Test 7: Test PreToolUse hook
echo -e "${BLUE}Test 7: Testing PreToolUse hook...${NC}"
if command -v jq &>/dev/null; then
    TEST_INPUT='{"tool_name": "Read", "tool_input": {"file_path": "'"$(pwd)"'/README.md"}}'
    TEST_OUTPUT=$(echo "$TEST_INPUT" | bash "$SCRIPT_DIR/claude-pretooluse.sh" 2>/dev/null)

    if echo "$TEST_OUTPUT" | jq empty 2>/dev/null; then
        echo -e "${GREEN}✓ PreToolUse hook produces valid JSON${NC}"
        HAS_OUTPUT=$(echo "$TEST_OUTPUT" | jq 'has("hookSpecificOutput")' 2>/dev/null)
        if [ "$HAS_OUTPUT" = "true" ]; then
            echo -e "${GREEN}✓ Output has hookSpecificOutput field${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Output missing hookSpecificOutput field${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}✗ PreToolUse hook output is invalid JSON${NC}"
        echo "  Output: $TEST_OUTPUT"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${YELLOW}⊘ Skipped (jq not installed)${NC}"
fi
echo ""

# Test 8: Check for git repositories
echo -e "${BLUE}Test 8: Checking for git repositories...${NC}"
GIT_COUNT=$(find "$(pwd)" -maxdepth 2 -name ".git" -type d 2>/dev/null | wc -l)
if [ "$GIT_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $GIT_COUNT git repository/repositories${NC}"
    find "$(pwd)" -maxdepth 2 -name ".git" -type d 2>/dev/null | while read -r git_dir; do
        repo_root=$(dirname "$git_dir")
        branch=$(git -C "$repo_root" branch --show-current 2>/dev/null || echo "detached")
        url=$(git -C "$repo_root" config --get remote.origin.url 2>/dev/null || echo "no remote")
        echo "  - $(basename "$repo_root") [$branch] ($url)"
    done
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⊘ No git repositories found in current directory (depth 2)${NC}"
    echo "  This is OK if you're not in a git workspace"
fi
echo ""

# Test 9: Check log directory
echo -e "${BLUE}Test 9: Checking log directory...${NC}"
LOG_DIR="$HOME/.cache/pn-plugin"
if [ -d "$LOG_DIR" ]; then
    echo -e "${GREEN}✓ Log directory exists at $LOG_DIR${NC}"
    LOG_SIZE=$(du -sh "$LOG_DIR" 2>/dev/null | awk '{print $1}')
    echo "  Size: $LOG_SIZE"
    if [ -f "$LOG_DIR/userpromptsubmit-hook.log" ]; then
        LAST_LINES=$(tail -3 "$LOG_DIR/userpromptsubmit-hook.log" 2>/dev/null)
        echo "  Recent UserPromptSubmit logs:"
        echo "$LAST_LINES" | sed 's/^/    /'
    fi
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⊘ Log directory not yet created (will be created on first hook execution)${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}===========================${NC}"
echo -e "${BLUE}Diagnostic Summary${NC}"
echo -e "${BLUE}===========================${NC}"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! The plugin should be working correctly.${NC}"
    echo ""
    echo "If the plugin still isn't injecting context:"
    echo "  1. Make sure the plugin is enabled: claude /plugin list"
    echo "  2. Check the logs: tail -f ~/.cache/pn-plugin/*.log"
    echo "  3. Test manually: echo '{\"cwd\": \"'$(pwd)'\"}' | bash scripts/claude-userpromptsubmit.sh"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. See above for details.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  1. Install jq: https://stedolan.github.io/jq/"
    echo "  2. Make scripts executable: chmod +x scripts/*.sh"
    echo "  3. Reinstall the plugin: claude /plugin uninstall pn-plugin && claude /plugin install github:saadahmad-pn/pn-plugin-demo"
    exit 1
fi