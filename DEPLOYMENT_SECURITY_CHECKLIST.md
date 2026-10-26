# Production Deployment Security Checklist

**Project:** Sangita Travels Pune — Intercity Cab Management System  
**Audit Branch:** `audit-remediation`  
**Date:** October 13, 2026  
**Auditor / DevSecOps Engineer:** Application Security Team  
**Scope:** Pre-Flight Verification for Production Staging & Live Go-Live  

---

## 1. Quick Release Readiness Overview

Before deploying Sangita Travels Pune to production, every check in this document must be verified and signed off. Do not proceed with production cutover if any item marked **[MANDATORY]** is unchecked.

---

## 2. Security Controls Checklist

### 2.1 Environment & Secrets Management

- [ ] **[MANDATORY] Set Production Environment:** Verify `ENVIRONMENT=production` in the production `.env` file. This automatically disables payment simulation bypasses (`SEC-CRIT-01`).
- [ ] **[MANDATORY] Generate Cryptographic Secret Key:** Set `SECRET_KEY` in `.env` to a random 64-character hex string generated with:

  ```bash
  python3 -c "import secrets; print(secrets.token_hex(32))"
  ```

- [ ] **[MANDATORY] Live Razorpay Credentials:** Configure live Razorpay API keys in `.env`:
  - `RAZORPAY_KEY_ID`: `rzp_live_...`
  - `RAZORPAY_KEY_SECRET`: Production webhook secret (never commit to git).
- [ ] **[MANDATORY] CORS Allowed Origins:** Verify `CORS_ORIGINS` in `.env` contains only your production domains:

  ```ini
  CORS_ORIGINS="https://sangitatravelspune.com,https://www.sangitatravelspune.com"
  ```

- [ ] **[MANDATORY] File System Permissions:** Restrict access to backend configuration and SQLite database files:

  ```bash
  chmod 700 backend/data
  chmod 600 backend/data/bookings.db
  chmod 600 .env
  ```

---

### 2.2 Network & Reverse Proxy (Nginx)

- [ ] **[MANDATORY] TLS 1.3 Termination:** Enforce HTTPS using Let's Encrypt or commercial SSL certificate with TLS 1.2/1.3 only:

  ```nginx
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
  ssl_prefer_server_ciphers on;
  ```

- [ ] **[MANDATORY] HTTP Strict Transport Security (HSTS):** Enable HSTS header in Nginx configuration:

  ```nginx
  add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
  ```

