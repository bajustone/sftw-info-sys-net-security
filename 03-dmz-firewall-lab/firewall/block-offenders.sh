#!/bin/bash
# Block Offenders daemon — pfSense Suricata "Block Offenders (SRC)" equivalent.
#
# Tails Suricata's eve.json, extracts the source IP of every drop/blocked event,
# and adds it to the ipset `suricata_block` with a 1 hour TTL. iptables references
# the set at the top of INPUT/FORWARD so all subsequent traffic from the offender
# is dropped — this is what makes post-attack curl/ping fail.
#
# A human-readable audit line is also appended to /var/log/suricata/blocked.log
# for the report artifact ("Blocked tab" equivalent).

set -u

EVE=/var/log/suricata/eve.json
BLOCKED_LOG=/var/log/suricata/blocked.log
SET_NAME=suricata_block
TIMEOUT=3600

# HOME_NET subnets that must never be blocked (LAN / DMZ / firewall WAN IP)
is_home_net() {
    case "$1" in
        10.0.0.2|192.168.1.*|192.168.2.*) return 0 ;;
        *) return 1 ;;
    esac
}

# Wait until eve.json exists
while [ ! -f "$EVE" ]; do
    sleep 1
done

echo "block-offenders: tailing $EVE, blocking drop-event src_ips for ${TIMEOUT}s"
touch "$BLOCKED_LOG"

tail -F -n 0 "$EVE" 2>/dev/null | while read -r line; do
    parsed=$(echo "$line" | jq -r '
        select(.event_type == "drop" or (.event_type == "alert" and (.alert.action == "blocked" or .alert.action == "drop")))
        | [.timestamp, .src_ip, (.alert.signature // "drop"), (.alert.signature_id // 0)]
        | @tsv' 2>/dev/null)

    [ -z "$parsed" ] && continue

    while IFS=$'\t' read -r ts src_ip sig sid; do
        [ -z "$src_ip" ] && continue
        if is_home_net "$src_ip"; then
            continue
        fi
        if ipset add "$SET_NAME" "$src_ip" timeout "$TIMEOUT" -exist 2>/dev/null; then
            echo "$ts,$src_ip,$sid,$sig" >> "$BLOCKED_LOG"
        fi
    done <<< "$parsed"
done
