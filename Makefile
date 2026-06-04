# Symfony CLI image — developer convenience targets.

IMAGE        ?= symfony-cli
# Default tag is the Symfony CLI version (single source of truth: the Dockerfile
# build arg). Override with `make build TAG=...` if needed.
SYMFONY_CLI_VERSION ?= $(shell sed -n 's/^ARG SYMFONY_CLI_VERSION=//p' Dockerfile)
TAG          ?= $(SYMFONY_CLI_VERSION)
IMAGE_REF    := $(IMAGE):$(TAG)
PLATFORMS    ?= linux/amd64,linux/arm64

# Provenance args (best-effort; CI overrides these).
VERSION      ?= dev
VCS_REF      := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
BUILD_DATE   := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_ARGS   := --build-arg VERSION=$(VERSION) \
                --build-arg VCS_REF=$(VCS_REF) \
                --build-arg BUILD_DATE=$(BUILD_DATE)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build the image for the local platform
	docker build $(BUILD_ARGS) -t $(IMAGE_REF) .

.PHONY: buildx
buildx: ## Build multi-arch (does not load into local docker)
	docker buildx build $(BUILD_ARGS) --platform $(PLATFORMS) -t $(IMAGE_REF) .

.PHONY: lint
lint: ## Lint the Dockerfile with hadolint
	docker run --rm -i hadolint/hadolint < Dockerfile

.PHONY: scan
scan: build ## Scan the built image for HIGH/CRITICAL vulnerabilities
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		aquasec/trivy:latest image --ignore-unfixed \
		--severity HIGH,CRITICAL $(IMAGE_REF)

.PHONY: shell
shell: build ## Open an interactive shell in the image (cwd mounted at /app)
	docker run --rm -it -v "$(PWD)":/app $(IMAGE_REF) bash

.PHONY: check
check: build ## Run `symfony check:requirements` inside the image
	docker run --rm $(IMAGE_REF) symfony check:requirements

.PHONY: push
push: ## Build and push multi-arch to a registry (set IMAGE=registry/name)
	docker buildx build $(BUILD_ARGS) --platform $(PLATFORMS) \
		-t $(IMAGE_REF) --push .