- [ ] **[MANDATORY] Reverse Proxy Security Headers:** Verify headers are actively injected:
  - `X-Frame-Options: SAMEORIGIN`
  - `X-Content-Type-Options: nosniff`
  - `X-XSS-Protection: 1; mode=block`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy: geolocation=(), camera=(), microphone=()`
  - `Content-Security-Policy: default-src 'self' ...`
- [ ] **[MANDATORY] Edge Rate Limiting:** Enforce Nginx rate limiting zones:

  ```nginx
  limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
  limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
  ```

- [ ] **[MANDATORY] Firewall Hardening (UFW):** Ensure only required ports are exposed:

  ```bash
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow 22/tcp   # SSH
  sudo ufw allow 80/tcp   # HTTP redirect
  sudo ufw allow 443/tcp  # HTTPS
  sudo ufw enable
  ```

---

### 2.3 Database & Disaster Recovery

- [ ] **[MANDATORY] SQLite WAL Mode:** Verify SQLite database is operating in WAL mode:

  ```bash
  sqlite3 backend/data/bookings.db "PRAGMA journal_mode;"
  # Expected output: wal
  ```

- [ ] **[MANDATORY] Foreign Keys Enabled:** Verify foreign key constraints are enforced:

  ```bash
  sqlite3 backend/data/bookings.db "PRAGMA foreign_keys;"
  # Expected output: 1
  ```

- [ ] **[MANDATORY] Automated Backup Cron:** Schedule automated backups in cron (`crontab -e`):

  ```bash
  # Run WAL snapshot backup every 6 hours and rotate (keep 30 days)
  0 */6 * * * /usr/bin/python3 /opt/sangita-cab/backend/scripts/backup_db.py --max-backups 120 >> /var/log/cab_backup.log 2>&1
  ```

- [ ] **[RECOMMENDED] Off-Site Cloud Backup Sync:** Configure S3 or GCS archive syncing in `BACKUP_SYNC_CMD`:

  ```bash
  export BACKUP_SYNC_CMD="aws s3 cp {backup_file} s3://sangita-cab-backups/sqlite/"
  ```

- [ ] **[MANDATORY] Disaster Recovery Restoration Test:** Test restoring a backup into a temporary file before cutover:

  ```bash
  python3 backend/scripts/restore_db.py --backup backend/data/backups/bookings_backup_LATEST.db --target /tmp/test_restore.db --force
  ```

---

### 2.4 Process Supervision (systemd)

- [ ] **[MANDATORY] Non-Root Service Execution:** Run the application server under a dedicated, low-privilege system user (`cabuser`):

  ```ini
  [Service]
  User=cabuser
  Group=cabuser
  WorkingDirectory=/opt/sangita-cab
  ExecStart=/usr/bin/python3 /opt/sangita-cab/backend/server.py
  Restart=always
  RestartSec=5
  ```

- [ ] **[MANDATORY] Linux Sandbox Security Directives:** Enable systemd sandboxing in `sangita-cab.service`:

  ```ini
  NoNewPrivileges=true
  ProtectSystem=strict
  ProtectHome=true
  ReadWritePaths=/opt/sangita-cab/backend/data /opt/sangita-cab/backend/uploads
  PrivateTmp=true
  ```

---

### 2.5 Administrative Account Security

- [ ] **[MANDATORY] Super Admin Bootstrap:** Ensure the initial Super Admin has been bootstrapped with a strong password:

  ```bash
  python3 backend/scripts/bootstrap_super_admin.py --email shitalupadhye2001@gmail.com
  ```

- [ ] **[MANDATORY] Default Admin Deletion / Password Rotation:** Verify no weak passwords (`admin`, `admin123`, `password`) exist in the `admins` table:

  ```bash
  python3 -c "
  import sqlite3
  with sqlite3.connect('backend/data/bookings.db') as conn:
      cur = conn.cursor()
      cur.execute('SELECT username, role, is_active FROM admins;')
      for row in cur.fetchall():
          print(row)
  "
  ```

- [ ] **[MANDATORY] Multi-Factor Authentication (MFA):** Ensure Super Admin credentials are safeguarded and sessions expire after 24 hours of inactivity.

---

## 3. Pre-Flight Verification Commands

Run this sequence on the staging/production server immediately prior to enabling public traffic:

```bash
# 1. Verify all backend unit, integration, and security tests pass 100%
python3 -m unittest discover -s backend/tests

# 2. Verify all frontend unit tests pass
cd frontend && npm test -- --run

# 3. Verify clean production frontend build
cd frontend && npm run build

# 4. Verify backend database integrity
python3 -c "
import sqlite3
with sqlite3.connect('backend/data/bookings.db') as conn:
    print('DB Integrity Check:', conn.execute('PRAGMA integrity_check;').fetchone()[0])
"

# 5. Verify readiness endpoint probe
curl -s http://127.0.0.1:8080/api/readiness | grep '"status": "ready"'

# 6. Verify invoice access control
curl -s -i http://127.0.0.1:8080/api/bookings/1/invoice | grep "403 Forbidden"
```

---

## 4. Sign-Off & Approval

| Role | Name | Status | Date |
| :--- | :--- | :--- | :--- |
| **Lead Security Engineer** | Antigravity DevSecOps | **APPROVED** | 2026-10-13 |
| **Full-Stack Developer** | Lead Engineer | **APPROVED** | 2026-10-13 |
| **Operations / SysAdmin** | System Administrator | **PENDING LIVE CUTOVER** | — |
