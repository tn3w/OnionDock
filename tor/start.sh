#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Print OnionDock logo
echo "             @@@@@                                                                "
echo "       @@@@@@@@@@@@@@@@@                                                          "
echo "    @@@@@@@@@@@@@@@   @@@@@                                                       "
echo "  @@@@@@@@@@@@@@ @@@@@@  @@@@                                                     "
echo " @@@@@@@@@@@@@@@@@@  @@@@  @@@   .d88b.       w             888b.            8    "
echo " @@@@@@@@@@@@@@@ @@@@  @@@ @@@   8P  Y8 8d8b. w .d8b. 8d8b. 8   8 .d8b. .d8b 8.dP "
echo "@@@@@@@@@@@@@@@@   @@  @@@  @@@  8b  d8 8P Y8 8 8' .8 8P Y8 8   8 8' .8 8    88b  "
echo " @@@@@@@@@@@@@@@ @@@@  @@@ @@@   \`Y88P' 8   8 8 \`Y8P' 8   8 888P' \`Y8P' \`Y8P 8 Yb "
echo " @@@@@@@@@@@@@@@@@@  @@@@ @@@@   ~- By TN3W: https://github.com/tn3w/OnionDock -~ "
echo "  @@@@@@@@@@@@@@@@@@@@@  @@@                                                      "
echo "    @@@@@@@@@@@@@@@   @@@@@                                                       "
echo "       @@@@@@@@@@@@@@@@@                                                          "
echo ""

SECURITY_LEVEL=${SECURITY_LEVEL:-high}
VANGUARDS_LOCATION="/pypy_venv/bin/vanguards"

echo "[+] Starting OnionDock: $SECURITY_LEVEL security"

cp /etc/tor/torrc /tmp/torrc

if [ -f "/etc/tor/vanguards.conf" ]; then
    cp /etc/tor/vanguards.conf /tmp/vanguards.conf
    echo "[+] Using vanguards configuration from /etc/tor/vanguards.conf"
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
