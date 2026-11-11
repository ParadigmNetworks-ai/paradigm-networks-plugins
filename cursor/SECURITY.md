# Security Policy

This plugin connects Cursor to your organization's Paradigm Networks
deployment, which checks prompts and the agent's tool calls against your
organization's security policy.

## Reporting a vulnerability

Please report security issues privately by email to
**plugins@paradigmnetworks.ai**.

Please do not open a public issue for security reports. Reporting
privately gives us the chance to assess and ship a fix before the issue
is publicly disclosed.

### What to include

Where possible, please include:

- A description of the issue and its potential impact.
- Steps to reproduce it, or a proof of concept.
- The plugin version and platform (macOS/Linux/Windows) you tested on.

## Response

We aim to acknowledge reports within a few business days and to keep the
reporter updated as a fix is developed.

## How the plugin protects your login

- You log in through your browser. The plugin never sees your password.
- The plugin's login token can only be used to send checks to Paradigm
  Networks. It can't be used for any other Paradigm Networks API.
- Your login is kept in your OS credential store (macOS Keychain, Linux
  Secret Service, or DPAPI on Windows). See
  [Data handling](README.md#data-handling) for the details and the
  fallback.
- A login lasts up to 7 days, after which you sign in again. Logging out
  ends the login on the server too, and your organization's admins can end
  any user's logins at any time.
- If a stolen copy of a login is used after the real one has been
  refreshed, the server ends that whole login.
