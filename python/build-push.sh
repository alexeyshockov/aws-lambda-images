#!/usr/bin/env bash

set -e
set -x

#
# Local build script
#
# CI (GH Actions) version: .github/workflows/publish.yml
#

REPOSITORY="ghcr.io/alexeyshockov/aws-lambda-images/python"

function build_version {
  PYTHON_BRANCH="$1"
  export PYTHON_VERSION="$2"
  export DEBIAN_VERSION="${3:-bullseye}"

  # Unfortunately, Docker does not include proper annotations for a multiplatform image with provenance...
  # More about labels and multiplatform builds: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#adding-a-description-to-multi-arch-images
  GITHUB_REPO="https://github.com/alexeyshockov/aws-lambda-images"
  DESCRIPTION="Debian-based Python AWS Lambda runtime"

  docker buildx build --file=debian.dockerfile --target debian-slim \
    --build-arg PYTHON_VERSION \
    --build-arg DEBIAN_VERSION \
    --label org.opencontainers.image.url="$GITHUB_REPO" \
    --label org.opencontainers.image.source="$GITHUB_REPO" \
    --label org.opencontainers.image.description="$DESCRIPTION" \
    --label org.opencontainers.image.version="$(git rev-parse --abbrev-ref HEAD)" \
    --label org.opencontainers.image.created="$(date -u --iso-8601=seconds)" \
    --label org.opencontainers.image.revision="$(git rev-parse HEAD)" \
    --output "type=image,name=target,annotation-index.org.opencontainers.image.source=$GITHUB_REPO,annotation-index.org.opencontainers.image.description=$DESCRIPTION" \
    --tag "${REPOSITORY}:${PYTHON_BRANCH}" \
    --tag "${REPOSITORY}:${PYTHON_BRANCH}-debian-slim" \
    --tag "${REPOSITORY}:${PYTHON_VERSION}-debian-slim" \
    --platform linux/amd64,linux/arm64 \
    --provenance mode=min \
    --push \
    .

  docker buildx build --file=debian.dockerfile --target debian \
    --build-arg PYTHON_VERSION \
    --build-arg DEBIAN_VERSION \
    --label org.opencontainers.image.url="$GITHUB_REPO" \
    --label org.opencontainers.image.source="$GITHUB_REPO" \
    --label org.opencontainers.image.description="$DESCRIPTION" \
    --label org.opencontainers.image.version="$(git rev-parse --abbrev-ref HEAD)" \
    --label org.opencontainers.image.created="$(date -u --iso-8601=seconds)" \
    --label org.opencontainers.image.revision="$(git rev-parse HEAD)" \
    --output "type=image,name=target,annotation-index.org.opencontainers.image.source=$GITHUB_REPO,annotation-index.org.opencontainers.image.description=$DESCRIPTION" \
    --tag "${REPOSITORY}:${PYTHON_BRANCH}-debian" \
    --tag "${REPOSITORY}:${PYTHON_VERSION}-debian" \
    --platform linux/amd64,linux/arm64 \
    --provenance mode=min \
    --push \
    .
}

# TODO Consider bake (https://docs.docker.com/engine/reference/commandline/buildx_bake/) later
build_version 3.10 3.10.10
build_version 3.11 3.11.2
