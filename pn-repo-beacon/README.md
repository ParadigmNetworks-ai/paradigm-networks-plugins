# pn-repo-beacon

Automatically injects git repository context (`<GIT>URL|BRANCH</GIT>`) into every Claude Code tool call and prompt. This ensures Claude always knows which repository and branch you're working in, enabling better context awareness and more accurate code modifications.

**Part of the [pn-plugins](https://github.com/paradigm-networks/pn-plugins) marketplace** — discover other Paradigm Networks tools starting with `pn-*`.

## Features

- **Automatic Repo Context Injection**: Detects git repositories in your workspace and injects their URLs and branch names
- **Two-Way Context**: 
  - Injects context on **every prompt submission** (discovers parent and child repos)
  - Injects context on **every tool call** (attaches repo info to reads, writes, and commands)
- **Multi-Repo Support**: Works seamlessly with monorepos and workspaces with multiple git repositories
- **Credential Safe**: Strips embedded userinfo (credentials) from git URLs before injection
- **Fail-Safe**: Gracefully handles errors without breaking tool calls or prompts

## Installation

### Requirements

- **jq** (JSON query tool) - Required for the plugin to function
  - **macOS**: `brew install jq`
  - **Ubuntu/Debian**: `sudo apt-get install jq`
  - **Fedora/RHEL**: `sudo dnf install jq`
  - **Windows**: `choco install jq` (via Chocolatey) or download from https://stedolan.github.io/jq/

### Install the Plugin

#### Option 1: From GitHub (Recommended)

```bash
claude /plugin install github:saadahmad-pn/pn-plugin-demo
```

or from the pn-plugins marketplace:

```bash
claude /plugin install pn-plugins/pn-repo-beacon
```

#### Option 2: From a Local Directory (Development)

```bash
claude --plugin-dir /path/to/pn-plugin-demo
```

#### Option 3: Manual Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/saadahmad-pn/pn-plugin-demo ~/.claude/plugins/pn-repo-beacon
   ```

2. Enable the plugin:
   ```bash
   claude /plugin install local:~/.claude/plugins/pn-repo-beacon
   ```

## Usage

Once installed, the plugin works automatically—no configuration needed.

### Verify Installation

After installing, verify the plugin is loaded:

```bash
claude /plugin list
```

You should see:
```
Loaded Plugins:
- pn-repo-beacon (v1.0.0)
```

### How It Works

#### On Prompt Submission
When you submit a prompt to Claude Code, the plugin:
1. Finds the current working directory's git root (if one exists)
2. Walks down the directory tree to find child repos (up to depth 2)
3. Injects a context block with the working directory and all discovered repos

**Example injected context:**
```
Current working directory: /Users/me/workspace/my-project

Active git repositories:
<GIT>https://github.com/user/my-project|main</GIT>
<GIT>https://github.com/user/sub-module|feature-branch</GIT>
```

#### Before Tool Calls
When Claude calls Read, Write, Edit, or Bash tools, the plugin:
1. Extracts the file path from the tool call
2. Walks up to find the git repository root
3. Injects the repo's URL and current branch as `<GIT>` context

**Example injected context:**
```
<GIT>https://github.com/user/my-project|main</GIT>
```

This context helps Claude understand which repo a file belongs to when working in monorepos.

## Troubleshooting

### Plugin Not Injecting Context

**Check 1: Is jq installed?**
```bash
which jq
```

If not found, install jq:
- **macOS**: `brew install jq`
- **Ubuntu**: `sudo apt-get install jq`
- **Fedora**: `sudo dnf install jq`

**Check 2: Run the diagnostic script**
```bash
bash scripts/validate-plugin.sh
```

This will:
- Verify jq is installed
- Test hook script syntax
- Validate JSON output format
- Check for git repositories in the current directory

**Check 3: Check the logs**

The plugin logs to `~/.cache/pn-plugin/`:
```bash
# View UserPromptSubmit hook logs
tail -f ~/.cache/pn-plugin/userpromptsubmit-hook.log

# View PreToolUse hook logs
tail -f ~/.cache/pn-plugin/pretooluse-hook.log
```

Look for error messages like:
- `ERROR: jq is not installed` → Install jq
- `ERROR: received invalid JSON on stdin` → Plugin may have received malformed data
- `No git repo found` → No repositories detected in the search path

**Check 3: Test Manually**

Test if hooks fire correctly:

```bash
# Test UserPromptSubmit hook
echo '{"cwd": "/Users/me/workspace/my-project"}' | bash scripts/claude-userpromptsubmit.sh

# Test PreToolUse hook
echo '{"tool_name": "Read", "tool_input": {"file_path": "/Users/me/workspace/my-project/main.ts"}}' | bash scripts/claude-pretooluse.sh
```

Both should output valid JSON with `hookEventName` and `additionalContext` fields.

### Plugin Slowing Down Prompts

If you notice slow prompt submissions:
1. The plugin scans up to depth 2 for repos—this is typically fast unless you have deeply nested large directories
2. Check if your workspace has thousands of files: the find operation may be slow
3. Consider organizing repos: keep unrelated projects in separate parent directories

### Wrong Repo Context Injected

This can happen in these cases:

**Monorepo confusion**: If you have nested monorepos, the plugin finds the outermost `.git` directory first. If you need the innermost repo context, move the outer `.git` to a different location or restructure your monorepo.

**Detached HEAD state**: If a repo is in a detached HEAD state, the branch name shows as "detached" instead of the commit SHA. This is by design to keep context clean.

## Configuration

The plugin works automatically with no configuration needed. However, you can customize behavior by creating a `CLAUDE.md` file in your project root:

```markdown
# My Project Configuration

This plugin automatically injects git context. You don't need to add anything here—it works automatically!
```

## Architecture

### Hook System

The plugin uses Claude Code's hook system to inject context at two key points:

| Hook | When | Purpose |
|------|------|---------|
| `UserPromptSubmit` | Before Claude processes your prompt | Discover all repos in the workspace |
| `PreToolUse` | Before Claude calls a tool (Read, Write, etc.) | Attach repo context to the specific file |

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/claude-userpromptsubmit.sh` | Handles UserPromptSubmit hook events |
| `scripts/claude-pretooluse.sh` | Handles PreToolUse hook events |
| `scripts/lib/git-utils.sh` | Shared git utilities and sanitization functions |
| `scripts/validate-plugin.sh` | Diagnostic tool to verify plugin health |

### Security

- **Git values are sanitized**: Usernames, passwords, and control characters are stripped from git URLs and branch names before injection
- **No credentials exposed**: Even if your git remote URL contains credentials (bad practice!), they're removed before injection
- **Symlink safety**: The plugin refuses to follow symlinks during directory scanning to prevent symlink attacks
- **Fail-safe design**: Any error in the plugin results in the tool call or prompt proceeding without context, never blocking

## Development

### Running Tests

```bash
# Test the UserPromptSubmit hook
echo '{"cwd": "'$(pwd)'"}' | bash scripts/claude-userpromptsubmit.sh | jq .

# Test the PreToolUse hook
echo '{"tool_name": "Read", "tool_input": {"file_path": "'$(pwd)'/README.md"}}' | bash scripts/claude-pretooluse.sh | jq .
```

### Running the Diagnostic

```bash
bash scripts/validate-plugin.sh
```

### Modifying Hook Behavior

Edit the relevant script in `scripts/`:
- `claude-userpromptsubmit.sh` - Change how prompts are contextualized
- `claude-pretooluse.sh` - Change how tool calls are contextualized
- `lib/git-utils.sh` - Change git discovery or sanitization logic

After editing, test with the manual tests above.

## Common Questions

**Q: Does this work with private GitHub repos?**
A: Yes! The plugin extracts the public HTTPS URL from your git config. It doesn't authenticate or access the repo—it just uses the URL for context.

**Q: Can I disable the plugin?**
A: Yes, run:
```bash
claude /plugin disable pn-repo-beacon
```

Re-enable with:
```bash
claude /plugin enable pn-repo-beacon
```

**Q: Does this work with GitLab, Gitea, Bitbucket, etc.?**
A: Yes! The plugin extracts whatever URL is in your `remote.origin.url` git config, regardless of the git host.

**Q: What if I don't want context injected for a specific repo?**
A: Move it outside the workspace scan path. The plugin only scans from your current working directory down to depth 2.

**Q: Can I use this with multiple Claude Code instances?**
A: Yes! Each instance gets its own context based on the working directory it was started from.

## Contributing

Found a bug or have a feature request? Open an issue at [github.com/saadahmad-pn/pn-plugin-demo/issues](https://github.com/saadahmad-pn/pn-plugin-demo/issues).

## License

MIT License - See [LICENSE](LICENSE) file for details

## Support

For issues or questions:
1. Run the diagnostic: `bash scripts/validate-plugin.sh`
2. Check the logs: `tail -f ~/.cache/pn-plugin/*.log`
3. Review this README's Troubleshooting section
4. Open an issue with your diagnostic output