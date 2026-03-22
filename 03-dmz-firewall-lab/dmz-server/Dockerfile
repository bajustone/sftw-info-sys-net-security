FROM nginx:1.29.6-alpine

RUN apk add --no-cache iproute2 bash curl iputils

COPY index.html /usr/share/nginx/html/index.html

CMD ["/bin/sh", "-c", "ip route replace default via 192.168.2.1 2>/dev/null; nginx -g 'daemon off;'"]
