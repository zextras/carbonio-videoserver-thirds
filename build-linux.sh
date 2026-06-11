#!/bin/bash

# SPDX-FileCopyrightText: 2026 Zextras <https://www.zextras.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

set -e

# This script runs INSIDE the container on real x86_64 hardware (Linux CI).
# LTO is enabled and no QEMU workarounds are applied.
#
# Usage (inside container): ./build-linux.sh <deps-dir|none> <distro>

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

# Set up public Zextras repository
echo "==> Setting up public Zextras repository"
if [ -f /etc/debian_version ]; then
    apt-get update -qq
    apt-get install -y -qq gnupg2 ca-certificates curl
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 52FD40243E584A21
    UBUNTU_CODENAME="${DISTRO#ubuntu-}"
    echo "deb https://repo.zextras.io/release/ubuntu ${UBUNTU_CODENAME} main" > /etc/apt/sources.list.d/zextras.list
elif [ -f /etc/redhat-release ]; then
    case "$DISTRO" in
        rocky-8) RHEL_REPO="rhel8" ;;
        rocky-9) RHEL_REPO="rhel9" ;;
        *) echo "Error: Unknown RHEL distro variant: $DISTRO"; exit 1 ;;
    esac
    cat > /etc/yum.repos.d/zextras.repo <<EOF
[zextras]
name=Zextras
baseurl=https://repo.zextras.io/release/${RHEL_REPO}/
enabled=1
gpgcheck=0
EOF
fi

# Prepare yap
echo "==> Running yap prepare $DISTRO -g"
yap prepare "$DISTRO" -g

# Build packages
echo "==> Running yap build $DISTRO /project"
yap build "$DISTRO" "/project"

echo "==> Build complete!"
