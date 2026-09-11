# 🌟 MASTER AGENT INSTRUCTION & RECONSTRUCTION BLUEPRINT
# Project: Wasel Nalut Super-App Delivery Ecosystem (منظومة واصل نالوت للتوصيل الفائق)

> **Instructions for the AI Agent:**  
> You are tasked with architecting, implementing, and deploying the complete **Wasel Nalut Super-App Delivery Platform** from scratch. This document is your single source of truth. It outlines the platform vision, architecture, repository structure, strict business constraints, and step-by-step implementation order.
> Detailed module blueprints are available in the `./AGENT_BLUEPRINTS/` folder.

---

## 🎯 Executive Overview & Project Identity

**Wasel Nalut (واصل نالوت)** is an enterprise on-demand delivery super-app ecosystem engineered specifically for the city of **Nalut (نالوت) and the Western Mountain region (الجبل الغربي), Libya**.

The platform combines three high-frequency digital commerce verticals:
1. **Wasel Eat (واصل إيت)**: Food and beverage delivery from local restaurants and cafes.
2. **Wasel Mart / Jet (واصل مارت / إكسبريس)**: Ultra-fast 15-to-30 minute groceries, bakeries, and convenience stores.
3. **Wasel Marketplace / Mataa (واصل متاع)**: Electronics, lifestyle, perfumes, and general commerce.

### ⚠️ Strict Business Rules & Non-Negotiable Constraints:
1. **Operating Currency**: Strictly **Libyan Dinar (`د.ل` / `LYD`)**. No dollar (`$`) or foreign currency signs anywhere in the codebase, database, or UI.
2. **Geographical Scope**: Centered exclusively on **Nalut, Libya** (approx coordinates: `31.8687° N, 10.9818° E`).
3. **Zero Deprecations Rule**: All Flutter code must strictly adhere to modern Flutter 3.24+ / 3.47+ standards:
   - Use `Color.withValues(alpha: ...)` instead of `.withOpacity(...)`.
   - Use `RadioGroup` or modern custom `InkWell` + `AnimatedContainer` cards instead of deprecated `RadioListTile` with `groupValue`/`onChanged`.
   - Guard all `BuildContext` usage across async gaps with `if (!mounted) return;` or `if (!context.mounted) return;`.
4. **Multi-Tenant Merchant Isolation**: Each merchant/store must have completely isolated data. In the merchant web portal, selecting or logging into a store (e.g., "مطعم قصر نالوت") scopes all orders, menu items, and revenue strictly to that store using persistent `localStorage` and `sessionStorage`. No merchant may see another store's orders or financial figures.
5. **Master Admin PIN Shield**: The central operations hub and admin portal must be protected by a secure master PIN gate (**PIN: 7788**) before revealing any dispatch controls, financial data, or fleet tracking.

---

## 🏗️ Platform Repository Layout

