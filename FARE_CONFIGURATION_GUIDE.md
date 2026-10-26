# Fare Configuration & Admin Management Guide

**Sangita Travels Pune — Super Admin & Fleet Pricing Operations**

---

## 1. Access Control & Role Permissions

The Pricing Rules module is protected by the Sangita Travels RBAC (Role-Based Access Control) security model.

| Role | Access Level | Permissions |
| :--- | :--- | :--- |
| **SUPER_ADMIN** | Full Control | Create, update, delete pricing rules, toggle public visibility, view audit logs |
| **MANAGER** | Full Management | Create and edit rate cards, configure vehicle pricing, preview quotes |
| **BOOKING_STAFF** | View Only | View configured prices for customer phone inquiries; cannot modify rates |
| **CONTENT_MANAGER** | No Access | Restricted to blog posts, SEO, and CMS media assets |
| **Customers / Public** | Read Only | Public API only reads sanitized pricing breakdowns; mutation endpoints reject with 401/403 |

> [!IMPORTANT]
> **Authentication Endpoint:**
> Authorized administrators must log in via `http://localhost:8080/login.html` (or `https://sangitatravelspune.com/login.html`). Bearer session tokens are required for all pricing update requests.

---

## 2. Navigating to the Pricing Management View

1. Log in to the Admin Dashboard.
2. In the navigation sidebar, click **Pricing Rules** (or navigate to `/admin.html#pricing`).
3. You will see two primary sections:
   - **Rate Cards Table:** Lists all active fleet vehicles with their rates and visibility.
   - **Interactive Fare Estimator / Previewer:** Live simulation tool for customer quotes.

---

## 3. Configuring Swift Dzire and Maruti Ertiga Rates

### A. Swift Dzire (Sedan — 4 Passengers)

Recommended Baseline Configuration:

- **Vehicle Key:** `dzire`
- **Vehicle Name:** `Swift Dzire (Sedan)`
- **One-Way Base Fare:** `₹2,299`
- **Per-Kilometre Rate:** `₹13.00`
- **Minimum Billable Distance:** `130 km`
- **Driver Allowance:** `₹300` (Day) / `₹450` (Round-Trip)
- **Round-Trip Base Fare:** `₹4,500`
- **Airport Rate:** `₹2,299`
- **Public Visibility:** Active (`1`)

### B. Maruti Ertiga (New MUV — 6 Passengers)

Recommended Baseline Configuration:

- **Vehicle Key:** `ertiga`
- **Vehicle Name:** `Maruti Ertiga (New MPV)`
- **One-Way Base Fare:** `₹3,199`
- **Per-Kilometre Rate:** `₹15.00`
- **Minimum Billable Distance:** `130 km`
- **Driver Allowance:** `₹300` (Day) / `₹450` (Round-Trip)
- **Round-Trip Base Fare:** `₹6,000`
- **Airport Rate:** `₹3,199`
- **Public Visibility:** Active (`1`)

---

## 4. How to Update or Add Pricing Rules

### Step 1: Open Edit Modal

- Locate the vehicle row in the **Rate Cards** table.
- Click the blue **Edit** button (pencil icon).

### Step 2: Configure Price Parameters

1. **Base Rate (One-Way):** Minimum floor price charged for standard corridor (e.g. Pune to Mumbai).
2. **Rate Per KM:** Dynamic distance multiplier applied when `Road Distance × Per-Km Rate` exceeds the base rate.
3. **Minimum Billable KM:** Minimum distance charged regardless of shorter trips (e.g. 130 km for outstation).
4. **Driver Allowance:** Fixed allowance for driver food and upkeep per calendar day.
5. **Round-Trip Base:** Flat baseline rate for return journeys within 24–48 hours.
6. **Airport Transfer Rate:** Fixed flat rate for Mumbai Airport CSMIA (T1/T2) drops.
7. **Show on Website:** Toggle checkbox to make this vehicle visible on the public customer booking widget.

### Step 3: Save Changes

- Click **Save Rate Card**.
- The backend validates all inputs, updates SQLite database records, invalidates cached quotations, and creates a persistent audit log entry.

---

## 5. Live Fare Preview & Quotation Simulation

Before applying rate changes to customer bookings, test them using the built-in **Fare Calculator**:

1. Select the vehicle (**Swift Dzire** or **Maruti Ertiga**).
2. Choose the trip type (**One Way**, **Round Trip**, **Airport Transfer**, or **Outstation**).
3. Enter driving distance (e.g. `152 km` for Pune-Mumbai or `212 km` for Pune-Nashik).
4. Toggle **Include Expressway Tolls** on or off.
5. Check the real-time breakdown:
   - Base Fare
   - Extra KM Charge
   - Driver Allowance
   - Tolls & Surcharges
   - Guaranteed Total Quote
6. Click **Copy WhatsApp Quote** to send instant professional quotations to phone customers.

---

## 6. Audit Logging & Security Compliance

Every create, update, or delete action in the Pricing module is permanently logged in the SQLite `audit_logs` table for compliance:

```sql
SELECT 
    id, user_id, username, action, resource, details, ip_address, created_at 
FROM audit_logs 
WHERE resource = 'pricing' 
ORDER BY id DESC;
```

### Example Audit Log Entry

- **Action:** `UPDATE_PRICING`
- **Resource:** `pricing`
- **User:** `admin` (Shital Upadhye)
- **Details:** `Updated pricing rule 1 (Swift Dzire: per_km set to 13.0, oneway set to 2299.0)`
- **IP Address:** `127.0.0.1` (or production client IP)
- **Timestamp:** `2026-10-13 16:30:00`
