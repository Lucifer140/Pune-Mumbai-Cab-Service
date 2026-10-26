# Sangita Travels Pune (Pune-Mumbai Cab Service)

A full-stack, enterprise-grade cab booking platform and administrative management portal built for **Sangita Travels Pune**, providing round-the-clock one-way and round-trip taxi booking between Pune, Mumbai, Mumbai International Airport (T2), Shirdi, Mahabaleshwar, and intercity routes.

---

## Architecture Overview

The system is architected as a decoupled, layered application with clean separation between the frontend presentation layer and the backend service layer:

- **Frontend:** Single Page Application (SPA) built with **React 19**, **TypeScript**, and **Vite 8**. Employs a custom, performance-focused Vanilla CSS design system with zero bloated runtime CSS frameworks, animated components, and Lucide icons.
- **Backend:** High-reliability, modular REST API and static SPA server powered exclusively by **Python's native standard library** (`http.server`, `sqlite3`, `hashlib`, `secrets`, `urllib`). Requires zero third-party packages at runtime for minimal attack surface, instantaneous boot times, and maintenance-free deployments.
- **Database:** Embedded relational **SQLite 3** utilizing Write-Ahead Logging (`WAL`) mode for concurrent reads/writes and foreign key constraints.
- **Security:** Layered Role-Based Access Control (RBAC), PBKDF2-HMAC-SHA256 password hashing with salt, constant-time token comparison, cryptographically secure session management, and HTTP security headers (`nosniff`, `SAMEORIGIN`, CSP/Permissions policies).

---

## Directory Structure

```
Pune Mumbai Cab/
├── .gitignore                   # Enterprise root git ignore covering all 10 essential layers
├── README.md                    # Project documentation & setup guide (this file)
│
├── backend/                     # Python Modular REST API & Static Server
│   ├── pyproject.toml           # PEP 517/621 packaging metadata & tool configurations
│   ├── requirements.txt         # Production dependencies (pure stdlib)
│   ├── requirements-dev.txt     # Development & testing dependencies (pytest, ruff, mypy)
│   ├── README.md                # Dedicated backend documentation
│   ├── server.py                # Server entry point & static SPA request dispatcher
│   ├── router.py                # Route dispatcher mapping HTTP methods to controllers
│   ├── migrate.py               # Enterprise schema migration & seeding script
│   ├── schema.sql               # Base SQLite database schema definition
│   ├── .env.example             # Backend environment template
│   ├── core/                    # Core infrastructural services
│   │   ├── config.py            # Environment loader & configuration constants
│   │   ├── database.py          # SQLite connection manager with WAL mode
│   │   ├── security.py          # Password hashing, tokens, RBAC permissions
│   │   └── response.py          # JSON/CSV response handlers & request readers
│   ├── controllers/             # Business logic handlers
│   │   ├── booking_controller.py
│   │   ├── user_controller.py
│   │   ├── vehicle_controller.py
│   │   ├── pricing_controller.py
│   │   ├── tour_controller.py
│   │   ├── cms_controller.py
│   │   └── settings_controller.py
│   ├── repositories/            # Database access layer (Repository Pattern)
│   │   ├── base_repository.py
│   │   ├── booking_repository.py
│   │   ├── user_repository.py
│   │   ├── vehicle_repository.py
│   │   ├── pricing_repository.py
│   │   ├── tour_repository.py
│   │   ├── seo_repository.py
│   │   └── audit_repository.py
│   └── data/                    # Database storage directory
│       └── .gitkeep             # Directory tracking placeholder (DB files ignored)
│
└── frontend/                    # React 19 + TypeScript + Vite SPA
    ├── package.json             # NPM package specification & script definitions
    ├── vite.config.ts           # Vite development server & build configuration
    ├── tsconfig.json            # TypeScript project configuration
    ├── .oxlintrc.json           # Oxlint rules configuration
    ├── .env.example             # Frontend environment variables template
    ├── index.html               # SPA HTML entry point
    ├── public/                  # Public static assets & favicon
    └── src/                     # React application source code
        ├── App.tsx              # Root component & page router
        ├── main.tsx             # Application bootstrap entry point
        ├── types/               # TypeScript interfaces & types
        ├── components/          # Reusable UI components & modals
        ├── pages/               # Customer site & Admin Dashboard views
        ├── services/            # API client layer for backend endpoints
        └── styles/              # Global CSS & theme styles
```

---

## Prerequisites

Ensure the following tools are installed on your machine:

- **Node.js**: v18.0.0 or higher (v20+ recommended)
- **npm**: v9.0.0 or higher
- **Python**: v3.9 or higher

Verify your installation:

```bash
node -v
npm -v
python3 --version
```

---

## Quickstart & Local Setup

### Step 1: Clone or Open the Repository

```bash
cd "Pune Mumbai Cab"
```

### ⚡ Quick Commands (Makefile Shortcuts)

If you have `make` installed, you can manage the entire application using these one-line commands:

| Command | Action |
| :--- | :--- |
| `make setup` | One-command full-stack bootstrap (installs deps, configs, seeds DB) |
| `make dev` | Starts **both** backend & frontend servers concurrently with colorized logs |
| `make build` | Compiles frontend production assets and verifies backend compilation |
| `make migrate` | Applies SQLite schema migrations in WAL mode |
| `make seed` | Seeds default admin roles, pricing, vehicles, and tours |
| `make lint` | Runs Prettier format checks, Oxlint, ESLint, and backend checks |
| `make format` | Formats all frontend source code with Prettier |
| `make clean` | Cleans temporary cache files, build artifacts, and SQLite journals |

