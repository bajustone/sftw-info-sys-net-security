#!/bin/bash
# View Suricata IPS Blocked Hosts (pfSense "Blocked tab" equivalent)
# Usage: bash view-blocked.sh [--flush]

set -u

if [ "${1:-}" = "--flush" ]; then
    echo "Flushing suricata_block ipset..."
    docker exec firewall ipset flush suricata_block && echo "Done."
    : > /dev/null
    docker exec firewall sh -c ': > /var/log/suricata/blocked.log'
    exit 0
fi

echo "========================================"
echo " Suricata IPS - Blocked Hosts"
echo "========================================"
echo ""

if ! docker exec firewall pgrep suricata > /dev/null 2>&1; then
    echo "WARNING: Suricata is not running in the firewall container"
    echo ""
fi

echo "=== Active Blocked IPs (ipset suricata_block) ==="
docker exec firewall ipset list suricata_block 2>/dev/null || {
    echo "ipset 'suricata_block' does not exist yet. Restart the firewall container."
    exit 1
}
echo ""

echo "=== Block Audit Log (/var/log/suricata/blocked.log) ==="
echo "timestamp,src_ip,sid,signature"
docker exec firewall tail -n 20 /var/log/suricata/blocked.log 2>/dev/null || \
    echo "No blocks recorded yet."
echo ""

echo "Tip: remove all blocks with 'bash view-blocked.sh --flush'"
