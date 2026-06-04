# Symfony CLI image — developer convenience targets.

IMAGE        ?= symfony-cli
# Default tag is the Symfony CLI version (single source of truth: the Dockerfile
# build arg). Override with `make build TAG=...` if needed.
SYMFONY_CLI_VERSION ?= $(shell sed -n 's/^ARG SYMFONY_CLI_VERSION=//p' Dockerfile)
TAG          ?= $(SYMFONY_CLI_VERSION)
IMAGE_REF    := $(IMAGE):$(TAG)
PLATFORMS    ?= linux/amd64

# Keep the local scan in lockstep with CI (.github/workflows/build.yml).
# NOTE: this is the Trivy *binary* version, which differs from the
# aquasecurity/trivy-action version used in CI (action v0.36.0 ships Trivy
# 0.70.0). Bump this in step with the action so local and CI scans agree.
TRIVY_VERSION ?= 0.70.0
TRIVY_IGNORE  := .trivyignore.yaml

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build the image for the local platform
	docker build -t $(IMAGE_REF) .

.PHONY: buildx
buildx: ## Build multi-arch (does not load into local docker)
	docker buildx build --platform $(PLATFORMS) -t $(IMAGE_REF) .

.PHONY: lint
lint: ## Lint the Dockerfile with hadolint (uses .hadolint.yaml, matches CI)
	docker run --rm -i -v "$(PWD)/.hadolint.yaml":/.hadolint.yaml \
		hadolint/hadolint hadolint --config /.hadolint.yaml - < Dockerfile

.PHONY: scan
scan: build ## Scan the built image for HIGH/CRITICAL vulnerabilities (matches CI)
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v "$(PWD)/$(TRIVY_IGNORE)":/$(TRIVY_IGNORE) \
		aquasec/trivy:$(TRIVY_VERSION) image --ignore-unfixed \
		--ignorefile /$(TRIVY_IGNORE) \
		--severity HIGH,CRITICAL --exit-code 1 $(IMAGE_REF)

.PHONY: shell
shell: build ## Open an interactive shell in the image (cwd mounted at /app)
	docker run --rm -it -v "$(PWD)":/app $(IMAGE_REF) bash

.PHONY: check
check: build ## Run `symfony check:requirements` inside the image
	docker run --rm $(IMAGE_REF) symfony check:requirements

.PHONY: push
push: ## Build and push to a registry (set IMAGE=registry/name)
	docker buildx build --platform $(PLATFORMS) \
		-t $(IMAGE_REF) --push .
