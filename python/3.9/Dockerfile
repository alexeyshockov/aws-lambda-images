ARG PYTHON_VERSION="3.9.13"



FROM amazonlinux:2
ARG PYTHON_VERSION
LABEL org.opencontainers.image.authors="Alexey Shokov <alexey@shokov.dev>"
LABEL org.opencontainers.image.source="https://github.com/alexeyshockov/aws-lambda-base"

RUN yum groupinstall -y "Development Tools"

# It would be great just run "amazon-linux-extras enable python3.9", but no, the only available version is 3.8

RUN yum install -y openssl-devel bzip2-devel libffi-devel wget \
    postgresql-devel
RUN wget https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz \
    && tar -xf Python-$PYTHON_VERSION.tgz \
    && cd Python-$PYTHON_VERSION \
    && ./configure --enable-optimizations \
    && make \
    && make altinstall
RUN python3.9 -m ensurepip --upgrade \
    && python3.9 -m pip install --upgrade pip setuptools wheel
