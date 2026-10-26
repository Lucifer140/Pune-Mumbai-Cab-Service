# Security Incident Response Plan & Playbook

**Project:** Sangita Travels Pune — Intercity Cab Management System  
**Audit Branch:** `audit-remediation`  
**Date:** October 13, 2026  
**Document Version:** 1.0.0 — Production Standard  
**Framework Alignment:** NIST SP 800-61 Rev. 2 (Computer Security Incident Handling Guide)

---

## 1. Incident Response Objectives

This incident response plan establishes technical procedures for detecting, triaging, containing, eradicating, and recovering from potential security incidents affecting the Sangita Travels Pune platform.

**Core Objectives:**

1. Safeguard customer Personally Identifiable Information (PII) and booking travel details.
2. Maintain financial transaction and payment record integrity.
3. Minimize operational downtime for cab dispatch operations.
4. Preserve forensic artifacts for post-incident root cause analysis.

---

## 2. Incident Classification & Severity Matrix

| Severity Level | Definition / Criteria | Response SLA | Examples |
| :--- | :--- | :--- | :--- |
| **P1 — CRITICAL** | Active exploitation of financial transactions, customer data exfiltration, database corruption, or complete service outage | **< 15 Minutes** | Payment forgery bypass, unauthorized database drop, bulk customer data exfiltration |
| **P2 — HIGH** | Super Admin account compromise, unauthorized privilege escalation, localized data tampering | **< 1 Hour** | Compromised admin credentials, altered booking pricing, unauthorized fleet modifications |
| **P3 — MEDIUM** | Distributed Denial of Service (DDoS), API abuse, repeated authentication brute-force attacks | **< 4 Hours** | High-volume automated scraping, bot attacks on booking endpoints, credential stuffing |
| **P4 — LOW** | Unsuccessful scanning, anomalous error spikes, isolated rate-limit triggers | **< 24 Hours** | Port scanning against perimeter, single-IP endpoint fuzzing, minor client-side anomalies |

---

## 3. Incident Handling Lifecycle (NIST Framework)

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ 1. Detection │ ──> │  2. Triage   │ ──> │3. Containment│
│   & Analysis │     │& Escalation  │     │  (Isolate)   │
└──────────────┘     └──────────────┘     └──────────────┘
                                                 │
┌──────────────┐     ┌──────────────┐            ▼
│6. Post-Mortem│ <── │ 5. Recovery  │ <── ┌──────────────┐
│  & Learning  │     │ & Monitoring │     │4. Eradication│
└──────────────┘     └──────────────┘     │   (Patch)    │
                                          └──────────────┘
```

---

## 4. Phase-by-Phase Incident Playbooks

---

### Phase 1: Detection & Triage

#### Signal Sources

1. **Application Logs:** Structured JSON events in `backend/data/logs/app.log`.
2. **Audit Logs Table:** Tamper-evident admin logs in SQLite table `audit_logs`.
3. **Nginx Access/Error Logs:** `/var/log/nginx/access.log` and `/var/log/nginx/error.log`.
4. **Health & Readiness Alerts:** Monitoring `/api/health` and `/api/readiness`.

#### Forensic Investigation Commands

```bash
# 1. Search for 4xx/5xx security anomalies in structured application logs
grep '"status": 403' backend/data/logs/app.log | tail -n 50
grep '"status": 500' backend/data/logs/app.log | tail -n 50

# 2. Trace specific malicious requests by X-Request-ID
grep 'd07cb9df93e7' backend/data/logs/app.log

# 3. Inspect recent administrative actions in audit_logs table
python3 -c "
import sqlite3
with sqlite3.connect('backend/data/bookings.db') as conn:
    cur = conn.cursor()
    cur.execute('''
        SELECT id, action, entity_type, entity_id, admin_id, ip_address, created_at 
        FROM audit_logs 
        ORDER BY created_at DESC LIMIT 25;
    ''')
    for row in cur.fetchall():
        print(row)
"

# 4. Identify IPs generating high failure volumes
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head -n 20
```

---

### Phase 2: Containment Procedures

#### Step 1: Immediate IP Perimeter Block

If an attack is originating from specific IP addresses, block them immediately at the firewall:

```bash
# Block attacking IP via UFW firewall
sudo ufw insert 1 deny from 203.0.113.42 to any

