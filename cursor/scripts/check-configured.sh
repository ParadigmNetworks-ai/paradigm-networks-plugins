#!/bin/bash
# Prints CONFIGURED or NOT_CONFIGURED: whether this machine has a
# Paradigm Networks login.
# Usage: check-configured.sh
#
# The login and logout skills, and the plugin's own messages to the agent,
# run this script by this path; the work is done by pn-plugin (bin/).

# On Windows, the PowerShell script next to this one is the one to run.
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "error: this is the Unix check script. On Windows, run check-configured.ps1 instead." >&2
    exit 1
    ;;
esac

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/pn-plugin" check-configured "$@"
