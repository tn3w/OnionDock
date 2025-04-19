FROM alpine:latest

RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk update

RUN apk add --no-cache \
    python3 py3-pip bash git \
    tor \
    pypy3 \
    shadow

RUN python3 -m venv /venv
ENV PATH="/venv/bin:$PATH"
RUN pip install --no-cache-dir stem

RUN pypy3 -m venv /pypy_venv
ENV PYPY_PATH="/pypy_venv/bin"

RUN mkdir -p /usr/local/lib/vanguards

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
COPY entrypoint.sh /usr/local/bin/

RUN mkdir -p /tmp/vanguards_logs

RUN mkdir -p /var/lib/tor/hidden_service /etc/tor/torrc.d /var/lib/hidden_service && \
    chown -R tor:tor /var/lib/tor /etc/tor /usr/local/bin/start.sh /usr/local/lib/vanguards /tmp/vanguards_logs /var/lib/hidden_service && \
    chmod -R 700 /var/lib/tor /var/lib/hidden_service && \
    chmod 755 /usr/local/bin/start.sh /usr/local/bin/entrypoint.sh

HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
    CMD torify curl -f http://localhost:80 || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]