# 🚀 Wasel Nalut Super-App Unified Backend Platform (واصل نالوت)

Enterprise backend architecture, PostGIS geospatial database schema, real-time fleet tracking WebSocket engine, and double-entry escrow ledger service for Wasel Nalut Super-App (Libya).

---

## 📑 Table of Contents
1. [Architecture Overview](#-architecture-overview)
2. [Directory Structure](#-directory-structure)
3. [Database Schema & PostGIS Setup (`schema.sql`)](#-database-schema--postgis-setup)
4. [OpenAPI 3.0 REST Specification (`api_spec.json`)](#-openapi-30-rest-specification)
5. [Real-Time Tracking Engine (`tracking_socket_server.js`)](#-real-time-tracking-engine)
6. [Double-Entry Ledger & Escrow Service (`wallet_service.js`)](#-double-entry-ledger--escrow-service)
7. [Environment Variables](#-environment-variables)
8. [Local Development & Docker Setup](#-local-development--docker-setup)

---

## 🏛 Architecture Overview

The backend is built around a decoupled, event-driven, high-concurrency micro-architecture designed for sub-second delivery tracking, high transactional throughput, and zero-loss financial accounting.

```mermaid
flowchart TB
    subgraph Clients["Clients Layer"]
        CUST["📱 Customer App (iOS / Android / Web)"]
        DRIV["🛵 Driver App (GPS Telemetry Stream)"]
        MRCH["🏪 Merchant Portal (Kitchen Display)"]
        ADMN["🖥 Admin / Dispatch Dashboard"]
    end

    subgraph Gateway["API Gateway & Real-time Layer"]
        REST["⚡ REST API (OpenAPI 3.0 / Fastify)"]
        WS["📡 WebSocket / Socket.io Tracking Server\n(:4001)"]
    end

    subgraph CoreServices["Core Engine Layer"]
        WALLET["💰 Double-Entry Ledger & Escrow Service"]
        DISPATCH["📍 PostGIS Geospatial & Dispatch Engine"]
        CATALOG["🍔 Merchant Catalog & Order Service"]
    end

    subgraph DataStore["Data & Persistence Layer"]
        PG[("🐘 PostgreSQL 14+ with PostGIS\n(Supabase Compatible)")]
        REDIS[("⚡ Redis Pub/Sub & Cluster Adapter")]
    end

    CUST -->|HTTP REST| REST
    MRCH -->|HTTP REST| REST
    ADMN -->|HTTP REST| REST

    DRIV -->|GPS Ping (1.5s)| WS
    CUST -->|Live Room Stream| WS
    MRCH -->|Order Events| WS

    REST --> WALLET
    REST --> DISPATCH
    REST --> CATALOG

    WS --> REDIS
    WS --> PG
    WALLET --> PG
    DISPATCH --> PG
    CATALOG --> PG
```

---

## 📁 Directory Structure

```
C:\Users\kalifa\super_app_delivery\backend\
├── server.js                    # Complete Express + Socket.io Unified Super-App Server (:3000)
├── seed_data.json               # Authentic Libyan market seed data (Tripoli/Benghazi, LYD prices)
├── test_server.js               # Standalone test & verification suite
├── schema.sql                   # Full PostgreSQL DDL (PostGIS, RLS, Indexes, Triggers)
├── api_spec.json                # Complete OpenAPI 3.0 API Specification
├── tracking_socket_server.js    # Dedicated PostgreSQL/PostGIS Socket.io telemetry server (:4001)
├── wallet_service.js            # Double-entry ledger with atomic escrow & settlement
├── package.json                 # Node.js dependencies & runtime scripts
└── README.md                    # Architecture guide and deployment documentation
```

---

## ⚡ Quick Start: Standalone Server

Run the complete super-app server out-of-the-box (no external PostgreSQL required for local testing):

```bash
# Start Express + Socket.io Server on port 3000
npm start
# or: node server.js

# Run test suite
node test_server.js
```

---

## 🐘 Database Schema & PostGIS Setup (`schema.sql`)

The database is built on **PostgreSQL 14+** and fully compatible with **Supabase**. It leverages `postgis` for spatial operations, `uuid-ossp` for primary keys, and Row Level Security (RLS).

### Entity Relationship Model

| Table | Purpose | Key Spatial / Financial Attributes |
| :--- | :--- | :--- |
| `users` | Customers, Drivers, Merchants, Admins | Role, Status, Phone unique index |
| `user_addresses` | Saved customer delivery locations | `location GEOMETRY(Point, 4326)`, GIST Index |
| `wallets` | Multi-currency user & system balances | `balance`, `locked_balance`, Non-negative check |
| `wallet_transactions` | Immutable double-entry financial journal | `idempotency_key`, `wallet_id`, `counterparty_wallet_id` |
| `stores` | Merchant profiles & commissions | `location GEOMETRY(Point, 4326)`, Opening hours JSONB |
| `store_categories` | Menu category groupings | Store-isolated hierarchy |
| `products` | Menu items & pricing | Base price, discounted price, tax status |
| `product_addons` | Options & variant modifiers | Group names, max select limits, pricing |
| `orders` | Central order state machine | Subtotal, delivery fee, platform fee, tip, `delivery_location` |
| `order_items` | Normalized purchased line items | Selected addons JSONB, unit pricing |
| `order_status_logs` | Audit trail of transitions | Auto-populated by trigger on order update |
| `drivers` | Fleet profile & real-time telemetry | `current_location`, heading, speed, battery level |
| `driver_locations` | Time-series GPS location breadcrumbs | `location GEOMETRY(Point, 4326)`, accuracy, timestamp |
| `geofence_zones` | Operational polygon boundaries | `boundary GEOMETRY(Polygon, 4326)`, surge multiplier |

### Applying the Migration

To apply `schema.sql` directly to your local or Supabase database:

```bash
# Using standard psql
psql -h localhost -U postgres -d presto_mataa_db -f schema.sql

# Or using Supabase CLI
supabase db push
```

---

## 📡 Real-Time Tracking Engine (`tracking_socket_server.js`)

The Socket.io server handles high-throughput GPS telemetry ingestion from delivery drivers, calculates dynamic ETAs, evaluates geofence boundaries, and broadcasts coordinates to customer and store rooms.

### Features
- **JWT Handshake Authentication**: Validates driver, customer, or merchant tokens during connection handshake.
- **Telemetry Throttling**: Limits driver pings to 1 update every 1.5 seconds to protect database I/O while maintaining smooth animations.
- **Geofence Proximity Alerting**: Automatically fires `driver:proximity_alert` when a driver is within 200 meters of the merchant or customer destination.
- **Reconnection Grace Period**: If a driver drops connection due to mobile network handoffs (e.g. 4G to 5G), a 30-second grace timer prevents marking the driver offline prematurely.

### Socket Event Catalog

```mermaid
sequenceDiagram
    autonumber
    actor Driver as 🛵 Driver App
    participant WS as 📡 Socket.io Server
    actor Cust as 📱 Customer App
    participant DB as 🐘 PostgreSQL / PostGIS

    Cust->>WS: order:subscribe { order_id }
    WS-->>Cust: Return live snapshot & store/driver locations
    
    loop Every 1.5s
        Driver->>WS: driver:location_update { lat, lon, heading, speed, battery }
        WS->>DB: Async persist to driver_locations
        WS->>WS: Compute Haversine distance & ETA
        WS-->>Cust: Emit order:driver_location { telemetry, eta_minutes }
    end

    opt When distance <= 200m
        WS-->>Cust: Emit driver:proximity_alert ("Driver is arriving")
    end
```

### Running the Socket Server

```bash
npm install
node tracking_socket_server.js
```

---

## 💰 Double-Entry Ledger & Escrow Service (`wallet_service.js`)

All financial operations in the Presto/Mataa platform adhere to strict **Double-Entry Bookkeeping** principles.

### Escrow & Settlement Flow

1. **Order Placed**: Customer wallet funds are debited and moved into the `platform_escrow` system wallet (`00000000-0000-0000-0000-000000000001`).
2. **Order Delivered**: Escrow is atomically released and split:
   - **Store Receives**: `Subtotal - Commission`
   - **Driver Receives**: `Delivery Fee + Tip`
   - **Platform Receives**: `Platform Fee + Store Commission`
3. **Order Cancelled**: Escrow is immediately credited back to the customer's available balance.

### Mathematical Invariant

$$\text{Total Escrow} = \text{Store Payout} + \text{Driver Payout} + \text{Platform Revenue}$$

### Deadlock Prevention Strategy

When multiple wallets are modified simultaneously (e.g., in a 4-party split settlement), `_lockWalletsInOrder` deduplicates and lexicographically sorts wallet UUIDs before executing `SELECT ... FOR UPDATE`, eliminating PostgreSQL deadlocks under high concurrency.

---

## 🔌 OpenAPI 3.0 REST Specification (`api_spec.json`)

The API follows RESTful standards with complete JSON schemas, authorization headers, and error codes.

### Key Endpoint Groups

- `POST /api/v1/auth/register` - Create account
- `POST /api/v1/auth/login` - Obtain JWT access/refresh tokens
- `GET /api/v1/stores` - Geosearched merchant directory
- `POST /api/v1/orders` - Place order & lock escrow
- `PATCH /api/v1/orders/{id}/status` - Advance order lifecycle
- `GET /api/v1/tracking/orders/{id}/live` - Current tracking snapshot
- `GET /api/v1/wallets/me` - Balance & transaction ledger
- `POST /api/v1/wallets/topup` - Credit wallet via ZainCash / QiCard

---

## ⚙ Environment Variables

| Variable | Description | Default |
| :--- | :--- | :--- |
| `PORT` | WebSocket server listening port | `4001` |
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://postgres:postgres@localhost:5432/presto_mataa_db` |
| `JWT_SECRET` | Secret used to sign and verify tokens | `super-secret-presto-jwt-key-change-in-prod` |
| `LOCATION_THROTTLE_MS` | GPS telemetry throttle interval | `1500` (1.5 seconds) |

---

## 🐳 Local Development & Docker Setup

### `docker-compose.yml`

```yaml
version: '3.8'

services:
  postgres:
    image: postgis/postgis:15-3.3-alpine
    container_name: presto_postgis
    environment:
      POSTGRES_DB: presto_mataa_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgrespassword
    ports:
      - "5432:5432"
    volumes:
      - ./schema.sql:/docker-entrypoint-initdb.d/init.sql
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: presto_redis
    ports:
      - "6379:6379"

  tracking_server:
    build: .
    container_name: presto_tracking
    environment:
      PORT: 4001
      DATABASE_URL: postgresql://postgres:postgrespassword@postgres:5432/presto_mataa_db
      JWT_SECRET: your-production-secret
    ports:
      - "4001:4001"
    depends_on:
      - postgres
      - redis

volumes:
  pgdata:
```

### Verification & Health Check

```bash
curl -X GET http://localhost:4001/health
```

Expected response:
```json
{
  "status": "UP",
  "uptime": 12.45,
  "activeConnections": 0,
  "timestamp": "2026-08-24T15:10:00.000Z"
}
```

---

## ☁️ 24/7 Cloud Deployment Guide (Render / Railway / Docker)

### Option 1: Render (Recommended - Free Tier, Auto-SSL, Frankfurt Region)
1. Push this repository to GitHub or GitLab.
2. Sign in to [Render.com](https://render.com).
3. Click **New +** -> **Web Service** -> Connect repository.
4. Select the `backend` directory (Root Directory: `backend`).
5. Render detects the `Dockerfile` or settings:
   - **Environment:** Node
   - **Build Command:** `npm install`
   - **Start Command:** `node server.js`
   - **Port:** `3000`
6. Click **Deploy**. Your service will be live 24/7 at:
   `https://<your-service-name>.onrender.com/api/v1`

### Option 2: Railway
1. Sign in to [Railway.app](https://railway.app).
2. Click **New Project** -> **Deploy from GitHub repo**.
3. Select `backend/Dockerfile` or `Procfile`.
4. Add environment variable `PORT=3000`.
5. Railway provides an HTTPS domain instantly.

### Option 3: Connecting the Flutter Apps
All 4 Flutter apps (`flutter_mobile_app`, `flutter_merchant_app`, `flutter_driver_app`, `flutter_admin_app`) are pre-configured to use the cloud server URL or can be built with `--dart-define`:
```bash
flutter run --dart-define=API_BASE_URL=https://<your-service-name>.onrender.com/api/v1
```
Or for local Android emulator testing:
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

