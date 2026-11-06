#!/bin/bash
# Logs this machine in to Paradigm Networks with a browser login.
# Usage: login.sh --base-url https://acme.paradigmnetworks.ai
#
# The login and logout skills, and the plugin's own messages to the agent,
# run this script by this path; the work is done by pn-plugin (bin/).

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/pn-plugin" login "$@"
