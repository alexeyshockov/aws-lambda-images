# syntax=docker/dockerfile:1.5

ARG DEBIAN_VERSION=bookworm
ARG PYTHON_VERSION=3.11.7



FROM ghcr.io/alexeyshockov/aws-lambda-images/python:${PYTHON_VERSION}-debian AS debian
ARG PYTHON_DEPS_DIR

# libpq5 is required for psycopg _in runtime_ (in some cases), while
# libpq-dev is required to build (psycopg2, psycopg[c]).
# See:
#  - https://www.psycopg.org/psycopg3/docs/api/pq.html#pq-module-implementations
#  - https://www.psycopg.org/docs/install.html#psycopg-vs-psycopg-binary
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eu && \
    apt-get update -q && \
    apt-get install -q -y --no-install-recommends build-essential \
                                                  ca-certificates wget unzip \
                                                  libpq5 libpq-dev
