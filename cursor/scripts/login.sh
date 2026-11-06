#!/bin/bash
# Logs this machine in to Paradigm Networks with a browser login.
# Usage: login.sh --base-url https://acme.paradigmnetworks.ai
#
# The login and logout skills, and the plugin's own messages to the agent,
# run this script by this path; the work is done by pn-plugin (bin/).

# On Windows, the PowerShell script next to this one is the one to run.
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "error: this is the Unix login script. On Windows, run login.ps1 instead (via powershell -File login.ps1 -BaseUrl <url>)." >&2
    exit 1
    ;;
esac

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/pn-plugin" login "$@"
