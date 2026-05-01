FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# LAMP + ModSecurity + tooling (curl/ss/openssl/git for the entrypoint to
# clone DVWA and for lab test scripts).
RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2 \
        libapache2-mod-php \
        libapache2-mod-security2 \
        modsecurity-crs \
        mariadb-server \
        php php-mysql php-cli php-curl php-gd php-xml php-mbstring \
        git curl iproute2 iputils-ping openssl ca-certificates nano \
    && rm -rf /var/lib/apt/lists/*

# Clone DVWA into the Apache docroot at build time so the container starts
# with the application already on disk.
RUN git clone --depth 1 https://github.com/digininja/DVWA.git /var/www/html/DVWA \
    && chown -R www-data:www-data /var/www/html/DVWA \
    && chmod -R 755 /var/www/html/DVWA

# DVWA configuration (matches Lab 5 — dvwa/password)
COPY config.inc.php /var/www/html/DVWA/config/config.inc.php

# Simple landing page at / so the existing DMZ firewall tests still pass.
COPY index.html /var/www/html/index.html

# Apache site + TLS virtual host
COPY default.conf /etc/apache2/sites-available/000-default.conf

# Enable required Apache modules (mod_security was installed above but
# needs a2enmod; mod_ssl and rewrite for DVWA HTTPS + friendly URLs).
RUN a2enmod security2 ssl rewrite headers

# OWASP CRS linkage (Lab 9, Step 4 — modsecurity-crs package ships rules
# under /usr/share/modsecurity-crs, wire them into ModSecurity).
COPY zzz-overrides.conf /etc/modsecurity/zzz-overrides.conf

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80 443

CMD ["/usr/local/bin/entrypoint.sh"]
