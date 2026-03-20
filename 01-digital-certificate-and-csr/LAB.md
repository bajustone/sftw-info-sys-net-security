# Lab: Simulating Digital Certificates & CSR Generation via Email using OpenSSL (Kali Linux)

## Objective

By the end of this lab, students will be able to:

- Understand the purpose and structure of digital certificates and CSRs
- Generate a private/public key pair
- Create and email a CSR to a Certificate Authority
- Simulate a Certificate Authority (CA) by signing the CSR and returning the signed certificate
- Verify the authenticity and trust chain of the certificate
- Use email to mimic real-world secure certificate issuance and sharing

## Requirements

- **Kali Linux** (OpenSSL pre-installed)
- **Two students** (or terminals):
  - **Alice** (Client/User): Requests and uses a digital certificate
  - **Bob** (CA): Acts as Certificate Authority to issue certificates
- Valid email accounts for both students (e.g., Gmail, Outlook, etc.)
- Internet access (for email exchange)
- A text editor (e.g., nano, vim, gedit)

## Background Theory

This lab mirrors how real-world Public Key Infrastructure (PKI) works:

1. A client generates a private/public key pair
2. A CSR is generated and sent to the CA via email
3. The CA verifies the request, signs the CSR, and sends back a digital certificate
4. The client installs and verifies the certificate using the CA's certificate

## Lab Procedure

### Step 1: Alice — Generate Private Key (Client)

```bash
openssl genpkey -algorithm RSA -out user_private.key -aes256
```

**Explanation:**
- Generates a password-protected private key (2048-bit RSA)
- Save it as `user_private.key`. Keep it private and secure

### Step 2: Alice — Generate a CSR (Certificate Signing Request)

```bash
openssl req -new -key user_private.key -out user_request.csr
```

During the prompts, enter values like:

| Field                 | Value            |
|-----------------------|------------------|
| Country Name          | RW               |
| State                 | Kigali           |
| Locality              | Gisozi           |
| Organization          | ULK              |
| Organizational Unit   | ICT Dept         |
| Common Name           | user.local       |
| Email Address         | user@example.com |

**Output File:** `user_request.csr` — contains public key + identity to be signed by the CA.

**Optional:** To view the public key inside the CSR:

```bash
openssl req -in user_request.csr -noout -text
```

### Step 3: Alice — Email CSR to Bob

Use your email client and attach `user_request.csr`:

- **To:** ca@example.com
- **Subject:** Certificate Signing Request
- **Body:** Hello, please find attached my CSR for digital certificate issuance. Regards, Alice.

### Step 4: Bob — Simulate a Certificate Authority (CA)

**(a) Generate the CA's Private Key:**

```bash
openssl genpkey -algorithm RSA -out ca.key
```

**(b) Generate a Self-Signed Root Certificate (CA Certificate):**

```bash
openssl req -x509 -new -nodes -key ca.key -sha256 -days 1825 -out ca.crt
```

When prompted, enter:

| Field                 | Value                      |
|-----------------------|----------------------------|
| Country Name          | RW                         |
| State                 | Kigali                     |
| Locality              | Nyarugenge                 |
| Organization          | RISA                       |
| Organizational Unit   | Digital certificate office |
| Common Name           | RISA-CA                    |
| Email Address         | ca@example.com             |

**Output File:** `ca.crt` — the trusted root certificate used to sign others. Valid for 5 years.

### Step 5: Bob — Sign the CSR and Generate a Certificate

Save the received file (from Alice) as `user_request.csr`, then:

```bash
openssl x509 -req -in user_request.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out user_cert.crt -days 365 -sha256
```

**Output:** `user_cert.crt` (signed certificate for Alice) — valid for 1 year, issued by CA.

### Step 6: Bob — Email the Signed Certificate & CA Certificate Back

Reply via email and attach:

- `user_cert.crt` (Alice's signed certificate)
- `ca.crt` (Root CA certificate for verification)

**To:** user@example.com
**Subject:** Your Signed Certificate
**Body:** Hello, please find attached your signed certificate and our CA certificate. Regards, Bob (CA).

**Optional:** View CA Certificate:

```bash
openssl x509 -in ca.crt -text -noout
```

### Step 7: Alice — Verify the Certificate

Save the received files as `user_cert.crt` and `ca.crt`.

**(a) Check Certificate Details:**

```bash
openssl x509 -in user_cert.crt -text -noout
```

Confirm:
- **Subject:** Matches the details submitted
- **Issuer:** Matches CA info
- **Validity:** One year
- **Public Key Info:** Present

**(b) Verify the Trust Chain:**

```bash
openssl verify -CAfile ca.crt user_cert.crt
```

**Expected Output:**

```
user_cert.crt: OK
```

## Learning Outcomes and Concepts

| Activity                    | Concept                          |
|-----------------------------|----------------------------------|
| Private key generation      | Confidentiality and ownership    |
| CSR creation                | Identity and public key sharing  |
| Email transfer of CSR       | Secure request submission        |
| CA key & self-signed cert   | Root of trust                    |
| Signing CSR                 | Authentication and trust issuance|
| Certificate verification    | Trust chain validation           |
| Email return                | Real-world secure communication  |

## Discussion Questions

1. What risks are there if a CSR is intercepted during email transmission?
2. Why must the private key never be emailed or shared?
3. What is the importance of verifying the CA's certificate?
4. Why is a certificate only valid for a certain period?
5. What are the implications if a CA's private key is compromised?

## File Exchanges

| File              | From  | To    | Purpose                               |
|-------------------|-------|-------|---------------------------------------|
| user_request.csr  | Alice | Bob   | Certificate Signing Request           |
| user_cert.crt     | Bob   | Alice | Signed user certificate               |
| ca.crt            | Bob   | Alice | CA root certificate for verification  |
