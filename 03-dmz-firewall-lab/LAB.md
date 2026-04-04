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
| firewall     | Replaces pfSense (iptables + Suricata IDS) | WAN, LAN, DMZ   | 10.0.0.2 / 192.168.1.1 / 192.168.2.1    |
| lan-client   | Internal user workstation   | LAN             | 192.168.1.100                            |
| dmz-server   | Public-facing nginx server  | DMZ             | 192.168.2.100                            |
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

## IDS (Intrusion Detection System) - Suricata

Suricata runs in **IDS mode** on the firewall's WAN interface. It detects and alerts on suspicious traffic but does **NOT block** it.

### How It Works

- Suricata monitors all traffic arriving on the WAN interface using AF-PACKET
- Custom rules detect nmap scans (SYN, NULL, XMAS, FIN), ping sweeps, and HTTP recon
- Alerts are written to `/var/log/suricata/fast.log` (human-readable) and `/var/log/suricata/eve.json` (JSON)
- `checksum-validation: no` is set because Docker virtual interfaces have invalid checksums (equivalent to disabling hardware offloading on pfSense)

### Practice 5: Verify Suricata is Running
```bash
# Check Suricata process
docker exec firewall pgrep suricata

# View Suricata startup log
docker exec firewall cat /var/log/suricata/suricata.log
```

### Practice 6: Run Scans and Generate Alerts
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

### Practice 7: View and Interpret Alerts
```bash
# View alerts (human-readable)
bash view-alerts.sh

# Follow alerts in real-time (run in one terminal, scan in another)
bash view-alerts.sh --follow

# Or directly from the container
docker exec firewall cat /var/log/suricata/fast.log

# View JSON logs for detailed analysis
docker exec firewall cat /var/log/suricata/eve.json
```

Each alert shows: timestamp, priority, signature name, source IP, destination IP.

### Expected Alerts

| Scan Type | Expected Alert |
|-----------|---------------|
| `nmap -sS` | LOCAL SCAN Nmap SYN Scan Detected |
| `nmap -sN` | LOCAL SCAN Nmap NULL Scan |
| `nmap -sX` | LOCAL SCAN Nmap XMAS Scan |
| `nmap -sF` | LOCAL SCAN Nmap FIN Scan |
| `nmap -A`  | LOCAL SCAN Nmap Service Detection |
| `ping`     | LOCAL SCAN ICMP Ping Sweep |
| `curl http://10.0.0.2` | LOCAL POLICY HTTP Request to DMZ from External |

### Practice 8: Confirm IDS Mode (Not IPS)
```bash
# After generating alerts, confirm traffic still passes (IDS = alert only, no blocking)
docker exec attacker curl -s http://10.0.0.2
# Should still return the DMZ web server page
```