```text
super_app_delivery/
├── AGENT_BLUEPRINTS/                     # Complete architectural specifications
│   ├── 01_PLATFORM_ARCHITECTURE_AND_SPECS.md
│   ├── 02_BACKEND_API_AND_DATABASE.md
│   ├── 03_FLUTTER_CUSTOMER_APP.md
│   ├── 04_FLUTTER_DRIVER_APP.md
│   ├── 05_MERCHANT_AND_ADMIN_SYSTEMS.md
│   ├── 06_LOGISTICS_AND_DISPATCH_ENGINE.md
│   └── 07_PRODUCTION_DEPLOYMENT_AND_DEVOPS.md
├── backend/                              # Node.js + Express + Socket.io Server
│   ├── public/                           # Static production web portals & Flutter Web release
│   │   ├── app/                          # Flutter Mobile Web release (Customer app)
│   │   ├── merchant/                     # Standalone Merchant KDS Web Portal
│   │   └── admin/                        # Standalone Admin Dispatch & Master Hub Web Portal
│   ├── schema.sql                        # PostGIS / PostgreSQL schema
│   ├── seed_data.json                    # Authentic Libyan seed dataset (Nalut stores & drivers)
│   ├── server.js                         # Production REST API + WebSocket server
│   ├── tracking_socket_server.js         # Dedicated fleet telemetry Socket.io server
│   ├── wallet_service.js                 # Double-entry escrow ledger service
│   └── package.json
├── flutter_mobile_app/                   # Customer Super-App (iOS / Android / Web)
│   ├── lib/
│   │   ├── design_system.dart            # Unified typography, colors, gradients & radius
│   │   ├── home_screen.dart              # Multi-vertical tab switcher & catalog
│   │   ├── order_tracking_screen.dart    # Live GPS tracking, status timeline, OTP
│   │   ├── product_detail_sheet.dart     # Dual-mode food & e-commerce modifier sheet
│   │   └── main.dart
│   └── pubspec.yaml
├── flutter_driver_app/                   # Captain / Driver App
│   ├── lib/
│   │   ├── active_delivery_flow_screen.dart # 4-step delivery lifecycle (Navigate, Arrive, Pickup, OTP Deliver)
│   │   ├── driver_home_screen.dart       # Shift toggle (Online/Offline) & daily COD earnings
│   │   ├── driver_wallet_screen.dart     # COD debt, cash deposit requests, payout ledger
│   │   ├── order_radar_dialog.dart       # Urgency popup with 15s circular countdown
│   │   └── main.dart
│   └── pubspec.yaml
├── flutter_merchant_app/                 # Native Merchant / Restaurant App
│   └── lib/ (Kitchen Display System, order prep-time, menu item availability)
├── flutter_admin_app/                    # Native Admin Operations & Financial Hub
│   └── lib/ (Accounting Z-report audit, dispute room, captain approvals, live fleet map)
├── logistics/                            # Python Logistics & Operations Research Engine
│   ├── dispatch_engine.py                # Hungarian algorithm bipartite matching
│   ├── pricing_engine.py                 # Dynamic surge & weight pricing
│   ├── batching_optimizer.py             # Multi-order clustering & PDPTW sequence optimizer
│   └── simulation_test.py                # End-to-end 10-driver / 20-order simulation
└── MASTER_AGENT_PROMPT.md                # This file
```

---

## 📋 Step-by-Step Reconstruction Roadmap for the Agent

When building this project from an empty directory, follow these sequential phases:

### Phase 1: Core Backend & Data Layer
1. Set up `backend/package.json` with `express`, `socket.io`, `cors`, `uuid`.
2. Implement `backend/schema.sql` (PostgreSQL 14+ compatible schema with PostGIS tables: users, stores, products, orders, drivers, wallets, transactions, daily_audits, vouchers).
3. Create `backend/seed_data.json` with authentic Nalut restaurants (e.g. مطعم قصر نالوت, شاورما وبيتزا النجم, كافيه القلعة, سوبرماركت الواحة), products in Libyan Dinar (`د.ل`), and initial active drivers.
4. Implement `backend/wallet_service.js` with double-entry accounting (Customer escrow on order placement, Merchant 90% payout, Captain delivery fee payout, 10% platform commission).
5. Implement `backend/server.js` with full REST API and Socket.io endpoints.
6. Build `backend/public/merchant/index.html` with multi-tenant store switcher, auto-refresh polling, audio chime, prep-time selector, and stock toggles.
7. Build `backend/public/admin/index.html` with Master PIN gate (7788), Leaflet live map, driver telemetry markers, and financial ledger.

### Phase 2: Logistics & Dispatching Optimization (Python)
1. Implement `logistics/pricing_engine.py` calculating base delivery fee + distance rate + dynamic surge multiplier.
2. Implement `logistics/dispatch_engine.py` using SciPy's `linear_sum_assignment` to minimize driver arrival and kitchen dwell times.
3. Implement `logistics/batching_optimizer.py` combining orders within 1.5 km heading in the same direction.
4. Verify by running `python simulation_test.py`.

### Phase 3: Customer Super-App (`flutter_mobile_app`)
1. Configure `pubspec.yaml` with `flutter_map`, `latlong2`, `provider`, `http`.
2. Implement `lib/design_system.dart` with Wasel color palette (Crimson Red `#E23744`, Sunset Orange `#FF6600`, Royal Violet `#7C3AED`, Emerald `#10B981`, Slate `#0F172A`).
3. Implement `lib/product_detail_sheet.dart` supporting authentic Libyan sizes (عادي, دبل, جامبو), Libyan add-ons (صلصة ثومية, بطاطا مقلية, مخلل نالوتي), and modern custom radio cards without deprecated widgets.
4. Implement `lib/home_screen.dart` with search bar, banner slider, brand categories, and restaurant list.
5. Implement `lib/order_tracking_screen.dart` with interactive vector map, driver marker moving in real-time, order status progress line, and customer delivery confirmation OTP code.
6. Run `flutter analyze` to ensure **0 errors and 0 warnings**.
7. Run `flutter build web --release --base-href /app/` and copy outputs into `backend/public/app/`.

