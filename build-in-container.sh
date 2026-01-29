#!/bin/bash

# SPDX-FileCopyrightText: 2026 Zextras <https://www.zextras.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

set -e

# This script runs INSIDE the container
# It installs dependencies, prepares yap, and builds the package
#
# Usage (inside container): ./build-in-container.sh <deps-dir|none> <distro>

DEPS_DIR=$1
DISTRO=$2

if [ -z "$DISTRO" ]; then
    echo "Usage: $0 <deps-dir|none> <distro>"
    exit 1
fi

echo "==> Building carbonio-videoserver-thirds for $DISTRO"

# Install dependencies if provided
if [ "$DEPS_DIR" != "none" ] && [ -n "$DEPS_DIR" ]; then
    echo "==> Installing dependencies from $DEPS_DIR"
    
    if [ -f /etc/debian_version ]; then
        # Ubuntu/Debian
        apt-get update
        find "$DEPS_DIR" -name '*.deb' -exec dpkg -i {} + || apt-get install -f -y
    elif [ -f /etc/redhat-release ]; then
        # Rocky Linux/RHEL
        find "$DEPS_DIR" -name '*.rpm' -exec rpm -ivh --force {} +
    else
        echo "Error: Unknown distribution"
        exit 1
    fi
    echo "==> Dependencies installed"
fi

# Prepare yap
echo "==> Running yap prepare $DISTRO -g"
yap prepare "$DISTRO" -g

# Build packages
echo "==> Running yap build $DISTRO /project"
yap build "$DISTRO" "/project"

echo "==> Build complete!"
