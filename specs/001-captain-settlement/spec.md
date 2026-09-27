# Feature Specification: Captain Cash Settlement & Merchant Order Notifications

**Feature Branch**: `001-captain-settlement`  
**Created**: 2026-09-27  
**Status**: Ready for Implementation  
**Target Applications**: `flutter_admin_app`, `flutter_merchant_app`, `backend`  

---

## 1. Executive Summary & Context
In the Wasel Nalut ecosystem, cash on delivery (COD) orders require drivers to hold collected cash in a physical float/custody (عُهدة مالية). The administrator must be able to periodically inspect each captain's collected cash, perform an immediate settlement (تسوية عهدة), zero out the driver's active balance, generate a verified digital receipt (سند قبض رسمي), and update the double-entry accounting ledger.

Concurrently, merchants and restaurant kitchens must receive instantaneous, loud notifications (both via Socket.io and Firebase Cloud Messaging) whenever a new order is placed so food preparation begins without delay.

---

## 2. User Scenarios & Acceptance Criteria *(Mandatory)*

### User Story 1 - Captain Cash Custody Settlement in Admin App (Priority: P1)
**As a** Wasel Nalut system administrator,  
**I want to** view each driver's accrued COD balance and trigger an immediate settlement with one click,  
**So that** I can collect the physical Libyan cash from the captain, clear their liability, and maintain financial integrity.

* **Why this priority**: Without settlement, drivers exceed their COD limit and cannot accept more orders, paralyzing field delivery operations in Nalut.
* **Independent Test**: Admin opens Captains tab in Admin App -> Taps "تسوية العهدة" on a captain with >0 LYD balance -> Confirms dialog -> Driver balance becomes 0.0 LYD in backend and UI, and Digital Voucher dialog opens.

**Acceptance Scenarios**:
1. **Given** driver `drv_nalut_01` has a `wallet_balance_lyd` of `45.0` LYD,  
   **When** Admin clicks "تسوية العهدة" and confirms cash collection,  
   **Then** Backend `/api/v1/drivers/:id/settle` zeroes the balance, creates an immutable voucher `REC-YYYY-XXXX` in the ledger, and emits `driver:settled` via WebSocket.
2. **Given** driver has `0.0` LYD balance,  
   **When** Admin views the captain list,  
   **Then** The "تسوية العهدة" button is disabled.

---

### User Story 2 - Audit Trail & Digital Settlement Voucher Generation (Priority: P2)
**As an** administrator and accountant,  
**I want** every settlement to produce an official digital receipt (سند قبض) with a unique number, amount in Arabic words, and timestamp,  
**So that** both the platform and the captain have proof of settlement conforming to Islamic financial transparency.

* **Why this priority**: Ensures zero dispute between captains and management (إبراء ذمة شرعي).
* **Independent Test**: After settlement, the `DigitalVoucherDialog` renders correctly with voucher type `receipt`, correct LYD amount, and Arabic spelled-out currency text.

**Acceptance Scenarios**:
1. **Given** a settlement for `143.0` LYD,  
   **When** settlement completes,  
   **Then** a voucher with number `REC-2026-XXXX` is stored in the database with status `completed` and displayed in `accounting_tab.dart`.

---

### User Story 3 - Merchant Order Alerts & FCM Topic Subscription (Priority: P3)
**As a** Nalut merchant (restaurant or grocery store owner),  
**I want** my tablet or phone to ring with a distinct high-priority alert when a customer orders,  
**So that** the kitchen staff immediately begins preparing the order.

* **Why this priority**: Minimizes food preparation delay and customer wait time.
* **Independent Test**: When order is created in Customer App -> Backend emits socket event to `store:<id>` and FCM to `store_<store_id>` -> Merchant app displays a sticky local notification banner with alarm sound.

**Acceptance Scenarios**:
1. **Given** merchant logs into `مطعم قصر نالوت للمشويات` (`store_nalut_01`),  
   **When** app initializes notifications,  
   **Then** `MerchantNotificationService` explicitly subscribes to FCM topic `store_store_nalut_01`.
2. **Given** a new order arrives,  
   **When** payload is received,  
   **Then** Android notification channel `wasel_kitchen_alerts_channel` triggers with maximum importance (`PRIORITY_MAX`).

---

## 3. Functional Requirements

- **FR-001**: Backend `/api/v1/drivers/:id/settle` MUST accept settlement requests, atomically reset driver balance to 0.0, and record a `receipt` voucher in `db.vouchers` with a unique serial number (`REC-YYYY-XXXX`).
- **FR-002**: Backend MUST persist the settlement in PostgreSQL / SQLite storage and broadcast `driver:settled` with `{ driver_id, settled_amount, balance: 0.0 }` via Socket.io.
- **FR-003**: `flutter_admin_app` MUST show a confirmation dialog showing driver name and exact cash amount before settling.
- **FR-004**: `flutter_admin_app` MUST immediately display the official digital receipt dialog (`DigitalVoucherDialog`) after successful settlement.
- **FR-005**: `flutter_admin_app` Accounting tab MUST list the generated settlement voucher in the "السندات الرقمية" and update the live cash in treasury.
- **FR-006**: `flutter_merchant_app` `MerchantNotificationService` MUST provide `subscribeToStore(storeId)` and `unsubscribeFromStore(storeId)` methods.
- **FR-007**: `flutter_merchant_app` MUST invoke `subscribeToStore(_currentStore.id)` upon login/init and unsubscribe on logout.
- **FR-008**: `backend/fcm_dispatcher.js` MUST ensure the merchant notification topic matches the format expected by the client: `store_${storeId.replace(/-/g, '_')}`.
- **FR-009**: Static analysis across all apps MUST remain at 0 issues (`flutter analyze` clean).
- **FR-010**: All monetary amounts MUST strictly use Libyan Dinar (`د.ل` / `LYD`).

---

## 4. Edge Cases & Mitigation

| Edge Case | Mitigation |
|---|---|
| Admin settles while offline | `AdminSupabaseService` simulates local zeroing and generates offline voucher, then queues sync on reconnect. |
| Double click on "تسوية العهدة" | Disable button and show spinner immediately upon click to prevent duplicate vouchers. |
| Negative or zero balance | Button disabled when `balance <= 0.0`. |
| Merchant device in sleep/Doze mode | FCM configured with `high` priority and `fullScreenIntent` on Android to wake device. |

---

## 5. Non-Functional & Sharia Constraints
* **No Hidden Fees**: Settlement only deals with actual collected COD cash. No unauthorized deductions.
* **Full Transparency**: Both parties must see the exact same breakdown of orders and totals.
