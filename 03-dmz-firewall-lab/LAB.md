# Lab 03: DMZ Firewall Lab (Docker)

## Topology

```
Internet (WAN: 10.0.0.0/24)
    │
    ├── attacker (Kali) ─── 10.0.0.100
    │
    └── firewall (Alpine + iptables + Suricata IDS) ─── 10.0.0.2
            │
            ├── LAN (192.168.1.0/24)
            │     └── lan-client (Ubuntu) ─── 192.168.1.100
            │
            └── DMZ (192.168.2.0/24)
                  └── dmz-server (nginx) ─── 192.168.2.100
```

## Components

| Container    | Role                        | Networks        | IP(s)                                    |
|--------------|-----------------------------|-----------------|------------------------------------------|
| firewall     | Replaces pfSense (iptables + Suricata IPS via NFQUEUE) | WAN, LAN, DMZ   | 10.0.0.2 / 192.168.1.1 / 192.168.2.1    |
| lan-client   | Internal user workstation   | LAN             | 192.168.1.100                            |
| dmz-server   | Public-facing Apache + PHP + MariaDB + DVWA + ModSecurity WAF | DMZ             | 192.168.2.100                            |
| attacker     | External threat (Kali)      | WAN             | 10.0.0.100                               |

## Quick Start

```bash
# Build and start all containers
docker compose up --build -d

# Check all containers are running
docker compose ps

# Run verification tests
bash test.sh

# Stop everything
docker compose down
```

## Interactive Access

```bash
docker exec -it firewall bash       # Inspect firewall rules
docker exec -it lan-client bash     # Test from internal network
docker exec -it dmz-server bash     # Test from DMZ
docker exec -it attacker bash       # Test from external attacker
```

## Firewall Rules (iptables.sh)

The firewall implements these rules matching the pfSense lab:

| Rule                        | Direction        | Protocol | Action |
|-----------------------------|------------------|----------|--------|
| Port forward HTTP (80)      | WAN → DMZ        | TCP      | DNAT   |
| Port forward HTTPS (443)    | WAN → DMZ        | TCP      | DNAT   |
| DMZ outbound to internet    | DMZ → WAN        | TCP      | ACCEPT |
| DMZ ping LAN                | DMZ → LAN        | ICMP     | ACCEPT |
| LAN outbound to internet    | LAN → WAN        | Any      | ACCEPT |
| NAT masquerade              | LAN/DMZ → WAN    | Any      | MASQ   |
| Default policy              | Everything else   | Any      | DROP   |

## Practice Exercises

### Practice 1: Verify Connectivity
```bash
# From LAN client, ping the firewall
docker exec lan-client ping -c 3 192.168.1.1

# From DMZ server, ping the firewall
docker exec dmz-server ping -c 3 192.168.2.1
```

### Practice 2: Inspect the Web Server
```bash
# Check nginx is running
docker exec dmz-server curl -s http://localhost

# Check from the attacker via port forward
docker exec attacker curl -s http://10.0.0.2
```

### Practice 3: Test Firewall Rules
```bash
# DMZ can ping LAN (allowed)
docker exec dmz-server ping -c 3 192.168.1.100

# LAN cannot ping DMZ (blocked)
docker exec lan-client ping -c 3 -W 2 192.168.2.100

# View all firewall rules
docker exec firewall iptables -L -v -n
docker exec firewall iptables -t nat -L -v -n
```

### Practice 4: Attack Simulation
```bash
# From Kali attacker — scan the firewall's WAN interface
docker exec attacker nmap -sS 10.0.0.2

# Try to access the web server via port forward
docker exec attacker curl -s http://10.0.0.2
```

---

## IPS (Intrusion Prevention System) - Suricata Inline

Suricata runs in **IPS (inline) mode** via Linux **NFQUEUE**. Every WAN-sourced packet
is handed to Suricata for a verdict; scan/recon signatures **drop** the packet, and
a companion daemon adds the source IP to an `ipset` with a 1-hour TTL — mirroring
pfSense's "Block Offenders (SRC)" and "Remove Blocked Hosts Interval: 1 Hour".

### Mode Comparison (what changed from the IDS lab)

