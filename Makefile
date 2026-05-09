# SPDX-FileCopyrightText: 2026 Zextras <https://www.zextras.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

# Makefile for building carbonio-videoserver-thirds packages using YAP

# Configuration
YAP_IMAGE_PREFIX ?= docker.io/m0rf30/yap
YAP_VERSION      ?= 1.54

# Prefer podman if installed AND reachable; fall back to docker if it is running;
# last resort: whichever binary exists (let the runtime emit the real error).
CONTAINER_RUNTIME ?= $(shell \
  (command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1 && echo podman) || \
  (command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && echo docker) || \
  (command -v podman >/dev/null 2>&1 && echo podman) || \
  echo docker)

# All supported distribution targets
ALL_DISTROS = ubuntu-jammy ubuntu-noble rocky-8 rocky-9

# Distribution target
TARGET ?= ubuntu-jammy

# Dependencies directory (Linux build only; use 'none' to skip)
DEPS_DIR ?= none

# Computed values
YAP_IMAGE    = $(YAP_IMAGE_PREFIX)-$(TARGET):$(YAP_VERSION)
CCACHE_DIR  ?= $(CURDIR)/.ccache
OUTPUT_DIR  ?= artifacts

# Auto-detect host OS: macOS uses build-macos.sh (QEMU workarounds),
# Linux uses build-linux.sh (LTO enabled, native x86_64).
HOST_OS := $(shell uname)
ifeq ($(HOST_OS),Darwin)
  BUILD_SCRIPT = /project/build-macos.sh
  BUILD_SCRIPT_ARGS = $(TARGET)
else
  BUILD_SCRIPT = /project/build-linux.sh
  BUILD_SCRIPT_ARGS = $(DEPS_DIR) $(TARGET)
endif

# Container mount options
CONTAINER_OPTS = --rm \
	--platform linux/amd64 \
	-v $(CURDIR):/project \
	-v $(CURDIR)/$(OUTPUT_DIR)/$(TARGET):/artifacts \
	-v $(CCACHE_DIR):/root/.ccache \
	-e CCACHE_DIR=/root/.ccache \
	--entrypoint bash

.PHONY: help build build-all build-macos build-linux pull clean list-targets list-packages

.DEFAULT_GOAL := help

## help: Show this help message
help:
	@echo "Carbonio Videoserver Thirds - Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [TARGET=<distro>] [DEPS_DIR=<path>]"
	@echo ""
	@echo "Targets:"
	@echo "  help               Show this help message"
	@echo "  build              Build for TARGET using auto-detected host OS"
	@echo "  build-<distro>     Build for a specific distro (e.g. make build-rocky-8)"
	@echo "  build-all          Build for all distros (use -jN for parallel)"
	@echo "  build-macos        Build with QEMU workarounds (for macOS / Apple Silicon)"
	@echo "  build-linux        Build with LTO enabled    (for Linux / CI)"
	@echo "  pull               Pull the YAP container image for TARGET"
	@echo "  clean              Remove build artifacts"
	@echo "  list-targets       List supported distribution targets"
	@echo "  list-packages      List all packages defined in yap.json"
	@echo ""
	@echo "Options:"
	@echo "  TARGET         Distribution target (default: ubuntu-jammy)"
	@echo "                 Supported: ubuntu-jammy, ubuntu-noble, rocky-8, rocky-9"
	@echo "  DEPS_DIR       Pre-built deps directory for build-linux (default: none)"
	@echo ""
	@echo "Examples:"
	@echo "  make build TARGET=rocky-8               # single distro"
	@echo "  make build-rocky-8                      # shorthand"
	@echo "  make build-all                          # all distros sequentially"
	@echo "  make -j4 build-all                      # all distros in parallel"
	@echo "  make -j2 build-rocky-8 build-rocky-9    # subset in parallel"
	@echo ""

## build: Build packages — auto-detects host OS
build:
	@echo "==> Detected host OS: $(HOST_OS)"
	@mkdir -p $(OUTPUT_DIR)/$(TARGET) $(CCACHE_DIR)
	$(CONTAINER_RUNTIME) run $(CONTAINER_OPTS) $(YAP_IMAGE) \
		$(BUILD_SCRIPT) $(BUILD_SCRIPT_ARGS)

## build-macos: Build with QEMU workarounds (macOS / Apple Silicon)
build-macos:
	@mkdir -p $(OUTPUT_DIR)/$(TARGET) $(CCACHE_DIR)
	$(CONTAINER_RUNTIME) run $(CONTAINER_OPTS) $(YAP_IMAGE_PREFIX)-$(TARGET):$(YAP_VERSION) \
		/project/build-macos.sh $(TARGET)

## build-linux: Build with LTO enabled (Linux / CI)
build-linux:
	@mkdir -p $(OUTPUT_DIR)/$(TARGET) $(CCACHE_DIR)
	$(CONTAINER_RUNTIME) run $(CONTAINER_OPTS) $(YAP_IMAGE_PREFIX)-$(TARGET):$(YAP_VERSION) \
		/project/build-linux.sh $(DEPS_DIR) $(TARGET)

## build-all: Build packages for all distros — run with -jN for parallel builds
build-all: $(addprefix build-, $(ALL_DISTROS))

# Generate explicit build-<distro> targets for each distro in ALL_DISTROS.
# Using $(eval) instead of a build-% pattern rule avoids build-all and
# build-macos/build-linux accidentally matching the pattern.
define distro-target
.PHONY: build-$(1)
build-$(1):
	$$(MAKE) build TARGET=$(1)
endef
$(foreach d,$(ALL_DISTROS),$(eval $(call distro-target,$(d))))

## pull: Pull the YAP container image for the specified TARGET
pull:
	@echo "Pulling YAP image for $(TARGET)..."
	$(CONTAINER_RUNTIME) pull $(YAP_IMAGE)

## clean: Remove build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(OUTPUT_DIR) .ccache
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
