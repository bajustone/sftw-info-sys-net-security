#!/bin/bash
# Web Application Security lab verification.
# Exercises DVWA → SQL Injection → XSS first without the WAF (Lab 8 baseline,
# both attacks succeed), then with ModSecurity enforcing (Lab 9, both blocked 403).
#
# Prerequisite: `bash view-blocked.sh --flush` if the attacker is still locked
# out from the IPS lab (otherwise the SYN scan triggered by earlier tests
# blackholes all traffic from 10.0.0.100 at the firewall).

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; }

# Run curl-with-session from the attacker container so traffic flows
# attacker → firewall → dmz-server (end-to-end, mirrors the PDF's Kali→Ubuntu path).
COOKIE_FILE=/tmp/dvwa.cookies
# Attacker is on WAN (10.0.0.0/24) and has no route to DMZ subnet, so it reaches
# DVWA through the firewall's WAN IP via port forwarding (iptables DNAT 80/443).
DVWA_URL="http://10.0.0.2/DVWA"
ac() { docker exec attacker timeout 10 "$@"; }

login_dvwa() {
    ac sh -c "rm -f $COOKIE_FILE; \
        TOKEN=\$(curl -s -c $COOKIE_FILE '$DVWA_URL/login.php' | grep -oP \"user_token' value='\\K[0-9a-f]+\"); \
        curl -s -L -b $COOKIE_FILE -c $COOKIE_FILE \
            -d \"username=admin&password=password&Login=Login&user_token=\$TOKEN\" \
            '$DVWA_URL/login.php' > /dev/null; \
        curl -s -b $COOKIE_FILE -c $COOKIE_FILE \
            -d 'security=low&seclev_submit=Submit' \
            '$DVWA_URL/security.php' > /dev/null"
}

sqli_request() {
    # Returns HTTP status. Success (200 + extra records) = vulnerable; 403 = blocked by WAF.
    ac sh -c "curl -s -o /tmp/sqli.html -w '%{http_code}' -b $COOKIE_FILE \
        \"$DVWA_URL/vulnerabilities/sqli/?id=1'+OR+'1'='1&Submit=Submit\""
}

sqli_body_has_multiple_rows() {
    # DVWA returns rows for admin/Gordon/Hack/Pablo/Bob when the injection
    # succeeds. `grep -c "First name"` would only count matching *lines* (DVWA
    # ships minified HTML on one line) — count *matches* instead.
    local count
    count=$(ac sh -c "grep -oE 'First name' /tmp/sqli.html 2>/dev/null | wc -l")
    count=${count//[^0-9]/}
    [ "${count:-0}" -gt 1 ]
}

xss_request() {
    ac sh -c "curl -s -o /tmp/xss.html -w '%{http_code}' -b $COOKIE_FILE \
        \"$DVWA_URL/vulnerabilities/xss_r/?name=%3Cscript%3Ealert('XSS')%3C%2Fscript%3E\""
}

xss_body_reflects_script() {
    ac sh -c "grep -q \"<script>alert('XSS')</script>\" /tmp/xss.html"
}

echo "========================================"
echo " Web App Security - Lab Verification"
echo "========================================"
echo ""

# ---- Test 1: DVWA reachable (Lab 5) ----
echo "--- Test 1: DVWA login page reachable from attacker ---"
STATUS=$(ac curl -s -o /dev/null -w '%{http_code}' "$DVWA_URL/login.php")
if [ "$STATUS" = "200" ]; then
    pass "DVWA login.php returns 200"
else
    fail "DVWA login.php returned $STATUS — is dmz-server up? run 'bash view-blocked.sh --flush' if attacker is IPS-blocked"
    exit 1
fi
echo ""

# ---- Test 2: Login + set security=Low (Lab 5, Step 10) ----
echo "--- Test 2: DVWA login as admin/password, security=low ---"
login_dvwa
if ac curl -s -b $COOKIE_FILE "$DVWA_URL/index.php" | grep -q "Welcome to Damn Vulnerable Web Application"; then
    pass "Logged in to DVWA"
else
    fail "DVWA login did not succeed"
fi
echo ""

# =================================================================
# PHASE A: WAF in DetectionOnly (Lab 8 — attacks must succeed)
# =================================================================
echo "--- Phase A: WAF in DetectionOnly (Lab 8 baseline) ---"
bash toggle-waf.sh detect > /dev/null

# ---- Test 3: SQL Injection succeeds ----
echo "--- Test 3: SQL Injection ' OR '1'='1 (WAF detection only) ---"
STATUS=$(sqli_request)
if [ "$STATUS" = "200" ] && sqli_body_has_multiple_rows; then
    pass "SQL injection returned multiple rows (vulnerable app, WAF not blocking)"
else
    fail "SQL injection did not behave as baseline (status=$STATUS)"
fi
echo ""

# ---- Test 4: Reflected XSS succeeds ----
echo "--- Test 4: Reflected XSS <script>alert('XSS')</script> (WAF detection only) ---"
STATUS=$(xss_request)
if [ "$STATUS" = "200" ] && xss_body_reflects_script; then
    pass "XSS payload reflected in response (vulnerable, WAF not blocking)"
else
    fail "XSS payload not reflected (status=$STATUS)"
fi
echo ""

# =================================================================
# PHASE B: WAF On (Lab 9 — attacks must be blocked)
# =================================================================
echo "--- Phase B: WAF enforcing (Lab 9) ---"
bash toggle-waf.sh on > /dev/null
sleep 1

# ---- Test 5: SQL Injection blocked ----
echo "--- Test 5: SQL Injection blocked with 403 ---"
STATUS=$(sqli_request)
if [ "$STATUS" = "403" ]; then
    pass "SQL injection returned 403 Forbidden (blocked by CRS)"
elif [ "$STATUS" = "406" ]; then
    pass "SQL injection returned 406 Not Acceptable (blocked by CRS)"
else
    fail "SQL injection not blocked (status=$STATUS)"
fi
echo ""

# ---- Test 6: XSS blocked ----
echo "--- Test 6: Reflected XSS blocked ---"
STATUS=$(xss_request)
if [ "$STATUS" = "403" ] || [ "$STATUS" = "406" ]; then
    pass "XSS returned $STATUS (blocked by CRS)"
else
    fail "XSS not blocked (status=$STATUS)"
fi
echo ""

# ---- Test 7: WAF audit log shows the blocked attacks (Lab 9, Step 7) ----
echo "--- Test 7: ModSecurity audit log has entries for the blocks ---"
HITS=$(docker exec dmz-server sh -c 'grep -cE "942[0-9]+|941[0-9]+" /var/log/apache2/modsec_audit.log 2>/dev/null || echo 0')
HITS=${HITS//[^0-9]/}
if [ "${HITS:-0}" -gt 0 ]; then
    pass "ModSecurity audit log shows $HITS CRS rule triggers (941xxx XSS / 942xxx SQLi)"
    echo "  Sample:"
    docker exec dmz-server sh -c 'grep -E "942[0-9]+|941[0-9]+" /var/log/apache2/modsec_audit.log | head -3' | sed 's/^/    /'
else
    fail "No CRS rule triggers in modsec_audit.log"
fi
echo ""

echo "========================================"
echo " Reset WAF to DetectionOnly (safe default)"
echo "========================================"
bash toggle-waf.sh detect > /dev/null
bash toggle-waf.sh status
