#!/bin/bash
set -e

PREFIX=/usr/local/banshee
BIN=${PREFIX}/bin/freeswitch

# If the first arg is "freeswitch" or starts with a flag, run FreeSWITCH;
# otherwise exec whatever was passed (e.g. bash, fs_cli) for debugging.
if [ "$1" = "freeswitch" ] || [ "${1:0:1}" = "-" ]; then
    shift || true

    # Ensure runtime dirs exist and are owned by the banshee user
    mkdir -p "${PREFIX}/var/run/freeswitch" "${PREFIX}/var/log/freeswitch" "${PREFIX}/var/lib/freeswitch"
    chown -R banshee:aswat "${PREFIX}/var" 2>/dev/null || true

    # Run in foreground (-nf), no daemon; drop to banshee:aswat
    exec gosu banshee:aswat "${BIN}" -u banshee -g aswat -nf -nonat "$@"
fi

exec "$@"
