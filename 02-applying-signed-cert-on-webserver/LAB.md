# Lab: Applying a Signed User Certificate (user_cert.crt) on a Web Server

## Objective

Apply and test a signed user certificate on an Apache web server to secure communication over HTTPS and validate certificate trust.

## Lab Scenario

You're a system administrator with a signed certificate and private key. You'll configure Apache to use the certificate and validate secure HTTPS connections.

## Pre-requisites

- Kali Linux with internet access
- Apache2 installed
- Files available:
  - `user_cert.crt` (signed certificate)
  - `user_private.key` (private key)
  - `ca.crt` (certificate authority root certificate)

## Lab Steps and Expected Outputs

### Step 1: Install Required Packages

```bash
sudo apt update
sudo apt install apache2 openssl -y
```

**Expected Output:**

```
Reading package lists... Done
Building dependency tree... Done
...
Setting up apache2 ...
Setting up openssl ...
```

### Step 2: Enable SSL in Apache

```bash
sudo a2enmod ssl
sudo systemctl restart apache2
```

**Expected Output:**

```
Enabling module ssl.
To activate the new configuration, you need to run:
systemctl restart apache2
```

No error message on restart (`systemctl restart apache2`) confirms success.

### Step 3: Move Certificate Files

```bash
sudo cp user_cert.crt /etc/ssl/certs/
sudo cp user_private.key /etc/ssl/private/
sudo cp ca.crt /etc/ssl/certs/
sudo chmod 600 /etc/ssl/private/user_private.key
```

**Expected Output:** No output means success (silence is golden in Unix/Linux).

Confirm file placement:

```bash
ls -l /etc/ssl/private/user_private.key
```

Should return:

```
-rw------- 1 root root 1704 Apr 14 10:15 /etc/ssl/private/user_private.key
```

### Step 4: Configure Apache to Use the Certificate

```bash
sudo nano /etc/apache2/sites-available/default-ssl.conf
```

Update these lines (or add them under `<VirtualHost _default_:443>`):

```apache
SSLEngine on
SSLCertificateFile      /etc/ssl/certs/user_cert.crt
SSLCertificateKeyFile   /etc/ssl/private/user_private.key
SSLCertificateChainFile /etc/ssl/certs/ca.crt
```

**Expected Output:** No terminal output. Save and close the file (`CTRL+O`, Enter, `CTRL+X`).

### Step 5: Enable HTTPS Site and Reload Apache

```bash
sudo a2ensite default-ssl
sudo systemctl reload apache2
```

**Expected Output:**

```
Enabling site default-ssl.
To activate the new configuration, you need to run:
  systemctl reload apache2
```

Check with:

```bash
sudo systemctl status apache2
```

Should include: `Active: active (running)`

### Step 6: Test HTTPS with Curl

```bash
curl -vk https://localhost
```

**Expected Output:**

```
*   Trying 127.0.0.1:443...
* Connected to localhost (127.0.0.1) port 443
* SSL connection using TLSv1.3
* Server certificate:
*  subject: CN=Your Common Name
*  start date: ...
*  expire date: ...
*  issuer: CN=TestCA
*  SSL certificate verify ok.
> GET / HTTP/1.1
> Host: localhost
...
< HTTP/1.1 200 OK
< Content-Type: text/html
```

### Step 7: Verify the Certificate with OpenSSL

```bash
openssl s_client -connect localhost:443 -CAfile /etc/ssl/certs/ca.crt
```

**Expected Output:**

```
CONNECTED(00000003)
depth=1 CN=TestCA
verify return:1
depth=0 CN=Your Common Name
verify return:1
---
Certificate chain
 0 s:CN = Your Common Name
   i:CN = TestCA
---
SSL handshake has read XXX bytes and written XXX bytes
---
New, TLSv1.3, Cipher is ...
---
SSL-Session:
    Protocol  : TLSv1.3
    Cipher    : ...
    Verify return code: 0 (ok)
```

### Step 8 (Optional): View Certificate Details

```bash
openssl x509 -in /etc/ssl/certs/user_cert.crt -text -noout
```

**Expected Output:**

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: ...
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=TestCA
        Validity
            Not Before: Apr 14 09:00:00 2025 GMT
            Not After : Apr 14 09:00:00 2026 GMT
        Subject: CN=Your Common Name
        ...
```

## Summary of What You Learned

| Task                        | Real-World Use                        |
|-----------------------------|---------------------------------------|
| Apache + SSL setup          | Enables secure websites (HTTPS)       |
| Certificate integration     | Authenticates server identity         |
| curl, openssl s_client      | Verifies server certificate and trust |
| Permissions (chmod 600)     | Protects sensitive private keys       |

## Discussion Questions

1. Why must the private key file be secured with `chmod 600`?
2. What role does the CA (`ca.crt`) play in trusting a server?
3. What happens when the certificate is expired or not yet valid?
4. How would you prevent MITM (man-in-the-middle) attacks?

## Optional Advanced Tasks

- Import `ca.crt` into Firefox (Trusted Root Certificate Authorities) and retry `https://localhost` (no warning)
- Use Wireshark to capture and inspect TLS handshake and certificate exchange
- Use `/etc/hosts` to bind a custom domain (`myserver.local`) and access via `https://myserver.local`
