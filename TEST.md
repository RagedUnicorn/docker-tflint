# Testing Guide

This document describes how to test the TFLint Docker image using Container
Structure Tests.

## Quick Start

```bash
# Build the image locally first
docker build -t ragedunicorn/tflint:test .

# Run all tests
TFLINT_VERSION=test docker compose -f docker-compose.test.yml run test-all

# Run individual test suites
TFLINT_VERSION=test docker compose -f docker-compose.test.yml up container-test          # File structure
TFLINT_VERSION=test docker compose -f docker-compose.test.yml up container-test-command  # Command execution
TFLINT_VERSION=test docker compose -f docker-compose.test.yml up container-test-metadata # Metadata
```

## Test Structure

The test suite consists of three files:

### 1. File Structure Tests (`test/tflint_test.yml`)

Validates:

- The `tflint` binary exists at `/usr/local/bin/tflint` with the expected permissions
- The `/workspace` working directory exists
- CA certificates are present (required for `tflint --init` plugin downloads)

### 2. Command Execution Tests (`test/tflint_command_test.yml`)

Validates:

- `tflint --version` and `tflint --help` output
- The working directory is `/workspace`
- The container runs as the non-root `tflint` user
- Linting a clean config exits `0`
- Linting a config with an unused variable reports
  `terraform_unused_declarations` and exits `2` (bundled ruleset, fully offline)

### 3. Metadata Tests (`test/tflint_metadata_test.yml`)

Validates:

- OCI-compliant labels are present and correct
- The entrypoint is `tflint` and the default command is `--help`
- The working directory is `/workspace`
- The image runs as the `tflint` user

## Running Tests

### Prerequisites

1. Docker must be installed and running
2. Build the TFLint image locally before testing

### Important: Always Test Local Builds

**⚠️ Always build and test locally to ensure consistency:**

```bash
docker build -t ragedunicorn/tflint:test .
```

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

**Why local testing is important:**
- Remote images (Docker Hub, GHCR) may have different labels due to CI/CD overrides
- Ensures you are testing exactly what you built
- Avoids false positives/negatives from version mismatches

**Never pull a remote image for testing** - build locally and test the `:test` tag.

### Running Specific Test Categories

**Linux/macOS:**

```bash
# File structure tests
TFLINT_VERSION=test docker compose -f docker-compose.test.yml up container-test

# Command execution tests
TFLINT_VERSION=test docker compose -f docker-compose.test.yml up container-test-command

# Metadata tests
TFLINT_VERSION=test docker compose -f docker-compose.test.yml up container-test-metadata
```

**Windows (PowerShell):**

```powershell
$env:TFLINT_VERSION="test"; docker compose -f docker-compose.test.yml up container-test
$env:TFLINT_VERSION="test"; docker compose -f docker-compose.test.yml up container-test-command
$env:TFLINT_VERSION="test"; docker compose -f docker-compose.test.yml up container-test-metadata
```

## Troubleshooting Test Failures

### Version-specific output

`tflint --version` output changes with every TFLint release, so the command
tests match a stable prefix (`TFLint version`) rather than an exact version. If
you add stricter version assertions, remember to update them on every Renovate
bump.

### Lint test exit codes

TFLint exits `0` when no issues are found, `2` when it reports issues, and `1`
on an application error. The command-test that expects a finding asserts
`exitCode: 2`. If a future TFLint release changes the default-enabled rules,
update the `.tflint.hcl` written in the test's `setup` step accordingly.

### Metadata Test Failures

**Common causes:**

1. **Testing remote images instead of local builds** - remote labels are
   overridden by CI/CD. Always test your local `:test` build.
2. **Label value mismatches** - the `org.opencontainers.image.version` and
   `created` labels are dynamic and set at build time.
3. **Alpine version drift** - Renovate keeps the `FROM` lines, the
   `org.opencontainers.image.base.name` label, and the matching value in
   `test/tflint_metadata_test.yml` in sync via `customManagers`. Only a manual
   edit that touches one of these without the others can cause drift.

### Permission Errors

If you encounter Docker socket permission errors:

```bash
sudo docker compose -f docker-compose.test.yml run test-all
```

Or ensure your user is in the `docker` group:

```bash
sudo usermod -aG docker "$USER"
# Log out and back in for changes to take effect
```

## CI/CD Integration

These tests run automatically in GitHub Actions:

- **On every push** to `master`
- **On every pull request** to `master`
- **Before releases** (the release workflow runs the full suite first and blocks
  the build/push if it fails)

The test workflow (`.github/workflows/test.yml`):
1. Builds the Docker image
2. Runs all Container Structure Tests
3. Runs a basic functionality smoke test (`--version`, then linting a config
   with a known issue) to catch a broken binary or missing runtime dependency
   that `--version` alone would not surface
4. Blocks releases if anything fails

The `test-all` service returns:
- Exit code 0: all tests passed
- Exit code 1: one or more tests failed

## Test Maintenance

When updating the image:

1. **TFLint version updates**: usually no test changes needed (version-prefix matching)
2. **Alpine version updates**: handled by Renovate, which bumps the `FROM` lines,
   the `base.name` label, and the metadata test value together (no manual change needed)
3. **New functionality**: add corresponding tests
4. **Label changes**: update the metadata test to match

Always run the full test suite before creating a release.
