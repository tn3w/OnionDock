#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

TOR_THREADS=${TOR_THREADS:-$(nproc)}
HIDDEN_SERVICE_PORT=${HIDDEN_SERVICE_PORT:-80}
SECURITY_LEVEL=${SECURITY_LEVEL:-high}
VANGUARDS_LOCATION=$(which vanguards)
OTHER_OPTIONS="--control_port 9051"
VANGUARDS_CONFIG="/etc/tor/vanguards.conf"

echo "[+] Starting OnionDock with security level: $SECURITY_LEVEL"
echo "[+] Using $TOR_THREADS Tor threads"

if [ "$(id -u)" = "0" ]; then
    echo "[+] Running as root, fixing permissions..."
    chown -R tor:tor /var/lib/tor
    chmod -R 700 /var/lib/tor
    exec su -s /bin/bash tor -c "$0"
fi

cp /etc/tor/torrc /tmp/torrc
sed "s/{{TOR_THREADS}}/$TOR_THREADS/g" /tmp/torrc > /tmp/torrc.tmp && mv /tmp/torrc.tmp /tmp/torrc
sed "s/{{HIDDEN_SERVICE_PORT}}/$HIDDEN_SERVICE_PORT/g" /tmp/torrc > /tmp/torrc.tmp && mv /tmp/torrc.tmp /tmp/torrc

if [ -f "/etc/tor/vanguards.conf" ]; then
    cp /etc/tor/vanguards.conf /tmp/vanguards.conf
    echo "[+] Using vanguards configuration from /etc/tor/vanguards.conf"
fi

if [ ! -f /var/lib/tor/hidden_service/hostname ]; then
    echo "[+] First run, generating hidden service..."
    tor -f /tmp/torrc &
    TOR_PID=$!

    while [ ! -f /var/lib/tor/hidden_service/hostname ]; do
        sleep 1
    done

    ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname)
    echo "[+] Hidden service created: $ONION_ADDRESS"

    kill $TOR_PID
    wait $TOR_PID || true
fi

ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname)
echo "[+] Starting Tor hidden service at: $ONION_ADDRESS"
echo "[+] Port $HIDDEN_SERVICE_PORT is being forwarded to the hidden service"

tor -f /tmp/torrc &
TOR_PID=$!

echo "[+] Waiting for Tor to bootstrap..."

mkdir -p /var/lib/tor
chmod 700 /var/lib/tor

while true; do
    if grep -q "Bootstrapped 100" /var/lib/tor/notices.log 2> /dev/null; then
        echo "[+] Tor has bootstrapped 100%"
        break
    fi

    if ! kill -0 $TOR_PID 2> /dev/null; then
        echo "[!] Tor process is not running anymore. Continuing anyway..."
        break
    fi

    sleep 1
done

VANGUARDS_STATE_DIR="/var/lib/tor/vanguards_state"
mkdir -p $VANGUARDS_STATE_DIR
chmod 700 $VANGUARDS_STATE_DIR

mkdir -p /tmp/vanguards_logs

LOG_FILE="/var/lib/tor/notices.log"
touch $LOG_FILE
chmod 644 $LOG_FILE

(tail -n 0 -F $LOG_FILE | grep -v "CIRCUIT_IS_CONFLUX" | grep -v "circ->purpose == CIRCUIT_PURPOSE_CONFLUX_UNLINKED" &)
LOG_MONITOR_PID=$!

run_vanguards() {
    local name="$1"
    shift
    cd $VANGUARDS_STATE_DIR
    
    local options="$*"
    echo "[+] Starting vanguards-$name with options: $options"
    
    $VANGUARDS_LOCATION --state "$VANGUARDS_STATE_DIR/$name.state" --logfile "$LOG_FILE" --config "/tmp/vanguards.conf" $options &
    local pid=$!
    echo $pid > "/tmp/vanguards_$name.pid"
    return 0
}

if [[ "$SECURITY_LEVEL" == "high" ]]; then
    echo "[+] Starting vanguards instances in parallel with high security settings"

    run_vanguards "guards" --disable_bandguards --disable_rendguard --control_port 9051 &
    run_vanguards "band" --disable_vanguards --disable_rendguard --control_port 9051 &
    run_vanguards "rend" --disable_vanguards --disable_bandguards --control_port 9051 &

elif [[ "$SECURITY_LEVEL" == "medium" ]]; then
    echo "[+] Starting vanguards instances in parallel with medium security settings"

    run_vanguards "guards" --disable_bandguards --disable_rendguard --disable_cbtverify --control_port 9051 &
    run_vanguards "band" --disable_vanguards --disable_rendguard --disable_cbtverify --control_port 9051 &

elif [[ "$SECURITY_LEVEL" == "low" ]]; then
    echo "[+] Starting vanguards instance with basic security settings"

    run_vanguards "guards" --disable_bandguards --disable_rendguard --disable_cbtverify --control_port 9051 &
fi

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
