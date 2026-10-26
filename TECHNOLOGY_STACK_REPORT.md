# Technology Stack & Architecture Report

**Project:** Sangita Travels Pune (Pune Taxi Cab Management System)  
**Date:** October 13, 2026  
**Auditor:** Senior Application Security & DevSecOps Engineer  
**Document Version:** 1.0.0 — Production Baseline  

---

## 1. Executive Summary

Sangita Travels Pune is an intercity cab dispatch, fleet management, and tour reservation web platform serving routes between Pune, Mumbai, Mumbai Airport, and major outstation destinations across Maharashtra.

The system is architected as a lightweight, high-performance web platform combining:

- A modern **React 19 + TypeScript + Vite** client-side Single-Page Application (SPA) with hash-based routing and multi-lingual localization (English, Hindi, Marathi).
- A high-throughput, low-overhead **Python 3 standard library microservice** backend operating with **zero external third-party runtime dependencies**.
- An embedded **SQLite 3 relational database running in WAL mode** with foreign key constraints, connection pooling, and versioned schema migrations.
- A layered deployment architecture supporting Docker containerization, systemd process management, and Nginx reverse proxying.

---

## 2. Component Inventory & Technology Mapping

| Layer | Discovered Technology | Version / Configuration | Purpose |
| :--- | :--- | :--- | :--- |
| **Frontend Framework** | React + TypeScript | React 19.2.8, TypeScript 6.0.2 | Reactive UI components, state management, form validation |
| **Frontend Tooling** | Vite | Vite 8.3.0, @vitejs/plugin-react 6.1.1 | Fast compilation, HMR, production bundling with asset hashing |
| **Code Quality (Frontend)** | Oxlint + ESLint + Prettier | Oxlint 1.81.0, ESLint 10.12.0, Prettier 3.9.10 | Linting, AST verification, code style consistency |
| **Frontend Testing** | Vitest | Vitest 5.0.4 | Unit and regression testing for client services and validation |
| **Icons & UI** | Lucide React | Lucide React 1.55.0 | Responsive SVG iconography |
| **Backend Runtime** | Python 3 | Python 3.9+ (Standard Library) | Application server, HTTP parsing, API routing |
| **Backend Dependencies** | None (Zero 3rd-party) | Python Standard Library (`http.server`, `sqlite3`, `hashlib`, `secrets`, `urllib.request`) | Maximum stability, zero supply-chain CVE risk, instant start |
| **Database** | SQLite 3 | WAL Mode (`PRAGMA journal_mode = WAL;`) | ACID transactions, foreign keys (`PRAGMA foreign_keys = ON;`), busy timeout 5000ms |
| **Database Migrations** | Custom Versioned Runner | `backend/migrate.py` (001 through 009) | Reversible schema migrations, data seeding, integrity check |
| **Reverse Proxy** | Nginx | 1.25+ (`nginx/nginx.conf`) | Reverse proxy, static asset caching, Gzip compression, TLS termination |
| **Containerization** | Docker & Compose | `docker-compose.yml`, `docker-compose.prod.yml` | Multi-stage production container builds |
| **Process Supervision** | systemd | `deploy/systemd/sangita-cab.service` | Linux daemon auto-restart, logging to journald |

---

## 3. Directory Structure

