#!/bin/bash

# SPDX-FileCopyrightText: 2026 Zextras <https://www.zextras.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

set -e

# This script runs INSIDE the container for macOS / Apple Silicon hosts.
# It sets up the public Zextras repo and applies QEMU workarounds (LTO disabled,
# opus pre-downloaded) needed when running an amd64 container via Rosetta/QEMU.
#
# Usage (inside container): ./build-macos.sh [distro]

DISTRO=${1:-ubuntu-jammy}

echo "==> Building carbonio-videoserver-thirds for $DISTRO"

# Detect package manager family
if [ -f /etc/debian_version ]; then
    PKG_FAMILY="debian"
elif [ -f /etc/redhat-release ]; then
    PKG_FAMILY="rhel"
else
    echo "Error: Unknown Linux distribution in container"
    exit 1
fi

echo "==> Installing base tools (PKG_FAMILY=$PKG_FAMILY)"
if [ "$PKG_FAMILY" = "debian" ]; then
    apt-get update -qq
    apt-get install -y -qq gnupg2 ca-certificates curl

    echo "==> Setting up public Zextras repository"
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 52FD40243E584A21
    UBUNTU_CODENAME="${DISTRO#ubuntu-}"
    echo "deb https://repo.zextras.io/release/ubuntu ${UBUNTU_CODENAME} main" > /etc/apt/sources.list.d/zextras.list
else
    dnf install -y -q curl ca-certificates 2>/dev/null || true

    echo "==> Setting up public Zextras repository"
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

# Work on a copy of the project so that local patches never touch host files
BUILD_DIR=$(mktemp -d)
echo "==> Copying project to $BUILD_DIR"
cp -r /project/. "$BUILD_DIR/"

# Disable LTO in x264: LTO causes lto-wrapper crashes under QEMU emulation
# (amd64 container on Apple Silicon). build-linux.sh runs on real x86_64
# hardware where LTO works fine.
echo "==> Disabling LTO in x264 for local build (QEMU workaround)"
sed -i 's/--enable-lto/--disable-lto/' "$BUILD_DIR/videoserver/x264/PKGBUILD"

# Pre-download sources that trigger TLS "bad record MAC" with yap's Go HTTP client
# under QEMU emulation (amd64 on Apple Silicon). curl handles TLS correctly.
# yap caches downloads at: buildDir + "/" + package_project_path + "/" + filename
# i.e. /tmp/videoserver/<pkg>/<file>
echo "==> Pre-downloading sources prone to QEMU TLS issues (using curl)"
mkdir -p /tmp/videoserver/libopus/
curl -L --retry 3 --retry-delay 2 -o /tmp/videoserver/libopus/opus-1.6.1.tar.gz \
  "https://downloads.xiph.org/releases/opus/opus-1.6.1.tar.gz"

# Prepare yap build environment
echo "==> Running yap prepare $DISTRO -g"
yap prepare "$DISTRO" -g

# Build all packages from the copy
echo "==> Running yap build $DISTRO $BUILD_DIR"
yap build "$DISTRO" "$BUILD_DIR"

echo "==> Build complete!"
