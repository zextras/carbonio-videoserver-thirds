#!/bin/bash

# SPDX-FileCopyrightText: 2026 Zextras <https://www.zextras.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

set -euo pipefail

# Build carbonio-videoserver-thirds packages with yap.
#
# yap does the heavy lifting itself:
#   * --runtime           : Linux uses the built-in rootless runner (no daemon,
#                           no root); macOS falls back to the cli runtime which
#                           dispatches into a Docker/Podman container (rootless
#                           is Linux-only — it needs user namespaces + pivot_root).
#                           Override with YAP_RUNTIME=cli|rootless.
#   * --target-arch       : installs the cross toolchain and configures the
#                           build env automatically (no manual gcc-aarch64 setup).
#   * --repo              : injects the Zextras release repo at build time
#                           instead of editing /etc/apt or /etc/yum.repos.d.
#
# Usage: ./build.sh <distro> [arch]
#   distro : ubuntu-jammy | ubuntu-noble | rocky-8 | rocky-9
#   arch   : amd64 (default) | arm64
#
# macOS note: needs Docker Desktop or `podman machine` running, since the
# rootless runner is unavailable on Darwin.

DISTRO="${1:-}"
ARCH="${2:-amd64}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# yap version to bootstrap when not already installed.
YAP_VERSION="${YAP_VERSION:-latest}"

if [ -z "$DISTRO" ]; then
  echo "Usage: $0 <distro> [arch]"
  echo "  distro : ubuntu-jammy | ubuntu-noble | rocky-8 | rocky-9"
  echo "  arch   : amd64 (default) | arm64"
  exit 1
fi

# Install yap if it is not on PATH using the official install script. It detects
# host OS/arch and installs both yap and yap-mcp. YAP_VERSION pins a release tag
# (default: latest); YAP_INSTALL_DIR overrides the install location.
ensure_yap() {
  if command -v yap >/dev/null 2>&1; then
    return
  fi

  echo "==> yap not found — installing $YAP_VERSION via install.sh"

  local args="--tool yap"
  [ "$YAP_VERSION" != "latest" ] && args="$args --version $YAP_VERSION"

  local installer="https://raw.githubusercontent.com/M0Rf30/yap/main/scripts/install.sh"
  if command -v curl >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    curl -fsSL "$installer" | sh -s -- $args
  elif command -v wget >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    wget -qO- "$installer" | sh -s -- $args
  else
    echo "Error: need curl or wget to install yap"
    exit 1
  fi

  # install.sh defaults to /usr/local/bin or ~/.local/bin — make sure the latter
  # is reachable for this run.
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac

  command -v yap >/dev/null 2>&1 || {
    echo "Error: yap install failed"
    exit 1
  }
  yap version || true
}

ensure_yap

# Map the requested arch to a yap --target-arch value (empty = native amd64).
case "$ARCH" in
  amd64) TARGET_ARCH="" ;;
  arm64) TARGET_ARCH="aarch64" ;;
  *)
    echo "Error: unsupported arch '$ARCH' (use amd64 or arm64)"
    exit 1
    ;;
esac

# Build the Zextras release repo spec for the requested distro. gpgCheck=false
# mirrors the historical setup (apt-key trust / rpm gpgcheck=0); -U below allows
# the unverified apt source.
case "$DISTRO" in
  ubuntu-*)
    CODENAME="${DISTRO#ubuntu-}"
    REPO="name=zextras,url=https://repo.zextras.io/release/ubuntu,suite=${CODENAME},components=main,format=deb,gpgCheck=false,distros=ubuntu"
    ;;
  rocky-8) REPO="name=zextras,url=https://repo.zextras.io/release/rhel8/,format=rpm,gpgCheck=false,distros=rocky" ;;
  rocky-9) REPO="name=zextras,url=https://repo.zextras.io/release/rhel9/,format=rpm,gpgCheck=false,distros=rocky" ;;
  *)
    echo "Error: unknown distro '$DISTRO'"
    exit 1
    ;;
esac

# Select the container runtime. The rootless runner is Linux-only (user
# namespaces + pivot_root); on macOS yap dispatches into a Docker/Podman
# container via the cli runtime. Override with YAP_RUNTIME.
if [ -n "${YAP_RUNTIME:-}" ]; then
  RUNTIME="$YAP_RUNTIME"
elif [ "$(uname -s)" = "Linux" ]; then
  RUNTIME="rootless"
else
  RUNTIME="cli"
fi

echo "==> Building carbonio-videoserver-thirds for $DISTRO (arch: $ARCH, runtime: $RUNTIME)"

# Shared flags: runtime + Zextras repo (+ cross arch when requested).
YAP_FLAGS=(--runtime "$RUNTIME" --repo "$REPO")
[ -n "$TARGET_ARCH" ] && YAP_FLAGS+=(--target-arch "$TARGET_ARCH")

# The rootless runtime needs the builder rootfs extracted locally first; the
# cli runtime pulls the image on demand during prepare/build, so skip it there.
if [ "$RUNTIME" = "rootless" ]; then
  echo "==> yap pull $DISTRO"
  yap pull "$DISTRO" --runtime rootless
fi

echo "==> yap prepare $DISTRO"
yap prepare "$DISTRO" -g "${YAP_FLAGS[@]}"

# -U allows the unverified Zextras apt source (build-only flag).
echo "==> yap build $DISTRO $PROJECT_DIR"
yap build "$DISTRO" "$PROJECT_DIR" "${YAP_FLAGS[@]}" -U

echo "==> Build complete!"
