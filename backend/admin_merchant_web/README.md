# 🚀 Super App Delivery - Merchant Portal & Super Admin Dispatch Mesh

Welcome to the **Merchant Operations & Super Admin Logistics Control Suite** for the Super App Delivery ecosystem.

This directory contains two standalone, fully responsive, zero-build interactive web applications crafted with HTML5, CSS3 (Tailwind CSS), and modern JavaScript:

1. [**`merchant_portal.html`**](file:///C:/Users/kalifa/super_app_delivery/admin_merchant_web/merchant_portal.html) - Restaurant & Merchant Kitchen Display System (KDS) and Live Menu Catalog Manager.
2. [**`admin_dispatch_dashboard.html`**](file:///C:/Users/kalifa/super_app_delivery/admin_merchant_web/admin_dispatch_dashboard.html) - Super Admin Operations Center featuring Interactive Fleet Dispatch Map (Leaflet.js), Live Order Stream, Geofencing Surge Engine, and Double-Entry Financial Ledger.

---

## 📂 Architecture & File Structure

```
C:\Users\kalifa\super_app_delivery\admin_merchant_web\
├── merchant_portal.html             # Restaurant KDS & Catalog Management Web App
├── admin_dispatch_dashboard.html    # Super Admin Live Fleet Map & Financial Control Center
└── README.md                        # User Guide & Testing Documentation
```

---

## ⚡ Quick Start: How to Open & Test

Both applications are **100% self-contained** and run in any modern web browser (Google Chrome, Microsoft Edge, Mozilla Firefox, Safari, Brave) without requiring Node.js, npm, or a web server.

### Option A: Open directly in your browser
- **Merchant Portal**: Double-click or open `C:\Users\kalifa\super_app_delivery\admin_merchant_web\merchant_portal.html` in your browser.
- **Admin Dispatch Center**: Double-click or open `C:\Users\kalifa\super_app_delivery\admin_merchant_web\admin_dispatch_dashboard.html` in your browser.

### Option B: Run via a local development server (Optional)
If you prefer testing over `localhost`:
```bash
# Python 3
cd C:\Users\kalifa\super_app_delivery\admin_merchant_web
python -m http.server 8080

# Then navigate to:
# http://localhost:8080/merchant_portal.html
# http://localhost:8080/admin_dispatch_dashboard.html
```

---

## 🍔 1. Merchant Portal & Kitchen Display System (`merchant_portal.html`)

### Key Features:
1. **Interactive 3-Column Kitchen Display System (KDS)**:
   - **New Orders (Orange/Amber)**: Incoming customer tickets with animated pulsing highlight, elapsed counter badge, customer notes, and prep-time adjusters (`10m`, `20m`, `30m`).
   - **Preparing (Blue)**: Real-time progress bar counting down kitchen preparation time, ingredient breakdown, and `Mark Ready for Pickup` button.
   - **Ready for Pickup (Green)**: Indicates order is packed and displays the assigned courier widget (`Courier Name`, `Vehicle`, `ETA: At Store Front`), plus `Handover to Courier` button to archive the order.

2. **Web Audio API Order Chime Generator**:
   - Synthesizes a melodic 3-tone chime (`G5 -> C6 -> E6`) using the native Web Audio API when a new order arrives.
   - Works offline with zero MP3 file dependencies.
   - Includes a **"Test Audio Chime"** button in the header.

3. **Incoming Order Simulator**:
   - Click the **`+ Sim Order`** button in the header to simulate incoming orders from customers in Riyadh. An audio alert sounds and the order lands instantly in the `New Orders` column.

4. **Thermal POS Receipt Modal**:
   - Click **"View & Print Ticket"** on any order card to preview a thermal receipt slip formatted for 80mm kitchen ticket printers with itemized add-ons and customer notes.

5. **Menu & Inventory Catalog Manager**:
   - Navigate to the **"Menu Catalog"** tab to manage your food menu.
   - **In-Stock / Out-of-Stock Toggle Switches**: Toggle item availability live.
   - **In-line Price Editor**: Click and change the SAR price of any dish and it updates immediately.
   - **Add New Dish Modal**: Create new menu items with Arabic/English titles, category tags, photo URL, and price.

6. **Real-time Sales & Earnings Analytics**:
   - Navigate to the **"Sales & Metrics"** tab to view gross daily revenue, completed order volume, average ticket value, and net settled earnings (15% platform fee deducted).
   - Interactive **Chart.js Hourly Sales Curve** displaying peak lunch and dinner rush hours.

7. **Bilingual (Arabic RTL & English) and Dark/Light Modes**:
   - Toggle **`العربية`** in the top navigation to switch the entire application into Right-to-Left (RTL) mode with localized Arabic typography and labels.

---

## 🗺️ 2. Super Admin Dispatch Dashboard (`admin_dispatch_dashboard.html`)

### Key Features:
1. **Full-Screen Interactive Fleet Map (Leaflet.js / OSM)**:
   - High performance CartoDB Dark tile mapping centered over the Riyadh Metropolitan Area.
   - **Pulsing Animated Courier Markers**: Active drivers move along streets in real-time. Hovering or clicking reveals courier speed, vehicle type, battery level, and assigned order ID.
   - **Merchant Store Markers**: Shows restaurant locations (Al-Baik, Al-Sultan Gourmet, Starbucks Reserve, Al-Romansiah, Sushi Art) with pending orders count.
   - **Customer Dropoff Pins**: Visual pins with dropoff addresses and live delivery ETAs.
   - **Route Tracing**: Click on any active order in the sidebar or table to draw animated route polylines connecting Store -> Driver -> Customer.

2. **Geofencing & Dynamic Surge Pricing Engine**:
   - 4 Pre-configured Polygon Zones across Riyadh:
     - **Zone 1**: *KAFD & Olaya Financial* (1.4x Surge)
     - **Zone 2**: *Al-Malqa & Hittin North* (1.1x Surge)
     - **Zone 3**: *Sulaimaniyah & Downtown* (1.6x Surge)
     - **Zone 4**: *Diplomatic Quarter (DQ)* (1.2x Restricted Access)
   - Real-time surge multiplier slider (1.0x to 2.5x) to rebalance delivery pricing and fleet distribution.

3. **Live Order Dispatch Stream & Reassignment**:
   - Switch to the **"Active Orders Feed"** tab to inspect all platform orders across all merchants.
   - Click **"Reassign"** on any order to open the Courier Assignment modal and dispatch to the nearest available driver.
   - Toggle AI Auto-Dispatch routing on or off.

4. **Double-Entry Wallet & Financial Ledger Inspector**:
   - Switch to the **"Financial Ledger & Escrow"** tab to inspect financial health:
     - Gross Merchandise Value (GMV): **SAR 384,920.00**
     - Platform Commission Revenue (15%): **SAR 62,410.00**
     - Merchant Escrow Balance: **SAR 274,360.00**
     - Pending Driver Payouts: **SAR 39,200.00**
     - Cryptographic Double-Entry Proof: **100% Balanced ($\Sigma \text{Debits} = \Sigma \text{Credits}$)**.
   - **Batch Payout Trigger**: Simulates automated clearing through Saudi SARIE / Mada instant bank transfer network.

5. **Driver Push Broadcast System**:
   - Click **"Zone Surge Push"** to broadcast incentive bonuses (e.g. `+SAR 8 per delivery`) to all couriers active within a specific geofence sector.

6. **Bilingual Arabic RTL & English Support**:
   - Full toggle for Arabic (العربية) and English with layout mirroring.

---

## 🧪 Interactive Test Workflows

| Test Scenario | Steps | Expected Outcome |
| :--- | :--- | :--- |
| **Test KDS Order Flow** | Open `merchant_portal.html` -> Click `+ Sim Order` | Order chime plays, order card appears in *New Orders*, click *Accept & Cook*, order moves to *Preparing*, click *Mark Ready*, order moves to *Ready for Pickup*, click *Handover to Courier*. |
| **Test Menu Stock Toggle** | Open `merchant_portal.html` -> Click `Menu Catalog` -> Toggle switch on *Smoked BBQ Brisket* | Stock status changes between *In Stock* and *Paused* with a live confirmation toast. |
| **Test In-line Price Edit** | Open `merchant_portal.html` -> Click `Menu Catalog` -> Change price to `45.00` | Toast confirms price update immediately. |
| **Test Live Map Routing** | Open `admin_dispatch_dashboard.html` -> Click on order `ORD-1092` in sidebar | Map zooms to the courier, and a route polyline is drawn from store to destination. |
| **Test Driver Reassignment** | Open `admin_dispatch_dashboard.html` -> Click `Reassign` -> Select courier -> Click `Confirm Dispatch` | Order driver is updated, status changes to *In Transit*, and toast notification appears. |
| **Test Surge Slider** | Open `admin_dispatch_dashboard.html` -> Click `Geofences & Surge` -> Drag slider to `1.8x` | Surge badge updates, polygon color/tooltip updates on map. |
| **Test Financial Ledger** | Open `admin_dispatch_dashboard.html` -> Click `Financial Ledger & Escrow` -> Click `Trigger Batch Payouts` | Confirmation prompt runs, new SARIE clearing transaction is recorded in the double-entry journal. |
| **Test Arabic RTL Mode** | Click `العربية` on either portal | Layout mirrors to RTL, fonts switch to *Cairo*, and all UI labels translate to Arabic. |

---

## 🛠️ Technology Stack
- **Framework**: Semantic HTML5 / Vanilla ES6+ JavaScript (Zero compile step required).
- **Styling**: Tailwind CSS (via CDN) + Cairo & Inter Typography + FontAwesome / Lucide SVG Icons.
- **Mapping**: Leaflet.js v1.9.4 with OpenStreetMap & CartoDB Dark Matter tiles.
- **Data Visualization**: Chart.js for hourly sales and order volume analytics.
- **Audio Engine**: Web Audio API (Multi-oscillator synthesizer for crystal clear notification chimes).
