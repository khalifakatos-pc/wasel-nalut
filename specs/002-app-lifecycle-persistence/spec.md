# Feature Specification: Cross-App State Loss & Lifecycle Persistence

**Feature Branch**: `002-app-lifecycle-persistence`  
**Created**: 2026-09-27  
**Status**: In Implementation  
**Input**: "استخدام spec kit tool على كامل التطبيقات لاستخراج أخطاء فقدان الطلبات وحالة التطبيقات وإصلاحها"

---

## 🎯 1. Overview & Problem Statement
In mobile field operations across Nalut and Nafusa Mountains (Libya), captains, merchants, and customers frequently face intermittent cellular connectivity, app backgrounding by Android battery optimization, phone calls, and device reboots.

A critical vulnerability across the ecosystem was **in-memory-only state retention** and **destructive lifecycle events**:
1. **Customer App (`flutter_mobile_app`)**:
   - The shopping cart was stored purely in RAM (`CartService._items`). Any OS kill or restart wiped the customer's cart.
   - Active order polling (`_checkActiveOrder`) prematurely cleared active orders (`ApiService.clearActiveOrderId()`) if the order was in `assigned`, `accepted`, `arrived_at_store`, `picked_up`, or `delivering` because the filter only checked a hardcoded subset of statuses.
2. **Merchant App (`flutter_merchant_app`)**:
   - The main shell widget `dispose()` method automatically toggled the physical store status to `closed` in the cloud (`toggleStoreStatus(_currentStore.id, false)`). This caused restaurants and grocery stores to unexpectedly appear closed to all customers whenever the merchant took a phone call or minimized the app!
   - Kitchen Display System (KDS) orders were unpersisted in local storage, causing delayed or missing tickets upon reconnect.
3. **Captain App (`flutter_driver_app`)**:
   - Back button in delivery flow triggered full order termination (`onFinishedDelivery`).
   - Radar order search lacked active-delivery mutual exclusion.
   - Order lacked local SQLite/SharedPreferences persistence.
4. **Admin App (`flutter_admin_app`)**:
   - Filter state and active search queries were lost on sub-modal navigation. Double-tap race conditions in driver cash settlements needed debounce protection.

---

## 👥 2. User Scenarios & Prioritized Stories

### User Story 1 - Customer Cart & Order Recovery (Priority: P1)
**User Persona**: Nalut Citizen ordering lunch or medicine.  
**Scenario**: The customer adds items to their cart, locks the phone, and receives a phone call. Upon unlocking and reopening Wasel Nalut, the cart remains 100% intact. Furthermore, if they have an active delivery order, reopening the app displays an unmissable live tracking card regardless of whether the status is `assigned`, `preparing`, `picked_up`, or `out_for_delivery`.

**Acceptance Scenarios**:
1. **Given** a customer with items in their cart, **When** the app is terminated and reopened, **Then** all items, customizations, and quantities are restored from disk.
2. **Given** an ongoing order in any non-terminal state (`placed`, `assigned`, `accepted`, `preparing`, `ready_for_pickup`, `arrived_at_store`, `picked_up`, `out_for_delivery`, `delivering`), **When** `_checkActiveOrder` runs, **Then** the active order is NEVER wiped from storage until reaching `delivered`, `cancelled`, or `rejected`.

---

### User Story 2 - Merchant Store Continuity & KDS Resilience (Priority: P1)
**User Persona**: Nalut Restaurant or Supermarket Owner.  
**Scenario**: The merchant opens their store in the morning. When switching between apps or answering a phone call, their store MUST remain `open` to the public. Only explicit merchant action ("إغلاق مؤقت") or manual logout may close the store. In addition, existing cooking tickets must remain cached locally.

**Acceptance Scenarios**:
1. **Given** an open merchant store, **When** the app is minimized, rotated, or closed, **Then** the cloud backend is NOT sent a `closed` command on `dispose()`.
2. **Given** ongoing cooking tickets in the KDS, **When** the app restarts, **Then** tickets are immediately loaded from local cache while cloud sync verifies updates in the background.

---

### User Story 3 - Captain Safe Navigation & Mutual Exclusion (Priority: P1)
**User Persona**: Wasel Captain in Nalut.  
**Scenario**: While delivering an order, the captain can switch to the Home tab without destroying the active order. The manual radar trigger and automated order polling must be locked while a delivery is active.

**Acceptance Scenarios**:
1. **Given** an active delivery, **When** the captain presses the back arrow on the delivery screen, **Then** the UI returns to the main tabs while preserving the order in memory and disk.
2. **Given** an active delivery, **When** the captain presses "فحص وصول طلبات نالوت الجديدة", **Then** the system blocks new orders and offers a single tap to return to the active delivery.

---

### User Story 4 - Admin Settlement Debounce & State Preservation (Priority: P2)
**User Persona**: Platform Operations Manager.  
**Scenario**: Admin settles a driver's cash custody. The settlement button must be debounced to prevent duplicate vouchers, and captain search queries should persist when returning from the digital voucher dialog.

**Acceptance Scenarios**:
1. **Given** the captain settlement dialog, **When** the admin taps "تأكيد واستلام العهدة", **Then** the button is disabled immediately to prevent duplicate vouchers.

---

## 📋 3. Functional Requirements

- **FR-001**: `CartService` MUST serialize `CartItem` to JSON and persist changes to `SharedPreferences` under key `wasel_customer_cart_v1`.
- **FR-002**: `CartService` MUST automatically load and deserialize cached cart items during app initialization.
- **FR-003**: Customer `HomeScreen._checkActiveOrder` MUST recognize the complete set of non-terminal statuses: `['placed', 'assigned', 'accepted', 'preparing', 'ready_for_pickup', 'arrived_at_store', 'picked_up', 'out_for_delivery', 'delivering']`.
- **FR-004**: Merchant `MerchantMainShell` MUST NOT toggle store status to false on `dispose()`. Store status shall only change on explicit user toggle or logout.
- **FR-005**: Merchant `KdsScreen` / `MerchantMainShell` MUST cache active tickets locally so the kitchen never appears blank on connection hiccup.
- **FR-006**: Captain `ActiveDeliveryFlowScreen` MUST NOT invoke `onFinishedDelivery` upon back button press; it MUST invoke `onBackToHome`.
- **FR-007**: Admin `CaptainsTab` settlement flow MUST include in-flight state lock to prevent double execution.

---

## 🛡️ 4. Non-Functional & Reliability Requirements
- **NFR-001 (Zero Data Loss)**: No order, cart item, or financial voucher shall be lost due to client-side app lifecycle events.
- **NFR-002 (Offline Tolerant)**: Apps must render cached operational data in under 200ms upon launch before network calls resolve.
- **NFR-003 (Currency Integrity)**: All prices and balances must strictly remain in Libyan Dinars (`د.ل` / `LYD`).
