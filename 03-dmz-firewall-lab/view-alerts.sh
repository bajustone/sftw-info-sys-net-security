#!/bin/bash
# View Suricata IDS Alerts
# Usage: bash view-alerts.sh [--follow]

echo "========================================"
echo " Suricata IDS - Alert Viewer"
echo "========================================"
echo ""

# Check if Suricata is running
if ! docker exec firewall pgrep suricata > /dev/null 2>&1; then
    echo "WARNING: Suricata does not appear to be running in the firewall container"
    echo ""
fi

if [ "$1" = "--follow" ] || [ "$1" = "-f" ]; then
    echo "Following alerts in real-time (Ctrl+C to stop)..."
    echo ""
    docker exec firewall tail -f /var/log/suricata/fast.log 2>/dev/null || \
        echo "No alert log found yet. Run an nmap scan first."
else
    echo "=== Recent Alerts (fast.log) ==="
    echo ""
    docker exec firewall cat /var/log/suricata/fast.log 2>/dev/null || \
        echo "No alerts yet. Run an nmap scan to generate alerts."
    echo ""
    echo "=== Alert Statistics ==="
    ALERT_COUNT=$(docker exec firewall cat /var/log/suricata/fast.log 2>/dev/null | wc -l)
    echo "Total alerts: $ALERT_COUNT"
    echo ""
    echo "Tip: Use 'bash view-alerts.sh --follow' to watch alerts in real-time"
    echo "Tip: For JSON logs: docker exec firewall cat /var/log/suricata/eve.json"
fi
