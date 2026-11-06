#!/bin/bash
# Logs this machine out of Paradigm Networks, revoking the login on the
# server.
# Usage: logout.sh
#
# The login and logout skills, and the plugin's own messages to the agent,
# run this script by this path; the work is done by pn-plugin (bin/).

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/pn-plugin" logout "$@"
