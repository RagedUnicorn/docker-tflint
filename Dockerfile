############################################
# Download + verify stage
############################################
FROM alpine:3.24.1 AS build

# renovate: datasource=github-releases depName=terraform-linters/tflint
ARG TFLINT_VERSION=0.63.1
# Provided automatically by buildx (linux/amd64 -> amd64, linux/arm64 -> arm64)
ARG TARGETARCH

# Build stage labels
LABEL org.opencontainers.image.authors="Michael Wiesendanger <michael.wiesendanger@gmail.com>" \
      org.opencontainers.image.source="https://github.com/RagedUnicorn/docker-tflint" \
      org.opencontainers.image.licenses="MIT"

# Tools needed to download and cryptographically verify the release:
#   curl   - download the release assets
#   unzip  - extract the single tflint binary
#   cosign - verify the keyless signature on checksums.txt (Alpine community repo)
RUN apk add --no-cache --update curl unzip cosign

WORKDIR /tmp/build

# Download the TFLint release, then verify it end to end:
#   1. cosign-verify checksums.txt against its keyless signature + certificate,
#      proving it was produced by TFLint's GitHub Actions release workflow
#   2. verify the zip's checksum against the now-trusted checksums.txt
#
# Note: TFLint release assets are NOT versioned in the filename
# (tflint_linux_amd64.zip); the version only appears in the download path.
RUN set -eux; \
    base="https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}"; \
    file="tflint_linux_${TARGETARCH}.zip"; \
    curl -fsSLO "${base}/${file}"; \
    curl -fsSLO "${base}/checksums.txt"; \
    curl -fsSLO "${base}/checksums.txt.keyless.sig"; \
    curl -fsSLO "${base}/checksums.txt.pem"; \
    # Keyless verification: the certificate identity must be TFLint's release
    # workflow and the OIDC issuer must be GitHub Actions' token service.
    cosign verify-blob \
      --certificate checksums.txt.pem \
      --signature checksums.txt.keyless.sig \
      --certificate-identity-regexp '^https://github.com/terraform-linters/tflint' \
      --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
      checksums.txt; \
    # Reduce checksums.txt to just our file's line and assert it is non-empty,
    # otherwise an empty checksum list would make `sha256sum -c` pass silently.
    grep "  ${file}\$" checksums.txt > "${file}.sha256"; \
    [ -s "${file}.sha256" ]; \
    sha256sum -c "${file}.sha256"; \
    unzip "${file}" tflint -d /out; \
    /out/tflint --version

############################################
# Runtime stage
############################################
FROM alpine:3.24.1

ARG BUILD_DATE
ARG VERSION

# OCI-compliant labels
LABEL org.opencontainers.image.title="TFLint on Alpine Linux" \
      org.opencontainers.image.description="Lightweight TFLint Docker image built on Alpine Linux" \
      org.opencontainers.image.vendor="ragedunicorn" \
      org.opencontainers.image.authors="Michael Wiesendanger <michael.wiesendanger@gmail.com>" \
      org.opencontainers.image.source="https://github.com/RagedUnicorn/docker-tflint" \
      org.opencontainers.image.documentation="https://github.com/RagedUnicorn/docker-tflint/blob/master/README.md" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="docker.io/library/alpine:3.24.1"

# Runtime dependencies:
#   ca-certificates - HTTPS for `tflint --init` plugin downloads from the registry
RUN apk add --no-cache --update ca-certificates

# Non-root user with a real home so `tflint --init` can write its plugin cache
# under $HOME/.tflint.d/plugins. Pre-create the directory so a volume mounted
# there inherits tflint's ownership instead of being created root-owned and
# unwritable.
RUN adduser -D -h /home/tflint -s /sbin/nologin tflint && \
    mkdir -p /home/tflint/.tflint.d/plugins && \
    chown -R tflint:tflint /home/tflint

COPY --from=build /out/tflint /usr/local/bin/tflint

WORKDIR /workspace
RUN chown -R tflint:tflint /workspace

USER tflint

# TFLint is the entrypoint; pass any subcommand/flags as `docker run` args
ENTRYPOINT ["tflint"]

# Default to showing help if no arguments are provided
CMD ["--help"]
