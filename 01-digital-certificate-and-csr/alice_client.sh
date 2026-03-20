#!/bin/bash
# =============================================================================
# Alice (Client) - Digital Certificate & CSR Lab Script
# =============================================================================
# This script simulates Alice's role in a Public Key Infrastructure (PKI) lab.
# Alice is the end-user requesting a digital certificate from Bob (the CA).
#
# Workflow:
#   Step 1: Generate a 2048-bit RSA private key (AES-256 encrypted)
#   Step 2: Create a CSR (Certificate Signing Request) using the private key
#   Step 3: Email the CSR to Bob (the CA) for signing
#   Step 4: Verify the signed certificate (user_cert.crt) received from Bob
#
# Prerequisites:
#   - openssl     : For key generation, CSR creation, and certificate verification
#   - python3     : Required for sending emails via send_email.py
#   - .env file   : SMTP credentials (SMTP_SERVER, SMTP_PORT, SMTP_USER, SMTP_PASSWORD)
#
# Generated files (in ../certs/):
#   - user_private.key  : Alice's encrypted private key (keep secret!)
#   - user_request.csr  : Certificate Signing Request (sent to Bob)
#
# Expected files from Bob (in ../certs/):
#   - user_cert.crt     : Signed certificate
#   - ca.crt            : CA root certificate (for trust chain verification)
#
# Usage:
#   chmod +x alice_client.sh
#   ./alice_client.sh
# =============================================================================

# Resolve the directory where this script lives and the project root (one level up)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CERTS_DIR="$PROJECT_ROOT/certs"

# Load SMTP configuration from .env file (needed for Step 3: emailing the CSR)
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
echo "  Alice (Client) - Digital Certificate Lab"
echo "=============================================="
echo ""

while true; do
    echo "Select a step to run:"
    echo "  1) Generate Private Key"
    echo "  2) Generate CSR (Certificate Signing Request)"
    echo "  3) Email CSR to Bob (CA)"
    echo "  4) Verify Signed Certificate from Bob"
    echo "  q) Quit"
    echo ""
    read -p "Enter choice [1-4, q]: " choice
    echo ""

    case $choice in
        1)
            echo "--- Step 1: Generate Private Key ---"
            echo ""
            echo "This generates a password-protected 2048-bit RSA private key."
            echo "You will be prompted to set a passphrase. Remember it!"
            echo ""
            if ! openssl genpkey -algorithm RSA -out "$CERTS_DIR/user_private.key" -aes256; then
                echo ""
                echo "ERROR: Failed to generate private key. Make sure passphrase is at least 4 characters."
                echo ""
                continue
            fi
            echo ""
            echo "Private key saved to: $CERTS_DIR/user_private.key"
            echo "IMPORTANT: Keep this file private and secure. Never share it!"
            echo ""
            ;;
        2)
            echo "--- Step 2: Generate CSR (Certificate Signing Request) ---"
            echo ""
            if [ ! -f "$CERTS_DIR/user_private.key" ]; then
                echo "ERROR: user_private.key not found in $CERTS_DIR. Run Step 1 first."
                echo ""
                continue
            fi
            echo "This creates a CSR containing your public key and identity info."
            echo "You will be prompted for identity details. Use these values:"
            echo "  Country Name:            RW"
            echo "  State:                   Kigali"
            echo "  Locality:                Gisozi"
            echo "  Organization:            ULK"
            echo "  Organizational Unit:     ICT Dept"
            echo "  Common Name:             user.local"
            echo "  Email Address:           user@example.com"
            echo ""
            if ! openssl req -new -key "$CERTS_DIR/user_private.key" -out "$CERTS_DIR/user_request.csr"; then
                echo ""
                echo "ERROR: Failed to generate CSR."
                echo ""
                continue
            fi
            echo ""
            echo "CSR saved to: $CERTS_DIR/user_request.csr"
            echo ""
            read -p "Would you like to view the CSR details? [y/n]: " view_csr
            if [ "$view_csr" = "y" ] || [ "$view_csr" = "Y" ]; then
                echo ""
                openssl req -in "$CERTS_DIR/user_request.csr" -noout -text
            fi
            echo ""
            ;;
        3)
            echo "--- Step 3: Email CSR to Bob (CA) ---"
            echo ""
            if [ ! -f "$CERTS_DIR/user_request.csr" ]; then
                echo "ERROR: user_request.csr not found in $CERTS_DIR. Run Step 2 first."
                echo ""
                continue
            fi
            echo "This will send user_request.csr to Bob (the CA) via email."
            echo ""
            read -p "Enter Bob's (CA) email address: " bob_email
            if [ -z "$bob_email" ]; then
                echo "ERROR: No email address provided."
                echo ""
                continue
            fi
            echo ""
            echo "Sending CSR to $bob_email..."
            python3 "$PROJECT_ROOT/send_email.py" \
                --to "$bob_email" \
                --subject "Certificate Signing Request" \
                --body "Hello, please find attached my CSR for digital certificate issuance. Regards, Alice." \
                --attach "$CERTS_DIR/user_request.csr"
            echo ""
            echo "After Bob signs the CSR, he will reply with:"
            echo "  - user_cert.crt (your signed certificate)"
            echo "  - ca.crt (CA root certificate for verification)"
            echo ""
            echo "Save both files in this directory, then run Step 4."
            echo ""
            ;;
        4)
            echo "--- Step 4: Verify the Signed Certificate ---"
            echo ""
            if [ ! -f "$CERTS_DIR/user_cert.crt" ]; then
                echo "ERROR: user_cert.crt not found in $CERTS_DIR."
                echo "Save the signed certificate from Bob in $CERTS_DIR first."
                echo ""
                continue
            fi
            if [ ! -f "$CERTS_DIR/ca.crt" ]; then
                echo "ERROR: ca.crt not found in $CERTS_DIR."
                echo "Save the CA certificate from Bob in $CERTS_DIR first."
                echo ""
                continue
            fi

            echo "(a) Certificate Details:"
            echo "========================"
            openssl x509 -in "$CERTS_DIR/user_cert.crt" -text -noout
            echo ""
            echo "Confirm the following:"
            echo "  - Subject matches the details you submitted in the CSR"
            echo "  - Issuer matches Bob's CA info"
            echo "  - Validity period is one year"
            echo "  - Public Key Info is present"
            echo ""

            echo "(b) Verify Trust Chain:"
            echo "======================="
            openssl verify -CAfile "$CERTS_DIR/ca.crt" "$CERTS_DIR/user_cert.crt"
            echo ""
            echo "If the output says 'user_cert.crt: OK', the certificate is valid"
            echo "and trusted by the CA."
            echo ""
            ;;
        q|Q)
            echo "Goodbye, Alice!"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter 1-4 or q."
            echo ""
            ;;
    esac
done
