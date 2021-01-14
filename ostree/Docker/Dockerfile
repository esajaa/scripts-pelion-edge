FROM ubuntu:18.04

RUN apt-get update && apt-get install locales \
    && dpkg-reconfigure locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
		python \
		python3 \
		python3-pip \
		python3-pexpect \
        python3-setuptools \
		python-pip \
		python-virtualenv

RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo \
        coreutils \
        gzip \
        tar \
        ostree

ENV LANG en_US.UTF-8

# Scripts used to build ostree static delta
COPY ostree-delta.py ./
COPY createOSTreeUpgrade.sh ./
COPY Docker/entrypoint.sh /usr/local/bin/entrypoint.sh

# Use the 'exec' form of ENTRYPOINT to ensure that docker run
# invocation arguments are appended to the command line.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
