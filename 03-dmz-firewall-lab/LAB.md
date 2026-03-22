# Lab 03: DMZ Firewall Lab (Docker)

## Topology

```
Internet (WAN: 10.0.0.0/24)
    │
    ├── attacker (Kali) ─── 10.0.0.100
    │
    └── firewall (Alpine + iptables) ─── 10.0.0.2
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
| firewall     | Replaces pfSense (iptables) | WAN, LAN, DMZ   | 10.0.0.2 / 192.168.1.1 / 192.168.2.1    |
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
