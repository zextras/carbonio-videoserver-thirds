# SPDX-FileCopyrightText: 2026 Zextras <https://www.zextras.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

# Makefile for building carbonio-videoserver-thirds packages using YAP

# Configuration
YAP_IMAGE_PREFIX ?= docker.io/m0rf30/yap
YAP_VERSION ?= 1.47
CONTAINER_RUNTIME ?= $(shell command -v podman >/dev/null 2>&1 && echo podman || echo docker)

# Build options
TARGET ?= ubuntu-jammy
DEPS_DIR ?= none

# Computed values
YAP_IMAGE = $(YAP_IMAGE_PREFIX)-$(TARGET):$(YAP_VERSION)
CCACHE_DIR ?= $(CURDIR)/.ccache
OUTPUT_DIR ?= artifacts

# Container mount options
CONTAINER_OPTS = --rm -ti \
	-v $(CURDIR):/project \
	-v $(CURDIR)/$(OUTPUT_DIR):/artifacts \
	-v $(CCACHE_DIR):/root/.ccache \
	-e CCACHE_DIR=/root/.ccache \
	--entrypoint bash

# Add deps volume if provided
ifneq ($(DEPS_DIR),none)
DEPS_MOUNT = -v $(realpath $(DEPS_DIR)):/deps:ro
DEPS_ARG = /deps
else
DEPS_MOUNT =
DEPS_ARG = none
endif

.PHONY: help build clean pull list-targets list-packages

.DEFAULT_GOAL := help

## help: Show this help message
help:
	@echo "Carbonio Videoserver Thirds - Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [TARGET=<distro>] [DEPS_DIR=<path>]"
	@echo ""
	@echo "Targets:"
	@echo "  help           Show this help message"
	@echo "  build          Build all packages"
	@echo "  pull           Pull the YAP container image"
	@echo "  clean          Remove build artifacts"
	@echo "  list-targets   List supported distribution targets"
	@echo "  list-packages  List all packages defined in yap.json"
	@echo ""
	@echo "Options:"
	@echo "  TARGET         Distribution target (default: ubuntu-jammy)"
	@echo "                 Supported: ubuntu-jammy, ubuntu-noble, rocky-8, rocky-9"
	@echo "  DEPS_DIR       Directory containing dependency packages (optional)"
	@echo "                 Example: ../carbonio-thirds/artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  # Build without dependencies (Zextras devs with Artifactory access)"
	@echo "  make build TARGET=ubuntu-jammy"
	@echo ""
	@echo "  # Build with dependencies (community contributors)"
	@echo "  make build TARGET=ubuntu-jammy DEPS_DIR=../carbonio-thirds/artifacts"
	@echo ""
	@echo "  # Build for Rocky Linux 9 with dependencies"
	@echo "  make build TARGET=rocky-9 DEPS_DIR=../carbonio-thirds/artifacts"
	@echo ""

## build: Build all packages
build:
	@mkdir -p $(OUTPUT_DIR) $(CCACHE_DIR)
	$(CONTAINER_RUNTIME) run $(CONTAINER_OPTS) $(DEPS_MOUNT) $(YAP_IMAGE) \
		/project/build-in-container.sh $(DEPS_ARG) $(TARGET)

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
