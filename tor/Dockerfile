# syntax=docker/dockerfile:1
FROM alpine:latest AS builder

RUN apk add --no-cache curl git python3 binutils gnupg

WORKDIR /tmp/build

ARG TOR_GPG_FPR=EF6E286DDA85EA2A4BA7DE684E2C6E8793298290

RUN set -eux; \
    export GNUPGHOME=$(mktemp -d); \
    ok=0; \
    for ks in keyserver.ubuntu.com keys.openpgp.org pgp.mit.edu; do \
        timeout 30 gpg --batch --keyserver "hkps://$ks" --recv-keys "$TOR_GPG_FPR" \
            && ok=1 && break || true; \
    done; \
    [ "$ok" = 1 ] || { echo "all keyservers failed"; exit 1; }; \
    gpg --batch --list-keys "$TOR_GPG_FPR" >/dev/null; \
    V=$(curl -fsSL https://dist.torproject.org/torbrowser/ \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+/' | tr -d '/' | sort -V | tail -1); \
    [ -n "$V" ] || { echo "no Tor version found"; exit 1; }; \
    BASE="https://dist.torproject.org/torbrowser/${V}/tor-expert-bundle-linux-x86_64-${V}.tar.gz"; \
    curl -fsSL "$BASE"     -o bundle.tar.gz; \
    curl -fsSL "$BASE.asc" -o bundle.tar.gz.asc; \
    gpg --batch --verify bundle.tar.gz.asc bundle.tar.gz; \
    tar -xzf bundle.tar.gz tor/pluggable_transports; \
    rm -rf "$GNUPGHOME" bundle.tar.gz bundle.tar.gz.asc; \
    find tor/pluggable_transports -type f -executable \
        -exec strip --strip-unneeded {} + 2>/dev/null || true

ARG VANGUARDS_SHA=c3961ac40ca0bce67f79bc76021f5817730033b8

RUN python3 -m venv --copies /venv && \
    /venv/bin/pip install --no-cache-dir --no-deps stem && \
    git init /tmp/vg && \
    git -C /tmp/vg remote add origin https://github.com/mikeperry-tor/vanguards.git && \
    git -C /tmp/vg fetch --depth=1 origin "$VANGUARDS_SHA" && \
    git -C /tmp/vg checkout --detach FETCH_HEAD && \
    [ "$(git -C /tmp/vg rev-parse HEAD)" = "$VANGUARDS_SHA" ] && \
    sed -i \
        -e 's/from configparser import SafeConfigParser, Error/from configparser import ConfigParser as SafeConfigParser, Error/' \
        -e 's/from ConfigParser import SafeConfigParser, Error/from configparser import ConfigParser as SafeConfigParser, Error/' \
        -e 's/config\.readfp(/config.read_file(/' \
        /tmp/vg/src/vanguards/config.py && \
    /venv/bin/pip install --no-cache-dir --no-deps /tmp/vg && \
    /venv/bin/python -m compileall -q /venv && \
    /venv/bin/pip uninstall -y pip setuptools && \
    rm -rf /venv/bin/pip* /venv/bin/easy_install* /root/.cache


FROM alpine:latest

LABEL org.opencontainers.image.title="OnionDock" \
      org.opencontainers.image.description="Hardened Tor v3 hidden-service container with Vanguards." \
      org.opencontainers.image.source="https://github.com/tn3w/OnionDock" \
      org.opencontainers.image.licenses="Apache-2.0"

RUN apk add --no-cache tini tor python3 && \
    install -d -o tor -g tor -m 0700 /var/lib/tor /var/lib/tor/hidden_service /run/tor

COPY --from=builder /venv /venv
COPY --from=builder /tmp/build/tor/pluggable_transports /usr/local/bin/pluggable_transports
COPY --chmod=0444 config/torrc /etc/tor/torrc.tmpl
COPY --chmod=0555 oniondock.py /usr/local/bin/oniondock

RUN set -eux; \
    mv /usr/local/bin/pluggable_transports/pt_config.json /etc/tor/pt_config.json; \
    chmod 0444 /etc/tor/pt_config.json; \
    chmod 0555 /usr/local/bin/pluggable_transports/*; \
    find / -xdev -type f \( -perm -4000 -o -perm -2000 \) -exec chmod ug-s {} + 2>/dev/null || true; \
    rm -rf /var/cache/apk/* /tmp/*

ENV PATH="/venv/bin:/usr/local/bin/pluggable_transports:/usr/local/bin:/usr/bin:/bin" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

STOPSIGNAL SIGTERM

HEALTHCHECK --interval=60s --timeout=5s --start-period=45s \
    CMD python3 -c "import socket,sys; s=socket.socket(); s.settimeout(3); \
sys.exit(0 if s.connect_ex(('127.0.0.1',9051))==0 else 1)"

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/oniondock"]
