# 🛡️ Sangita Travels Pune — Admin Authentication & Security Architecture

This document specifies the security controls, cryptographic standards, session management policies, and role-based access controls implemented across the Sangita Travels Pune Cab Management System.

---

## 1. Authentication Engine & Cryptography

### 1.1 Password Hashing Specification

- **Algorithm:** PBKDF2 (Password-Based Key Derivation Function 2)
- **Hash Function:** HMAC-SHA256
- **Iteration Count:** 100,000 rounds
- **Salt Generation:** Cryptographically secure 16-byte random salt (`secrets.token_hex(16)`) generated per password
- **Storage Schema:**
  - `password_hash`: 64-character hex string (SHA-256 digest)
  - `password_salt`: 32-character hex string
- **Zero Plaintext Rule:** Plaintext passwords are never persisted in SQLite, never returned in API payloads, and never logged in stdout or file logs.

### 1.2 Password Complexity Policy

All passwords created via bootstrap, user management, or password reset must satisfy:

- Minimum length of 8 characters.
- At least one alphabetic letter (`[A-Za-z]`).
- At least one numeric digit (`[0-9]`).

---

## 2. Session & Token Management

### 2.1 Session Identifier Specification

- **Token Format:** 32-byte cryptographically secure random token (64-character hex string).
- **Storage:** Persisted in the `sessions` table:
  - `token` (Primary Key)
  - `admin_id` (Foreign Key -> `admins(id)`)
  - `ip_address`
  - `user_agent`
  - `created_at`
  - `expires_at`

### 2.2 Dual Token Delivery

Sessions are verified through either:

1. **HTTP Authorization Header:** `Authorization: Bearer <token>`
2. **HttpOnly Cookie:**

   ```http
   Set-Cookie: admin_token=<token>; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000; [Secure]
   ```

   - `HttpOnly`: Prevents client-side scripts from reading session tokens, mitigating XSS token extraction.
   - `SameSite=Lax`: Defends against Cross-Site Request Forgery (CSRF).
   - `Secure`: Automatically appended when `ENVIRONMENT=production`.

### 2.3 Session Expiration & Invalidation

- **Session Duration:** 30 days (when "Remember session" is selected) or 7 days default.
- **Immediate Invalidation:** All active sessions for a user are deleted from `sessions` upon:
  - Explicit logout (`POST /api/logout`).
  - Account deactivation (`is_active = 0`).
  - Password rotation or reset.
  - User deletion.

---

## 3. Brute-Force Protection & Account Lockout

- **Attempt Threshold:** 5 consecutive failed login attempts within an active window.
- **Lockout Duration:** 15 minutes (`locked_until = now + 15 minutes`).
- **Response Headers & Messaging:**
  - Failed attempt: Uniform message indicating invalid credentials and remaining attempts.
  - Locked account: HTTP 403 Forbidden with minutes remaining until release.
- **Lockout Reset:** A successful login clears `failed_attempts` and resets `locked_until` to `NULL`.

---

## 4. Role-Based Access Control (RBAC) Matrix

Permissions are enforced strictly on the server by `router.py` and `core/security.py`:

| Role | Title | Core Permissions | Allowed Administrative Actions |
| --- | --- | --- | --- |
| **`SUPER_ADMIN`** | Super Admin | `['*']` | Manage users, assign roles, system configuration, audit logs, and all operational tasks. |
| **`ADMIN`** | Administrator | `dashboard`, `bookings:*`, `customers:*`, `fleet:*`, `drivers:*`, `tours:*`, `services:*`, `pricing:*`, `coupons:*`, `reviews:*`, `analytics:*`, `export:*` | Full day-to-day dispatch, fleet, customer CRM, pricing, and driver assignments. Cannot manage users or audit logs. |
| **`MANAGER`** | Fleet Manager | `dashboard`, `bookings:read`, `bookings:write`, `customers:read`, `fleet:*`, `tours:*`, `services:*`, `pricing:read`, `analytics:read` | Daily operations, booking status changes, and vehicle assignments. |
| **`STAFF` / `BOOKING_STAFF`** | Booking Staff | `dashboard`, `bookings:read`, `bookings:write`, `customers:read`, `customers:contact`, `fleet:read` | Accept new bookings, contact passengers, review vehicle schedules. |
| **`CONTENT_MANAGER`** | Content Manager | `content:*`, `media:*`, `tours:*`, `services:*`, `seo:*` | Manage blog posts, homepage promotions, and photo galleries. |
| **`DRIVER`** | Fleet Driver | `driver:trips:read`, `driver:profile:read`, `driver:status:write` | Access assigned trips and report trip status. |
| **`CUSTOMER`** | Passenger | `customer:bookings:read`, `customer:profile:write` | Track own booking and view confirmation invoice. |

---

## 5. Critical Super Admin Safeguards

To prevent accidental system lockout, privilege escalation, or unauthorized modifications:

1. **Self-Role Modification Block:** An administrator cannot modify their own role. Attempting to change one's own role returns HTTP 400.
2. **Self-Deactivation Block:** An administrator cannot deactivate their own account.
3. **Self-Deletion Block:** An administrator cannot delete their own account.
4. **Last Super Admin Protection:** If only one active `SUPER_ADMIN` exists in the system, any attempt to deactivate, demote, or delete that Super Admin is rejected by the server with HTTP 400.
5. **Privilege Escalation Prevention:** Only an authenticated `SUPER_ADMIN` can assign the `SUPER_ADMIN` role to another account.

---

## 6. Audit Trail & Tamper Evidence

Every privileged action is recorded in the SQLite `audit_logs` table:

```sql
CREATE TABLE audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NULL,
    user_name VARCHAR(100) NOT NULL,
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(100) NOT NULL,
    details TEXT DEFAULT '',
    ip_address VARCHAR(45) DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Logged Operations

- `LOGIN_SUCCESS`, `LOGIN_FAILED`, `ACCOUNT_LOCKED`, `LOGOUT`
- `SUPER_ADMIN_BOOTSTRAP`, `SUPER_ADMIN_PASSWORD_ROTATED`
- `CREATE_USER`, `UPDATE_USER`, `DEACTIVATE_USER`, `ACTIVATE_USER`, `DELETE_USER`

Sensitive data (passwords, tokens, salts) are strictly excluded from audit log details.

---

## 7. Multi-Factor Authentication (MFA / 2FA) Roadmap

While the current Python standard library backend does not bundle an external TOTP dependency, MFA can be integrated seamlessly:

1. **TOTP (RFC 6238):** Add standard TOTP secret generation (`pyotp`) and QR code rendering for Google Authenticator / Microsoft Authenticator.
2. **Email OTP:** The existing `EmailService` (`backend/services/email_service.py`) can be extended to dispatch a 6-digit verification code to the Super Admin's email address during login challenge.
3. **Hardware Keys (WebAuthn):** Standard browser `navigator.credentials.create()` flow for FIDO2 hardware tokens.
