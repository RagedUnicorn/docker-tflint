# Development Guide

This document provides information for developers working on the TFLint Docker
image.

## Development Environment

### Prerequisites

- Docker installed and running (with BuildKit / buildx)
- Docker Compose installed
- Git for version control
- Text editor or IDE

### Project Structure

```
docker-tflint/
├── Dockerfile               # Multi-stage: verified download + minimal runtime
├── docker-compose.yml       # Basic usage configuration
├── docker-compose.dev.yml   # Development environment (shell)
├── docker-compose.test.yml  # Test orchestration
├── .env                     # Default environment variables
├── examples/                # Runnable example configuration
│   ├── docker-compose.yml   # Workflow example (read-only mount + plugin cache)
│   ├── main.tf              # Sample module that trips a lint rule
│   ├── .tflint.hcl          # Enables a bundled terraform rule
│   └── README.md
├── test/                    # Container Structure Tests
│   ├── tflint_test.yml
│   ├── tflint_command_test.yml
│   └── tflint_metadata_test.yml
└── docs/                    # Documentation assets
```

## How the Image Is Built

The Dockerfile uses two stages:

1. **Download + verify stage** - installs `curl`, `unzip` and `cosign`, downloads
   the TFLint release zip, `checksums.txt`, its keyless signature
   (`checksums.txt.keyless.sig`) and certificate (`checksums.txt.pem`), uses
   `cosign verify-blob` to prove `checksums.txt` was produced by TFLint's GitHub
   Actions release workflow, then verifies the zip against that trusted checksum
   and unzips the single `tflint` binary. **This verification is the whole point
   of building our own image and must never be skipped.**
2. **Runtime stage** - a clean Alpine image with `ca-certificates`, a non-root
   `tflint` user (with a home directory for the plugin cache), and the verified
   binary copied in from the build stage.

The TFLint version is pinned via `ARG TFLINT_VERSION` and updated by Renovate
using the `# renovate:` comment above it. `TARGETARCH` is supplied automatically
by buildx (and by BuildKit for single-platform `docker build`), which lines up
with TFLint's zip arch naming (`amd64`, `arm64`).

> **Note:** TFLint's release assets are not versioned in the filename
> (`tflint_linux_amd64.zip`); the version only appears in the download path.

## Development Workflow

### 1. Local Development Mode

The `docker-compose.dev.yml` file provides an interactive shell built from the
local Dockerfile:

```bash
# Build the image locally
docker compose -f docker-compose.dev.yml build

# Drop into a shell to run tflint manually
docker compose -f docker-compose.dev.yml run --rm tflint-dev

# Inside the container
tflint --version
tflint --chdir=/workspace
```

### 2. Building the Image

```bash
# Basic build (BuildKit supplies TARGETARCH automatically)
docker build -t ragedunicorn/tflint:dev .

# Build with version metadata
docker build \
  --build-arg TFLINT_VERSION=0.63.1 \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg VERSION=0.63.1-alpine3.22.1-1 \
  -t ragedunicorn/tflint:0.63.1-alpine3.22.1-1 .

# Multi-platform build (requires buildx). Do NOT set TARGETARCH by hand.
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg TFLINT_VERSION=0.63.1 \
  --build-arg VERSION=0.63.1-alpine3.22.1-1 \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  -t ragedunicorn/tflint:0.63.1-alpine3.22.1-1 .
```

### 3. Testing Your Changes

After making changes, always build and test locally:

```bash
docker build -t ragedunicorn/tflint:test .
```

#### Running Tests (Cross-Platform)

**Linux/macOS:**

```bash
TFLINT_VERSION=test docker compose -f docker-compose.test.yml run test-all
```

**Windows (PowerShell):**

```powershell
$env:TFLINT_VERSION="test"; docker compose -f docker-compose.test.yml run test-all
```

**Windows (Command Prompt):**

```cmd
set TFLINT_VERSION=test && docker compose -f docker-compose.test.yml run test-all
```

**Important:** Never test against remote images - they may have different labels
or configurations due to CI/CD overrides.

See [TEST.md](TEST.md) for detailed testing information.

## Making Changes

### Version Updates

This project uses [Renovate](https://docs.renovatebot.com/) to manage updates:

- **TFLint**: tracked via the GitHub releases datasource; the `v` prefix is
  stripped via an `extractVersion` rule in `renovate.json`.
- **Alpine Linux**: tracked via the Docker datasource on the `FROM` lines.

When Renovate creates a PR:

1. Review the changes
2. Check that CI passes all tests
3. Test the build locally for major updates
4. Merge if everything looks good

Manual updates are rarely needed. If required, edit `ARG TFLINT_VERSION` in the
Dockerfile (and the `FROM alpine:X.Y.Z` lines for Alpine), then rebuild and
test. Remember to keep the `org.opencontainers.image.base.name` label and the
metadata test in sync with the Alpine version.

## Code Style and Best Practices

### Dockerfile Best Practices

1. **Verify everything**: never skip the cosign/checksum verification
2. **Single purpose**: keep `tflint` as the only entrypoint - no extra tools
3. **Layer optimization**: group related commands to minimize layers
4. **Security**: run as the non-root `tflint` user
5. **Labels**: follow OCI naming conventions

### Documentation

1. **README.md**: keep focused on user-facing information
2. **Comments**: explain non-obvious build steps in the Dockerfile
3. **Examples**: provide working examples for new features
4. **Commit messages**: use conventional format (`feat:`, `fix:`, `docs:`, …)

## Debugging

### Common Issues

**Build failures (download/verify):**

```bash
# Verbose build output
docker build --progress=plain --no-cache -t ragedunicorn/tflint:debug .
```

A failure at `cosign verify-blob` or `sha256sum -c` means the download did not
match the published, signed checksums - investigate before doing anything else;
do not work around the verification.

**TFLint not working:**

```bash
docker run --rm --entrypoint sh ragedunicorn/tflint:dev -c "which tflint && tflint --version"
```

**Plugin install (`tflint --init`) fails:**

`tflint --init` needs network access and a writable plugin directory. Mount a
writable volume at `~/.tflint.d/plugins` and set `GITHUB_TOKEN` to avoid GitHub
API rate limits.

## Contributing

### Before Submitting Changes

1. Run the full test suite
2. Update documentation if needed
3. Add tests for new behavior
4. Follow the existing style
5. Write clear commit messages

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit using conventional commits
4. Push to your fork
5. Open a Pull Request with a clear description

### Release Process

See [RELEASE.md](RELEASE.md) for information about creating releases.
