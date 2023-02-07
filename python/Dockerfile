# syntax=docker/dockerfile:1.4

ARG PYTHON_VERSION="3.11.1"
ARG PYTHON_PREFIX=/var/lang
ARG LAMBDA_RUNTIME_DIR=/var/runtime
ARG LAMBDA_TASK_ROOT=/var/task



FROM debian:bullseye AS aws-lambda-rie
ARG TARGETARCH
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    set -eu && \
    apt-get -q update && apt-get install -y ca-certificates wget && \
    LAMBDA_ARCH=$TARGETARCH && if [ "$TARGETARCH" = "amd64" ]; then LAMBDA_ARCH="x86_64"; fi && \
    wget --no-verbose https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie-$LAMBDA_ARCH \
         -O /usr/local/bin/aws-lambda-rie && \
    chmod +x /usr/local/bin/aws-lambda-rie



FROM debian:bullseye AS build
ARG PYTHON_VERSION
ARG PYTHON_PREFIX
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    set -eu && \
    apt-get -q update && \
    apt-get install -y --no-install-recommends ca-certificates build-essential pkg-config wget \
                                               zlib1g-dev libbz2-dev liblzma-dev libssl-dev libsqlite3-dev libffi-dev uuid-dev
RUN set -eu && \
    wget --no-verbose https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar xf Python-${PYTHON_VERSION}.tgz
RUN set -eu && \
    cd Python-${PYTHON_VERSION} && \
    ./configure --prefix=$PYTHON_PREFIX --enable-optimizations \
                                        --with-lto=full \
                                        --with-computed-gotos \
                                        --enable-loadable-sqlite-extensions && \
    make -j "$(nproc)" && \
    make install
# Cleanup build artifacts
RUN set -eu && \
    rm -rf $PYTHON_PREFIX/lib/pkgconfig && \
    rm -rf $PYTHON_PREFIX/lib/python*/config-* && \
    rm -rf $PYTHON_PREFIX/lib/python*/test
RUN set -eu && \
    $PYTHON_PREFIX/bin/python3 -m pip install --quiet --upgrade pip setuptools wheel



FROM debian:bullseye AS debian
ARG PYTHON_VERSION
ARG PYTHON_PREFIX
ARG LAMBDA_RUNTIME_DIR
ARG LAMBDA_TASK_ROOT

LABEL maintainer="Alexey Shokov <alexey@shokov.dev>"
LABEL org.opencontainers.image.authors="Alexey Shokov <alexey@shokov.dev>"
LABEL org.opencontainers.image.title="AWS Lambda Python $PYTHON_VERSION"
LABEL org.opencontainers.image.licenses="MIT"

# See https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars.html#configuration-envvars-runtime
ENV \
    LAMBDA_RUNTIME_DIR=$LAMBDA_RUNTIME_DIR \
    LAMBDA_TASK_ROOT=$LAMBDA_TASK_ROOT \
    PIP_ROOT_USER_ACTION=ignore \
    PATH="$PATH:$PYTHON_PREFIX/bin" \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$PYTHON_PREFIX/lib" \
    DEBIAN_FRONTEND=noninteractive

COPY --from=build          $PYTHON_PREFIX                $PYTHON_PREFIX
COPY --from=aws-lambda-rie /usr/local/bin/aws-lambda-rie /usr/local/bin/aws-lambda-rie

RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    set -eu && \
    apt-get -q update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata \
                                               zlib1g libbz2-1.0 liblzma5 libssl1.1 libsqlite3-0 libffi7 libuuid1 && \
    python3 -m pip install --quiet --target $LAMBDA_RUNTIME_DIR awslambdaric

COPY lambda-entrypoint.sh /
COPY bootstrap            $LAMBDA_RUNTIME_DIR
COPY bootstrap.py         $LAMBDA_RUNTIME_DIR

WORKDIR $LAMBDA_TASK_ROOT
EXPOSE 8080
ENTRYPOINT [ "/lambda-entrypoint.sh" ]



FROM debian:bullseye-slim AS debian-slim
ARG PYTHON_VERSION
ARG PYTHON_PREFIX
ARG LAMBDA_RUNTIME_DIR
ARG LAMBDA_TASK_ROOT

LABEL maintainer="Alexey Shokov <alexey@shokov.dev>"
LABEL org.opencontainers.image.authors="Alexey Shokov <alexey@shokov.dev>"
LABEL org.opencontainers.image.title="AWS Lambda Python $PYTHON_VERSION"
LABEL org.opencontainers.image.licenses="MIT"

# See https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars.html#configuration-envvars-runtime
ENV \
    LAMBDA_RUNTIME_DIR=$LAMBDA_RUNTIME_DIR \
    LAMBDA_TASK_ROOT=$LAMBDA_TASK_ROOT \
    PIP_ROOT_USER_ACTION=ignore \
    PATH="$PATH:$PYTHON_PREFIX/bin" \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$PYTHON_PREFIX/lib" \
    DEBIAN_FRONTEND=noninteractive

COPY --from=build          $PYTHON_PREFIX                $PYTHON_PREFIX
COPY --from=aws-lambda-rie /usr/local/bin/aws-lambda-rie /usr/local/bin/aws-lambda-rie

RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    set -eu && \
    apt-get -q update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata \
                    zlib1g libbz2-1.0 liblzma5 libssl1.1 libsqlite3-0 libffi7 libuuid1 && \
    python3 -m pip install --quiet --target $LAMBDA_RUNTIME_DIR awslambdaric

COPY lambda-entrypoint.sh /
COPY bootstrap            $LAMBDA_RUNTIME_DIR
COPY bootstrap.py         $LAMBDA_RUNTIME_DIR

WORKDIR $LAMBDA_TASK_ROOT
EXPOSE 8080
ENTRYPOINT [ "/lambda-entrypoint.sh" ]
