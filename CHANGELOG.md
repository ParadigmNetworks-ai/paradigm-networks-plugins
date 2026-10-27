# Changelog

All notable changes to this project will be documented in this file.
The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

## [Unreleased]

### Added
- [PN-12435] - Paradigm Networks plugin for Cursor in `cursor/`, the repo-level Cursor marketplace file, a root README and LICENSE

### Changed
- [PN-12435] - `.gitignore` re-includes each plugin's `scripts/lib/` folder (the template's `lib/` rule would otherwise drop it)
- [PN-12435] - `.gitignore` trimmed to OS, editor, env and log files

### Fixed
- [PN-12435] - Windows login check no longer reports NOT_CONFIGURED for logged-in users

### Removed
- [PN-12435] - Dependabot config for pip/Docker (the repo has neither)

### Security
- [PN-12435] - Git remote URLs and branch names are checked against an allowlist before they go into the agent's repo context
- [PN-12435] - Logout revokes the login on the server before deleting local credentials

