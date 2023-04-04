#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob globstar

# This script is started BEFORE the VScode dev container is launched
# in order to ensure the environment is properly set up on the host of execution.

# Ensure mounted path's are created before Docker launch to that they are not
# created by Docker daemon with root permissions
mkdir -p \
    "$HOME/.ssh" \
    "$HOME/.kube" \
    "$HOME/.cache/pip" \
    "$HOME/.ccache" \
    "$HOME/.conan/data" \
    "$HOME/.cache/pre-commit-vscode" \
    "$HOME/.azure" \
