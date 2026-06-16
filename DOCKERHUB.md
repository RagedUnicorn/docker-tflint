# TFLint Alpine Docker Image

![Docker TFLint](https://raw.githubusercontent.com/RagedUnicorn/docker-tflint/master/docs/docker_tflint.png)

A lightweight [TFLint](https://github.com/terraform-linters/tflint) CLI built on
Alpine Linux. The official TFLint release is cosign- and checksum-verified at
build time, then shipped as a non-root, single-purpose image with `tflint` as
its entrypoint.

## Quick Start

```bash
# Pull latest version
docker pull ragedunicorn/tflint:latest

# Or pull a specific version
docker pull ragedunicorn/tflint:0.63.1-alpine3.22.1-1

# Show the version
docker run --rm ragedunicorn/tflint:latest --version

# Lint Terraform code in the current directory
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest --chdir=/workspace
```

## Features

- 🪶 **Small footprint**: minimal Alpine-based runtime image
- 🔐 **Verified download**: cosign keyless signature and SHA256 checksum verified at build time
- 🎯 **Single purpose**: `tflint` is the entrypoint, nothing else bundled
- 🔒 **Runs as non-root**: executes as the unprivileged `tflint` user
- 🏗️ **Multi-platform**: supports `linux/amd64` and `linux/arm64`
- 🧩 **ca-certificates**: ready for `tflint --init` plugin downloads over HTTPS

## Usage Examples

### Lint the working directory

```bash
docker run --rm -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest --chdir=/workspace
```

### Install external rulesets (AWS, Google, Azure, …)

```bash
docker run --rm \
  -v "$(pwd)":/workspace \
  -v tflint-plugin-cache:/home/tflint/.tflint.d/plugins \
  ragedunicorn/tflint:latest --chdir=/workspace --init
```

### Output findings as JSON

```bash
docker run --rm -v "$(pwd)":/workspace:ro \
  ragedunicorn/tflint:latest --chdir=/workspace --format=json
```

### Match host user for bind-mount ownership

```bash
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$(pwd)":/workspace:ro ragedunicorn/tflint:latest --chdir=/workspace
```

## Runtime Notes

- **Read-only workspace is fine.** TFLint only reads your config; mount
  `/workspace` read-only if you like.
- **External rulesets need `tflint --init`.** That requires network access and a
  writable plugin directory (`~/.tflint.d/plugins`, overridable with
  `TFLINT_PLUGIN_DIR`). The bundled `terraform` ruleset works offline.
- **Bind-mount ownership.** The container runs as the non-root `tflint` user;
  match your host user with `--user "$(id -u):$(id -g)"` so files stay yours.
- **Exit codes:** `0` = no issues, `2` = issues found, `1` = an application error.

## Tags

This image uses versioning that includes all component versions:

**Format:** `{tflint_version}-alpine{alpine_version}-{build_number}`

### Version Examples

- `0.63.1-alpine3.22.1-1` - Initial release with TFLint 0.63.1 and Alpine 3.22.1
- `0.63.1-alpine3.22.1-2` - Rebuild of the same versions (base CVE patch, fixes)
- `0.63.1-alpine3.22.2-1` - Alpine Linux patch update
- `0.64.0-alpine3.22.1-1` - TFLint version update (build resets to 1)

## License

This image's build tooling is MIT-licensed. The bundled **TFLint binary** is
distributed by the terraform-linters project under the **Mozilla Public License
2.0 (MPL-2.0)**, an OSI-approved open source license. See the
[TFLint LICENSE](https://github.com/terraform-linters/tflint/blob/master/LICENSE).

## Links

- **GitHub**: [https://github.com/RagedUnicorn/docker-tflint](https://github.com/RagedUnicorn/docker-tflint)
- **Issues**: [https://github.com/RagedUnicorn/docker-tflint/issues](https://github.com/RagedUnicorn/docker-tflint/issues)
- **Releases**: [https://github.com/RagedUnicorn/docker-tflint/releases](https://github.com/RagedUnicorn/docker-tflint/releases)
