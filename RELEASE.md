# Release Process

This document describes how to create a new release for the docker-tflint
project.

## Quick Start

```bash
# Tag format: v{tflint_version}-alpine{alpine_version}-{build_number}
git tag -a v0.63.1-alpine3.22.1-1 -m "v0.63.1-alpine3.22.1-1"
git push origin v0.63.1-alpine3.22.1-1
```

This automatically triggers the release process via GitHub Actions.

## Version Tag Format

See [README.md](README.md#versioning) for the complete versioning documentation.

**Format:** `v{tflint_version}-alpine{alpine_version}-{build_number}`

Examples:
- `v0.63.1-alpine3.22.1-1` - Initial release
- `v0.63.1-alpine3.22.1-2` - Rebuild with the same versions
- `v0.63.1-alpine3.22.2-1` - Alpine patch update (build resets to 1)
- `v0.64.0-alpine3.22.1-1` - TFLint update (build resets to 1)

## Release Workflow

When you push a tag, GitHub Actions automatically:

1. **Builds and tests, then pushes Docker images** (`.github/workflows/docker_release.yml`)
   - Runs the full Container Structure Test suite first and fails fast if it breaks
   - Multi-platform: `linux/amd64` and `linux/arm64`
   - Pushes to both GitHub Container Registry and Docker Hub
   - Publishes the full tag (`0.63.1-alpine3.22.1-1`), a bare TFLint version
     tag (`0.63.1`) and `latest`

2. **Creates a GitHub Release** (`.github/workflows/github_release.yml`)
   - Generates a changelog from commit history
   - Adds Docker pull commands
   - Links to the release

## When to Create a Release

Create a new release when:

1. **Renovate updates dependencies** - after merging Renovate PRs for TFLint
   or Alpine updates
2. **Bug fixes** - after fixing issues in the Dockerfile or build process
3. **Security patches** - immediately after security-related updates

### Build Number Guidelines

- **Reset to 1**: when the TFLint or Alpine version changes
- **Increment**: when rebuilding with the same versions (base CVE patch, fixes)

## Post-Release Tasks

### Update Docker Hub Documentation

After creating a release, update the Docker Hub repository description:

1. Go to [Docker Hub](https://hub.docker.com/r/ragedunicorn/tflint)
2. Click "Manage Repository" → "Description"
3. Copy the contents of `DOCKERHUB.md`
4. Update any version numbers in the examples to match the latest release
5. Save the changes

**Note**: `DOCKERHUB.md` is maintained in the repository as the source of truth
for the Docker Hub description.

## Best Practices

### Commit Messages

Use conventional commit format for better changelogs:

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `chore:` Maintenance tasks
- `refactor:` Code refactoring
- `test:` Test additions/changes
- `perf:` Performance improvements

### Pre-release Testing

Before creating a release:

1. Build the image locally with your version changes
2. Run the full test suite (`TFLINT_VERSION=test docker compose -f docker-compose.test.yml run test-all`)
3. Verify `tflint` lints a sample config and reports the expected findings
4. Check that multi-platform builds work (especially arm64)

## Troubleshooting

### Release didn't trigger

- Ensure the tag starts with `v` and follows the format (e.g. `v0.63.1-alpine3.22.1-1`)
- Check the GitHub Actions tab for workflow runs
- Verify you have push permissions

### Docker build failed

- Check the Docker workflow logs
- Ensure the Dockerfile builds locally
- A failure at cosign/checksum verification means the download did not match the
  signed checksums - investigate, do not work around it
- Verify multi-platform compatibility

### Docker Hub Configuration

To enable Docker Hub deployment, add these secrets to the GitHub repository:

1. Go to Settings → Secrets and variables → Actions
2. Add:
   - `DOCKERHUB_USERNAME`: your Docker Hub username
   - `DOCKERHUB_TOKEN`: your Docker Hub access token (not your password)

To create a Docker Hub access token:
1. Log in to Docker Hub
2. Go to Account Settings → Security
3. Click "New Access Token"
4. Give it a descriptive name (e.g. "GitHub Actions")
5. Copy the token and add it as the `DOCKERHUB_TOKEN` secret

## Manual Release (if needed)

If automation fails, create a release manually:

1. Go to the repository's "Releases" page
2. Click "Create a new release"
3. Choose your tag (must follow the format: `v0.63.1-alpine3.22.1-1`)
4. Add release notes
5. Include Docker pull commands:
   ```
   docker pull ghcr.io/ragedunicorn/docker-tflint:0.63.1-alpine3.22.1-1
   docker pull ragedunicorn/tflint:0.63.1-alpine3.22.1-1
   ```
