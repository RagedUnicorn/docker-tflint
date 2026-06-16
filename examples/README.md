# TFLint Docker Examples

This directory contains a minimal Terraform configuration and a Docker Compose
file that demonstrate linting with the image.

## Files

- `main.tf` - a small, provider-less configuration. It intentionally declares an
  unused variable so TFLint reports a finding without any network access.
- `.tflint.hcl` - enables `terraform_unused_declarations` from TFLint's bundled
  "terraform" ruleset (no `tflint --init` needed).
- `docker-compose.yml` - a workflow example with a read-only workspace, host
  UID/GID matching and a persistent plugin cache for `tflint --init`.

## Running the Example

### Using Docker directly

```bash
# From the repository root. The workspace can be read-only: TFLint never
# modifies your configuration.
docker run --rm -v "$(pwd)/examples":/workspace:ro ragedunicorn/tflint:latest --chdir=/workspace
```

### Using Docker Compose

```bash
docker compose -f examples/docker-compose.yml run --rm tflint
```

### Expected Output

TFLint reports the unused variable and exits with a non-zero status (`2`):

```
1 issue(s) found:

Warning: variable "unused" is declared but not used (terraform_unused_declarations)

  on main.tf line 21:
  21: variable "unused" {
```

A configuration with no findings exits `0` and prints nothing.

## Using External Rulesets (AWS, Google, Azure, …)

The bundled "terraform" ruleset works offline. Cloud rulesets are external
plugins that must be installed first:

1. Add a `plugin` block with a `source` and `version` to `.tflint.hcl`.
2. Run `tflint --init` to download the plugin. This needs:
   - **Network access** to GitHub releases (set `GITHUB_TOKEN` to avoid rate limits).
   - **A writable plugin directory** (`~/.tflint.d/plugins` by default, overridable
     with `TFLINT_PLUGIN_DIR`). The compose example mounts a named volume there so
     plugins persist across runs.

```bash
docker compose -f examples/docker-compose.yml run --rm tflint --init
docker compose -f examples/docker-compose.yml run --rm tflint
```

## Notes for Real Configurations

- **Read-only workspace is fine.** TFLint only reads your `.tf`/`.tflint.hcl`
  files; mount `/workspace` read-only if you like.
- **File ownership.** The image runs as the non-root `tflint` user. Match your
  host user with `--user "$(id -u):$(id -g)"` (docker run) or the `user:` field
  (compose) so any written files stay owned by you.
- **Plugin cache.** `tflint --init` downloads plugins into `~/.tflint.d/plugins`.
  Mount a volume there so they survive across runs.
- **Exit codes.** `0` = no issues, `2` = issues found, `1` = an application error.
