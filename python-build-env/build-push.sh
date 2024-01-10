#!/usr/bin/env bash

set -e
set -x

#
# Local build script
#
# CI (GH Actions) version: .github/workflows/publish.yml
#
GITHUB_REPO="https://github.com/alexeyshockov/aws-lambda-images"
REPOSITORY="ghcr.io/alexeyshockov/aws-lambda-images/python-build-env"

function build_version {
  local python_branch="$1"
  local python_version="$2"

  # Unfortunately, Docker does not include proper annotations for a multiplatform image with provenance...
  # More about labels and multiplatform builds: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#adding-a-description-to-multi-arch-images
  local description="Python AWS Lambda runtime build environment"

#    --platform linux/amd64,linux/arm64 \
  caffeinate docker buildx build --file amazonlinux.dockerfile \
    --build-arg PYTHON_BRANCH="$python_branch" \
    --build-arg PYTHON_VERSION="$python_version" \
    --label org.opencontainers.image.url="$GITHUB_REPO" \
    --label org.opencontainers.image.source="$GITHUB_REPO" \
    --label org.opencontainers.image.description="$description" \
    --label org.opencontainers.image.version="$(git rev-parse --abbrev-ref HEAD)" \
    --label org.opencontainers.image.created="$(date -u --iso-8601=seconds)" \
    --label org.opencontainers.image.revision="$(git rev-parse HEAD)" \
    --output "type=image,name=target,annotation-index.org.opencontainers.image.source=$GITHUB_REPO,annotation-index.org.opencontainers.image.description=$description" \
    --tag "${REPOSITORY}:${python_branch}" \
    --tag "${REPOSITORY}:${python_version}" \
    --platform linux/amd64,linux/arm64 \
    --provenance mode=min \
    --push \
    .
}

function build_debian_version {
  local python_branch="$1"
  local python_version="$2"

  # Unfortunately, Docker does not include proper annotations for a multiplatform image with provenance...
  # More about labels and multiplatform builds: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#adding-a-description-to-multi-arch-images
  local description="Python AWS Lambda runtime build environment"

  caffeinate docker buildx build --file debian.dockerfile \
    --build-arg PYTHON_VERSION="$python_version" \
    --label org.opencontainers.image.url="$GITHUB_REPO" \
    --label org.opencontainers.image.source="$GITHUB_REPO" \
    --label org.opencontainers.image.description="$description" \
    --label org.opencontainers.image.version="$(git rev-parse --abbrev-ref HEAD)" \
    --label org.opencontainers.image.created="$(date -u --iso-8601=seconds)" \
    --label org.opencontainers.image.revision="$(git rev-parse HEAD)" \
    --output "type=image,name=target,annotation-index.org.opencontainers.image.source=$GITHUB_REPO,annotation-index.org.opencontainers.image.description=$description" \
    --tag "${REPOSITORY}:${python_branch}" \
    --tag "${REPOSITORY}:${python_version}" \
    --platform linux/arm64 \
    --provenance mode=min \
    --push \
    .
}

# TODO Consider bake (https://docs.docker.com/engine/reference/commandline/buildx_bake/) later

# AWS has released base images for Python 3.11 and 3.12 lately...
# See https://aws.amazon.com/blogs/compute/python-3-12-runtime-now-available-in-aws-lambda/
build_version 3.10 3.10.13
build_version 3.11 3.11.7
build_version 3.12 3.12.1

#build_debian_version 3.11 3.11.4
