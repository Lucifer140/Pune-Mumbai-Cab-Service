# 🚨 Disaster Recovery Runbook & Operations Manual

**Sangita Travels Pune (Pune Mumbai Cab Platform)**  
*Document Version: 1.0.0 | Phase 40 Production Hardening*

---

## 1. System Recovery Objectives (RPO & RTO)

| Metric | Target SLA | Description |
| --- | --- | --- |
| **RPO (Recovery Point Objective)** | **< 1 Hour** | Maximum permissible data loss in any catastrophic failure scenario. Maintained via hourly WAL checkpoints and automated snapshots. |
| **RTO (Recovery Time Objective)** | **< 15 Minutes** | Maximum permissible downtime before service is restored and taking live bookings. |
| **Integrity Target** | **100% Verification** | Every snapshot is pre-validated with `PRAGMA integrity_check` and tamper-checked via SHA-256 checksums before archive. |

---

## 2. Core Architecture & Persistence State

- **Primary Database**: `/backend/data/bookings.db` (SQLite in WAL mode).
- **WAL Journaling**: Active write-ahead log stored in `bookings.db-wal` and `bookings.db-shm`.
- **Media Uploads**: `/frontend/public/assets/uploads/` (Driver documents, fleet images, blog thumbnails).
- **Runtime Environment**: Python 3.11+ stdlib (zero framework overhead) running on port `8080` behind Nginx reverse proxy.
- **TLS / SSL**: Let's Encrypt automated via Certbot with TLS 1.3 / HSTS.

---

## 3. Automated Backup Strategy

### 3.1 Non-Blocking Online Snapshot Backups

SQLite's native streaming backup API (`src.backup(dst, pages=250)`) allows hot, zero-downtime backups while active transactions and customer bookings are in progress.

```bash
# Run manual on-demand backup
python3 backend/scripts/backup_db.py

# Specify custom retention (e.g. keep last 60 backups)
python3 backend/scripts/backup_db.py --max-backups 60

# Backup with automated cloud mirror sync (AWS S3 or GCS)
python3 backend/scripts/backup_db.py --cloud-cmd "aws s3 cp {backup_file} s3://sangita-travels-backups/prod/"
```

### 3.2 Automated Cron Scheduling

Add the following job to the system crontab (`crontab -e`):

```cron
# Every 4 hours: Run WAL-consistent online database snapshot & rotate retention
0 */4 * * * cd /var/www/punemumbaicab && python3 backend/scripts/backup_db.py >> /var/log/cab_backup.log 2>&1

# Daily at 3:30 AM: Deep integrity check & remote cloud synchronization
30 3 * * * cd /var/www/punemumbaicab && python3 backend/scripts/backup_db.py --cloud-cmd "gcloud storage cp {backup_file} gs://sangita-cab-disaster-recovery/" >> /var/log/cab_backup_daily.log 2>&1
```

---

## 4. Restoration & Recovery Drills

### 4.1 Step 1: Verify Backup Health (Non-Destructive)

Always test that the candidate backup file is 100% valid before applying it:

```bash
python3 backend/scripts/restore_db.py --verify-only
# Or test a specific snapshot:
python3 backend/scripts/restore_db.py --backup-file backend/data/backups/bookings_backup_20261013_120000.db --verify-only
```

### 4.2 Step 2: Atomic Database Restoration

The restoration tool automatically creates a **safety pre-restore snapshot** (`bookings_pre_restore_*.db`) before overwriting anything, preventing accidental data loss:

```bash
# Restores from the newest valid backup with safety rollback
python3 backend/scripts/restore_db.py --force
```

### 4.3 Step 3: Restart Application Server & Validate

```bash
# Restart backend daemon
kill -9 $(lsof -t -i :8080) 2>/dev/null || true
python3 backend/server.py &

# Validate readiness probe
curl -s http://127.0.0.1:8080/api/readiness | jq .
```

---

## 5. Critical Incident Playbooks

### Playbook A: Accidental Data Deletion or Table Corruption

1. **Freeze live traffic**: (Optional) point Nginx to maintenance page or temporary redirect.
2. **Inspect latest backups**:

   ```bash
   ls -lt backend/data/backups/bookings_backup_*.db | head -n 5
   ```

3. **Execute restore**:

   ```bash
   python3 backend/scripts/restore_db.py --force
   ```

4. **Run migration verify**:

   ```bash
   python3 backend/migrate.py
   ```

5. **Verify live probes**:

   ```bash
   curl -I http://127.0.0.1:8080/api/health
   curl -s http://127.0.0.1:8080/api/readiness | jq .
   ```

### Playbook B: Complete Host / Server Hardware Destruction

1. Provision new Ubuntu 22.04 LTS instance.
2. Clone repository:

   ```bash
   git clone https://github.com/sangita-travels/pune-mumbai-cab.git /var/www/punemumbaicab
   cd /var/www/punemumbaicab
   ```

3. Fetch latest backup from Cloud Storage:

   ```bash
   aws s3 cp s3://sangita-travels-backups/prod/latest_backup.db backend/data/bookings.db
   ```

4. Apply schema migrations & integrity check:

   ```bash
   python3 backend/migrate.py
   python3 backend/scripts/restore_db.py --verify-only --backup-file backend/data/bookings.db
   ```

5. Start services:

   ```bash
   docker compose -f docker-compose.prod.yml up -d
   ```

6. Update DNS `A` records to point to new public IP (TTL should be 300s).

### Playbook C: SQLite WAL Disk Starvation

If disk usage exceeds 90% or the `-wal` file grows abnormally large:

```bash
# Force full checkpoint into main DB file
sqlite3 backend/data/bookings.db "PRAGMA wal_checkpoint(TRUNCATE);"

# Vacuum free space
sqlite3 backend/data/bookings.db "VACUUM;"
```

---

## 6. Real-Time Health & Alerting Probes

The platform exposes two enterprise monitoring endpoints:

### Liveness Probe (`GET /api/health`)

- **Purpose**: Verifies that the HTTP server process is running and accepting sockets.
- **Expected Status**: HTTP 200 `{"status": "healthy", "uptime_seconds": 3600}`.
- **Uptime Monitor**: Configure UptimeRobot / BetterUptime / Pingdom HTTP monitor:
  - **URL**: `https://punemumbaicab.com/api/health`
  - **Check Interval**: 60 seconds
  - **Alert Threshold**: 2 consecutive failures triggers SMS/Call to operations desk (+91 8261021008).

### Readiness Probe (`GET /api/readiness`)

- **Purpose**: Deep functional check verifying SQLite read/write capability, table counts, and disk write permissions.
- **Expected Status**: HTTP 200 `{"status": "ready", "database": {"connected": true, "tables_count": 22}}`.
- **Failure Condition**: HTTP 503 if database disconnected or uploads directory unwritable.

---

## 7. Emergency Escalation Contacts

- **Operations Desk**: +91 8261021008 (24/7 WhatsApp & Voice)
- **Technical Lead / Admin**: <sangitatravels08@gmail.com>
- **Disaster Escalation Policy**: Any unacknowledged outage > 5 minutes escalates via SMS dispatch.
