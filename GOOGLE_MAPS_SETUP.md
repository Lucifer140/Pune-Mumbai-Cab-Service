# Google Maps Platform Setup & Security Configuration

**Sangita Travels Pune — Cab Management System**

---

## 1. Executive Summary & Security Directives

Google Maps Platform APIs power address autocomplete, interactive driving route visualization, distance measurement, travel duration estimation, and highway toll discovery.

> [!CAUTION]
> **Key Compromise & Rotation Protocol:**
> Any API key previously shared or committed in chat sessions, source code, or public repositories must be treated as **compromised**. Never commit API keys to version control. Restrict browser keys strictly by HTTP referrers, and restrict server-side keys by IP addresses and specific API scopes.

---

## 2. Dual-Key Architecture (Frontend vs Backend)

To protect your Google Cloud billing account and maintain high availability, Sangita Travels Pune implements a **dual-credential architecture**:

```
+-------------------------------------------------------------------------+
|                              CLIENT BROWSER                             |
|                                                                         |
|  [PlacesAutocompleteInput.tsx]         [GoogleRouteMap.tsx]             |
|                |                                  |                     |
|                +-----------------+----------------+                     |
|                                  |                                      |
|                       [googleMapsLoader.ts]                             |
|                                  |                                      |
|            Uses: VITE_GOOGLE_MAPS_API_KEY (frontend/.env.local)         |
|            Restricted by: HTTP Referrers & Maps JS / Places API         |
+-------------------------------------------------------------------------+
                                   |
                   (REST API Calls /api/public/*)
                                   |
+-------------------------------------------------------------------------+
|                              BACKEND SERVER                             |
|                           (Python stdlib / 8080)                        |
|                                                                         |
|                       [PricingController.py]                            |
|                                  |                                      |
|                         [maps_service.py]                               |
|                                  |                                      |
|            Uses: GOOGLE_MAPS_API_KEY (backend/.env)                     |
|            Restricted by: Server IP & Routes / Distance Matrix API      |
|                                  |                                      |
|             Fallback: SQLite route_cache & Highway Route Matrix         |
+-------------------------------------------------------------------------+
```

### A. Frontend Browser Key (`VITE_GOOGLE_MAPS_API_KEY`)

- **Location:** `frontend/.env.local`
- **Purpose:** Loads Google Maps JavaScript SDK, Places Autocomplete, and interactive route polylines in the client browser.
- **Exposure:** Visible in browser client code by design.
- **Mandatory Restriction:** HTTP Referrer restriction in Google Cloud Console.

### B. Backend Server Key (`GOOGLE_MAPS_API_KEY`)

- **Location:** `backend/.env`
- **Purpose:** Server-side authoritative route distance, driving duration, and toll price queries (`computeRoutes` with `extraComputations: ["TOLLS"]`).
- **Exposure:** Strictly confidential; never sent to or visible in client browsers.
- **Mandatory Restriction:** IP address restriction in Google Cloud Console.

---

## 3. Step-by-Step Google Cloud Console Configuration

### Step 1: Create or Select Your Google Cloud Project

1. Visit the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project: `sangita-travels-maps` (or select your existing project).
3. Ensure **Billing** is linked to an active payment method.

### Step 2: Enable Required APIs

Enable the following APIs in **APIs & Services > Library**:

1. **Maps JavaScript API** (Interactive map canvas and directions rendering)
2. **Places API** and **Places API (New)** (Address search and place autocomplete)
3. **Routes API** (Next-generation routing with real-time toll calculations)
4. **Distance Matrix API** (Secondary route fallback)
5. **Geocoding API** (Coordinate translation for custom landmarks)

### Step 3: Create & Restrict the Frontend Browser Key

1. Go to **APIs & Services > Credentials > Create Credentials > API Key**.
2. Rename key to: `Sangita-Travels-Frontend-Browser-Key`.
3. Under **Application restrictions**, choose **Websites**:
   Add permitted website referrers:
   - `http://localhost:5173/*` (Local Vite dev server)
   - `http://localhost:8080/*` (Local production test server)
   - `https://sangitatravelspune.com/*` (Production website)
   - `https://*.sangitatravelspune.com/*` (Subdomains)
4. Under **API restrictions**, choose **Restrict key**:
   - Maps JavaScript API
   - Places API
   - Places API (New)
5. Save the key.

### Step 4: Create & Restrict the Backend Server Key

1. Click **Create Credentials > API Key**.
2. Rename key to: `Sangita-Travels-Backend-Server-Key`.
3. Under **Application restrictions**, choose **IP addresses**:
   - Add your production server's static public IPv4/IPv6 address.
   - For local development testing, leave unrestricted or specify local external IP temporarily.
4. Under **API restrictions**, choose **Restrict key**:
   - Routes API
   - Distance Matrix API
   - Geocoding API
5. Save the key.

---

## 4. Environment File Placement & Git Protection

Both `.env` files are excluded from Git repository tracking via the root `.gitignore`:

```gitignore
# 1. Environment & Secret Configuration
.env
.env.*
*.env
*.env.local
!.env.example
!backend/.env.example
!frontend/.env.example
```

### Configuring Frontend (`frontend/.env.local`)

Create or edit `frontend/.env.local`:

```bash
# Google Maps JavaScript Browser Key (HTTP Referrer Restricted)
VITE_GOOGLE_MAPS_API_KEY=AIzaSy...YourRestrictedBrowserKeyHere
```

### Configuring Backend (`backend/.env`)

Edit `backend/.env`:

```bash
# Google Maps Server-Side Web Service Key (IP Restricted)
GOOGLE_MAPS_API_KEY=AIzaSy...YourRestrictedServerKeyHere
```

---

## 5. Graceful Degradation & High-Availability Failover

The Sangita Travels integration does **not** crash or display blank screens if the Google Maps API key is unconfigured, revoked, or rate-limited:

1. **Authentication Error Catching (`window.gm_authFailure`):**
   `frontend/src/services/googleMapsLoader.ts` catches quota or referrer rejection immediately and automatically activates the local visual route card.
2. **SQLite Local Route Cache (`backend/data/bookings.db` -> `route_cache`):**
   Previously calculated routes and tolls are stored locally. Repeated queries for identical routes (e.g. Pune to Mumbai) return in `< 2ms` with zero Google Cloud API cost.
3. **Maharashtra Highway Route Matrix (`backend/services/maps_service.py`):**
   High-precision offline route and toll database covering:
   - Pune to Mumbai (152 km, 3h 15m, ₹320 Expressway Toll)
   - Pune to Nashik (212 km, 4h 30m, ₹190 NH60 Toll)
   - Pune to Shirdi (185 km, 4h 30m, ₹130 Toll)
   - Pune to Mahabaleshwar (120 km, 3h 15m, ₹140 Toll)
   - Pune to Lonavala (68 km, 1h 30m, ₹120 Toll)
   - Pune to Kolhapur (235 km, 4h 45m, ₹240 Toll)
   - Pune to Goa (445 km, 9h 30m, ₹380 Toll)

---

## 6. Budget Alerts & Quota Control

To prevent unexpected Google Cloud charges:

1. Navigate to **Billing > Budgets & alerts** in Google Cloud Console.
2. Create a monthly budget of ₹1,000 (or $15 USD).
3. Set alerts at 50%, 80%, 100%, and 120% threshold notifications sent to `shitalupadhye287@gmail.com`.
4. Under **APIs & Services > Quotas**, configure daily per-day query caps on Routes API and Places API to prevent denial-of-wallet spikes.