| Aspect              | IDS (previous)          | IPS (current)                                        |
|---------------------|-------------------------|------------------------------------------------------|
| Packet path         | `--pcap` sniffer        | NFQUEUE 0 (in-line, verdicts DROP/ACCEPT)            |
| Rule action         | `alert`                 | `drop` for scans/recon (alert kept for policy)       |
| Blocked hosts       | none                    | `ipset suricata_block` (1 h timeout)                 |
| Block enforcement   | n/a                     | iptables rule at top of INPUT+FORWARD drops set IPs  |
| Audit log           | `fast.log` (alerts)     | `fast.log` `[Drop]` entries + `blocked.log` (hosts)  |
| Rule-set updates    | `suricata-update`       | same (ET Open + Abuse.ch SSL Blacklist)              |

### How It Works

- iptables sends WAN-sourced packets to NFQUEUE 0 with `-j NFQUEUE --queue-bypass`
  (fail-open if Suricata dies); Suricata re-marks accepted packets with `0x1` so
  they aren't re-queued (`repeat-mark: 1`)
- Custom rules in `firewall/custom.rules` (SIDs 1000001–1000009) drop nmap SYN,
  NULL, XMAS, FIN, aggressive scans + ping sweep + Nmap UA HTTP probes
- `block-offenders.sh` tails `eve.json` and adds every drop-event `src_ip` to
  `ipset suricata_block` with a 3600s timeout; iptables drops all packets from the
  set at the top of INPUT and FORWARD — that's what makes follow-up `curl`/`ping`
  from the attacker fail
- `checksum-validation: no` keeps working around Docker virtual interfaces
  (equivalent to disabling hardware offloading on pfSense)

### Practice 5: Verify Suricata IPS is Running
```bash
# Confirm Suricata is running in inline (NFQUEUE) mode
docker exec firewall pgrep -a suricata
# Expected: ...suricata -c /etc/suricata/suricata.yaml -q 0 -D

# Show the iptables rules that send WAN traffic to Suricata
docker exec firewall iptables -L INPUT -n --line-numbers | head
docker exec firewall iptables -L FORWARD -n --line-numbers | head

# View Suricata startup log
docker exec firewall cat /var/log/suricata/suricata.log
```

### Practice 6: Run Scans and Generate Drops
```bash
# SYN Scan (most common)
docker exec attacker nmap -sS 10.0.0.2

# Aggressive Scan (OS detection, version detection, scripts)
docker exec attacker nmap -A 10.0.0.2

# XMAS Scan (FIN+PSH+URG flags)
docker exec attacker nmap -sX 10.0.0.2

# NULL Scan (no flags)
docker exec attacker nmap -sN 10.0.0.2

# FIN Scan
docker exec attacker nmap -sF 10.0.0.2
```

### Practice 7: View and Interpret Drop Events
```bash
# Show recent drops + alerts (fast.log). Drops are prefixed [Drop].
bash view-alerts.sh
docker exec firewall grep '\[Drop\]' /var/log/suricata/fast.log

# Follow in real-time (run in one terminal, scan in another)
bash view-alerts.sh --follow

# JSON events with classification, signature_id, payload
docker exec firewall cat /var/log/suricata/eve.json | jq 'select(.event_type=="drop")' | head -40
```

Each drop line shows: timestamp, `[Drop]`, priority, signature name, classification, src → dst.

### Expected Signatures (all drop except where noted)

| Scan Type | Signature | Action |
|-----------|-----------|--------|
| `nmap -sS` | LOCAL SCAN Nmap SYN Scan Detected (SID 1000001) | drop |
| `nmap -sN` | LOCAL SCAN Nmap NULL Scan (SID 1000003) | drop |
| `nmap -sX` | LOCAL SCAN Nmap XMAS Scan (SID 1000004) | drop |
| `nmap -sF` | LOCAL SCAN Nmap FIN Scan (SID 1000005) | drop |
| `nmap -A`  | LOCAL SCAN Nmap Service Detection / Nmap UA Probe (SIDs 1000006, 1000009) | drop |
| ping flood | LOCAL SCAN ICMP Ping Sweep (SID 1000007) | drop |
| `curl http://10.0.0.2` | LOCAL POLICY HTTP Request to DMZ from External (SID 1000008) | alert (published service, not dropped) |

### Practice 8: View the Blocked-Hosts List (pfSense "Blocked tab")
```bash
# Show current 1-hour blocks + audit log (IP, timestamp, SID, signature)
bash view-blocked.sh

# Inspect ipset directly
docker exec firewall ipset list suricata_block

# Manually flush between runs (re-unblock the attacker)
bash view-blocked.sh --flush
```

