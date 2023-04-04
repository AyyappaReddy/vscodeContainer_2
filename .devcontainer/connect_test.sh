#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob globstar

# Small helper script to check if internet connectivity is okay
# Optional command line parameter 1: URL to check
# Optional command line parameter 2: Content which is expected to check

URL=${1:-http://www.msftconnecttest.com/connecttest.txt}
RESULT=$(wget -nv -O - "$URL")
if [ -z "${1:-}" ]; then
    if [ "$RESULT" != "Microsoft Connect Test" ]; then
        echo "Connect test failed, Unexpected result: $RESULT"
        exit 1
    fi
else
    if [ -n "${2:-}" ]; then
        if [ "$RESULT" != "$2" ]; then
            echo "Connect test failed, Unexpected result: $RESULT"
            exit 2
        fi
    fi
fi