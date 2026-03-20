#!/bin/bash
# =============================================================================
# Bob (Certificate Authority) - Digital Certificate & CSR Lab Script
# =============================================================================
# This script simulates Bob's role as a Certificate Authority (CA) in a PKI lab.
# Bob is responsible for issuing and signing digital certificates.
#
# Workflow:
#   Step 1: Generate the CA's RSA private key (root of trust)
#   Step 2: Create a self-signed root CA certificate (valid for 5 years)
#   Step 3: Sign Alice's CSR to produce a trusted certificate (valid for 1 year)
#   Step 4: Email the signed certificate and CA cert back to Alice
#
# Prerequisites:
#   - openssl     : For key generation, certificate creation, and CSR signing
#   - python3     : Required for sending emails via send_email.py
#   - .env file   : SMTP credentials (SMTP_SERVER, SMTP_PORT, SMTP_USER, SMTP_PASSWORD)
#
# Generated files (in ../certs/):
#   - ca.key            : CA private key (root of trust — keep highly secure!)
#   - ca.crt            : Self-signed CA root certificate (distributed to clients)
#   - ca.srl            : Serial number file (auto-generated, tracks issued certs)
#   - user_cert.crt     : Alice's signed certificate (produced in Step 3)
#
# Expected file from Alice (in ../certs/):
#   - user_request.csr  : Alice's Certificate Signing Request
#
# Usage:
#   chmod +x bob_ca.sh
#   ./bob_ca.sh
# =============================================================================

# Resolve the directory where this script lives and the project root (one level up)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CERTS_DIR="$PROJECT_ROOT/certs"

# Load SMTP configuration from .env file (needed for Step 4: emailing the signed cert)
if [ -f "$PROJECT_ROOT/.env" ]; then
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line%"${line##*[! ]}"}"
        [[ -z "$line" ]] && continue
        export "$line"
    done < "$PROJECT_ROOT/.env"
else
    echo "WARNING: .env file not found. Email sending will not work."
    echo "Create a .env file with SMTP_SERVER, SMTP_PORT, SMTP_USER, SMTP_PASSWORD."
    echo ""
fi

echo "=============================================="
echo "  Bob (CA) - Digital Certificate Lab"
echo "=============================================="
echo ""

while true; do
    echo "Select a step to run:"
    echo "  1) Generate CA Private Key"
    echo "  2) Generate Self-Signed Root Certificate"
    echo "  3) Sign Alice's CSR"
    echo "  4) Email Signed Certificate to Alice"
    echo "  q) Quit"
    echo ""
    read -p "Enter choice [1-4, q]: " choice
    echo ""

    case $choice in
        1)
            echo "--- Step 1: Generate CA Private Key ---"
            echo ""
            echo "This generates the CA's RSA private key."
            echo ""
            if ! openssl genpkey -algorithm RSA -out "$CERTS_DIR/ca.key"; then
                echo ""
                echo "ERROR: Failed to generate CA private key."
                echo ""
                continue
            fi
            echo ""
            echo "CA private key saved to: $CERTS_DIR/ca.key"
            echo "IMPORTANT: This key is the root of trust. Keep it secure!"
            echo ""
            ;;
        2)
            echo "--- Step 2: Generate Self-Signed Root Certificate ---"
            echo ""
            if [ ! -f "$CERTS_DIR/ca.key" ]; then
                echo "ERROR: ca.key not found in $CERTS_DIR. Run Step 1 first."
                echo ""
                continue
            fi
            echo "This creates a self-signed root CA certificate (valid for 5 years)."
            echo "You will be prompted for CA identity details. Use these values:"
            echo "  Country Name:            RW"
            echo "  State:                   Kigali"
            echo "  Locality:                Nyarugenge"
            echo "  Organization:            RISA"
            echo "  Organizational Unit:     Digital certificate office"
            echo "  Common Name:             RISA-CA"
            echo "  Email Address:           ca@example.com"
            echo ""
            if ! openssl req -x509 -new -nodes -key "$CERTS_DIR/ca.key" -sha256 -days 1825 -out "$CERTS_DIR/ca.crt"; then
                echo ""
                echo "ERROR: Failed to generate CA certificate."
                echo ""
                continue
            fi
            echo ""
            echo "CA root certificate saved to: $CERTS_DIR/ca.crt"
            echo "This is the trusted root certificate used to sign others."
            echo ""
            read -p "Would you like to view the CA certificate details? [y/n]: " view_ca
            if [ "$view_ca" = "y" ] || [ "$view_ca" = "Y" ]; then
                echo ""
                openssl x509 -in "$CERTS_DIR/ca.crt" -text -noout
            fi
            echo ""
            ;;
        3)
            echo "--- Step 3: Sign Alice's CSR ---"
            echo ""
            if [ ! -f "$CERTS_DIR/ca.key" ]; then
                echo "ERROR: ca.key not found in $CERTS_DIR. Run Step 1 first."
                echo ""
                continue
            fi
            if [ ! -f "$CERTS_DIR/ca.crt" ]; then
                echo "ERROR: ca.crt not found in $CERTS_DIR. Run Step 2 first."
                echo ""
                continue
            fi
            if [ ! -f "$CERTS_DIR/user_request.csr" ]; then
                echo "ERROR: user_request.csr not found in $CERTS_DIR."
                echo "Save Alice's CSR file (received via email) in $CERTS_DIR first."
                echo ""
                continue
            fi

            echo "Signing Alice's CSR with the CA certificate..."
            echo "The signed certificate will be valid for 1 year (365 days)."
            echo ""
            if ! openssl x509 -req -in "$CERTS_DIR/user_request.csr" -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" \
                -CAcreateserial -out "$CERTS_DIR/user_cert.crt" -days 365 -sha256; then
                echo ""
                echo "ERROR: Failed to sign the CSR."
                echo ""
                continue
            fi
            echo ""
            echo "Signed certificate saved to: $CERTS_DIR/user_cert.crt"
            echo ""
            ;;
        4)
            echo "--- Step 4: Email Signed Certificate to Alice ---"
            echo ""
            if [ ! -f "$CERTS_DIR/user_cert.crt" ]; then
                echo "ERROR: user_cert.crt not found in $CERTS_DIR. Run Step 3 first."
                echo ""
                continue
            fi
            if [ ! -f "$CERTS_DIR/ca.crt" ]; then
                echo "ERROR: ca.crt not found in $CERTS_DIR. Run Step 2 first."
                echo ""
                continue
            fi
            echo "This will send user_cert.crt and ca.crt to Alice via email."
            echo ""
            read -p "Enter Alice's email address: " alice_email
            if [ -z "$alice_email" ]; then
                echo "ERROR: No email address provided."
                echo ""
                continue
            fi
            echo ""
            echo "Sending signed certificate and CA certificate to $alice_email..."
            python3 "$PROJECT_ROOT/send_email.py" \
                --to "$alice_email" \
                --subject "Your Signed Certificate" \
                --body "Hello, please find attached your signed certificate and our CA certificate. Regards, Bob (CA)." \
                --attach "$CERTS_DIR/user_cert.crt" "$CERTS_DIR/ca.crt"
            echo ""
            echo "Alice will use ca.crt to verify the trust chain of user_cert.crt."
            echo ""
            ;;
        q|Q)
            echo "Goodbye, Bob!"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter 1-4 or q."
            echo ""
            ;;
    esac
done
