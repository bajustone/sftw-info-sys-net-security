#!/bin/bash
set -e

# Discover interfaces by their assigned IPs
WAN_IF=$(ip -4 addr | grep '10.0.0.2/' | awk '{print $NF}')
LAN_IF=$(ip -4 addr | grep '192.168.1.1/' | awk '{print $NF}')
DMZ_IF=$(ip -4 addr | grep '192.168.2.1/' | awk '{print $NF}')

echo "=== Interface Mapping ==="
echo "WAN = $WAN_IF (10.0.0.2)"
echo "LAN = $LAN_IF (192.168.1.1)"
echo "DMZ = $DMZ_IF (192.168.2.1)"
echo ""

# Fix default route to go via WAN gateway (Docker may set it to wrong interface)
ip route replace default via 10.0.0.254 dev "$WAN_IF"
echo "Default route set via WAN (10.0.0.254)"
echo ""

# Flush existing rules
iptables -F
iptables -t nat -F
iptables -X 2>/dev/null || true

# ===========================
# IPS Block List (Suricata "Block Offenders (SRC)" equivalent)
#   - ipset entries expire after 3600s (matches pfSense "Remove Blocked Hosts Interval: 1 Hour")
#   - block-offenders.sh populates this set by tailing eve.json drop events
# ===========================
ipset create suricata_block hash:ip timeout 3600 -exist
ipset flush suricata_block

# Drop everything from blocked source IPs — applied before any other rule
iptables -I INPUT   1 -m set --match-set suricata_block src -j DROP
iptables -I FORWARD 1 -m set --match-set suricata_block src -j DROP

# ===========================
# Default Policies: DROP all
# ===========================
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ===========================
# Loopback
# ===========================
iptables -A INPUT -i lo -j ACCEPT

# ===========================
# Stateful: allow established/related
# ===========================
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# ===========================
# IPS inline inspection: send WAN-sourced new/invalid packets to Suricata (NFQUEUE 0)
#   - Suricata re-marks accepted packets with 0x1 (repeat-mark) so we skip re-queueing them
#   - queue-bypass lets traffic flow if Suricata is down (fail-open)
# ===========================
iptables -A INPUT   -i "$WAN_IF" -m mark ! --mark 0x1/0x1 -j NFQUEUE --queue-num 0 --queue-bypass
iptables -A FORWARD -i "$WAN_IF" -m mark ! --mark 0x1/0x1 -j NFQUEUE --queue-num 0 --queue-bypass

# ===========================
# NAT: Masquerade outbound traffic through WAN
# ===========================
iptables -t nat -A POSTROUTING -o "$WAN_IF" -j MASQUERADE

# NAT: Masquerade DNAT'd traffic entering DMZ (so DMZ server sees firewall as source)
iptables -t nat -A POSTROUTING -o "$DMZ_IF" -s 10.0.0.0/24 -j MASQUERADE

# NAT Hairpin: Allow LAN clients to reach DMZ via firewall's WAN IP
iptables -t nat -A PREROUTING -i "$LAN_IF" -p tcp --dport 80 -d 10.0.0.2 -j DNAT --to-destination 192.168.2.100:80
iptables -t nat -A PREROUTING -i "$LAN_IF" -p tcp --dport 443 -d 10.0.0.2 -j DNAT --to-destination 192.168.2.100:443

# ===========================
# WAN RULES
# ===========================

# Port Forward: HTTP (80) from WAN -> DMZ web server
iptables -t nat -A PREROUTING -i "$WAN_IF" -p tcp --dport 80 -j DNAT --to-destination 192.168.2.100:80
iptables -A FORWARD -i "$WAN_IF" -o "$DMZ_IF" -p tcp --dport 80 -d 192.168.2.100 -j ACCEPT

# Port Forward: HTTPS (443) from WAN -> DMZ web server
iptables -t nat -A PREROUTING -i "$WAN_IF" -p tcp --dport 443 -j DNAT --to-destination 192.168.2.100:443
iptables -A FORWARD -i "$WAN_IF" -o "$DMZ_IF" -p tcp --dport 443 -d 192.168.2.100 -j ACCEPT

# ===========================
# DMZ RULES
# ===========================

# Allow DMZ server outbound TCP to internet (via WAN)
iptables -A FORWARD -i "$DMZ_IF" -o "$WAN_IF" -p tcp -j ACCEPT

# Allow DMZ to ping LAN (ICMP)
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -i "$LAN_IF" -o "$DMZ_IF" -p icmp --icmp-type echo-reply -j ACCEPT

# ===========================
# LAN RULES
# ===========================

# Allow LAN to access internet
iptables -A FORWARD -i "$LAN_IF" -o "$WAN_IF" -j ACCEPT

# Allow LAN to access DMZ web server (HTTP + HTTPS)
iptables -A FORWARD -i "$LAN_IF" -o "$DMZ_IF" -p tcp --dport 80 -d 192.168.2.100 -j ACCEPT
iptables -A FORWARD -i "$LAN_IF" -o "$DMZ_IF" -p tcp --dport 443 -d 192.168.2.100 -j ACCEPT

# ===========================
# Allow ping to firewall from LAN and DMZ (for testing)
# ===========================
iptables -A INPUT -i "$LAN_IF" -p icmp -j ACCEPT
iptables -A INPUT -i "$DMZ_IF" -p icmp -j ACCEPT

# ===========================
# Everything else: blocked by default DROP policy
# ===========================

echo ""
echo "=== Firewall rules applied successfully ==="
echo ""
echo "--- FILTER TABLE ---"
iptables -L -v -n
echo ""
echo "--- NAT TABLE ---"
iptables -t nat -L -v -n
