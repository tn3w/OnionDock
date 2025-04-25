#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

echo ".d88b.       w             888b.            8    "
echo "8P  Y8 8d8b. w .d8b. 8d8b. 8   8 .d8b. .d8b 8.dP "
echo "8b  d8 8P Y8 8 8' .8 8P Y8 8   8 8' .8 8    88b  "
echo "\`Y88P' 8   8 8 \`Y8P' 8   8 888P' \`Y8P' \`Y8P 8 Yb "

TOR_TRANSPORT_TYPE=${TOR_TRANSPORT_TYPE:-"snowflake"}
TOR_SERVICE_PORTS=${TOR_SERVICE_PORTS:-"80:webapp:80"}
SECURITY_LEVEL=${SECURITY_LEVEL:-high}
VANGUARDS_LOCATION="/pypy_venv/bin/vanguards"
PT_CONFIG_PATH="/etc/tor/pt_config.json"
PT_PATH="/usr/local/bin/pluggable_transports/"

echo "[+] Starting OnionDock: $SECURITY_LEVEL using $TOR_TRANSPORT_TYPE transport with ports: $TOR_SERVICE_PORTS"

cp /etc/tor/torrc /tmp/torrc

PORTS_CONFIG=""
for port_mapping in ${TOR_SERVICE_PORTS//,/ }; do
    IFS=':' read -r tor_port service_name service_port <<< "$port_mapping"
    PORTS_CONFIG="${PORTS_CONFIG}HiddenServicePort $tor_port $service_name:$service_port\n"
done

sed -i "s/# PORTS/$PORTS_CONFIG/g" /tmp/torrc

if [ -f "/etc/tor/vanguards.conf" ]; then
    cp /etc/tor/vanguards.conf /tmp/vanguards.conf
    echo "[+] Using vanguards configuration from /etc/tor/vanguards.conf"
fi

if [ "$TOR_TRANSPORT_TYPE" != "none" ] && [ -f "$PT_CONFIG_PATH" ]; then
    echo "[+] Setting up $TOR_TRANSPORT_TYPE transport..."
    
    case "$TOR_TRANSPORT_TYPE" in
        "obfs4")
            PLUGIN_NAME="lyrebird"
            ;;
        "snowflake"|"conjure")
            PLUGIN_NAME="$TOR_TRANSPORT_TYPE"
            ;;
        *)
            PLUGIN_NAME=""
            ;;
    esac

    if [ -n "$PLUGIN_NAME" ]; then
        TRANSPORT_PLUGIN=$(jq -r ".pluggableTransports.$PLUGIN_NAME // empty" "$PT_CONFIG_PATH" | sed "s#\${pt_path}#$PT_PATH#g")
        BRIDGES=$(jq -r ".bridges.$TOR_TRANSPORT_TYPE[]" "$PT_CONFIG_PATH" 2>/dev/null \
            | shuf -n 2 \
            | sed 's/^/Bridge /' \
            | sed 's/iat-mode=\([01]\)/iat-mode=2/g')
        
        echo -e "\n# Pluggable Transport Configuration\nUseBridges 1\n$TRANSPORT_PLUGIN" >> /tmp/torrc

        if [ -n "$BRIDGES" ]; then
            echo -e "$BRIDGES" >> /tmp/torrc
            echo "[+] Added $(echo "$BRIDGES" | wc -l) random bridges for $TOR_TRANSPORT_TYPE"
        else
            echo "[!] No bridges found for $TOR_TRANSPORT_TYPE"
        fi
    else
        echo "[!] No transport plugin configuration found for $TOR_TRANSPORT_TYPE"
    fi
fi

echo "[+] Starting Tor hidden service..."
TOR_LOG="/tmp/tor.log"

mkfifo /tmp/tor_fifo
tor -f /tmp/torrc > /tmp/tor_fifo 2>&1 &
TOR_PID=$!
cat /tmp/tor_fifo | tee -a "$TOR_LOG" &
CAT_PID=$!

mkdir -p /var/lib/tor
chmod 700 /var/lib/tor

while true; do
    if ! kill -0 $TOR_PID 2>/dev/null; then
        echo "[!] Tor process died during bootstrap"
        exit 1
    fi

    if grep -q "Bootstrapped 100" "$TOR_LOG"; then
        break
    fi

    sleep 1
done

kill $CAT_PID 2>/dev/null || true
rm -f /tmp/tor_fifo

if [ -f /var/lib/tor/hidden_service/hostname ]; then
    ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname)
    echo "[+] Tor hidden service: $ONION_ADDRESS"
else
    echo "[!] Hidden service hostname file not found after bootstrap"
fi

VANGUARDS_STATE_DIR="/var/lib/tor/vanguards_state"
mkdir -p $VANGUARDS_STATE_DIR
chmod 700 $VANGUARDS_STATE_DIR

mkdir -p /tmp/vanguards_logs

run_vanguards() {
    if [ -f "/tmp/vanguards_$1.pid" ]; then
        return
    fi

    (
        cd $VANGUARDS_STATE_DIR &&
        $VANGUARDS_LOCATION \
            --state "$VANGUARDS_STATE_DIR/$1.state" \
            --config "/tmp/vanguards.conf" \
            --control_port 9051 \
            "${@:2}" &
        echo $! > "/tmp/vanguards_$1.pid"
    )
}

case "$SECURITY_LEVEL" in
    high)
        run_vanguards "guards" --disable_bandguards --disable_rendguard &
        run_vanguards "band" --disable_vanguards --disable_rendguard &
        run_vanguards "rend" --disable_vanguards --disable_bandguards &
        ;;
    medium)
        run_vanguards "guards" --disable_bandguards --disable_rendguard --disable_cbtverify &
        run_vanguards "band" --disable_vanguards --disable_rendguard --disable_cbtverify &
        ;;
    *)
        run_vanguards "guards" --disable_bandguards --disable_rendguard --disable_cbtverify &
        ;;
esac

cleanup() {
    echo "[+] Shutting down Tor and vanguards..."
    find /tmp -name "vanguards_*.pid" -type f -exec sh -c 'kill $(cat {}) 2>/dev/null; rm {}' \; || true

    [ -n "$TOR_PID" ] && kill -0 $TOR_PID 2>/dev/null && { kill $TOR_PID; wait $TOR_PID || true; }

    exit 0
}

trap cleanup INT TERM
wait $TOR_PID
cleanup
