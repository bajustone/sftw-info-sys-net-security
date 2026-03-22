FROM kalilinux/kali-rolling

RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 iputils-ping curl nmap net-tools dnsutils \
    && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash", "-c", "ip route replace default via 10.0.0.2 2>/dev/null; sleep infinity"]
