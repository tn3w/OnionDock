FROM alpine:latest

RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk update

RUN apk add --no-cache \
    python3 py3-pip bash git \
    build-base automake autoconf libtool pkgconfig libevent-dev openssl-dev zlib-dev xz-dev \
    pypy3

RUN python3 -m venv /venv
ENV PATH="/venv/bin:$PATH"
RUN pip install --no-cache-dir stem

RUN pypy3 -m venv /pypy_venv
ENV PYPY_PATH="/pypy_venv/bin"

RUN mkdir -p /usr/src/tor && \
    cd /usr/src/tor && \
    TOR_VERSION=$(wget -q -O- https://dist.torproject.org/ | grep -o 'tor-[0-9]\.[0-9]\.[0-9]\.[0-9]*\.tar\.gz' | sort -V | tail -1 | sed 's/tor-\(.*\)\.tar\.gz/\1/') && \
    echo "Building Tor version: $TOR_VERSION" && \
    wget "https://dist.torproject.org/tor-${TOR_VERSION}.tar.gz" && \
    tar -xzf "tor-${TOR_VERSION}.tar.gz" && \
    cd "tor-${TOR_VERSION}" && \
    ./configure --disable-asciidoc && \
    make && \
    make install && \
    cd / && \
    rm -rf /usr/src/tor && \
    mkdir -p /var/lib/tor/hidden_service /etc/tor/torrc.d \
    /usr/local/lib/vanguards /var/lib/tor/onion_auth

RUN git clone https://github.com/mikeperry-tor/vanguards.git /tmp/vanguards && \
    cd /tmp/vanguards && \
    # Fix Python 3.12 compatibility issues
    sed -i 's/from configparser import SafeConfigParser, Error/from configparser import ConfigParser as SafeConfigParser, Error/' \
        /tmp/vanguards/src/vanguards/config.py && \
    sed -i 's/from ConfigParser import SafeConfigParser, Error/from configparser import ConfigParser as SafeConfigParser, Error/' \
        /tmp/vanguards/src/vanguards/config.py && \
    # Fix readfp issue (line 224)
    sed -i 's/config.readfp(open(config_file, "r"))/config.read_file(open(config_file, "r"))/' \
        /tmp/vanguards/src/vanguards/config.py && \
    $PYPY_PATH/pip install . && \
    cp -r /tmp/vanguards/* /usr/local/lib/vanguards/ && \
    rm -rf /tmp/vanguards

ENV PATH="/pypy_venv/bin:$PATH"

COPY config/torrc /etc/tor/torrc
COPY config/vanguards.conf /etc/tor/vanguards.conf

COPY start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh

RUN adduser -D -h /var/lib/tor tor && \
    chown -R tor:tor /var/lib/tor /etc/tor && \
    chmod -R 700 /var/lib/tor

USER tor

HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
    CMD torify curl -f http://localhost:80 || exit 1

CMD ["/usr/local/bin/start.sh"]