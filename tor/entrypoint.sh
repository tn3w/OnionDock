#!/bin/bash
set -e

chown -R tor:tor /var/lib/tor /var/lib/hidden_service
chmod -R 700 /var/lib/tor /var/lib/hidden_service

chown -R tor:tor /usr/local/bin/pluggable_transports
chmod -R 755 /usr/local/bin/pluggable_transports

exec su -s /bin/bash tor -c "/usr/local/bin/start.sh"