FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 iputils-ping curl dnsutils traceroute net-tools \
    && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash", "-c", "ip route replace default via 192.168.1.1 2>/dev/null; sleep infinity"]
