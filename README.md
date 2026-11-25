# Paradigm Networks plugins

Plugins that connect AI coding tools to [Paradigm Networks](https://paradigmnetworks.ai),
so prompts, tool calls and code changes are checked against your
organization's security policy.

## Plugins

| Tool | Plugin | Folder |
| --- | --- | --- |
| Cursor | Paradigm Networks | [`cursor/`](cursor/) |
| Claude Code | Paradigm Networks | [`claude/`](claude/) |

Each plugin's own README covers what it does, how to install it, what data it
sends and its limitations.

## Quick start (Cursor)

> A Paradigm Networks account is required. New to Paradigm Networks?
> [Sign up](https://signup.paradigmnetworks.ai/signup).

Install from the Cursor Marketplace:

```
/add-plugin paradigm-networks
```

Cursor Team and Enterprise admins can also import this repository as a private
marketplace (**Dashboard → Customize → Add Marketplace → Import from GitHub**)
and make the plugin **Default On** or **Required** for their team. See
[`cursor/README.md`](cursor/README.md) for the full steps.

## Quick start (Claude Code)

> A Paradigm Networks account is required. New to Paradigm Networks?
> [Sign up](https://signup.paradigmnetworks.ai/signup).

Add this repository as a marketplace, then install the plugin:

```
/plugin marketplace add ParadigmNetworks-ai/paradigm-networks-plugins
/plugin install paradigm-networks@paradigm-networks-plugins
```

Then turn on updates, which Claude Code leaves off for marketplaces like this one: run `/plugin`,
open the **Marketplaces** tab, select `paradigm-networks-plugins` and turn auto-update on. Without
it you only get a new version, including security fixes, when you update by hand.

Admins can roll it out to their organization through Claude Code's managed
settings. See [`claude/README.md`](claude/README.md) for the full steps.

## Verifying a release

Every release is built from a reviewed commit in Paradigm Networks' source
repository by a reproducible build, and approved by a second person before it
reaches this repository. You can check what you install:

- **The plugin checks itself.** The plugins don't contain their program: the
  first time a plugin runs, its launcher (`runtime/pn-plugin`) downloads the
  build for your machine (`pn-plugin-<version>-<os>-<arch>`) from this
  repository's GitHub Release for its version, and keeps it in
  `~/.paradigm-networks/bin/<version>/` (`%LOCALAPPDATA%\ParadigmNetworks\bin\<version>\`
  on Windows). Before every run, it checks the build against the plugin's
  signed list, `runtime/SHA256SUMS`, which names each build with the plugin's
  version. If the build can't be downloaded or doesn't match, the plugin
  blocks tool calls instead of running it unchecked.
- **Check the builds by hand.** Download the builds from the release page, then
  run `sha256sum --check --ignore-missing claude-SHA256SUMS` next to them.
  `BUILD` records the source commit, version and Go version each release was
  built from, so you can rebuild it and compare.
- **Release pages.** Each version's GitHub Release carries the six builds and
  each plugin's signed list with its signatures (`claude-SHA256SUMS`,
  `cursor-SHA256SUMS`, each with `.sig` and `.sig.p1363`). A new version is
  first published as a pre-release for testing, and marked as the latest
  release once it reaches `main`, the branch you install from.
- **Release signatures.** Each plugin's `runtime/SHA256SUMS` comes with
  `SHA256SUMS.sig` (and `SHA256SUMS.sig.p1363`, the same signature in the
  format Windows PowerShell reads), signed by a key held in a hardware-backed
  key service that only the approved release job can use. The plugin refuses
  to run a build whose list isn't signed with this key. The public key is in each plugin's `runtime/pn-plugin`, between the
  `BEGIN` and `END pn-release-signing keys` lines. Its SHA-256 fingerprint
  (of the DER public key) is:

  ```
  1ecb9232ad0f32a2ae04d183cc4c51e5b94f8b35decc6196cbdf895393150d5a
  ```

  Check a release with the key from the launcher:

  ```
  sed -n "/^release_key_1='/,/END PUBLIC KEY/p" claude/runtime/pn-plugin | sed -e "s/^release_key_1='//" -e "s/'$//" > pn-release.pem
  openssl pkey -pubin -in pn-release.pem -outform DER | sha256sum   # the fingerprint above
  openssl dgst -sha256 -verify pn-release.pem -signature claude/runtime/SHA256SUMS.sig claude/runtime/SHA256SUMS
  ```

- **Security posture.** This repository's OpenSSF Scorecard:
  [scorecard.dev](https://scorecard.dev/viewer/?uri=github.com/ParadigmNetworks-ai/paradigm-networks-plugins).

## Support

- Questions and bugs: plugins@paradigmnetworks.ai, or open an issue on this
  repository.
- Security issues: see [`cursor/SECURITY.md`](cursor/SECURITY.md) or
  [`claude/SECURITY.md`](claude/SECURITY.md). Please don't open a public
  issue.

## Privacy and terms

- [Privacy Policy](https://paradigmnetworks.ai/privacy-policy/)
- [Terms of Service](https://paradigmnetworks.ai/terms/)

## License

MIT. See [`LICENSE`](LICENSE).
