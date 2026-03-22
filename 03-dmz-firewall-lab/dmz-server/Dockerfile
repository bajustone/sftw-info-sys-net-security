FROM nginx:1.29.6-alpine

RUN apk add --no-cache iproute2 bash curl iputils openssl

COPY index.html /usr/share/nginx/html/index.html
COPY default.conf /etc/nginx/conf.d/default.conf

CMD ["/bin/sh", "-c", "\
    ip route replace default via 192.168.2.1 2>/dev/null; \
    mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/server.key \
        -out /etc/nginx/ssl/server.crt \
        -subj '/CN=dmz-server' 2>/dev/null; \
    nginx -g 'daemon off;'"]
