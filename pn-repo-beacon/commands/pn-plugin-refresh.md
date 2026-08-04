---
description: Force pn-plugin to rescan all git repos in the workspace right now
---

Run the pn-plugin rescan script directly and report back what it found:

1. Run `bash scripts/cursor-generate-rule.sh <<< '{"workspace_roots": ["'"$(pwd)"'"]}'` from the plugin root.
2. Read back `rules/pn-plugin.mdc` and summarize which repos and branches were detected.
3. If no repos were found, tell the user plainly rather than guessing.
