# Tasks: KDS Kitchen & Captain Delivery Handover Synchronization

**Branch**: `004-kds-captain-handover-sync` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

---

## Task List

### Phase 1: Backend Hardening (`backend/server.js`)
- [x] **TASK-001**: Make `POST /api/v1/orders/:id/handover` idempotent and accept orders already in `out_for_delivery`.
- [x] **TASK-002**: Fix status validation in `POST /api/v1/orders/:id/status` so merchant confirming handover doesn't invalidate subsequent driver pickup requests.
- [x] **TASK-003**: Verify syntax with `node -c backend/server.js`.

### Phase 2: Captain App Hardening (`flutter_driver_app`)
- [x] **TASK-004**: Broaden `isKitchenReady` in `active_delivery_flow_screen.dart` to include `ready_for_pickup`, `out_for_delivery`, and `picked_up`.
- [x] **TASK-005**: Add automatic stepper forward transition in `_fetchOrderStatus` when order reaches `out_for_delivery`.
- [x] **TASK-006**: Improve handover error handling and notification in `_advanceToStep` and the pickup checklist button callback.

### Phase 3: Merchant KDS App Enhancements (`flutter_merchant_app`)
- [x] **TASK-007**: Ensure `_markOrderHandedOver` invokes `MerchantSupabaseService.confirmHandover` with proper handover code.
- [x] **TASK-008**: Retain visibility of active out-for-delivery orders in KDS with driver details.

### Phase 4: Testing & Verification
- [x] **TASK-009**: Run `flutter analyze` on modified Dart files. (0 issues found)
- [x] **TASK-010**: Run `flutter test` across apps. (50/50 tests passed)
- [x] **TASK-011**: Commit and deploy updates.