### Practice 9: Confirm Prevention (Follow-up Connections Fail)
```bash
# 1. Clear any prior blocks first
bash view-blocked.sh --flush

# 2. Attack — equivalent of "nmap -A [WAN-IP]" from the assignment
docker exec attacker nmap -A 10.0.0.2
#    The scan output will be truncated/inaccurate because packets are being dropped.

# 3. Verify the attacker is now in the blocked set
docker exec firewall ipset test suricata_block 10.0.0.100 && echo "BLOCKED"

# 4. Follow-up access should FAIL (this is the IPS prevention guarantee)
docker exec attacker curl --max-time 3 http://10.0.0.2      # fails
docker exec attacker ping  -c 2 -W 2 10.0.0.2              # 100% loss
```

### Mapping to IPS Lab Evaluation Form (50 pts)

| # | Rubric Item | Evidence / Command |
|---|-------------|--------------------|
| 1 | Environment Setup (5) | `docker compose ps`, `bash test.sh` tests 1–7 |
| 2 | Suricata Configuration (5) | `docker exec firewall pgrep -a suricata` shows `-q 0`; `firewall/suricata.yaml` (nfq + action-order); `firewall/custom.rules` (drop rules) |
| 3 | Attack Simulation (15) | `docker exec attacker nmap -A 10.0.0.2` |
| 4 | Prevention / IPS (15) | `bash view-blocked.sh` shows `10.0.0.100`; follow-up `curl` and `ping` fail (Practice 9 steps 3–4) |
| 5 | Log Analysis (10) | `bash view-alerts.sh \| grep '\[Drop\]'`, `docker exec firewall tail /var/log/suricata/blocked.log` — shows IP, timestamp, SID, signature |

---

## Web Application Security Lab Series (DVWA + ModSecurity WAF)

The `dmz-server` container is a full LAMP stack hosting DVWA (Damn Vulnerable Web
Application) behind ModSecurity with the OWASP Core Rule Set. This replaces the
VirtualBox path in the PDF (Labs 1–9 of *Hands-On Web Application Security*) —
same tools, same outcomes, faster to stand up.

### Mapping PDF Labs → This Docker Stack

| PDF Lab | Outcome | How we do it here |
|--------|----------|-------------------|
| 1 Virtualization setup | VirtualBox + Kali + Ubuntu VMs | **Docker Compose** (`docker compose up -d`) replaces the VMs |
| 2 Virtual network       | 192.168.56.0/24 host-only      | WAN/LAN/DMZ networks in `docker-compose.yml` |
| 3 Linux admin basics    | Navigate Ubuntu server          | `docker exec -it dmz-server bash` |
| 4 LAMP stack            | Apache + MySQL + PHP            | Baked into `dmz-server` image (Apache 2.4, MariaDB 10.6, PHP 8.1) |
| 5 DVWA deployment       | DVWA at `/DVWA`, `admin/password` | Cloned at image build, DB seeded by `entrypoint.sh` |
| 6 HTTP traffic analysis | Browser DevTools + Burp proxy   | Run Kali VM's Burp against DVWA (see below) |
| 7 OWASP ZAP scan        | Spider + active scan            | Run Kali VM's ZAP against DVWA |
| 8 Burp SQLi + XSS       | Manual attacks succeed          | `bash toggle-waf.sh detect` → run attacks |
| 9 ModSecurity WAF       | OWASP CRS blocks attacks (403)  | `bash toggle-waf.sh on` → retry attacks |

### Reaching DVWA from your Kali VM (Parallels)

The `dmz-server` publishes ports 80/443 on the Mac host. From the Kali VM:

```bash
# On the Mac (host), find the LAN IP
ipconfig getifaddr en0                         # e.g. 192.168.1.42

# From the Kali VM browser / Burp / ZAP
http://<mac-ip>/DVWA/                          # login admin / password
http://<mac-ip>/info.php                       # PHP info (Lab 4 artifact)
```

If Parallels is in **Shared** mode the Mac is reachable; **Bridged** is easier
(Kali on the same LAN as the Mac). The attacker container can also reach DVWA:

```bash
docker exec attacker curl -s http://192.168.2.100/DVWA/login.php | head
```

### Practice 10 — Lab 4/5: Verify LAMP + DVWA

```bash
# Apache running
docker exec dmz-server systemctl is-active apache2 2>/dev/null || \
    docker exec dmz-server pgrep -a apache2

# PHP info page (Deliverable #3 of Lab 4)
curl -s http://localhost/info.php | grep -oE 'PHP Version [0-9.]+'

# DVWA login page reachable (Deliverable #1 of Lab 5)
docker exec attacker curl -sI http://192.168.2.100/DVWA/login.php | head -1

# Database tables created (Deliverable #2 of Lab 5)
docker exec dmz-server mysql -udvwa -ppassword dvwa -e "SHOW TABLES;"
```

