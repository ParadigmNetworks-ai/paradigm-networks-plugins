---
name: paradigmnetworks-login
description: Log this machine in to Paradigm Networks so Paradigm Networks security checks work. Use when Paradigm Networks isn't configured yet — e.g. the SessionStart hook added a "Paradigm Networks is not configured" notice, or a tool call was denied because Paradigm Networks is not logged in or the login has ended — or when the user explicitly asks to log in to Paradigm Networks, switch Paradigm Networks orgs, or re-authenticate.
---

# Paradigm Networks login

## When to use this

- The `SessionStart` hook added context saying Paradigm Networks is not
  configured.
- A tool call was denied with "Paradigm Networks is not logged in" or "Your
  Paradigm Networks login has ended".
- The user asks to log in, re-authenticate, or switch to a different Paradigm
  Networks organization.

## What not to do

- Don't invent, guess, or reuse a base URL from another project, example, or
  training data. The base URL (e.g. `https://acme.paradigmnetworks.ai`) is
  specific to the user's organization and **must come from the user**.
- Don't fabricate a successful login. Only report success once `login.sh`
  actually exits `0`.
- Don't ask for or accept an access token directly — this is a browser login,
  not manual token entry.
- Don't loop the base-URL question more than once. Validate, correct at most
  one mistake, then move on (see step 3).

## Workflow

### 1. The scripts directory

This plugin's scripts are in:

```
${CLAUDE_PLUGIN_ROOT}/scripts
```

That is this installation's own path, so use it exactly as written here — it
is correct even when several versions of the plugin are cached. The
`SessionStart` hook also puts it in your context as
`Paradigm Networks plugin scripts directory: <scripts-dir>`, and the deny
message for a blocked tool call repeats the full login command. All three name
the same directory. **Never search for the scripts.**

This matters because **while Paradigm Networks is unconfigured, every tool
call except this login flow is denied**: searching (`ls`, `find`, Glob, Read
of other files) is blocked, so trying it is the one way to get stuck.

### 2. Check whether login is actually needed

Skip this if you already know login is missing (the SessionStart notice or a
deny message said so). Otherwise run, with the Bash tool:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-configured.sh"
```

Run it **exactly as shown and nothing else** — don't combine it with `cd`,
`&&`, `;`, or any other command, and don't add arguments. This standalone,
argument-free shape is what lets Paradigm Networks' own security scanning
recognize it and skip scanning it. **Don't hand-write your own
file-existence check** (e.g. `test -f ~/.pn/claude-code-credentials.json`)
instead: the credentials path in the command text is flagged as a
credential-path exposure finding, and the login is usually in the OS
credential store with no such file anyway.

- `CONFIGURED` → tell the user they're already logged in and stop here.
- `NOT_CONFIGURED` → continue to step 3.

### 3. Get the base URL

**Use the `AskUserQuestion` tool for this — not a plain chat message.** Ask:

- question: `What's your Paradigm Networks base URL? (e.g. https://acme.paradigmnetworks.ai). Don't have one yet? Sign up at https://signup.paradigmnetworks.ai/signup.`
- header: `Base URL`
- options: `I'm not sure what my base URL is` and
  `I think I'm already logged in — recheck`

The user types their actual URL through the tool's free-text "Other" answer,
which is the expected path for most users.

If they pick **"I'm not sure what my base URL is"**: they likely don't have a
Paradigm Networks account yet. Point them to
https://signup.paradigmnetworks.ai/signup, then stop and wait — don't guess a
URL or retry the question in a loop. Once they say they have it, ask again.

If they pick **"I think I'm already logged in — recheck"**: run step 2.

Validate the answer: it should start with `https://` and include a host. If it
clearly doesn't, ask exactly one follow-up (also with `AskUserQuestion`) — for
an `http://` URL, offer the same URL with `https://`, since `login.sh` refuses
plain `http://` for anything but `localhost`. If it still doesn't parse after
that, proceed anyway: `login.sh` validates the URL itself and reports a clear
error.

### 4. Run the login script in the background

With the Bash tool, **with `run_in_background: true`** (it waits up to five
minutes for the browser sign-in):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/login.sh" --base-url <the-base-url>
```

Run this command **exactly as shown and nothing else** — don't combine it with
`cd`, `&&`, `;`, or any other command, and don't add extra flags. This
standalone shape is what lets Paradigm Networks' own security scanning
recognize it as the login step and skip scanning it.

The script opens the user's browser itself, falling back to copying the link
to their clipboard, then to printing it, and says which happened. **Read the
background task's output file** (the path the Bash tool returned) to see that
line, and relay it to the user verbatim. If the line isn't there yet, read the
file again after a moment (`sleep 2` with the Bash tool between reads is fine)
— the script prints it within a few seconds. Don't add your own caveats about
browsers failing to open, and don't try to launch a browser yourself.

Each run generates a new URL, and every run listens on the same local port, so
a URL from an earlier run will not work: if the user opens one, the current
run rejects it with a state mismatch. If you retry, relay only the newest URL
and tell the user not to use earlier ones.

### 5. Wait for the result

You are notified when the background command finishes. Until then, the only
tool calls that work are reading that output file, `sleep`, and
`AskUserQuestion`; don't run anything else, and don't rely on
`check-configured.sh` alone — it says `NOT_CONFIGURED` both before the login
finishes and after it has failed.

**Judge the result from the script's own output and exit code**, not from what
the user says ("done", or "the browser says I'm signed in"): the browser page
appears before the script collects the token, so it can show sign-in complete
even when the login then fails.

### 6. Relay the outcome

- Exit `0` → Paradigm Networks is configured and its checks are active. No
  further action needed; continue with what the user originally asked.
- Non-zero → quote the script's own `error:` line to the user. Don't replace
  it with your own guess (e.g. "you didn't finish in the browser" or "it timed
  out") unless that is what the script printed.
- If the error says the URL `must start with https://`, ask the user (with
  `AskUserQuestion`) whether to use the same URL with `https://`, and run the
  login again with that. Never set `PN_ALLOW_INSECURE_HTTP` yourself: it is
  the user's own setting for local development.
- If the error says `could not reach` or `unexpected non-JSON response`, the
  script had no network access — likely Claude Code's sandbox. Give the user
  the exact command from step 4 to run in their own terminal, and stop.
- Any other error (timeout, denied, state mismatch) → offer to retry with a
  fresh run. If retrying, remind the user to click through the new link within
  the five-minute window.
