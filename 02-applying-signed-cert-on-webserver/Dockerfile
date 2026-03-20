# Apache HTTPS Web Server with SSL/TLS
# Configures Apache httpd to serve over HTTPS using a signed user certificate.
#
# Certificate files are mounted at runtime via docker-compose (not baked into the image):
#   - /etc/ssl/certs/user_cert.crt    (signed server certificate)
#   - /etc/ssl/private/user_private.key (private key, must be unencrypted)
#   - /etc/ssl/certs/ca.crt            (CA root certificate for chain of trust)
#
# Usage:
#   docker compose up --build
#
# Test:
#   curl -vk https://localhost
#   openssl s_client -connect localhost:443 -CAfile certs/ca.crt

FROM httpd:2.4

# Install SSL support package
RUN apt-get update && apt-get install -y ssl-cert && rm -rf /var/lib/apt/lists/*

# Enable required Apache modules (ssl, socache_shmcb) and include the SSL config
RUN sed -i \
    -e 's/^#LoadModule ssl_module/LoadModule ssl_module/' \
    -e 's/^#LoadModule socache_shmcb_module/LoadModule socache_shmcb_module/' \
    -e 's/^#Include conf\/extra\/httpd-ssl.conf/Include conf\/extra\/httpd-ssl.conf/' \
    conf/httpd.conf

# Point SSL config to the certificate and key paths where volumes will be mounted
RUN sed -i \
    -e 's|SSLCertificateFile.*|SSLCertificateFile "/etc/ssl/certs/user_cert.crt"|' \
    -e 's|SSLCertificateKeyFile.*|SSLCertificateKeyFile "/etc/ssl/private/user_private.key"|' \
    conf/extra/httpd-ssl.conf

# Add the CA certificate chain so clients can verify the full trust path
RUN echo 'SSLCertificateChainFile "/etc/ssl/certs/ca.crt"' >> conf/extra/httpd-ssl.conf

EXPOSE 443
