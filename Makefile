# SPDX-FileCopyrightText: 2026 Zextras <https://www.zextras.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

# Makefile for building carbonio-videoserver-thirds packages using yap.
#
# yap runs rootless (built-in user-namespace runtime — no Docker/Podman daemon)
# and cross-compiles via --target-arch, so make just dispatches build.sh.

# All supported distribution targets
ALL_DISTROS = ubuntu-jammy ubuntu-noble rocky-8 rocky-9

# Distribution target
TARGET ?= ubuntu-jammy

# Target architecture: amd64 (default) or arm64 (cross-compiled by yap)
ARCH ?= amd64

OUTPUT_DIR ?= artifacts

.PHONY: help build build-all pull clean list-targets list-packages

.DEFAULT_GOAL := help

## help: Show this help message
help:
	@echo "Carbonio Videoserver Thirds - Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [TARGET=<distro>] [ARCH=<amd64|arm64>]"
	@echo ""
	@echo "Targets:"
	@echo "  help               Show this help message"
	@echo "  build              Build for TARGET / ARCH via yap (rootless)"
	@echo "  build-<distro>     Build for a specific distro (e.g. make build-rocky-8)"
	@echo "  build-all          Build for all distros (use -jN for parallel)"
	@echo "  pull               Pull the yap builder image for TARGET"
	@echo "  clean              Remove build artifacts"
	@echo "  list-targets       List supported distribution targets"
	@echo "  list-packages      List all packages defined in yap.json"
	@echo ""
	@echo "Options:"
	@echo "  TARGET         Distribution target (default: ubuntu-jammy)"
	@echo "                 Supported: ubuntu-jammy, ubuntu-noble, rocky-8, rocky-9"
	@echo "  ARCH           Target architecture: amd64 (default) or arm64"
	@echo ""
	@echo "Examples:"
	@echo "  make build TARGET=rocky-8               # single distro (x86_64)"
	@echo "  make build TARGET=rocky-8 ARCH=arm64    # single distro (aarch64)"
	@echo "  make build-rocky-8                      # shorthand"
	@echo "  make build-all                          # all distros sequentially"
	@echo "  make -j4 build-all                      # all distros in parallel"
	@echo ""

## build: Build packages for TARGET / ARCH via yap (rootless runtime)
build:
	@mkdir -p $(OUTPUT_DIR)
	./build.sh $(TARGET) $(ARCH)

## build-all: Build packages for all distros — run with -jN for parallel builds
build-all: $(addprefix build-, $(ALL_DISTROS))

# Generate explicit build-<distro> targets for each distro in ALL_DISTROS.
define distro-target
.PHONY: build-$(1)
build-$(1):
	$$(MAKE) build TARGET=$(1)
endef
$(foreach d,$(ALL_DISTROS),$(eval $(call distro-target,$(d))))

## pull: Pull the yap builder image for the specified TARGET
pull:
	yap pull $(TARGET) --runtime rootless

## clean: Remove build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(OUTPUT_DIR)
	@echo "Clean complete!"

## list-targets: List supported distribution targets
list-targets:
	@echo "Supported distribution targets:"
	@echo ""
	@echo "  ubuntu-jammy    (Ubuntu 22.04 LTS)"
	@echo "  ubuntu-noble    (Ubuntu 24.04 LTS)"
	@echo "  rocky-8         (Rocky Linux 8)"
	@echo "  rocky-9         (Rocky Linux 9)"
	@echo ""
	@echo "Usage: make build TARGET=<target>"

## list-packages: List all packages defined in yap.json
list-packages:
	@echo "Packages defined in yap.json:"
	@echo ""
	@cat yap.json | grep -oP '"name":\s*"\K[^"]+' | while read pkg; do echo "  - $$pkg"; done
