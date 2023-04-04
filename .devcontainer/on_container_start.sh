#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob globstar

# In order to run Docker from Docker, the user must have RW permissions for the
# Docker socket. If they are not set, some features cannot be run.
SOCKET_PERM=$(stat -c %A /var/run/docker.sock)

if [[ "${SOCKET_PERM}" != "srw-rw----" ]]; then
    echo "WARNING: Docker-in-Docker functionality will be disabled due to insufficient"
    echo "         Socket permissions '${SOCKET_PERM}' of /var/run/docker.sock of current user."
    echo "         In order to activate them, run"
    echo "         sudo chmod 660 /var/run/docker.sock"
else
    echo "INFO: Docker socket permissions are '${SOCKET_PERM}'."
fi

# Install pre-commit
if [ -x "$(command -v pre-commit)" ]; then
    pre-commit install -f -t pre-commit
    pre-commit install -f -t commit-msg
fi
