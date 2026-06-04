# Symfony CLI

A small, production-grade Docker image for developing and running [Symfony](https://symfony.com) projects. It bundles the **Symfony CLI**, **Composer**, and the PHP extensions the vast majority of Symfony apps need — on top of the official `php:8.5-cli-alpine` base, running as a **non-root user**.

> Everything is **pinned** (Symfony CLI, Composer, PHP, extension installer) for reproducible builds and kept current automatically by Renovate. Each release is **linted (hadolint)** and **scanned for HIGH/CRITICAL CVEs (Trivy)** in CI before it's published.

---

## 🚀 Quick start

```bash
docker pull lonikor/symfony-cli:latest

# Show what the Symfony CLI can do
docker run --rm lonikor/symfony-cli:latest symfony list

# Check the Symfony CLI version
docker run --rm lonikor/symfony-cli:latest symfony version
```

Work against your project by mounting it into `/app`:

```bash
# Create a new Symfony web app in the current directory
docker run --rm -it -v "$PWD":/app lonikor/symfony-cli:latest \
    symfony new my_project --webapp

# Install dependencies with Composer
docker run --rm -it -v "$PWD":/app lonikor/symfony-cli:latest \
    composer install
```

---

## 🏷️ Supported tags

| Tag              | Points at                                                        |
|------------------|------------------------------------------------------------------|
| `latest`         | The newest published Symfony CLI version                         |
| `5.17.1`         | The exact Symfony CLI version baked into the image               |
| `1.2.3` / `1.2`  | Semver tags, published when a `v1.2.3` git tag is pushed         |
| `sha-<commit>`   | Immutable, tied to a specific source commit                     |

The version tag **always matches the Symfony CLI binary inside the image** — both come from the same `SYMFONY_CLI_VERSION` build arg. A push to `main` only rebuilds and republishes when that version is new (its tag isn't already on Docker Hub); unchanged versions are skipped, while `v*` git tags always build.

---

## 📦 What's inside

| Component       | Details                                                              |
|-----------------|---------------------------------------------------------------------|
| **Base image**  | `php:8.5-cli-alpine`                                                 |
| **Symfony CLI** | Installed from the official GitHub release, **SHA-256 verified** against the release `checksums.txt` |
| **Composer**    | Copied from the official, pinned `composer` image                   |
| **PHP config**  | Development `php.ini`, `memory_limit=-1` (Composer & cache warmup friendly) |
| **User**        | Non-root `symfony` (uid/gid **1000**, so mounted files keep correct ownership) |
| **Workdir**     | `/app`                                                               |
| **Exposed port**| `8000` (for `symfony server:start`)                                 |
| **Default CMD** | `symfony list`                                                      |
| **Architecture**| `linux/amd64`                                                       |

### PHP extensions

Core Symfony requirements plus the extensions most projects use:

```
ctype · iconv · intl · mbstring · opcache
pdo_mysql · pdo_pgsql · pdo_sqlite · mysqli · pgsql
bcmath · gd · gmp · zip · exif · sodium · xsl · soap · ldap
apcu · redis · amqp
```

…plus everything bundled with the base PHP image (`curl`, `dom`, `json`, `openssl`, `tokenizer`, `simplexml`, `xml`, `fileinfo`, `session`, …). System tools `bash`, `git`, `curl`, `openssh-client`, `unzip`, `tar` and `ca-certificates` are included for Composer and Git-based workflows.

Verify what's available at any time:

```bash
docker run --rm lonikor/symfony-cli:latest symfony check:requirements
docker run --rm lonikor/symfony-cli:latest php -m
```

---

## 🧑‍💻 Common usage

### Open an interactive shell

```bash
docker run --rm -it -v "$PWD":/app lonikor/symfony-cli:latest bash
```

### Run the local web server

`symfony server:start` serves your app on port **8000**:

```bash
docker run --rm -it -v "$PWD":/app -p 8000:8000 lonikor/symfony-cli:latest \
    symfony server:start --no-tls --port=8000 --allow-all-ip
```

Then open <http://localhost:8000>.

> `--allow-all-ip` is required because the request reaches the server from outside the container; `--no-tls` keeps it on plain HTTP for local use.

### Use it as a base image

```dockerfile
FROM lonikor/symfony-cli:5.17.1

# Already non-root (user `symfony`) with WORKDIR /app.
COPY --chown=symfony:symfony . .
RUN composer install --no-dev --optimize-autoloader
```

### docker compose (development)

```yaml
services:
  app:
    image: lonikor/symfony-cli:latest
    working_dir: /app
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    command: symfony server:start --no-tls --port=8000 --allow-all-ip
```

---

## 🔁 Keeping a stable build

Pin the exact version in CI and production so builds are reproducible:

```bash
docker pull lonikor/symfony-cli:5.17.1
```

For maximum immutability, reference a digest:

```bash
docker pull lonikor/symfony-cli@sha256:<digest>
```

---

## 🛠️ Source & build

This image is built from a public repository — you don't have to build it yourself, but you can:

```bash
docker build -t symfony-cli:5.17.1 .

# Override pinned versions:
docker build \
    --build-arg SYMFONY_CLI_VERSION=5.17.1 \
    --build-arg COMPOSER_VERSION=2.10.0 \
    -t symfony-cli:5.17.1 .
```

**Source code, Dockerfile and issues:** <https://github.com/lonikor/symfony-cli-docker>

---

## 📄 License

Released under the MIT License. See the [LICENSE](https://github.com/lonikor/symfony-cli-docker/blob/main/LICENSE) in the source repository.
