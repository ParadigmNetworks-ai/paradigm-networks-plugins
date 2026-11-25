# Changelog

What's new in the Paradigm Networks plugins, newest first.

## v0.1.3, 2026-11-25

- Tool calls are now blocked when the plugin's program is missing or has been changed, or when
  the plugin has no program for your computer. Before, they were let through without a policy
  check. Reinstalling the plugin fixes a missing or changed program.
- Releases are signed, and the plugin checks the signature before it runs its program. On Linux
  this needs `openssl`, which most systems include; on minimal images without it (for example
  Alpine), install it with `apk add openssl`. Without it, tool calls are blocked with the install
  command.
- NixOS is supported: the plugin's check finds the system tools it needs in NixOS's system
  folder.
- Cursor on Windows: the check of the plugin's program runs in Windows PowerShell, which must not
  be locked down (Constrained Language Mode). If it is, the check can't run, and tool calls are
  blocked with a message saying a Windows security policy blocks it, so your administrator knows
  what to allow.
- A clearer message when a system tool the plugin's check needs isn't installed: the message
  names what's missing instead of failing for another reason.
- The plugins no longer contain their program. The first time a plugin runs, and after each
  update, it downloads the program for your computer (about 8 MB) from the plugin's GitHub
  release, checks it, and keeps it in `~/.paradigm-networks/bin` (on Windows,
  `%LOCALAPPDATA%\ParadigmNetworks\bin`). This needs access to `github.com` and
  `release-assets.githubusercontent.com` (`HTTPS_PROXY` is used if set) and, on macOS and Linux,
  `curl`. If the program can't be downloaded, tool calls are blocked with a message saying so. For
  a computer that can't reach GitHub, put the program in that folder first; see the plugin's
  README.
- The plugin's launcher moved from `bin/` to `runtime/` in each plugin, so Claude.ai organization
  plugins and Cowork accept the plugin.
- Cursor on Windows: tool calls and prompts are now always checked. Cursor can start the
  information it sends the plugin with an invisible marker, which made the plugin treat it as
  unreadable and let the tool call through without a policy check.

## v0.1.2, 2026-11-16

- The Claude Code plugin's manifest now states that it needs Claude Code 2.1.295 or later. On
  older versions, a check that crashes or times out lets the prompt or tool call through
  instead of blocking it, so update Claude Code if yours is older.

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
