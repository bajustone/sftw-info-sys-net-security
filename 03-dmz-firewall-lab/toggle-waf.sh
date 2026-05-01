#!/bin/bash
# ModSecurity WAF toggle — flips SecRuleEngine between DetectionOnly, On, Off.
# Used to demonstrate Lab 9: attacks that succeeded with the WAF in DetectionOnly
# (Lab 8) now return 403 Forbidden with the WAF On.
#
# Usage:
#   bash toggle-waf.sh on        # block malicious requests (Lab 9 demo)
#   bash toggle-waf.sh off       # disable ModSecurity entirely
#   bash toggle-waf.sh detect    # log but don't block (Lab 8 baseline)
#   bash toggle-waf.sh status    # show current SecRuleEngine value

set -u

CONTAINER=dmz-server
CFG=/etc/modsecurity/zzz-overrides.conf

mode="${1:-status}"

case "$mode" in
    on|ON|On)        newval="On" ;;
    off|OFF|Off)     newval="Off" ;;
    detect|DetectionOnly) newval="DetectionOnly" ;;
    status|STATUS)
        cur=$(docker exec "$CONTAINER" grep -E '^\s*SecRuleEngine' "$CFG" 2>/dev/null | awk '{print $2}')
        echo "ModSecurity SecRuleEngine = ${cur:-unknown}"
        exit 0
        ;;
    *)
        echo "Usage: $0 {on|off|detect|status}"
        exit 1
        ;;
esac

echo "Setting ModSecurity SecRuleEngine = $newval"
docker exec "$CONTAINER" sed -i -E "s/^(\\s*SecRuleEngine)\\s+.*/\\1 ${newval}/" "$CFG"
docker exec "$CONTAINER" apache2ctl graceful
echo "Apache reloaded. New state:"
docker exec "$CONTAINER" grep -E '^\s*SecRuleEngine' "$CFG"
