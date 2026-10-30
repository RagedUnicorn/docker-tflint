# docker-tflint

![](./docs/docker_tflint_banner.svg)

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

On Windows, use the PowerShell form:

```powershell
# Lint Terraform code in the current directory
docker run --rm -v "${PWD}:/workspace:ro" ragedunicorn/tflint:latest --chdir=/workspace
```

Write `${PWD}` **with braces** and keep the colon (and the `:ro` suffix) inside
the quotes - without braces PowerShell parses `$PWD:` as a scope-qualified
variable (as in `$env:PATH`) and rejects the argument. See the
[Windows (PowerShell) notes](#windows-powershell-notes) for details.

For development and building from source, see [DEVELOPMENT.md](DEVELOPMENT.md).

## Usage

The container uses TFLint as the entrypoint, so any TFLint flag can be passed
directly to the `docker run` command.

### Basic Usage

```bash
# Using latest version
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest [tflint-args]

# Using a specific TFLint version
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:<tflint-version> [tflint-args]

# Using an exact version combination
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:<tflint-version>-alpine<alpine-version>-<build> [tflint-args]
```

PowerShell:

```powershell
# Using latest version
docker run --rm -v "${PWD}:/workspace:ro" ragedunicorn/tflint:latest [tflint-args]

# Using a specific TFLint version
docker run --rm -v "${PWD}:/workspace:ro" ragedunicorn/tflint:<tflint-version> [tflint-args]

# Using an exact version combination
docker run --rm -v "${PWD}:/workspace:ro" ragedunicorn/tflint:<tflint-version>-alpine<alpine-version>-<build> [tflint-args]
```

Available tags are listed on [Docker Hub](https://hub.docker.com/r/ragedunicorn/tflint/tags) and in the
[GitHub releases](https://github.com/RagedUnicorn/docker-tflint/releases).

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

PowerShell:

```powershell
# Lint the working directory (bundled terraform ruleset, fully offline)
docker run --rm -v "${PWD}:/workspace:ro" ragedunicorn/tflint:latest --chdir=/workspace

# Show the TFLint version
docker run --rm ragedunicorn/tflint:latest --version

# Output findings as JSON
docker run --rm -v "${PWD}:/workspace:ro" ragedunicorn/tflint:latest --chdir=/workspace --format=json

# Lint recursively
docker run --rm -v "${PWD}:/workspace:ro" ragedunicorn/tflint:latest --chdir=/workspace --recursive
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

PowerShell:

```powershell
docker run --rm -v "${PWD}:/workspace:ro" ragedunicorn/tflint:latest --chdir=/workspace
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

PowerShell:

```powershell
docker run --rm `
  -v "${PWD}:/workspace" `
  -v tflint-plugin-cache:/home/tflint/.tflint.d/plugins `
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

**Windows hosts:** skip this section. Docker Desktop bind mounts do not carry
Unix file ownership, so `--user` matching has no effect there (and `id` does
not exist in PowerShell). Ownership matching applies to Linux and macOS hosts.

In Docker Compose, match the host UID/GID:

```yaml
user: "${UID:-1000}:${GID:-1000}"
```

### Windows (PowerShell) notes

The PowerShell variants above differ from the bash ones in two ways: the
mount is written `-v "${PWD}:/workspace:ro"` instead of
`-v "$(pwd)":/workspace:ro`, and the backtick replaces `\` as the
line-continuation character.

The mount spelling matters:

- Pasting the bash form into PowerShell breaks: the argument ends at the
  closing quote, so `"$(pwd)":/workspace:ro` reaches Docker as two arguments
  (`C:\path` and `:/workspace:ro`).
- `"$PWD:/workspace:ro"` without braces is a parse error: PowerShell reads a
  colon after a variable as a scope qualifier (as in `$env:PATH`), and `/` is
  not a valid variable-name character.
- `"${PWD}:/workspace:ro"` works: the braces end the variable name at `PWD`,
  the colons stay literal, and Docker splits the resulting
  `C:\path:/workspace:ro` into host path, container path and the `ro` option
  because it recognises the `C:` drive prefix. Drop `:ro` for a writable
  mount.

To check what the container actually sees under `/workspace`, run a
look-inside command:

```powershell
docker run --rm -v "${PWD}:/workspace:ro" --entrypoint sh ragedunicorn/tflint:latest -c 'pwd; ls -la /workspace'
```

The single quotes keep `pwd; ls -la /workspace` as one literal argument to
the container's `sh`, so the `;` runs inside the container - unquoted,
PowerShell would treat `;` as its own statement separator and run
`ls -la /workspace` on the host.

For more complex invocations where PowerShell keeps mangling arguments, the
[stop-parsing token `--%`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parsing#the-stop-parsing-token)
is an escape hatch: PowerShell passes everything after it verbatim. Nothing
after `--%` is expanded - including `${PWD}` - so it cannot be combined with
the mount examples above; none of the examples in this README need it.

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

Examples (`X.Y.Z` is the TFLint version, `A.B.C` the Alpine version):
- `X.Y.Z-alpineA.B.C-1` - TFLint X.Y.Z on Alpine A.B.C, build 1
- `X.Y.Z` - Most recent build of TFLint X.Y.Z
- `latest` - Most recent stable release

The current tags are listed on [Docker Hub](https://hub.docker.com/r/ragedunicorn/tflint/tags).

The build number resets to `1` whenever TFLint is bumped, and is incremented
only for rebuilds that leave the TFLint version unchanged (an Alpine patch or
base CVE fix). For the detailed release process, see [RELEASE.md](RELEASE.md).

## Image Verification

Released images are signed with [cosign](https://docs.sigstore.dev/) keyless signing and carry SBOM and provenance attestations.

```bash
# Verify the signature (works for both ghcr.io/ragedunicorn/docker-tflint and ragedunicorn/tflint)
cosign verify ragedunicorn/tflint:latest \
  --certificate-identity-regexp '^https://github.com/RagedUnicorn/docker-tflint/\.github/workflows/docker_release\.yml@refs/tags/v' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# Inspect the SBOM and provenance attestations
docker buildx imagetools inspect ragedunicorn/tflint:latest --format '{{ json .SBOM }}'
docker buildx imagetools inspect ragedunicorn/tflint:latest --format '{{ json .Provenance }}'
```

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
