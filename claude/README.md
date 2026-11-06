# Paradigm Networks for Claude Code

Paradigm Networks checks what happens in your Claude Code sessions against
your organization's security policy. It catches things like destructive
commands or unsafe code before they go through.

> **A Paradigm Networks account is required.** The plugin does nothing on its
> own: every check is made by your organization's Paradigm Networks
> deployment (for example `https://acme.paradigmnetworks.ai`). New to
> Paradigm Networks? [Sign up](https://signup.paradigmnetworks.ai/signup).

## What it does

- **Checks prompts** before they are sent to the model.
- **Checks tool calls** before they run: file edits, shell commands and MCP
  tool calls made by the agent.
- **Checks git operations.** When the agent runs `git push` or `git commit`,
  the changed files are checked first and the operation is denied if they
  violate policy.
- **Records the conversation** (prompts, agent responses and tool results) in
  your organization's Paradigm Networks deployment, where your team can
  review it. Commits, pushes and pull requests made by the agent show up in
  Code Chain.

Blocked actions are denied with a message explaining why. The plugin never
approves a tool call on your behalf: anything it allows still goes through
Claude Code's own permission prompts and rules.

## Install

In Claude Code, add this repository as a plugin marketplace and install the
plugin:

```
/plugin marketplace add ParadigmNetworks-ai/paradigm-networks-plugins
/plugin install paradigm-networks@paradigm-networks-plugins
```

Then restart Claude Code.

### For admins

To roll the plugin out to your organization, add the marketplace and enable
the plugin in Claude Code's managed settings:

```json
{
  "extraKnownMarketplaces": {
    "paradigm-networks-plugins": {
      "source": { "source": "github", "repo": "ParadigmNetworks-ai/paradigm-networks-plugins" }
    }
  },
  "enabledPlugins": {
    "paradigm-networks@paradigm-networks-plugins": true
  }
}
```

If your managed settings set `allowManagedHooksOnly`, the plugin's hooks run
only when the plugin is enabled in managed settings like this.

### Requirements

- Claude Code 2.1.295 or later.
- macOS, Linux or Windows, on an Intel or ARM (Apple Silicon) processor.
  Nothing else needs installing:
  the plugin ships its own program for each. On Linux, `secret-tool`
  (libsecret) lets the plugin keep your login in the Secret Service keyring;
  without it, see [Data handling](#data-handling).
- Your organization's Paradigm Networks service must be reachable from your
  machine.

## Log in (one time per machine)

The first time you use Claude Code after installing, Claude asks for your
organization's Paradigm Networks URL, which must start with `https://`.
Confirm, and your browser opens to sign you in. Nothing to copy or paste. The
login is remembered on this machine.

To switch organizations, ask Claude to log in to Paradigm Networks again. It
replaces the old login. To sign out, ask Claude to log out of Paradigm
Networks (the **paradigmnetworks-logout** skill handles it). Logging out
revokes the login on your Paradigm Networks server and removes it from this
machine. If the server can't be reached, the login is still removed locally,
and Claude tells you it couldn't be revoked on the server.

Until you log in, prompts go through but Claude's tool calls (file edits,
shell commands, MCP tools) are blocked, apart from the login itself.

A login lasts up to 30 days (your organization can change this), after which
you sign in again in the browser. Your organization's admins can also end
your login, for example if a laptop is lost. In both cases your next prompt
is blocked with a message, and your browser opens so you can sign in again.

The Claude Code plugin has its own login, separate from the Cursor plugin's:
logging in to one doesn't log in the other.

## What's in the plugin

| Component | Purpose |
| --- | --- |
| `hooks/hooks.json` | Hooks for session start/end, prompt submit, tool calls and agent responses. These do the checking and recording. |
| `skills/paradigmnetworks-login` | Logs this machine in to your Paradigm Networks deployment. |
| `skills/paradigmnetworks-logout` | Revokes the login on the server and removes it from this machine. |
| `bin/` | The program the hooks run (`pn-plugin`, one build per OS and processor). |
| `scripts/` | The login, logout and login-check commands the skills run. |

## Data handling

The plugin sends data **only to your organization's own Paradigm Networks
deployment**, the URL you log in with. It does not send anything to a
shared or third-party server operated by the plugin.

What is sent, and when:

| Data | When |
| --- | --- |
| Your prompt text | Before each prompt is submitted |
| The agent's response | After each agent response |
| Tool call inputs (file edits, shell commands, MCP arguments) and their results | Before and after each tool call |
| The surrounding conversation for the current turn | With a tool call, so intent can be assessed |
| Contents of changed files | When the agent runs `git push` or `git commit` |
| Working directory, git remote URL, branch and model name | With each of the above |

The plugin reads the current turn's text and the model name from Claude
Code's session transcript (`transcript_path` in the hook input).

Your login (the server URL and login tokens) is kept in your OS credential
store: the macOS Keychain, the Secret Service keyring on Linux (via
`secret-tool`), or on Windows a file encrypted for your Windows account
(`~/.pn/claude-code-tokens.dpapi`, DPAPI). Where no credential store is
available, such as headless
Linux, it is kept in `~/.pn/claude-code-credentials.json` instead, readable
only by you. Set `PN_CREDENTIAL_STORE=file` to always keep it there.

What the plugin writes on your machine:

- `~/.paradigm-networks/claude-code/`: debug logs, an audit log, session
  metadata and caches, readable only by you. Each log is capped at about
  1 MB, plus one older copy (`<log>.1`).

Retention and use of the data on the server side is governed by your
organization's agreement with Paradigm Networks. See our
[Privacy Policy](https://paradigmnetworks.ai/privacy-policy/) and
[Terms of Service](https://paradigmnetworks.ai/terms/).

Paradigm Networks does not use data collected through this plugin to train
its AI models.

## Try it

1. Install the plugin and log in.
2. Submit a prompt or make an edit that your organization's policy blocks. It
   should be denied with a message explaining why.
3. Submit something that's allowed. It should go through normally.
4. Ask Claude to `git push` or `git commit` in a repo containing a
   policy-violating change. It should be denied before the operation runs.

If something doesn't work, see [Troubleshooting](#troubleshooting).

## Settings

The defaults suit most users. These environment variables change them; they
must be set in the environment Claude Code is started from.

| Variable | Default | Effect |
| --- | --- | --- |
| `PARADIGM_NETWORKS_FAILURE_MODE` | `block` | `allow` lets tool calls through, unchecked, when Paradigm Networks can't be reached or you aren't logged in. |
| `PARADIGM_NETWORKS_PROMPT_FAILURE_MODE` | `allow` | `block` blocks prompts when Paradigm Networks can't be reached. |
| `PARADIGM_NETWORKS_TIMEOUT` | `60` | Seconds to wait for Paradigm Networks on each check. |
| `PN_CREDENTIAL_STORE` | unset | `file` keeps your login in `~/.pn/claude-code-credentials.json` instead of the OS credential store. |
| `PN_ALLOW_INSECURE_HTTP` | unset | `1` lets you log in to a plain `http://` URL on any host. For local development only (for example a hosts-file name like `http://fs1.localhost.ai`); without it, `http://` is allowed only for `localhost`. |

## Troubleshooting

- Run `claude --debug` to see each hook run and what it returned, or check
  `/hooks` in Claude Code to see the plugin's hooks are loaded.
- The plugin logs to `~/.paradigm-networks/claude-code/`. When reporting a
  problem, attach `audit.jsonl` (one line per allow/deny decision) and the log
  for the step that failed: `check-prompt.log`, `check-tool-call.log`,
  `pn-config.log` (login and token refresh) or `background-login.log`. They
  don't contain your prompts, but they can contain the agent's commands and
  file paths, so check them before sharing.
- If the browser sign-in finishes but Claude says the login failed with
  `could not reach` or `unexpected non-JSON response`, Claude Code's sandbox
  blocked the login's network access. Run the login command Claude shows in
  your own terminal.

## Limitations

- **What is scanned.** Every prompt and every agent tool call (file edits,
  shell commands, MCP tools) is checked before it runs. The contents of
  changed files are checked for `git push` and `git commit` run by the agent;
  other edits are checked as the edit itself. A file changed by a shell
  command (e.g. `sed -i`) is checked as a command, but its resulting contents
  are not.
- **Only the agent's actions are checked.** Commands you type into a
  terminal yourself, including `git push`, are not.
- **If Paradigm Networks can't be reached, prompts are allowed through and
  tool calls are blocked** (see [Settings](#settings)). This is intentional,
  so a user who isn't logged in yet can still ask Claude to log in. It also
  means someone who can block this machine's network access to Paradigm
  Networks can disable prompt checks, while tool calls stay blocked.
- **If a check itself fails** (it crashes or exceeds its time limit), Claude
  Code blocks the prompt or tool call.
- **Tool results are recorded in the background**, so the result of the very
  last tool call can be missed if Claude Code exits straight after it.

## Support

- Questions and bugs: plugins@paradigmnetworks.ai or open an issue on this
  repo.
- Security issues: see [SECURITY.md](SECURITY.md). Please don't open a public
  issue.

## More

- [License](LICENSE) (MIT)
