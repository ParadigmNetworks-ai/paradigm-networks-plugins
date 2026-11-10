# Paradigm Networks for Cursor

Paradigm Networks checks what happens in your Cursor sessions against your
organization's security policy. It catches things like destructive commands
or unsafe code before they go through.

> **A Paradigm Networks account is required.** The plugin does nothing on its
> own: every check is made by your organization's Paradigm Networks
> deployment (for example `https://acme.paradigmnetworks.ai`). New to
> Paradigm Networks? [Sign up](https://signup.paradigmnetworks.ai/signup).

## What it does

- **Checks prompts** before they are sent to the model.
- **Checks tool calls** before they run: file edits, shell commands and MCP
  tool calls made by the agent.
- **Checks git operations.** When the agent runs `git push`, `git commit` or
  `gh pr create`, the changed files are checked first and the operation is
  denied if they violate policy.
- **Records the conversation** (prompts, agent responses and tool results) in
  your organization's Paradigm Networks deployment, where your team can
  review it.

Blocked actions are denied with a message explaining why.

## Install

### From the Cursor Marketplace

Search for **Paradigm Networks** in the Cursor Marketplace, or run:

```
/add-plugin paradigm-networks
```

### For team admins

Cursor Team and Enterprise admins can also import this repo as a private
marketplace and make the plugin **Default On** or **Required**, so teammates
get it automatically:

1. In the Cursor dashboard, go to **Dashboard → Customize**.
2. Under **Browse Marketplaces**, click **Add Marketplace**, then choose
   **Import from Github**.
3. Enter this repo's URL: `https://github.com/ParadigmNetworks-ai/paradigm-networks-plugins`.
4. Click **Add to Marketplace**, then under **Marketplace Settings** set
   **Marketplace Access** and save.

### Requirements

- macOS, Linux or Windows.
- An Intel or ARM (Apple Silicon) processor. Nothing else needs installing:
  the plugin ships its own program for each. On Linux,
  `secret-tool` (libsecret) lets the plugin keep your login in the Secret
  Service keyring; without it, see [Data handling](#data-handling).
- Windows: Windows PowerShell 5.1 (built in), for the login and logout
  commands.
- Your organization's Paradigm Networks service must be reachable from your
  machine.

## Log in (one time per machine)

The first time you use Cursor after installing, you'll be asked for your
organization's Paradigm Networks URL, which must start with `https://`.
Confirm, and your browser opens to sign
you in. Nothing to copy or paste. Cursor remembers the login on this machine.

To switch organizations, ask the agent to log in again. It replaces the old
login. To sign out, ask the agent to log out (the **paradigmnetworks-logout**
skill handles it). Logging out revokes the login on your Paradigm Networks
server and removes it from this machine. If the server can't be reached, the
login is still removed locally, and the agent tells you it couldn't be revoked
on the server.

Until you log in, prompts go through but the agent's tool calls (file edits,
shell commands, MCP tools) are blocked, apart from the login itself.

A login lasts up to 30 days (your organization can change this), after which
you sign in again in the browser. Your organization's admins can also end
your login, for example if a laptop is lost. In both cases your next prompt
is blocked with a message, and your browser opens so you can sign in again.

## What's in the plugin

| Component | Purpose |
| --- | --- |
| `hooks/hooks.json` | Hooks for session start/end, prompt submit, tool calls and agent responses. These do the checking and recording. |
| `skills/paradigmnetworks-login` | Logs this machine in to your Paradigm Networks deployment. |
| `skills/paradigmnetworks-logout` | Revokes the login on the server and removes it from this machine. |
| `rules/pn-login-check.mdc` | Makes the agent confirm you're logged in on the first message of a session. |
| `bin/` | The program the hooks run (`pn-plugin`, one build per OS and processor). |
| `scripts/` | The login, logout and login-check commands the skills run, and the hook dispatcher. |

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
| Contents of changed files | When the agent runs `git push`, `git commit` or `gh pr create` |
| Working directory, git remote URL, branch and model name | With each of the above |

Your login (the server URL and login tokens) is kept in your OS credential
store: the macOS Keychain, the Secret Service keyring on Linux (via
`secret-tool`), or on Windows a file encrypted for your Windows account
(`~/.pn/tokens.dpapi`, DPAPI). Where no credential store is available, such
as headless Linux, it is kept in `~/.pn/credentials.json` instead, readable
only by you. Set `PN_CREDENTIAL_STORE=file` to always keep it there.

What the plugin writes on your machine:

- `~/.paradigm-networks/`: debug logs, an audit log, session metadata and
  caches, readable only by you. Each log is capped at about 1 MB, plus one
  older copy (`<log>.1`).
- In each workspace, `.cursor/rules/paradigm-repo-context.mdc`, which lists the
  workspace's git remotes and branches so requests can be attributed to a
  repo. The plugin adds this path to the workspace's `.gitignore`.

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
4. Ask the agent to `git push`, `git commit` or run `gh pr create` in a repo
   containing a policy-violating change. It should be denied before the
   operation runs.

If something doesn't work, see [Troubleshooting](#troubleshooting).

## Settings

The defaults suit most users. These environment variables change them; they
must be set in the environment Cursor is started from.

| Variable | Default | Effect |
| --- | --- | --- |
| `PARADIGM_NETWORKS_FAILURE_MODE` | `block` | `allow` lets tool calls through, unchecked, when Paradigm Networks can't be reached or you aren't logged in. |
| `PARADIGM_NETWORKS_PROMPT_FAILURE_MODE` | `allow` | `block` blocks prompts when Paradigm Networks can't be reached. |
| `PARADIGM_NETWORKS_TIMEOUT` | `60` | Seconds to wait for Paradigm Networks on each check. |
| `PARADIGM_NETWORKS_URL` and `PARADIGM_NETWORKS_TOKEN` | unset | When both are set, they are used instead of the browser login. |
| `PN_CREDENTIAL_STORE` | unset | `file` keeps your login in `~/.pn/credentials.json` instead of the OS credential store. |
| `PN_ALLOW_INSECURE_HTTP` | unset | `1` lets you log in to a plain `http://` URL on any host. For local development only (for example a hosts-file name like `http://fs1.localhost.ai`); without it, `http://` is allowed only for `localhost`. |

## Troubleshooting

- Check **Cursor Settings → Hooks**, or the Hooks output channel, to see
  whether the hooks ran.
- The plugin logs to `~/.paradigm-networks/`. When reporting a problem,
  attach `audit.jsonl` (one line per allow/deny decision) and the log for
  the step that failed: `check-prompt.log`, `check-tool-call.log`,
  `pn-config.log` (login and token refresh) or `background-login.log`.
  They don't contain your prompts, but they can contain the agent's
  commands and file paths, so check them before sharing.
- If the browser sign-in finishes but the agent says the login failed with
  `could not reach` or `unexpected non-JSON response`, Cursor's sandbox
  blocked the login's network access. Run the login command the agent shows
  in your own terminal.

## Limitations

- **What is scanned.** Every prompt and every agent tool call (file edits,
  shell commands, MCP tools) is checked before it runs. The contents of
  changed files are checked only for edits made with Cursor's Write tool,
  and for `git push`, `git commit` and `gh pr create` run by the agent. A
  file changed by a shell command (e.g. `sed -i`) is checked as a command,
  but its resulting contents are not.
- **Only the agent's actions are checked.** Commands you type into a
  terminal yourself, including `git push`, are not.
- **If Paradigm Networks can't be reached, prompts are allowed through and
  tool calls are blocked** (see [Settings](#settings)). This is
  intentional, so a user who isn't logged in yet can still ask the agent to
  log in. It also means someone who can block this machine's network access
  to Paradigm Networks can disable prompt checks, while tool calls stay
  blocked.
- **If a check itself fails** (it crashes or exceeds Cursor's time limit),
  Cursor blocks the prompt or tool call.

## Support

- Questions and bugs: plugins@paradigmnetworks.ai or open an issue on this
  repo.
- Security issues: see [SECURITY.md](SECURITY.md). Please don't open a public
  issue.

## More

- [Changelog](https://github.com/ParadigmNetworks-ai/paradigm-networks-plugins/blob/develop/CHANGELOG.md)
- [License](LICENSE) (MIT)
