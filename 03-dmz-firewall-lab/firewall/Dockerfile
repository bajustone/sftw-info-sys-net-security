FROM alpine:3.19

RUN apk add --no-cache iptables ip6tables ipset iproute2 bash tcpdump curl bind-tools jq \
    suricata

COPY iptables.sh /opt/iptables.sh
RUN chmod +x /opt/iptables.sh

# Suricata IDS configuration
COPY suricata.yaml /etc/suricata/suricata.yaml
COPY custom.rules /etc/suricata/rules/custom.rules
COPY start-suricata.sh /opt/start-suricata.sh
COPY block-offenders.sh /opt/block-offenders.sh
RUN chmod +x /opt/start-suricata.sh /opt/block-offenders.sh
RUN mkdir -p /var/log/suricata /var/lib/suricata/rules

CMD ["/bin/bash", "-c", "/opt/iptables.sh && /opt/start-suricata.sh && tail -f /dev/null"]