```
Pune Mumbai Cab/
├── ADMIN_AUTH_SECURITY.md           # Admin auth, cryptographic specs & threat model
├── ADMIN_SETUP.md                   # Super Admin setup and operational commands
├── Makefile                         # Unified development, test, and build automation
├── README.md                        # Master repository documentation
├── SECURITY_TEST_REPORT.md          # Security verification test matrix
├── USER_MANAGEMENT.md               # User lifecycle and RBAC policies
├── docker-compose.yml               # Development multi-container orchestration
├── docker-compose.prod.yml          # Production multi-container orchestration
├── nginx/
│   └── nginx.conf                   # Nginx reverse proxy, gzip, caching & security headers
├── deploy/
│   ├── backup-db.sh                 # Scheduled WAL backup cron script
│   ├── deploy.sh                    # Zero-downtime production deployment runner
│   └── systemd/sangita-cab.service  # Production systemd daemon configuration
├── scripts/
│   ├── build.sh                     # Full build pipeline (frontend + backend verification)
│   ├── dev.py                       # Concurrent dev server runner
│   ├── dev.sh                       # Shell dev launcher
│   ├── lint.sh                      # Unified frontend/backend linter
│   ├── migrate.sh                   # Database migration CLI runner
│   └── setup.sh                     # Fresh environment initializer
├── tests/
│   └── e2e/                         # Playwright E2E test specs
├── backend/
│   ├── server.py                    # Production HTTP server entrypoint (port 8080)
│   ├── router.py                    # REST API dispatcher and route authentication
│   ├── migrate.py                   # 9 versioned relational database migrations
│   ├── schema.sql                   # 19-table DDL relational schema definition
│   ├── core/                        # Core infrastructural components
│   │   ├── config.py                # Environment variable parsing, default settings, ROLES
│   │   ├── database.py              # SQLite connection factory & row factory
│   │   ├── logger.py                # Structured JSON logging & request tracing
│   │   ├── response.py              # HTTP response envelopes, CORS, security headers
│   │   └── security.py              # PBKDF2 hashing, session tokens, permissions, XSS sanitize
│   ├── controllers/                 # 21 domain request controllers
│   ├── middleware/                  # Request middleware (rate limiting, CSRF origin checks)
│   ├── repositories/                # 19 data access repositories (Repository Pattern)
│   ├── services/                    # Domain services (Payment, Email, WhatsApp, Maps)
│   ├── scripts/                     # Operational scripts (bootstrap, backup, restore)
│   └── tests/                       # Automated unittest test suites
└── frontend/
    ├── package.json                 # Node dependencies and build scripts
    ├── vite.config.ts               # Vite configuration with React plugin & proxy rules
    ├── index.html                   # HTML entrypoint with PWA tags, fonts, CSP
    ├── src/
    │   ├── main.tsx                 # React application mounting
    │   ├── App.tsx                  # Client-side hash router & protected route guards
    │   ├── i18n/                    # Localization context (EN, HI, MR translations)
    │   ├── services/api.ts          # Central API client with bearer token injection
    │   └── modules/
    │       ├── auth/                # LoginPage, AuthContext (Zero hardcoded secrets)
    │       ├── admin/               # Admin dashboard, User management, Bookings, Fleet
    │       ├── public/              # Booking widget, Tour catalog, Tracking, Reviews
    │       └── shared/              # Header, Footer, ErrorBoundary, Modal, Toast
    └── dist/                        # Production built static assets
```

---

## 4. Trust Boundaries & Data Flow Analysis

### Trust Boundary 1: Public Internet ➔ Server HTTP Interface

- **Public Entrypoints**:
  - `GET /` and static assets (`/assets/*`, `/favicon.svg`, `/robots.txt`, `/sitemap.xml`).
  - `GET /api/public/*` (fleet, tours, services, pricing, reviews, blog).
  - `POST /api/bookings` (public cab booking submission).
  - `POST /api/public/track-booking` (booking lookup requiring reference + matching phone).
  - `POST /api/public/validate-coupon` (coupon verification).
  - `POST /api/public/reviews` (customer feedback submission).
  - `POST /api/payments/create-order` and `POST /api/payments/verify` (payment lifecycle).
  - `POST /api/auth/login`, `POST /api/auth/forgot-password`, `POST /api/auth/reset-password`.
- **Security Controls**:
  - Rate limiting via sliding-window IP buckets (`middleware/rate_limiter.py`).
  - Origin / Referer validation on mutating HTTP methods (`middleware/csrf.py`).
  - Strict Content-Security-Policy, X-Frame-Options, X-Content-Type-Options headers.

### Trust Boundary 2: Authenticated Users ➔ Privileged Operations

- **Protected Administrative Endpoints**:
  - `/api/dashboard/summary`, `/api/dashboard/charts`
  - `/api/bookings` (GET list, PUT edit, POST bulk-status, DELETE bulk-delete)
  - `/api/customers` (CRM records, customer trip histories)
  - `/api/fleet`, `/api/drivers` (fleet dispatch, driver personal phone/license data)
  - `/api/users` (Super Admin user creation, role assignment, account deactivation)
  - `/api/settings`, `/api/export/backup-sql`, `/api/audit-logs` (Super Admin only)
- **Security Controls**:
  - Session verification against `sessions` table in SQLite.
  - Role-Based Access Control (`SUPER_ADMIN`, `ADMIN`, `MANAGER`, `STAFF`, `BOOKING_STAFF`, `CONTENT_MANAGER`, `DRIVER`, `CUSTOMER`).
  - Tamper-resistant append-only audit trail in `audit_logs` table.

---

## 5. External Integrations & Supply Chain

1. **Payment Gateway (Razorpay)**:
   - Configured via `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`.
   - Client loads Razorpay Checkout modal dynamically from `https://checkout.razorpay.com/v1/checkout.js`.
   - Backend performs HMAC-SHA256 signature verification over `order_id|payment_id`.

2. **WhatsApp Business API**:
   - Meta Cloud API via direct HTTPS requests (`WHATSAPP_API_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`).
   - Deep-link fallback via `https://wa.me/` direct messaging links with prefilled text.

3. **Google Maps Distance Matrix**:
   - Configured via `GOOGLE_MAPS_API_KEY`.
   - Embedded offline route cache (`POPULAR_ROUTES` matrix & `route_cache` SQLite table) ensuring instant lookups without external network dependencies.

4. **SMTP Transactional Mail**:
   - Standard library `smtplib` using TLS (port 587) with HTML templates in `backend/templates/`.
   - Zero third-party dependencies (no Sendgrid/Mailgun packages required).
