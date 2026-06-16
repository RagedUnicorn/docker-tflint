# docker-tflint

![](./docs/docker_tflint.png)

[![Release Build](https://github.com/RagedUnicorn/docker-tflint/actions/workflows/docker_release.yml/badge.svg)](https://github.com/RagedUnicorn/docker-tflint/actions/workflows/docker_release.yml)
[![Test](https://github.com/RagedUnicorn/docker-tflint/actions/workflows/test.yml/badge.svg)](https://github.com/RagedUnicorn/docker-tflint/actions/workflows/test.yml)
![License: MIT](docs/license_badge.svg)

> Docker Alpine image with the TFLint CLI for linting Terraform code.

![](./docs/alpine_linux_logo.svg)

## Overview

This Docker image provides a minimal [TFLint](https://github.com/terraform-linters/tflint)
installation on Alpine Linux. It downloads the official TFLint release from
GitHub and **cryptographically verifies it** (cosign keyless signature on the
checksums, then the checksum of the binary) before it is ever placed into the
runtime image. The result is a small, non-root, fully OCI-labelled image with
`tflint` as its entrypoint.

## Features

- **Small footprint**: minimal runtime image using Alpine Linux
- **Verified download**: cosign keyless signature and SHA256 checksum are verified at build time
- **Single purpose**: `tflint` is the entrypoint - nothing else bundled
- **Non-root user**: runs as the unprivileged `tflint` user
- **Multi-architecture**: supports `linux/amd64` and `linux/arm64`
- **ca-certificates**: included for `tflint --init` plugin downloads over HTTPS

## Quick Start

```bash
# Pull the image
docker pull ragedunicorn/tflint:latest

# Show the version
docker run --rm ragedunicorn/tflint:latest --version

# Lint Terraform code in the current directory
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest --chdir=/workspace
```

For development and building from source, see [DEVELOPMENT.md](DEVELOPMENT.md).

## Usage

The container uses TFLint as the entrypoint, so any TFLint flag can be passed
directly to the `docker run` command.

### Basic Usage

```bash
# Using latest version
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest [tflint-args]

# Using a specific TFLint version
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:0.63.1 [tflint-args]

# Using an exact version combination
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:0.63.1-alpine3.22.1-1 [tflint-args]
```

### Examples

```bash
# Lint the working directory (bundled terraform ruleset, fully offline)
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest --chdir=/workspace

# Show the TFLint version
docker run --rm ragedunicorn/tflint:latest --version

# Output findings as JSON
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest --chdir=/workspace --format=json

# Lint recursively
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest --chdir=/workspace --recursive
```

TFLint exit codes: `0` = no issues, `2` = issues found, `1` = an application error.

## Runtime Notes

TFLint reads your configuration and (optionally) downloads ruleset plugins.
Keep these in mind:

### A read-only workspace is fine

TFLint only reads your `.tf` and `.tflint.hcl` files; it does not modify your
configuration. You can safely mount `/workspace` read-only:

```bash
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest --chdir=/workspace
```

### Installing external rulesets requires `tflint --init`

The bundled **terraform** ruleset works offline. Cloud rulesets (AWS, Google
Cloud, Azure, …) are external plugins declared with a `plugin` block in
`.tflint.hcl` and installed with `tflint --init`. That needs network access and
a writable plugin directory (`~/.tflint.d/plugins` by default, overridable with
`TFLINT_PLUGIN_DIR`):

```bash
docker run --rm \
  -v "$(pwd)":/workspace \
  -v tflint-plugin-cache:/home/tflint/.tflint.d/plugins \
  ragedunicorn/tflint:latest --chdir=/workspace --init
```

Set `GITHUB_TOKEN` to avoid GitHub API rate limits while downloading plugins.

### Match the host user for bind-mount ownership

The image runs as the non-root `tflint` user. If TFLint writes to a bind mount
(for example the plugin cache), run the container as your own user so files stay
owned by you:

```bash
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest --chdir=/workspace
```

In Docker Compose, match the host UID/GID:

```yaml
user: "${UID:-1000}:${GID:-1000}"
```

## Docker Compose Usage

This repository includes Docker Compose configurations for common workflows.

### Basic Setup

```bash
docker compose run --rm tflint --chdir=/workspace
```

The base `docker-compose.yml` mounts the current directory (read-only) at
`/workspace` and matches your host UID/GID. Export `UID`/`GID` first so they are
available to compose:

```bash
export UID GID
docker compose run --rm tflint --chdir=/workspace
```

### Example Configuration

The `examples/` directory contains a runnable example with a sample module, a
`.tflint.hcl`, and a persistent plugin cache:

```bash
docker compose -f examples/docker-compose.yml run --rm tflint
```

### Environment Variables

- `TFLINT_VERSION`: image tag to use (default: `latest`)
- `UID` / `GID`: host user/group IDs for bind-mount ownership
- `TFLINT_PLUGIN_DIR`: plugin install/cache directory (default `~/.tflint.d/plugins`)
- `GITHUB_TOKEN`: raises the GitHub API rate limit during `tflint --init`

## Building Custom Images

To create a custom image - for example a toolbox that adds extra tooling - start
from this image. Note that adding more tools moves away from the single-purpose
design; a toolbox is better kept in its own repository.

```dockerfile
FROM ragedunicorn/tflint:latest

USER root
RUN apk add --no-cache --update git
USER tflint

WORKDIR /workspace
```

## Versioning

This project uses versioning that matches the Docker image contents:

**Format:** `{tflint_version}-alpine{alpine_version}-{build_number}`

Examples:
- `0.63.1-alpine3.22.1-1` - TFLint 0.63.1 on Alpine 3.22.1, build 1
- `latest` - Most recent stable release

The build number resets to `1` whenever TFLint is bumped, and is incremented
only for rebuilds that leave the TFLint version unchanged (an Alpine patch or
base CVE fix). For the detailed release process, see [RELEASE.md](RELEASE.md).

## Automated Dependency Updates

This project uses [Renovate](https://docs.renovatebot.com/) to automatically
check for updates to:
- Alpine Linux base image version
- TFLint version (tracked via the GitHub releases datasource)

Renovate runs weekly and creates pull requests when updates are available.

## License

This repository - the Dockerfile, scripts and documentation - is licensed under
the **MIT License**.

The bundled **TFLint binary** is distributed by the terraform-linters project
under the **Mozilla Public License 2.0 (MPL-2.0)**, an OSI-approved open source
license. See TFLint's
[LICENSE](https://github.com/terraform-linters/tflint/blob/master/LICENSE) for
the terms governing the binary.

## Documentation

- [Development Guide](DEVELOPMENT.md) - Building, debugging, and contributing
- [Testing Guide](TEST.md) - Running and writing tests
- [Release Process](RELEASE.md) - Creating releases and versioning

## Links

- [TFLint Documentation](https://github.com/terraform-linters/tflint/tree/master/docs)
- [TFLint Releases](https://github.com/terraform-linters/tflint/releases)
- [TFLint Rulesets](https://github.com/terraform-linters)
- [Alpine Linux](https://www.alpinelinux.org/)
