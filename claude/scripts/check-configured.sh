#!/bin/bash
# Prints CONFIGURED or NOT_CONFIGURED: whether this machine has a
# Paradigm Networks login.
# Usage: check-configured.sh
#
# The login and logout skills, and the plugin's own messages to the agent,
# run this script by this path; the work is done by pn-plugin (bin/).

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/pn-plugin" check-configured "$@"
