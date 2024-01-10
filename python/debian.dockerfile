# syntax=docker/dockerfile:1.5

ARG DEBIAN_VERSION=bookworm
ARG PYTHON_VERSION=3.11.4
ARG LAMBDA_LANG_DIR=/var/lang
ARG LAMBDA_RUNTIME_DIR=/var/runtime
ARG LAMBDA_TASK_ROOT=/var/task



FROM debian:$DEBIAN_VERSION AS aws-lambda-rie
ARG TARGETARCH
ENV DEBIAN_FRONTEND="noninteractive"
# See https://hub.docker.com/r/docker/dockerfile for caching details
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eu && \
    apt-get -q update && apt-get install -y ca-certificates wget && \
    LAMBDA_ARCH="$TARGETARCH" && if [ "$TARGETARCH" = "amd64" ]; then LAMBDA_ARCH="x86_64"; fi && \
    wget --no-verbose https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie-$LAMBDA_ARCH \
         -O /usr/local/bin/aws-lambda-rie && \
    chmod +x /usr/local/bin/aws-lambda-rie



FROM debian:$DEBIAN_VERSION AS build
ARG TARGETARCH
ARG PYTHON_VERSION
ARG LAMBDA_LANG_DIR
ENV DEBIAN_FRONTEND="noninteractive"
# See https://hub.docker.com/r/docker/dockerfile for caching details
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eu && \
    apt-get -q update && \
    apt-get install -y ca-certificates wget "linux-headers-$TARGETARCH" build-essential pkg-config \
                       zlib1g-dev libbz2-dev liblzma-dev  \
                       libssl-dev \
                       libsqlite3-dev \
                       libffi-dev \
                       uuid-dev
RUN set -eu && \
    wget --no-verbose https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar xf Python-${PYTHON_VERSION}.tgz
# See config options: https://docs.python.org/3/using/configure.html
# See also https://stackoverflow.com/a/66479704/322079 for the custom OpenSSL options
# And https://github.com/docker-library/python/blob/master/3.11/bullseye/Dockerfile for the reference configuration
RUN set -eu && \
    cd Python-${PYTHON_VERSION} && \
    ./configure --prefix="$LAMBDA_LANG_DIR" \
		        --enable-option-checking=fatal \
                --enable-shared --without-static-libpython \
                --without-readline \
                --enable-optimizations --with-lto=full \
                --disable-test-modules && \
    make -j "$(nproc)" && \
    make install
# Make it work (AWS official images use LD_LIBRARY_PATH, but it's uglier IMO)
# (Can be also done with LDFLAGS="-Wl,-rpath ...", see https://stackoverflow.com/a/56088070/322079)
RUN set -eu && \
    echo "$LAMBDA_LANG_DIR/lib" > /etc/ld.so.conf.d/aws-lambda-runtime.conf && \
    ldconfig
# Cleanup build artifacts, see:
# https://github.com/docker-library/python/blob/e664abbb9af1ee6aae5778d70a5df79d86d9ec57/3.11/bullseye/Dockerfile#L80-L84
RUN set -eu && \
    find "$LAMBDA_LANG_DIR" -depth \
      \( \
        \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
        -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
      \) -exec rm -rf '{}' + ;
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    set -eu && \
    "$LAMBDA_LANG_DIR/bin/python3" -m pip install --quiet --upgrade pip setuptools wheel
# Determine runtime dependencies (see https://wiki.debian.org/apt-file)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eu && \
    apt-get install -y apt-file && apt-file update && \
    find "$LAMBDA_LANG_DIR" -type f -executable \
      | xargs -r ldd 2>/dev/null \
      | awk '/=>/ { print $(NF-1) }' \
      | apt-file search --from-file - \
      | cut -d: -f1 \
      | sort -u | uniq > "$LAMBDA_LANG_DIR/.runtime_deps"



FROM debian:$DEBIAN_VERSION AS debian
ARG PYTHON_VERSION
ARG LAMBDA_LANG_DIR
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
    PATH="$LAMBDA_LANG_DIR/bin:$PATH" \
    DEBIAN_FRONTEND=noninteractive

COPY --from=build          $LAMBDA_LANG_DIR                $LAMBDA_LANG_DIR
COPY --from=aws-lambda-rie /usr/local/bin/aws-lambda-rie /usr/local/bin/aws-lambda-rie

# See https://hub.docker.com/r/docker/dockerfile for caching details
# (assuming that users of this image will also use BuildKit cache for APT)
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eu && \
    apt-get -q update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata $(cat "$LAMBDA_LANG_DIR/.runtime_deps") && \
    echo "$LAMBDA_LANG_DIR/lib" > /etc/ld.so.conf.d/aws-lambda-runtime.conf && \
    ldconfig && \
    python3 -m pip install --quiet --target $LAMBDA_RUNTIME_DIR awslambdaric

COPY lambda-entrypoint.sh /
COPY bootstrap            $LAMBDA_RUNTIME_DIR
COPY bootstrap.py         $LAMBDA_RUNTIME_DIR

WORKDIR $LAMBDA_TASK_ROOT
EXPOSE 8080
ENTRYPOINT [ "/lambda-entrypoint.sh" ]



FROM debian:${DEBIAN_VERSION}-slim AS debian-slim
ARG PYTHON_VERSION
ARG LAMBDA_LANG_DIR
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
    PATH="$LAMBDA_LANG_DIR/bin:$PATH" \
    DEBIAN_FRONTEND=noninteractive

COPY --from=build          $LAMBDA_LANG_DIR                $LAMBDA_LANG_DIR
COPY --from=aws-lambda-rie /usr/local/bin/aws-lambda-rie /usr/local/bin/aws-lambda-rie

# See https://hub.docker.com/r/docker/dockerfile for caching details
# (assuming that users of this image will also use BuildKit cache for APT)
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eu && \
    apt-get -q update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata $(cat "$LAMBDA_LANG_DIR/.runtime_deps") && \
    echo "$LAMBDA_LANG_DIR/lib" > /etc/ld.so.conf.d/aws-lambda-runtime.conf && \
    ldconfig && \
    python3 -m pip install --quiet --target "$LAMBDA_RUNTIME_DIR" awslambdaric

COPY lambda-entrypoint.sh /
COPY bootstrap            $LAMBDA_RUNTIME_DIR
COPY bootstrap.py         $LAMBDA_RUNTIME_DIR

WORKDIR $LAMBDA_TASK_ROOT
EXPOSE 8080
ENTRYPOINT [ "/lambda-entrypoint.sh" ]
