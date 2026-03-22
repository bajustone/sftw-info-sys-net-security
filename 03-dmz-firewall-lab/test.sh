#!/bin/bash
# DMZ Lab Verification Tests
# Usage: bash test.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; }

echo "========================================"
echo " DMZ Lab - Verification Tests"
echo "========================================"
echo ""

# Test 1: LAN client can ping firewall
echo "--- Test 1: LAN client pings firewall (192.168.1.1) ---"
if docker exec lan-client ping -c 2 -W 3 192.168.1.1 > /dev/null 2>&1; then
    pass "LAN client can reach firewall"
else
    fail "LAN client cannot reach firewall"
fi
echo ""

# Test 2: DMZ server can ping firewall
echo "--- Test 2: DMZ server pings firewall (192.168.2.1) ---"
if docker exec dmz-server ping -c 2 -W 3 192.168.2.1 > /dev/null 2>&1; then
    pass "DMZ server can reach firewall"
else
    fail "DMZ server cannot reach firewall"
fi
echo ""

# Test 3: Attacker can reach DMZ web server via port forward (HTTP)
echo "--- Test 3: Attacker accesses DMZ web server via WAN port forward ---"
RESULT=$(docker exec attacker curl -s --max-time 5 http://10.0.0.2:80 2>/dev/null)
if echo "$RESULT" | grep -q "DMZ Web Server"; then
    pass "Port forwarding works — attacker sees nginx page"
else
    fail "Port forwarding not working"
fi
echo ""

# Test 4: DMZ server can ping LAN client (ICMP rule)
echo "--- Test 4: DMZ server pings LAN client (192.168.1.100) ---"
if docker exec dmz-server ping -c 2 -W 3 192.168.1.100 > /dev/null 2>&1; then
    pass "DMZ can ping LAN (ICMP rule works)"
else
    fail "DMZ cannot ping LAN"
fi
echo ""

# Test 5: LAN client CANNOT reach DMZ server (should be blocked)
echo "--- Test 5: LAN client tries to ping DMZ server (should be BLOCKED) ---"
if docker exec lan-client ping -c 2 -W 3 192.168.2.100 > /dev/null 2>&1; then
    fail "LAN can reach DMZ — should be blocked!"
else
    pass "LAN to DMZ is blocked as expected"
fi
echo ""

# Test 6: DMZ server can reach the internet (outbound TCP)
echo "--- Test 6: DMZ server outbound internet access ---"
if docker exec dmz-server curl -s --max-time 5 http://example.com > /dev/null 2>&1; then
    pass "DMZ server has internet access"
else
    fail "DMZ server cannot reach internet"
fi
echo ""

# Test 7: LAN client can reach the internet
echo "--- Test 7: LAN client outbound internet access ---"
if docker exec lan-client curl -s --max-time 5 http://example.com > /dev/null 2>&1; then
    pass "LAN client has internet access"
else
    fail "LAN client cannot reach internet"
fi
echo ""

echo "========================================"
echo " Firewall Rules Summary"
echo "========================================"
docker exec firewall iptables -L -v -n --line-numbers
echo ""
echo "--- NAT Rules ---"
docker exec firewall iptables -t nat -L -v -n --line-numbers
