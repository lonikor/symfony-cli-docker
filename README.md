# Symfony CLI Docker image

A Docker image for working with [Symfony](https://symfony.com) projects, based on
`php:8.5-cli-alpine`. It bundles the **Symfony CLI**, **Composer**, and all the
PHP extensions commonly required by Symfony applications.

## Pull the published image

CI builds, scans (hadolint + Trivy) and publishes the image to Docker Hub at
[`lonikor/symfony-cli`](https://hub.docker.com/r/lonikor/symfony-cli) — you
don't have to build it yourself. A push to `main` only rebuilds and republishes
when the Symfony CLI version (the `SYMFONY_CLI_VERSION` build arg) is new, i.e.
its tag isn't already on Docker Hub; pushes for an unchanged version are skipped.
`v*` git tags always build.

```bash
docker pull lonikor/symfony-cli:latest
# or a specific Symfony CLI version:
docker pull lonikor/symfony-cli:5.17.1
```

### Available tags

| Tag                     | Points at                                             |
|-------------------------|-------------------------------------------------------|
| `latest`                | The newest published Symfony CLI version               |
| `5.17.1`                | The exact Symfony CLI version baked into the image    |
| `1.2.3` / `1.2`         | Semver, published when you push a `v1.2.3` git tag    |
| `sha-<commit>`          | Immutable, tied to a specific commit                  |

The version tag always matches the Symfony CLI binary inside the image, since
both come from the `SYMFONY_CLI_VERSION` build arg (kept current by Renovate).

## What's inside

| Component    | Version / notes                                  |
|--------------|--------------------------------------------------|
| Base image   | `php:8.5-cli-alpine`                             |
| Symfony CLI  | pinned via `SYMFONY_CLI_VERSION` build arg, verified against the release `checksums.txt` |
| Composer     | pinned via `COMPOSER_VERSION` build arg (official `composer` image) |
| PHP ext.     | see below                                        |
| Runs as      | non-root user `symfony` (uid/gid 1000)           |

All third-party versions are pinned through build args (see the top of the
`Dockerfile`) and kept current automatically by Renovate.

### PHP extensions

Core Symfony requirements plus the extensions most projects use:

`ctype` · `iconv` · `intl` · `mbstring` · `opcache` ·
`pdo_mysql` · `pdo_pgsql` · `pdo_sqlite` · `mysqli` · `pgsql` ·
`bcmath` · `gd` · `gmp` · `zip` · `exif` · `sodium` · `xsl` · `soap` · `ldap` ·
`apcu` · `redis` · `amqp`

(plus everything bundled with the base PHP image: `curl`, `dom`, `json`,
`openssl`, `tokenizer`, `simplexml`, `xml`, `fileinfo`, `session`, …)

Verify at any time:

```bash
docker run --rm symfony-cli:5.17.1 symfony check:requirements
docker run --rm symfony-cli:5.17.1 php -m
```

## Build

```bash
docker build -t symfony-cli:5.17.1 .

# or pin/override versions:
docker build \
    --build-arg SYMFONY_CLI_VERSION=5.17.1 \
    --build-arg COMPOSER_VERSION=2.10.0 \
    -t symfony-cli:5.17.1 .
```

A `Makefile` wraps the common tasks:

```bash
make build   # build for the local platform
make lint    # hadolint the Dockerfile
make scan    # Trivy scan for HIGH/CRITICAL CVEs
make shell   # interactive shell with the cwd mounted at /app
make check   # symfony check:requirements
```

## Usage

Run any Symfony CLI command against the current directory by mounting it into
`/app`:

```bash
# Show the CLI version
docker run --rm symfony-cli:5.17.1 symfony version

# Create a new Symfony project in the current directory
docker run --rm -it -v "$PWD":/app symfony-cli:5.17.1 \
    symfony new my_project --webapp

# Composer inside the project
docker run --rm -it -v "$PWD":/app symfony-cli:5.17.1 composer install
```

### Run the local web server

`symfony server:start` serves the app on port 8000 (exposed by the image):

```bash
docker run --rm -it -v "$PWD":/app -p 8000:8000 symfony-cli:5.17.1 \
    symfony server:start --no-tls --port=8000 --allow-all-ip
```

Then open <http://localhost:8000>.

> `--allow-all-ip` is needed because the request reaches the server from outside
> the container; `--no-tls` keeps it on plain HTTP for local use.
