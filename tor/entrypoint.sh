#!/bin/bash
set -e

# Fix permissions on mounted volumes
chown -R tor:tor /var/lib/tor /var/lib/hidden_service
chmod -R 700 /var/lib/tor /var/lib/hidden_service

# Switch to tor user and run the original command
exec su -s /bin/bash tor -c "/usr/local/bin/start.sh"