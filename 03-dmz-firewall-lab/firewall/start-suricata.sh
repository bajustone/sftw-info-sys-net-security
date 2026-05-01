#!/bin/bash
# Start Suricata in IPS (inline) mode via NFQUEUE

# Sanity check: NFQUEUE interface used in this mode — no need to discover interface name
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
echo "=== Starting Suricata IPS ==="
echo "Mode: IPS (inline via NFQUEUE 0 - drop + alert)"
echo "Log directory: /var/log/suricata/"

# Start Suricata inline on NFQUEUE 0 (daemon, background)
suricata -c /etc/suricata/suricata.yaml -q 0 -D

# Wait for Suricata to come up before launching the block-offender tailer
for i in $(seq 1 15); do
    if [ -f /var/log/suricata/eve.json ]; then
        break
    fi
    sleep 1
done

echo "Suricata IPS started successfully"

# Launch Block Offenders daemon (pfSense "Block Offenders (SRC)" equivalent)
nohup /opt/block-offenders.sh > /var/log/suricata/block-offenders.out 2>&1 &
echo "Block Offenders daemon launched (PID $!)"
echo ""
