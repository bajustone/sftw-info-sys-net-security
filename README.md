# Information and Network Security

Lab assignments for the MSE Information and Network Security course.

## Project Structure

```
.
├── certs/                              # Shared certificate files
│   ├── ca.crt                          # CA root certificate
│   ├── ca.key                          # CA private key
│   ├── ca.srl                          # CA serial number tracker
│   ├── user_cert.crt                   # Signed user certificate
│   ├── user_private.key                # User private key
│   └── user_request.csr               # Certificate Signing Request
├── send_email.py                       # Shared SMTP email utility
├── .env                                # SMTP credentials (not committed)
│
├── 01-digital-certificate-and-csr/     # Assignment 1
│   ├── LAB.md                          # Lab instructions
│   ├── alice_client.sh                 # Alice (client) interactive script
│   └── bob_ca.sh                       # Bob (CA) interactive script
│
└── 02-applying-signed-cert-on-webserver/  # Assignment 2
    ├── LAB.md                          # Lab instructions
    ├── Dockerfile                      # Apache HTTPS server image
    └── docker-compose.yml              # Container orchestration
```

## Assignments

### 01 — Digital Certificate and CSR

Simulates a PKI workflow between two parties (Alice and Bob) using OpenSSL. Alice generates a private key and CSR, emails it to Bob (the CA), who signs it and returns a certificate. Both roles are automated via interactive shell scripts.

```bash
cd 01-digital-certificate-and-csr
./alice_client.sh   # Run as Alice (client)
./bob_ca.sh         # Run as Bob (CA)
```

### 02 — Applying a Signed Certificate on a Web Server

Configures an Apache web server with SSL/TLS using the signed certificate from Assignment 1. Runs in Docker for easy setup.

```bash
cd 02-applying-signed-cert-on-webserver
docker compose up --build
```

Verify:

```bash
curl -vk https://localhost
openssl s_client -connect localhost:443 -CAfile ../certs/ca.crt
```

## Prerequisites

- OpenSSL
- Python 3 (for email functionality)
- Docker & Docker Compose (for Assignment 2)

## Email Configuration

Create a `.env` file in the project root with your SMTP credentials:

```
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_password
```
