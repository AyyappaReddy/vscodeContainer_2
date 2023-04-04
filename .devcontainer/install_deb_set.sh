#!/usr/bin/env bash


set -euo pipefail
shopt -s nullglob globstar

# Helper script to execute steps in dev docker build for DEB packages install
# Command line parameter 1: Requirements TXT file to use as input
# The format is similar to a PIP requirements txt file with small extensions:
# - Comments are filtered before install
# - Special comments are used to mark other dependencies:
#   - "# PPA <name>" marks an addition PPA archive to be added prior install
#   - "# KEY <url>" marks an addition GPG key which needs to be added prior install
#   - "# LIST <name>=<url>" marks one additonal apt.sources.d/list to be added

LIST=$1

# Refresh APT lists and install updates first to be clean
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade --no-install-recommends
apt-get -y autoremove

# Download all required GPG keys
sed -ne 's/# KEY //p' "${LIST}" | while read -r key; do
    echo "Adding key ${key}"
    curl -s "${key}" | sudo apt-key add -
    touch /tmp/CHANGE
done

# Add needed package lists
sed -ne 's/# LIST //p' "${LIST}" | while read -r item; do
    # shellcheck disable=SC2086
    list_name=$(echo $item | cut -d= -f1)
    # shellcheck disable=SC2086
    list_url=$(echo $item | cut -d= -f2)
    echo "Adding list \"${list_url}\" to \"${list_name}.list\""
    eval echo "${list_url}" >>"/etc/apt/sources.list.d/${list_name}.list"
    touch /tmp/CHANGE
done

# Add needed PPA archives
sed -ne 's/# PPA //p' "${LIST}" | while read -r ppa; do
    echo "Adding PPA ${ppa}"
    add-apt-repository "${ppa}"
    touch /tmp/CHANGE
done

# Update package lists if needed
if [ -f /tmp/CHANGE ]; then
    rm /tmp/CHANGE
    apt-get update
fi

# shellcheck disable=SC2046
apt-get -y install --no-install-recommends $(sed -e 's/#.*//' "${LIST}")

# Clean the lists and temp files to keep docker layers lean
apt-get clean
rm -rf /var/lib/apt/lists/*
