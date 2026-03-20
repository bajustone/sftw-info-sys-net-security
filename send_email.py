#!/usr/bin/env python3
"""
Send an email with file attachments via SMTP.

This utility is used by alice_client.sh and bob_ca.sh to exchange certificate
files (CSRs, signed certificates, CA certs) between Alice and Bob during the
PKI lab workflow.

Environment Variables (loaded from .env by the calling shell scripts):
    SMTP_SERVER   : SMTP server hostname (e.g., smtp.gmail.com)
    SMTP_PORT     : SMTP server port (e.g., 587 for STARTTLS)
    SMTP_USER     : SMTP login username / email address
    SMTP_PASSWORD : SMTP login password or app-specific password
    SMTP_FROM     : (Optional) Sender address, defaults to SMTP_USER

Usage:
    python3 send_email.py --to <recipient> --subject <subject> --body <body> --attach file1 [file2 ...]

Examples:
    # Alice sends her CSR to Bob
    python3 send_email.py --to bob@example.com --subject "CSR" --body "Please sign" --attach user_request.csr

    # Bob sends signed cert and CA cert back to Alice
    python3 send_email.py --to alice@example.com --subject "Signed Cert" --body "Here you go" --attach user_cert.crt ca.crt
"""

import argparse
import os
import smtplib
import sys
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


def send_email(to_addr, subject, body, attachments):
    """Send an email with file attachments over SMTP with STARTTLS encryption."""
    smtp_server = os.environ.get("SMTP_SERVER")
    smtp_port = os.environ.get("SMTP_PORT")
    smtp_user = os.environ.get("SMTP_USER")
    smtp_password = os.environ.get("SMTP_PASSWORD")
    smtp_from = os.environ.get("SMTP_FROM", smtp_user)

    if not all([smtp_server, smtp_port, smtp_user, smtp_password]):
        print("ERROR: Missing SMTP configuration. Check your .env file.")
        print("Required: SMTP_SERVER, SMTP_PORT, SMTP_USER, SMTP_PASSWORD")
        sys.exit(1)

    msg = MIMEMultipart()
    msg["From"] = smtp_from
    msg["To"] = to_addr
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain"))

    for filepath in attachments:
        if not os.path.isfile(filepath):
            print(f"ERROR: Attachment not found: {filepath}")
            sys.exit(1)
        filename = os.path.basename(filepath)
        with open(filepath, "rb") as f:
            part = MIMEApplication(f.read(), Name=filename)
        part["Content-Disposition"] = f'attachment; filename="{filename}"'
        msg.attach(part)

    try:
        with smtplib.SMTP(smtp_server, int(smtp_port)) as server:
            server.starttls()
            server.login(smtp_user, smtp_password)
            server.sendmail(smtp_from, to_addr, msg.as_string())
        print(f"Email sent successfully to {to_addr}")
    except Exception as e:
        print(f"ERROR: Failed to send email: {e}")
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Send email with attachments via SMTP")
    parser.add_argument("--to", required=True, help="Recipient email address")
    parser.add_argument("--subject", required=True, help="Email subject")
    parser.add_argument("--body", required=True, help="Email body text")
    parser.add_argument("--attach", nargs="+", required=True, help="File(s) to attach")
    args = parser.parse_args()

    send_email(args.to, args.subject, args.body, args.attach)
