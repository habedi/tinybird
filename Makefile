################################################################################
# Configuration and Variables
################################################################################
ZIG    ?= $(shell test -f ~/.local/share/zig/0.17.0/zig && echo ~/.local/share/zig/0.17.0/zig || which zig)
ZIG_VERSION   := $(shell $(ZIG) version)
BUILD_TYPE    ?= Debug
BUILD_OPTS      = -Doptimize=$(BUILD_TYPE)
JOBS          ?= $(shell nproc || echo 2)
SRC_DIR       := src
TEST_DIR      := tests
BUILD_DIR     := zig-out
CACHE_DIR     := .zig-cache
DOC_SRC       := src/core/core.zig
DOC_OUT       := docs/api/
COVERAGE_DIR  := coverage
FIRMWARE_NAME ?= tinybird
FIRMWARE_UF2  ?= $(BUILD_DIR)/firmware/$(FIRMWARE_NAME).uf2
RELEASE_MODE := ReleaseSmall

SHELL         := /usr/bin/env bash
.SHELLFLAGS   := -eu -o pipefail -c

################################################################################
# Targets
################################################################################

.PHONY: all shell install build rebuild flash test cov lint format docs clean install-deps release help setup-hooks test-hooks
.DEFAULT_GOAL := help

help: ## Show the help messages for all targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

shell: ## Enter the Nix dev shell (the primary environment)
	nix develop

install: ## Install the uv-managed Python tools (pre-commit)
	uv sync

all: build test lint docs  ## build, test, lint, and doc

build: ## Build the host CLI, Wasm apps, and firmware (Mode=$(BUILD_TYPE))
	@echo "Building in $(BUILD_TYPE) mode with $(JOBS) concurrent jobs..."
	$(ZIG) build $(BUILD_OPTS) -j$(JOBS)

rebuild: clean build  ## clean and build

flash: build  ## Flash the firmware to the board over USB (default: FIRMWARE_NAME=tinybird)
	@echo "Flashing $(FIRMWARE_UF2)..."
	picotool load -fx $(FIRMWARE_UF2)

test: ## Run the host-side tests and generate coverage data
	@echo "Running tests with coverage enabled..."
	$(ZIG) build test $(BUILD_OPTS) -Denable-coverage=true -j$(JOBS)

release: ## Build the host CLI, Wasm apps, and firmware in Release mode
	@echo "Building in Release mode..."
	@$(MAKE) BUILD_TYPE=$(RELEASE_MODE) build

clean: ## Remove docs, build artifacts, and cache directories
	@echo "Removing build artifacts, cache, generated docs, and coverage files..."
	rm -rf $(BUILD_DIR) $(CACHE_DIR) $(DOC_OUT) *.profraw $(COVERAGE_DIR)

lint: ## Check code style and formatting of Zig files
	@echo "Running code style checks..."
	$(ZIG) fmt --check $(SRC_DIR) $(TEST_DIR) examples build.zig

format: ## Format Zig files
	@echo "Formatting Zig files..."
	$(ZIG) fmt $(SRC_DIR) $(TEST_DIR) examples build.zig

docs: ## Generate API documentation
	@echo "Generating documentation from $(DOC_SRC) to $(DOC_OUT)..."
	mkdir -p $(DOC_OUT)
	$(ZIG) test -fno-emit-bin -femit-docs=$(DOC_OUT) $(DOC_SRC)

install-deps: ## Install system dependencies (for Debian-based systems)
	@echo "Installing system dependencies..."
	sudo apt-get update
	sudo apt-get install -y make llvm snapd esptool
	sudo snap install zig  --beta --classic # Use `--edge --classic` to install the latest version

setup-hooks: ## Install Git hooks (pre-commit and pre-push)
	@echo "Installing Git hooks..."
	@uv run pre-commit install --hook-type pre-commit
	@uv run pre-commit install --hook-type pre-push
	@uv run pre-commit install-hooks

test-hooks: ## Run Git hooks on all files manually (both stages)
	@echo "Running Git hooks..."
	@uv run pre-commit run --all-files --hook-stage pre-commit
	@uv run pre-commit run --all-files --hook-stage pre-push