### Phase 4: Driver / Captain App (`flutter_driver_app`)
1. Implement `driver_home_screen.dart` with online switch, earnings summary, and COD cash-in-hand warning.
2. Implement `order_radar_dialog.dart` with 15-second radial countdown timer and sound simulation.
3. Implement `active_delivery_flow_screen.dart` handling 4 distinct stages:
   - `Heading to Store`: Directions, merchant phone call button, "Arrived at Store".
   - `At Store Pickup`: Item verification checklist, "Confirm Pickup".
   - `Heading to Customer`: Navigation to customer home, call customer button, "Arrived at Customer".
   - `Delivery & Settlement`: 4-digit Customer OTP verification input, COD cash collection badge, "Complete Order".
4. Implement `driver_wallet_screen.dart` showing daily trip ledger and cash deposit settlements.
5. Verify with `flutter analyze` for **0 issues**.

### Phase 5: Merchant & Admin Portals
1. Complete `flutter_merchant_app` with Kitchen Display System (KDS) column architecture:
   - `طلبات جديدة (New)` -> `قيد التحضير (Preparing)` -> `جاهز للاستلام (Ready)`.
2. Complete `flutter_admin_app` with:
   - Master PIN lock (`7788`).
   - Daily Cash Audit Z-Report matching platform cash, driver debt, and merchant disbursements.
   - Dispute Room for "Customer No-Show / تعذر الاستلام" (90% restaurant compensation, full driver payout, customer blacklist/debt penalty).
   - Digital Voucher Generator (`DigitalVoucherDialog`).
3. Verify with `flutter analyze` for **0 issues**.

### Phase 6: Cloud Deployment & Release
1. Containerize the unified backend using Docker.
2. Deploy to Render / Cloud Run with environment variables: `PORT=3000`, `NODE_ENV=production`.
3. Verify that `/app/`, `/merchant`, and `/admin` are accessible and real-time WebSockets connect seamlessly.

---

## 📖 Blueprint Reference Matrix

| File | Content & Focus |
|:---|:---|
| [`AGENT_BLUEPRINTS/01_PLATFORM_ARCHITECTURE_AND_SPECS.md`](file:///C:/Users/kalifa/super_app_delivery/AGENT_BLUEPRINTS/01_PLATFORM_ARCHITECTURE_AND_SPECS.md) | Platform overview, design tokens, Libyan context & entity relationships |
| [`AGENT_BLUEPRINTS/02_BACKEND_API_AND_DATABASE.md`](file:///C:/Users/kalifa/super_app_delivery/AGENT_BLUEPRINTS/02_BACKEND_API_AND_DATABASE.md) | PostgreSQL schema DDL, REST API endpoints, WebSocket event payloads |
| [`AGENT_BLUEPRINTS/03_FLUTTER_CUSTOMER_APP.md`](file:///C:/Users/kalifa/super_app_delivery/AGENT_BLUEPRINTS/03_FLUTTER_CUSTOMER_APP.md) | Mobile Super-App UI code, bottom sheets, Libyan food menus, Web build |
| [`AGENT_BLUEPRINTS/04_FLUTTER_DRIVER_APP.md`](file:///C:/Users/kalifa/super_app_delivery/AGENT_BLUEPRINTS/04_FLUTTER_DRIVER_APP.md) | Driver app flow, 15s radar timer, 4-step delivery journey, OTP verification |
| [`AGENT_BLUEPRINTS/05_MERCHANT_AND_ADMIN_SYSTEMS.md`](file:///C:/Users/kalifa/super_app_delivery/AGENT_BLUEPRINTS/05_MERCHANT_AND_ADMIN_SYSTEMS.md) | Multi-tenant merchant isolation, Kitchen Display System, Master PIN & daily Z-audit |
| [`AGENT_BLUEPRINTS/06_LOGISTICS_AND_DISPATCH_ENGINE.md`](file:///C:/Users/kalifa/super_app_delivery/AGENT_BLUEPRINTS/06_LOGISTICS_AND_DISPATCH_ENGINE.md) | Hungarian assignment, Haversine routing, dynamic surge pricing algorithms |
| [`AGENT_BLUEPRINTS/07_DEPLOYMENT_AND_DEVOPS.md`](file:///C:/Users/kalifa/super_app_delivery/AGENT_BLUEPRINTS/07_DEPLOYMENT_AND_DEVOPS.md) | Render deployment, Dockerfile, static web syncing, Google Play compliance |
