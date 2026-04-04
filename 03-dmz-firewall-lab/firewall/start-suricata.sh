#!/bin/bash
# Start Suricata in IDS mode on the WAN interface

# Discover WAN interface (same logic as iptables.sh)
WAN_IF=$(ip -4 addr | grep '10.0.0.2/' | awk '{print $NF}')

if [ -z "$WAN_IF" ]; then
    echo "ERROR: Could not find WAN interface"
    exit 1
fi

echo ""
echo "=== Updating Suricata Rule Sets ==="

# Enable Abuse.ch SSL Blacklist (includes Feodo Tracker botnet C2 indicators)
suricata-update enable-source sslbl/ssl-fp-blacklist 2>/dev/null
suricata-update enable-source sslbl/ja3-fingerprints 2>/dev/null

# Download and install ET Open + enabled sources, merge with custom rules
suricata-update --no-test \
    --local /etc/suricata/rules/custom.rules \
    --suricata-conf /etc/suricata/suricata.yaml 2>&1 | tail -5

echo "Rule sets updated: ET Open, Abuse.ch (Feodo/SSL Blacklist), Custom Rules"

echo ""
echo "=== Starting Suricata IDS ==="
echo "Monitoring interface: $WAN_IF (WAN - 10.0.0.2)"
echo "Mode: IDS (detect + alert, no blocking)"
echo "Log directory: /var/log/suricata/"

# Update suricata.yaml with the actual interface name
sed -i "s/WAN_INTERFACE_PLACEHOLDER/$WAN_IF/g" /etc/suricata/suricata.yaml

# Start Suricata in IDS mode (daemon, background)
suricata -c /etc/suricata/suricata.yaml --pcap="$WAN_IF" -D

echo "Suricata IDS started successfully"
echo ""