### Practice 11 — Lab 6: Intercept HTTP with Burp (from Kali VM)

1. In Kali: launch Burp Suite → Temporary Project → Use Burp Defaults → Start
2. **Proxy → Proxy settings** → confirm listener on 127.0.0.1:8080
3. **Proxy → Intercept → Intercept is on**
4. Configure Firefox → Settings → Network Settings → Manual proxy 127.0.0.1:8080
5. Navigate to `http://<mac-ip>/DVWA/login.php`, login — Burp catches the POST
6. Deliverable screenshot: intercepted `POST /DVWA/login.php` showing `username=admin&password=password`

### Practice 12 — Lab 7: OWASP ZAP Scan (from Kali VM)

1. In Kali terminal: `zaproxy` (or menu → Web Application Analysis → owasp-zap)
2. **No, I do not want to persist this session** → Start
3. Point Firefox at ZAP proxy (same 127.0.0.1:8080 — stop Burp first)
4. Browse `http://<mac-ip>/DVWA/`, login
5. In ZAP **Sites** panel → right-click the site → **Attack → Spider → Start Scan**
6. Right-click again → **Attack → Active Scan → Start Scan**
7. **Report → Generate Report** → HTML → save as `dvwa_scan_report.html` (Deliverable #5)
8. Expect alerts: SQL Injection (High), XSS Reflected (High), CSP (Medium), etc.

### Practice 13 — Lab 8: Burp SQL Injection + XSS (WAF in DetectionOnly)

```bash
bash toggle-waf.sh detect        # baseline: WAF logs but does not block
bash toggle-waf.sh status        # confirms SecRuleEngine = DetectionOnly
```

Then in Kali Burp:
1. DVWA → SQL Injection module → enter `1` → Submit → Burp intercepts
2. Right-click → **Send to Repeater**
3. In Repeater, change `id=1` to `id=1' OR '1'='1` → **Send** → response shows multiple rows (attack succeeded)
4. DVWA → XSS (Reflected) → enter `<script>alert('XSS')</script>` → Submit → browser popup appears (attack succeeded)
5. Deliverable screenshots: Burp Repeater request/response, XSS popup

### Practice 14 — Lab 9: ModSecurity WAF Blocks Both Attacks

```bash
bash toggle-waf.sh on            # SecRuleEngine = On (enforcing)
bash toggle-waf.sh status
```

Then retry the same attacks:
1. SQL Injection `id=1' OR '1'='1` → server returns **403 Forbidden** (Deliverable #4)
2. Reflected XSS `<script>alert('XSS')</script>` → **403 Forbidden**
3. Inspect the audit log:

```bash
# ModSecurity audit log (Deliverable #5 of Lab 9)
docker exec dmz-server tail -50 /var/log/apache2/modsec_audit.log

# Just the rule hits
docker exec dmz-server grep -E '942[0-9]+|941[0-9]+' /var/log/apache2/modsec_audit.log | head
#   942xxx = CRS SQL Injection rules
#   941xxx = CRS XSS rules
```

### Automated end-to-end test

```bash
bash view-blocked.sh --flush     # clear IPS block if attacker is locked out
bash test-webapp.sh              # 7 checks: DVWA up, login OK, SQLi+XSS succeed with WAF off, SQLi+XSS blocked with WAF on, audit log hits
```

### Mapping to the 9 PDF Deliverables

| PDF Lab | Deliverable screenshots | Command that produces evidence |
|---------|-------------------------|--------------------------------|
| 4 LAMP  | Apache status, default page, info.php, MySQL login, PHP version | `docker exec dmz-server pgrep apache2`, `curl http://localhost/info.php` |
| 5 DVWA  | Setup page, DB create, login, dashboard, security=Low | Visit `/DVWA/setup.php`, `/DVWA/login.php` |
| 6 HTTP  | DevTools Network, captured request, login POST, Burp intercept, params | Burp in Kali VM (Practice 11) |
| 7 ZAP   | ZAP dashboard, spider results, active scan, alerts, HTML report | ZAP in Kali VM (Practice 12) |
| 8 Burp  | Burp intercept, SQLi in Repeater, SQLi result, XSS popup, Intruder | `toggle-waf.sh detect` + Burp (Practice 13) |
| 9 WAF   | ModSecurity installed, Apache running with it, SQLi attempt, 403 Forbidden, modsec_audit.log entry | `toggle-waf.sh on` + retry (Practice 14) |
