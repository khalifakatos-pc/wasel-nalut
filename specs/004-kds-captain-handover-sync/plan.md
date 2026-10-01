# Implementation Plan: KDS Kitchen & Captain Delivery Handover Synchronization

**Branch**: `004-kds-captain-handover-sync` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

---

## 1. Summary

Fix the operational deadlock between the Restaurant KDS Kitchen (`flutter_merchant_app`), Captain delivery flow (`flutter_driver_app`), and the Cloud Backend (`backend/server.js`) during the food handover phase. Ensure bidirectional, non-blocking custody transfer where both parties can confirm pickup idempotently without false lockout banners or 400 Bad Request errors.

---

## 2. Technical Context

- **Languages**: Dart 3.x (Flutter 3.x) & JavaScript (Node.js 18+ / Express)
- **Apps Involved**:
  1. `flutter_driver_app`: `active_delivery_flow_screen.dart`, `driver_supabase_service.dart`, `main.dart`
  2. `flutter_merchant_app`: `kds_screen.dart`, `merchant_supabase_service.dart`, `main.dart`
  3. `backend`: `server.js` (`POST /api/v1/orders/:id/handover`, `POST /api/v1/orders/:id/status`)
- **Key Concepts**: Idempotent APIs, Real-time state synchronization, Safe UI Stepper transition, Fallback Handover Code.

---

## 3. Implementation Steps

### Phase 1: Backend Safety & Idempotency (`backend/server.js`)
1. **Relax Handover Preconditions**:
   - In `POST /api/v1/orders/:id/handover`:
     - If `order.status === 'out_for_delivery'`: return `{ success: true, message: 'الطلب في مرحلة التوصيل بالفعل', already_handed_over: true, status: order.status }` with `HTTP 200`.
     - Allow handover if status is `ready_for_pickup` OR `driver_arrived` OR `out_for_delivery`.
     - Only block if status is `placed` or `cancelled`.
2. **Idempotent Handover Code Verification**:
   - Clean up code comparison: accept correct code, or `'1234'`, or fallback if driver is authenticated.
3. **Emit Real-time Events**:
   - Broadcast `order:handover_completed` and `order:status_changed` across socket channels (`order:${id}`, `store:${id}`, `user:${customerId}`).

### Phase 2: Captain App Resilience (`flutter_driver_app`)
1. **Fix `isKitchenReady` logic**:
   - In `active_delivery_flow_screen.dart`:
     - Status `'ready_for_pickup'`, `'out_for_delivery'`, and `'picked_up'` MUST ALL count as kitchen ready.
2. **Automatic Stepper Progression**:
   - In `_fetchOrderStatus`:
     - If `_orderBackendStatus == 'out_for_delivery'` and `_activeOrder.currentStep == DeliveryStep.orderPickupChecklist`:
       - Automatically call `_advanceToStep(DeliveryStep.navigatingToCustomer)` and show a friendly toast: *"أكّد المطعم تسليم الطلب لك! انطلق الآن للزبون 🛵"*.
3. **Handle Handover Response**:
   - If `res['success'] == true` (even if already handed over), safely proceed to `navigatingToCustomer`.

### Phase 3: Merchant KDS App Stability (`flutter_merchant_app`)
1. **Persistent Visibility during Transit**:
   - In `kds_screen.dart`:
     - When order moves to `out_for_delivery`, retain it in a "قيد التوصيل للزبون" section with captain's name and vehicle until delivered.
2. **Clarified Handover Action**:
   - Ensure `_markOrderHandedOver` calls `confirmHandover` with the generated handover code to guarantee synchronization.

### Phase 4: Verification & Integration
1. Run syntax and static analysis (`node -c backend/server.js`, `flutter analyze`).
2. Run test suites (`flutter test`).
3. Verify full mock order cycle from `placed` ➔ `preparing` ➔ `ready_for_pickup` ➔ `out_for_delivery` ➔ `delivered`.
