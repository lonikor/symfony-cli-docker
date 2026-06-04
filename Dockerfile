# syntax=docker/dockerfile:1

###############################################################################
# Symfony CLI image
#
# Base:  php:8.5-cli-alpine
# Adds:  - all PHP extensions commonly required by Symfony applications
#        - Composer
#        - the Symfony CLI binary (https://symfony.com/download)
#
# All third-party versions are pinned via build args for reproducible builds.
# Override at build time, e.g.:
#   docker build --build-arg SYMFONY_CLI_VERSION=5.17.1 -t symfony-cli:5.17.1 .
###############################################################################
# Pinned tool versions. Declared in the global scope (before any FROM) so they
# can be used in the `FROM ... AS` stage references below — BuildKit does not
# allow variable expansion directly in `COPY --from=<image>:${VAR}`.
ARG PHP_VERSION=8.5
ARG COMPOSER_VERSION=2.10.0
ARG PHP_EXT_INSTALLER_VERSION=2.11.1

# Pinned source stages for the binaries we copy in. Naming them here lets the
# final stage do `COPY --from=composer` / `--from=php-ext-installer` without
# variable expansion in the `--from` reference.
FROM composer:${COMPOSER_VERSION} AS composer
FROM mlocati/php-extension-installer:${PHP_EXT_INSTALLER_VERSION} AS php-ext-installer

FROM php:${PHP_VERSION}-cli-alpine

# Re-declared inside the build stage so it is usable in the RUN below.
ARG SYMFONY_CLI_VERSION=5.17.1

# Fail pipelines on the first failing command (busybox ash needs this set
# explicitly) so checksum verification below can't be silently bypassed.
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# OCI image labels (title/description/source/version/revision/created) are
# applied at build time by docker/metadata-action in CI — see
# .github/workflows/build.yml — so they stay a single source of truth and
# don't need build-arg plumbing here.

# ---------------------------------------------------------------------------
# System packages used at runtime by the Symfony CLI, Composer and Git tooling.
# ---------------------------------------------------------------------------
RUN apk add --no-cache \
        bash \
        git \
        curl \
        openssh-client \
        unzip \
        tar \
        ca-certificates

# ---------------------------------------------------------------------------
# PHP extensions.
#
# `install-php-extensions` (mlocati) resolves and installs the required Alpine
# build/runtime libraries automatically, then cleans up the build deps, so the
# final image stays small. The list below covers the core extensions Symfony
# requires plus the ones the vast majority of Symfony projects pull in
# (databases, caching, messaging, image handling, etc.).
# ---------------------------------------------------------------------------
COPY --from=php-ext-installer \
        /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
        # --- Core Symfony requirements --------------------------------------
        ctype \
        iconv \
        intl \
        mbstring \
        opcache \
        # --- Databases ------------------------------------------------------
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        mysqli \
        pgsql \
        # --- Common application extensions ----------------------------------
        bcmath \
        gd \
        gmp \
        zip \
        exif \
        sodium \
        xsl \
        soap \
        ldap \
        # --- Cache / messaging (PECL) ---------------------------------------
        apcu \
        redis \
        amqp

# ---------------------------------------------------------------------------
# Composer (copied from the official, pinned image).
# ---------------------------------------------------------------------------
COPY --from=composer /usr/bin/composer /usr/local/bin/composer

# ---------------------------------------------------------------------------
# Symfony CLI binary.
#
# Installed from the official GitHub release for the pinned version. The tarball
# is verified against the release's `checksums.txt` (SHA-256) before extraction
# so a tampered or corrupted download fails the build.
# ---------------------------------------------------------------------------
RUN set -eux; \
    apkArch="$(apk --print-arch)"; \
    case "$apkArch" in \
        x86_64)  arch='amd64' ;; \
        aarch64) arch='arm64' ;; \
        *) echo >&2 "Unsupported architecture: $apkArch"; exit 1 ;; \
    esac; \
    base="https://github.com/symfony-cli/symfony-cli/releases/download/v${SYMFONY_CLI_VERSION}"; \
    tarball="symfony-cli_linux_${arch}.tar.gz"; \
    curl -fSL "${base}/${tarball}" -o "/tmp/${tarball}"; \
    curl -fSL "${base}/checksums.txt" -o /tmp/checksums.txt; \
    checksum="$(grep " ${tarball}\$" /tmp/checksums.txt | cut -d' ' -f1)"; \
    echo "${checksum}  /tmp/${tarball}" | sha256sum -c -; \
    tar -xzf "/tmp/${tarball}" -C /usr/local/bin symfony; \
    rm -f "/tmp/${tarball}" /tmp/checksums.txt; \
    chmod +x /usr/local/bin/symfony; \
    symfony version

# ---------------------------------------------------------------------------
# PHP CLI configuration tuned for development.
#
# Use the development php.ini and lift the memory limit so Composer and
# memory-hungry Symfony commands (e.g. cache:warmup) don't get killed.
# ---------------------------------------------------------------------------
RUN cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"; \
    printf 'memory_limit=-1\n' > "$PHP_INI_DIR/conf.d/zz-symfony-cli.ini"

# ---------------------------------------------------------------------------
# Composer environment.
# ---------------------------------------------------------------------------
ENV COMPOSER_HOME=/home/symfony/.composer \
    COMPOSER_MEMORY_LIMIT=-1 \
    COMPOSER_NO_INTERACTION=1

# ---------------------------------------------------------------------------
# Non-root user.
#
# Create a dedicated user/group with uid/gid 1000 (matching the typical host
# user on Linux) so files written to the mounted volume are owned correctly
# and no command runs as root.
# ---------------------------------------------------------------------------
RUN addgroup -g 1000 symfony \
    && adduser -u 1000 -G symfony -h /home/symfony -s /bin/bash -D symfony \
    && mkdir -p /app "$COMPOSER_HOME" \
    && chown -R symfony:symfony /app /home/symfony

WORKDIR /app

USER symfony

# Expose the default port used by `symfony server:start`.
#
# No HEALTHCHECK is baked in: the default use of this image is the CLI (see CMD
# below), which exits immediately, so an image-level health check would be
# inert or misleading. When running the web server, define the health check in
# your runtime layer (docker compose / k8s) where you know it's a server.
EXPOSE 8000

CMD ["symfony", "list"]
