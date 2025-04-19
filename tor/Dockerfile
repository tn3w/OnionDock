FROM alpine:latest

RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk update

RUN apk add --no-cache \
    python3 py3-pip bash git \
    tor \
    pypy3

RUN python3 -m venv /venv
ENV PATH="/venv/bin:$PATH"
RUN pip install --no-cache-dir stem

RUN pypy3 -m venv /pypy_venv
ENV PYPY_PATH="/pypy_venv/bin"

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
    mkdir -p /usr/local/lib/vanguards && \
    cp -r /tmp/vanguards/* /usr/local/lib/vanguards/ && \
    rm -rf /tmp/vanguards

ENV PATH="/pypy_venv/bin:$PATH"

COPY config/torrc /etc/tor/torrc
COPY config/vanguards.conf /etc/tor/vanguards.conf
COPY start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh

RUN mkdir -p /tmp/vanguards_logs && \
    mkdir -p /var/lib/tor/hidden_service /var/lib/tor/onion_auth /etc/tor/torrc.d && \
    chown -R tor:tor /tmp/vanguards_logs && \
    chown -R tor:tor /var/lib/tor && \
    chown -R tor:tor /etc/tor && \
    chown -R tor:tor /usr/local/lib/vanguards && \
    chmod 700 /var/lib/tor/hidden_service && \
    chmod 700 /var/lib/tor/onion_auth && \
    chmod 755 /etc/tor/torrc.d

USER tor

HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
    CMD torify curl -f http://localhost:80 || exit 1

CMD ["/usr/local/bin/start.sh"]