# Or block via Nginx configuration
echo "deny 203.0.113.42;" >> /etc/nginx/conf.d/blocklist.conf
sudo nginx -s reload
```

#### Step 2: Emergency Administrative Session Invalidation

If administrative credentials or tokens are suspected of compromise:

```bash
# Invalidate all active admin sessions immediately
python3 -c "
import sqlite3
with sqlite3.connect('backend/data/bookings.db') as conn:
    conn.execute('DELETE FROM sessions;')
    conn.commit()
    print('[!] All administrative sessions revoked.')
"
```

#### Step 3: Lock Compromised Account

```bash
# Lock specific administrative user account
python3 -c "
import sqlite3
with sqlite3.connect('backend/data/bookings.db') as conn:
    conn.execute(\"UPDATE admins SET is_active = 0, locked_until = '2099-01-01' WHERE username = 'compromised_user';\")
    conn.commit()
    print('[!] Account locked.')
"
```

---

### Phase 3: Eradication

1. **Rotate Credentials:** Immediately rotate `SECRET_KEY`, `RAZORPAY_KEY_SECRET`, and Super Admin passwords.

   ```bash
   python3 backend/scripts/bootstrap_super_admin.py --email shitalupadhye2001@gmail.com --rotate-password
   ```

2. **Review Code & Deploy Fix:** Check out the remediation branch, verify test pass rates, and redeploy:

   ```bash
   git status
   python3 -m unittest discover -s backend/tests
   cd frontend && npm test -- --run
   ```

3. **Verify File Integrity:** Verify no unauthorized files were written into `backend/uploads`:

   ```bash
   find backend/uploads -type f -name "*.php" -o -name "*.py" -o -name "*.sh" -o -name "*.html"
   ```

---

### Phase 4: Recovery & Database Restoration

If data corruption, unauthorized table modifications, or database damage occurred, restore from the latest verified WAL-consistent backup:

```bash
# 1. Identify the most recent uncorrupted backup snapshot
ls -lt backend/data/backups/bookings_backup_*.db | head -n 5

# 2. Run automated restoration with pre-restore safety snapshot
python3 backend/scripts/restore_db.py \
  --backup backend/data/backups/bookings_backup_20261013_101631_974169.db \
  --force

# 3. Verify database integrity after restoration
python3 -c "
import sqlite3
with sqlite3.connect('backend/data/bookings.db') as conn:
    print('Restored Integrity Status:', conn.execute('PRAGMA integrity_check;').fetchone()[0])
"

# 4. Restart backend application server
sudo systemctl restart sangita-cab
```

---

### Phase 5: Post-Incident Review & Lessons Learned

Within 48 hours of resolving a P1 or P2 incident, conduct a post-mortem review and document findings:

#### Post-Mortem Documentation Template

```markdown
# Incident Post-Mortem Report

**Incident Reference:** INC-2026-XXXX  
**Date of Incident:** YYYY-MM-DD  
**Severity Level:** P1 / P2 / P3 / P4  
**Incident Commander:** [Name]  

### 1. Incident Timeline
- **HH:MM** — Incident detected via [alert / log / customer report]
- **HH:MM** — Triage initiated; severity classified as [P#]
- **HH:MM** — Containment applied ([IP blocked / sessions revoked])
- **HH:MM** — Eradication patch deployed to production
- **HH:MM** — Normal operations restored; monitoring confirmed green

### 2. Root Cause Analysis (RCA)
[Detailed explanation of the technical vulnerability or misconfiguration that permitted the incident]

### 3. Impact Assessment
- Financial Impact: [₹0.00 / details]
- Customer PII Impact: [0 records / details]
- Downtime Duration: [X minutes]

### 4. Preventive Actions & Remediation Items
1. [Action Item 1 — Owner — Target Date]
2. [Action Item 2 — Owner — Target Date]
```

---

## 5. Emergency Contact & Escalation Roster

| Role | Responsibility | Contact Channel |
| :--- | :--- | :--- |
| **Super Admin / Platform Owner** | Incident Commander & Business Decisions | Phone / WhatsApp: +91 8261021008 |
| **Technical Lead** | Code Fixes & Infrastructure Recovery | Email: <shitalupadhye287@gmail.com> |
| **Payment Gateway Support** | Razorpay Fraud / Dispute Escalation | Razorpay Merchant Dashboard |
| **Hosting & Cloud Support** | Server Hardware / Network Defense | Hosting Provider Console |
