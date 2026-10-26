# Sangita Travels Pune — Backend

Modular Python REST API and Single-Page Application (SPA) backend server for Sangita Travels Pune (Pune-Mumbai Cab Service).

---

## Architectural Highlights

- **Standard Library Architecture:** Built purely on Python's robust native standard library (`http.server`, `sqlite3`, `hashlib`, `secrets`, `urllib`).
- **Zero External Runtime Dependencies:** Maximum reliability, lightning-fast boot times, and no dependency vulnerability surface.
- **Repository Pattern & Layered Architecture:** Distinct separation of concerns between `controllers/`, `repositories/`, `core/`, and `router.py`.
- **Relational Storage:** SQLite with Write-Ahead Logging (`WAL`) mode enabled and foreign key enforcement.

---

## System Requirements

- **Python:** 3.9 or higher (tested on 3.9, 3.10, 3.11, 3.12)
- **OS:** Linux, macOS, or Windows

---

## Quickstart

### 1. (Optional) Create a Virtual Environment

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

### 2. Configure Environment

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Adjust variables in `.env` if needed (e.g., `PORT=8080`, `ADMIN_SECRET_KEY`).

### 3. Initialize or Migrate the Database

```bash
python3 migrate.py
```

### 4. Start the Server

```bash
python3 server.py
```

Or using an explicit port:

```bash
python3 server.py 8080
```

The server will be available at:

- **Customer Web Application:** `http://localhost:8080/`
- **Admin Dashboard:** `http://localhost:8080/admin`
- **Admin Login:** `http://localhost:8080/login.html`
- **REST API Endpoints:** `http://localhost:8080/api/...`

---

## Dependency Management & Tooling

### Files Overview

- **`pyproject.toml`**: Modern PEP 517/621 packaging metadata, console scripts (`sangita-server`, `sangita-migrate`), and configurations for `ruff`, `pytest`, and `mypy`.
- **`requirements.txt`**: Production dependency declaration (zero runtime packages required).
- **`requirements-dev.txt`**: Development, testing, and linting packages (`pytest`, `ruff`, `mypy`).

### Installing Development Tools

To install development, testing, and linting packages:

```bash
pip install -r requirements-dev.txt
```

Or install in editable mode:

```bash
pip install -e ".[dev]"
```

### Code Formatting & Linting

```bash
ruff check .
ruff format .
```

### Type Checking

```bash
mypy .
```

---

## Directory Structure

```text
backend/
├── pyproject.toml        # PEP 517/621 package metadata & tool config
├── requirements.txt      # Production dependencies
├── requirements-dev.txt  # Dev/Test dependencies
├── server.py             # HTTP server entrypoint
├── router.py             # Route dispatcher and controller mappings
├── migrate.py            # SQLite database schema migration script
├── schema.sql            # Base SQL schema definition
├── .env.example          # Environment configuration template
├── core/                 # Shared system utilities (config, database, security, response)
├── controllers/          # Business logic handlers
├── repositories/         # Database access layer (CRUD)
└── data/                 # SQLite database storage (bookings.db)
```
