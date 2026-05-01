#!/bin/bash
# dmz-server entrypoint: start MariaDB, seed DVWA, start Apache with ModSecurity.
set -e

# 1. Default route via firewall (keeps Lab 4 behavior: server reaches internet through DMZ gateway)
ip route replace default via 192.168.2.1 2>/dev/null || true

# Docker Desktop publishes host-origin traffic with source 192.168.65.1 (Mac) and
# 172.16/12 ranges (Docker's default bridge on Linux). Route replies to those
# networks *directly* back out the DMZ bridge gateway — otherwise they get
# black-holed through our simulated firewall's WAN masquerade and the Mac never
# sees the response. Symptom when omitted: browser hangs then "Empty reply".
for _ in 1 2 3 4 5; do
    ip route replace 192.168.65.0/24 via 192.168.2.254 dev eth0 2>/dev/null || true
    ip route replace 172.16.0.0/12  via 192.168.2.254 dev eth0 2>/dev/null || true
    ip route show 192.168.65.0/24 | grep -q via && break
    sleep 1
done

# 2. Self-signed TLS (Lab 4/6 uses HTTPS access to DVWA)
mkdir -p /etc/ssl/private
if [ ! -f /etc/ssl/certs/dmz-server.crt ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/dmz-server.key \
        -out /etc/ssl/certs/dmz-server.crt \
        -subj '/CN=dmz-server' 2>/dev/null
fi

# 3. PHP info page (Lab 4, Step 6 — phpinfo() for verification)
cat > /var/www/html/info.php <<'PHP'
<?php phpinfo(); ?>
PHP

# 4. Start MariaDB (Lab 4, Step 4)
mkdir -p /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/run/mysqld /var/log/mysql /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --auth-root-authentication-method=normal >/dev/null 2>&1 || \
    mysql_install_db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || true
fi

mysqld --user=mysql --datadir=/var/lib/mysql &
MYSQLD_PID=$!

# Wait for MariaDB to accept connections
for i in $(seq 1 30); do
    if mysqladmin ping --silent 2>/dev/null; then
        break
    fi
    sleep 1
done

# 5. DVWA schema + user (Lab 5, Step 5)
mysql <<'SQL'
CREATE DATABASE IF NOT EXISTS dvwa;
CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'password';
CREATE USER IF NOT EXISTS 'dvwa'@'127.0.0.1' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

# 6. ModSecurity engine state — env var SECRULEENGINE controls DetectionOnly / On / Off.
#    Ubuntu's security2.conf already IncludeOptional's /etc/modsecurity/*.conf, so
#    our zzz-overrides.conf is loaded automatically — no extra wiring needed.
SECRULEENGINE="${SECRULEENGINE:-DetectionOnly}"
sed -i "s/SECRULEENGINE_PLACEHOLDER/${SECRULEENGINE}/g" /etc/modsecurity/zzz-overrides.conf
if [ ! -f /etc/modsecurity/modsecurity.conf ] && [ -f /etc/modsecurity/modsecurity.conf-recommended ]; then
    cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
fi

echo "=== dmz-server ready ==="
echo "  DVWA:       http://192.168.2.100/DVWA/ (admin/password)"
echo "  PHP info:   http://192.168.2.100/info.php"
echo "  ModSecurity: SecRuleEngine=${SECRULEENGINE}"
echo "  Toggle WAF: bash toggle-waf.sh [on|off|detect]  (from host)"

# 7. Auto-initialize DVWA database on first boot (Lab 5, Step 8 — Create/Reset DB)
#    setup.php POST with the user_token from setup.php GET creates all tables.
(
    sleep 4
    apache2ctl start 2>/dev/null || true
    sleep 2
    COOKIE=$(mktemp)
    TOKEN=$(curl -s -c "$COOKIE" "http://127.0.0.1/DVWA/setup.php" \
        | grep -oP "user_token' value='\K[0-9a-f]+" | head -1)
    if [ -n "$TOKEN" ]; then
        curl -s -b "$COOKIE" -c "$COOKIE" \
            -d "create_db=Create+%2F+Reset+Database&user_token=${TOKEN}" \
            "http://127.0.0.1/DVWA/setup.php" > /dev/null || true
        echo "DVWA database initialized."
    fi
    rm -f "$COOKIE"
) &

# 8. Apache in foreground
exec apache2ctl -D FOREGROUND
