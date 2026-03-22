FROM alpine:3.19

RUN apk add --no-cache iptables ip6tables iproute2 bash tcpdump curl bind-tools

COPY iptables.sh /opt/iptables.sh
RUN chmod +x /opt/iptables.sh

CMD ["/bin/bash", "-c", "/opt/iptables.sh && tail -f /dev/null"]
