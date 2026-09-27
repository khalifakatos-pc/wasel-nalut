# Wasel Nalut (واصل نالوت) — Project Constitution

## Core Principles

### I. Hyper-Local Nalut Context & Multi-Tenant Isolation
Every feature, store, driver, and transaction is strictly rooted in Nalut (نالوت) and Jabal Nafusa, Libya.
* All phone validations strictly enforce Libyan mobile formats (`091`, `092`, `094`, `095`, `093`).
* Currency must strictly remain Libyan Dinar (`د.ل` or `LYD`). USD (`$`) or generic currencies are strictly prohibited.
* Stores and fleets are geographically bound to Nalut coordinates (`31.8686° N, 10.9818° E`) with multi-tenant isolation across all 4 applications.

### II. Sharia Compliance & Financial Transparency (NON-NEGOTIABLE)
All financial flows must adhere to Islamic commercial principles (absence of Gharar and Riba):
* **Zero Customer Platform Surcharge**: Customers must never be billed a hidden "platform service fee". The customer invoice equals `Subtotal + Delivery Fee - Legitimate Discounts`.
* **Merchant-Side Operational Brokerage**: Wasel's commission (e.g. 10%) is deducted transparently from merchant payouts on the business-to-business layer.
* **Driver Cash Escrow (تسوية العهد المالية)**: COD (Cash on Delivery) collections belong to escrow until settled with the administrator via verifiable accounting records.

### III. Multi-App Architecture & Modular Contracts
The ecosystem consists of 4 distinct Flutter client applications and a unified real-time backend:
1. `flutter_mobile_app`: Customer ordering, live map tracking, loyalty, and checkout.
2. `flutter_driver_app`: Captain dispatch, order acceptance, turn-by-turn navigation, and OTP verification.
3. `flutter_merchant_app`: Multi-tenant portal for order acceptance, preparation state, and catalog management.
4. `flutter_admin_app`: Fleet oversight, PIN-locked dispatch operations, driver settlements, and metrics.
Backend APIs and WebSockets must maintain backward-compatible REST contracts and JSON schemas.

### IV. Test-Driven Verification & Zero-Warning Gate (NON-NEGOTIABLE)
Code quality is enforced via automated continuous testing:
* **Zero Analyzer Issues**: `flutter analyze` must report 0 issues across all 4 apps prior to any production commit.
* **Multi-Tier E2E Testing**: All UI and backend flows must be validated against Tier 1 (smoke), Tier 2 (boundaries), Tier 3 (cross-feature), and Tier 4 (Nalut scenarios).
* **Regression-Free Deployments**: Backend integration tests (`backend/test_server.js`) must exit with code 0 before code push.

### V. Offline Resilience & Mountainous Network Handling
Given Nalut's mountainous geography and sporadic mobile connectivity:
* Sockets must implement exponential backoff with capped retries and fallback to passive HTTP polling.
* Critical screens must never crash or freeze indefinitely due to network timeouts; seed data or cached state must serve as graceful fallbacks.

## Technology Stack & Standards
* **Mobile / Frontend**: Flutter 3.x, Dart 3.x, Material 3, Clean Architecture (UI -> Logic -> Data).
* **Backend**: Node.js, Express, Socket.io, JWT authentication, Render deployment pipeline.
* **Database**: PostgreSQL (Production) / SQLite / Seed Engine with idempotent SQL migrations.
* **AI & Dispatch**: HuggingFace / Local NLP for Libyan menu processing; Hungarian Algorithm dispatch heuristics.

## Governance
This Constitution is the supreme architectural guide for all agents and contributors on the Wasel Nalut project.
* Any proposed change to financial models, fees, or core contracts must be evaluated against this document.
* Automated testing and static analysis are mandatory gates for all milestones.

**Version**: 1.0.0 | **Ratified**: 2026-09-27 | **Scope**: Wasel Nalut Super-App Ecosystem
