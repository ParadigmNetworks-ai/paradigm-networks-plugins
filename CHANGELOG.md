# Changelog

What's new in the Paradigm Networks plugins, newest first.

## Unreleased

## v0.1.1, 2026-11-11

- Logging in and out works when your home folder's name has a space in it (for example
  `C:\Users\Jane Doe`). Before, Claude Code couldn't run the login and reported it as failed.
- If a login succeeds in the browser but can't be saved on your computer, it's now cancelled on
  the server, so it no longer shows under your organization's Plugin logins.

## v0.1.0, 2026-11-09

- First release of the Paradigm Networks plugin for Cursor and Claude Code. It checks your
  prompts, tool calls and git pushes against your organization's Paradigm Networks policy and
  blocks risky actions before they run.
- Sign in once per machine through your browser. Your login is kept in your operating system's
  credential store (macOS Keychain, Linux Secret Service, Windows DPAPI), and signing out also
  revokes it on the server.
- Works on macOS, Linux and Windows, on Intel and ARM machines. Claude Code on Windows runs
  through Git Bash.
- Requires a Paradigm Networks account. Claude Code needs version 2.1.295 or later; Cursor needs
  2.5.0 or later.
