#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

TOR_THREADS=${TOR_THREADS:-$(nproc)}
HIDDEN_SERVICE_PORT=${HIDDEN_SERVICE_PORT:-80}
SECURITY_LEVEL=${SECURITY_LEVEL:-high}
VANGUARDS_LOCATION="/pypy_venv/bin/vanguards"
OTHER_OPTIONS="--control_port 9051"
VANGUARDS_CONFIG="/etc/tor/vanguards.conf"

echo "[+] Starting OnionDock: $SECURITY_LEVEL security, $TOR_THREADS threads"

if [ "$(id -u)" = "0" ]; then
    echo "[+] Running as root, fixing permissions..."
    chown -R tor:tor /var/lib/tor
    chmod -R 700 /var/lib/tor
    exec su -s /bin/bash tor -c "$0"
fi

cp /etc/tor/torrc /tmp/torrc
sed -i "s/{{TOR_THREADS}}/$TOR_THREADS/g; s/{{HIDDEN_SERVICE_PORT}}/$HIDDEN_SERVICE_PORT/g" /tmp/torrc

if [ -f "/etc/tor/vanguards.conf" ]; then
    cp /etc/tor/vanguards.conf /tmp/vanguards.conf
    echo "[+] Using vanguards configuration from /etc/tor/vanguards.conf"
fi

echo "[+] Starting Tor hidden service..."
tor -f /tmp/torrc &
TOR_PID=$!

echo "[+] Waiting for Tor to bootstrap..."

mkdir -p /var/lib/tor
chmod 700 /var/lib/tor

while true; do
    if grep -q "Bootstrapped 100" /var/lib/tor/notices.log 2>/dev/null || ! kill -0 $TOR_PID 2>/dev/null; then
        break
    fi
    sleep 1
done

if [ -f /var/lib/tor/hidden_service/hostname ]; then
    ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname)
    echo "[+] Tor hidden service: $ONION_ADDRESS (port $HIDDEN_SERVICE_PORT)"
else
    echo "[!] Hidden service hostname file not found after bootstrap"
fi

VANGUARDS_STATE_DIR="/var/lib/tor/vanguards_state"
mkdir -p $VANGUARDS_STATE_DIR
chmod 700 $VANGUARDS_STATE_DIR

mkdir -p /tmp/vanguards_logs

LOG_FILE="/var/lib/tor/notices.log"
touch $LOG_FILE
chmod 644 $LOG_FILE

(tail -n 0 -F $LOG_FILE | grep -v "CIRCUIT_IS_CONFLUX\|circ->purpose == CIRCUIT_PURPOSE_CONFLUX_UNLINKED" &)
LOG_MONITOR_PID=$!

run_vanguards() {
    if [ -f "/tmp/vanguards_$1.pid" ]; then
        return
    fi
    
    (
        cd $VANGUARDS_STATE_DIR && 
        $VANGUARDS_LOCATION \
            --state "$VANGUARDS_STATE_DIR/$1.state" \
            --logfile "$LOG_FILE" \
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

cd /

cleanup() {
    echo "[+] Shutting down Tor and vanguards..."
    for pidfile in /tmp/vanguards_*.pid; do
        if [ -f "$pidfile" ]; then
            pid=$(cat "$pidfile")
            kill $pid 2>/dev/null || true
            rm -f "$pidfile"
        fi
    done
    
    if [ -n "$LOG_MONITOR_PID" ] && kill -0 $LOG_MONITOR_PID 2>/dev/null; then
        kill $LOG_MONITOR_PID 2>/dev/null || true
    fi
    
    if [ -n "$TOR_PID" ] && kill -0 $TOR_PID 2>/dev/null; then
        kill $TOR_PID
        wait $TOR_PID || true
    fi
    
    exit 0
}

trap cleanup INT TERM

wait $TOR_PID
cleanup
