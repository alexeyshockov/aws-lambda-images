# syntax=docker/dockerfile:1.5

ARG PYTHON_BRANCH="3.11"
ARG PYTHON_VERSION="3.11.7"



FROM public.ecr.aws/amazonlinux/amazonlinux:2023
ARG PYTHON_BRANCH
ARG PYTHON_VERSION
LABEL org.opencontainers.image.authors="Alexey Shokov <alexey@shokov.dev>"
LABEL org.opencontainers.image.source="https://github.com/alexeyshockov/aws-lambda-images"

# It would be great just run "amazon-linux-extras enable python3.11", but no, the only available version is 3.9
RUN yum groupinstall -y "Development Tools" && \
    yum install -y wget \
      openssl-devel bzip2-devel libffi-devel \
      postgresql-devel
RUN wget --no-verbose "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz" && \
    tar -xf "Python-$PYTHON_VERSION.tgz" && \
    cd "Python-$PYTHON_VERSION" && \
    ./configure --enable-optimizations --disable-test-modules && \
    make -j "$(nproc)" && \
    make install
RUN python3 -m ensurepip --upgrade && \
    python3 -m pip install --upgrade pip wheel setuptools