*Tip: If you do not have `make`, all commands are also available directly as executable POSIX scripts in `./scripts/` (e.g. `./scripts/dev.sh`, `./scripts/build.sh`, `./scripts/migrate.sh`, `./scripts/seed.sh`).*

---

### Step 2: Backend Setup & Database Migration

1. **Navigate to the backend directory:**

   ```bash
   cd backend
   ```

2. **(Recommended) Initialize a Python virtual environment:**

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   # On Windows: .venv\Scripts\activate
   ```

3. **Configure Environment Variables:**

   ```bash
   cp .env.example .env
   ```

   *Note: Edit `.env` to customize your port, business details, or secret keys if needed.*

4. **Run the Database Migrations:**

   ```bash
   python3 migrate.py
   ```

   *This initializes `data/bookings.db` in WAL mode, generates all required tables, and seeds default administrators, pricing, routes, vehicles, and tours.*

5. **Start the Backend Server:**

   ```bash
   python3 server.py
   ```

   The backend will start on `http://localhost:8080`.

---

### Step 3: Frontend Setup & Development

In a new terminal window:

1. **Navigate to the frontend directory:**

   ```bash
   cd frontend
   ```

2. **Configure Frontend Environment:**

   ```bash
   cp .env.example .env
   ```

3. **Install Dependencies:**

   ```bash
   npm install
   ```

4. **Start the Vite Development Server (with Hot Module Replacement):**

   ```bash
   npm run dev
   ```

   The development frontend will open at `http://localhost:5173`. Requests to `/api/` can be routed directly to `http://localhost:8080`.

---

## Production Deployment (Unified Server Mode)

The backend's [server.py](file:///Users/shital/Desktop/Pune%20Mumbai%20Cab/backend/server.py) is capable of serving both the REST API and the compiled frontend build as a unified service on a single port:

1. **Build the production frontend bundle:**

   ```bash
   cd frontend
   npm run build
   ```

   *This outputs optimized static assets into `frontend/dist/`.*

2. **Run the production backend:**

   ```bash
   cd ../backend
   python3 server.py
   ```

3. **Access the unified application:**
   - **Customer Web Application:** `http://localhost:8080/`
   - **Admin Management Portal:** `http://localhost:8080/admin`
   - **Admin Login:** `http://localhost:8080/login.html`
   - **REST API Endpoints:** `http://localhost:8080/api/`

---

## Default Administrator Credentials

When the database is seeded via `migrate.py`, default accounts with tiered permissions are configured for initial setup:

| Role | Username | Default Password | Permissions |
| :--- | :--- | :--- | :--- |
| **Super Admin** | `admin` | `admin123` *(change in prod)* | Full access across all modules, backups, logs & users |
| **Manager** | `manager` | `manager123` *(change in prod)* | Bookings, pricing, fleet management, and CMS |
| **Staff / Support** | `staff` | `staff123` *(change in prod)* | Booking operations and customer communication |
| **Editor** | `editor` | `editor123` *(change in prod)* | Content management, tours, FAQs, and SEO metadata |

> [!CAUTION]
> Always change default administrative credentials and generate a unique 64-character `ADMIN_SECRET_KEY` in `backend/.env` before deploying to a public production environment.

---

## Testing & Quality Control

### Frontend Verification

```bash
cd frontend

# Verify code formatting with Prettier
npm run format:check

# Run combined Oxlint + ESLint checks
npm run lint

# Run TypeScript typecheck & production build test
npm run build
```

### Backend Verification

```bash
cd backend

# Install development tooling
pip install -r requirements-dev.txt

# Run linter and formatting checks
ruff check .
ruff format --check .

# Run static type checker
mypy .
```

---

## Environment Variables Reference

### Backend (`backend/.env`)

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `PORT` | `8080` | Port for the HTTP server to listen on |
| `ENVIRONMENT` | `production` | Environment mode (`development` or `production`) |
| `DATABASE_PATH` | `data/bookings.db` | Filepath to SQLite database |
| `ADMIN_SECRET_KEY` | Hex token | Cryptographic secret for signing session tokens |
| `SESSION_EXPIRY_DAYS` | `30` | Number of days session tokens remain valid |
| `BUSINESS_NAME` | `"Sangita Travels Pune"` | Business display name |
| `SUPPORT_PHONE` | `8261021008` | Primary customer helpline |
| `WHATSAPP_NUMBER` | `918261021008` | WhatsApp booking helpline (with country code) |
| `SUPPORT_EMAIL` | `shitalupadhye287@gmail.com` | Customer care email address |

### Frontend (`frontend/.env`)

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `VITE_API_URL` | `http://localhost:8080` | Base URL of the backend REST API |
| `VITE_APP_ENV` | `production` | Frontend runtime environment flag |
| `VITE_PUBLIC_BRAND_NAME` | `"Sangita Travels Pune"` | Display brand name in header and footer |
| `VITE_PUBLIC_SUPPORT_PHONE` | `8261021008` | Helpline number displayed across UI |
| `VITE_PUBLIC_WHATSAPP_NUMBER` | `918261021008` | WhatsApp click-to-chat destination number |

---

## Key Features

- **Instant Quote & Booking Flow:** One-way & round-trip fare calculations with dynamic vehicle selection (Sedan, Ertiga, Innova Crysta).
- **Airport Transfer Specials:** Dedicated Mumbai Airport T2 pickup & drop-off booking.
- **Outstation Tour Packages:** Pre-configured curated holiday tours (Shirdi, Mahabaleshwar, Lonavala, Ashtavinayak Darshan).
- **Admin Dashboard:** Booking status tracking, live driver/cab assignment, revenue analytics, CSV reporting, and audit logging.
- **Content & SEO Engine:** Editable testimonials, vehicle fleet management, FAQs, and dynamic SEO metadata.
