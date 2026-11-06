#!/bin/bash
# Logs this machine out of Paradigm Networks, revoking the login on the
# server.
# Usage: logout.sh
#
# The login and logout skills, and the plugin's own messages to the agent,
# run this script by this path; the work is done by pn-plugin (bin/).

# On Windows, the PowerShell script next to this one is the one to run.
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "error: this is the Unix logout script. On Windows, run logout.ps1 instead (via powershell -File logout.ps1)." >&2
    exit 1
    ;;
esac

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/pn-plugin" logout "$@"
