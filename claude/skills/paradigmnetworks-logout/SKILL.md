---
name: paradigmnetworks-logout
description: Log this machine out of Paradigm Networks by revoking its login on the server and removing the locally stored credentials. Use when the user explicitly asks to log out of Paradigm Networks, disconnect it, remove their login, or switch which Paradigm Networks org/account Claude Code uses (log out first, then run the paradigmnetworks-login skill to log in again).
---

# Paradigm Networks logout

## When to use this

- The user explicitly asks to log out of Paradigm Networks, disconnect it, or
  remove their Paradigm Networks login.
- The user wants to switch to a different Paradigm Networks org/account — log
  out first (this skill), then run the `paradigmnetworks-login` skill to log
  back in under the new org.

Don't use this just because a hook reported "not configured" — that means
there's nothing to log out of. That's the `paradigmnetworks-login` skill's
territory instead.

## What not to do

- **Don't run the logout script without confirming with the user first.**
  Removing the stored login is a real, if low-stakes, destructive action on
  the user's machine — confirm intent before running it.
- **Don't hand-delete the login yourself** (e.g. a raw `rm`) — always go
  through `logout.sh` (step 2), which also revokes the login on the server.
  The login is usually in the OS credential store (Keychain or Secret
  Service), not in `~/.pn/claude-code-credentials.json`, and only the script
  removes it from there.
- **Don't claim the login was revoked on the server unless the script says
  so.** The script first asks the server to revoke this login, then always
  removes it from this machine. The server step can fail (server unreachable,
  or a server version that doesn't support revoking yet), and the script's
  second output line says which happened.

## Workflow

### 1. Confirm with the user

Ask a plain, direct confirmation (e.g. "This will sign you out of Paradigm
Networks: it revokes this login on the server and removes it from this machine
— you'll need to log in again afterward before Claude Code can use tools.
Proceed?"). Only continue on a clear yes.

### 2. Run it

With the Bash tool:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/logout.sh
```

Use that path exactly as written — it is this installation's own scripts
directory (the `SessionStart` hook also puts it in your context as
`Paradigm Networks plugin scripts directory: <scripts-dir>`). **Never search
for the script.**

Run this command **exactly as shown and nothing else** — don't combine it with
`cd`, `&&`, `;`, or any other command, and don't add any flags. This
standalone shape is what lets Paradigm Networks' own security scanning
recognize it as the logout step and skip scanning it.

### 3. Relay the outcome

Relay what the script printed verbatim — don't paraphrase or summarize it. It
always exits `0` (short of a filesystem error or the OS credential store
refusing to delete the login, which it reports as an `error:` line) and covers
these cases on its own:

- Login removed — logged out on this machine. A second line reports the
  server side: either the login was revoked there, or it couldn't be (server
  unreachable, revoke not supported yet, or no usable credentials), in which
  case the old login stays valid on the server until it expires. Don't retry
  the logout to "fix" that; just make sure the user saw it.
- Not logged in — no login was stored on this machine to begin with.
- Removed, but `PARADIGM_NETWORKS_URL`/`PARADIGM_NETWORKS_TOKEN` are still set
  in the environment — those take precedence over the stored login, so
  Paradigm Networks checks keep working via them until they're unset. Don't
  unset environment variables yourself; just make sure the user understands
  why they might still appear logged in.
