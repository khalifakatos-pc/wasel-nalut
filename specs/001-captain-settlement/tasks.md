# Tasks: Captain Cash Settlement & Merchant Order Notifications

**Feature**: `001-captain-settlement`  
**Spec**: [spec.md](./spec.md)  
**Plan**: [plan.md](./plan.md)  

---

## Phase 1: Backend Financial Settlement Enhancement (User Story 1 & 2)

- [x] T001 [US1, US2] Enhance `POST /api/v1/drivers/:id/settle` in `backend/server.js`:
  - Calculate `settledAmount = driver.wallet_balance_lyd || 0.0`
  - Generate official voucher `REC-YYYY-XXXX` and record in `db.vouchers`
  - Zero out `driver.wallet_balance_lyd = 0.0`
  - Broadcast `driver:settled` with `{ driver_id, settled_amount, balance: 0.0, voucher }` via Socket.io
  - Save seed data and persist to PostgreSQL
- [x] T002 [US1] Add automated backend test in `backend/test_server.js` verifying the driver settlement endpoint generates a voucher and clears wallet balance

---

## Phase 2: Merchant Order Notifications & Topic Subscription (User Story 3)

- [x] T003 [US3] Implement `subscribeToStore` and `unsubscribeFromStore` in `flutter_merchant_app/lib/services/merchant_notification_service.dart` for topic `store_${storeId.replaceAll('-', '_')}`
- [x] T004 [US3] Wire up `subscribeToStore(_currentStore.id)` in `_initNotifications` and `unsubscribeFromStore` on logout in `flutter_merchant_app/lib/main.dart`

---

## Phase 3: Admin Cash Settlement UI & Ledger Sync (User Story 1 & 2)

- [x] T005 [US1, US2] Enhance `AdminSupabaseService.settleDriverCashWithVoucher` in `flutter_admin_app/lib/services/admin_supabase_service.dart` to consume server-returned voucher
- [x] T006 [US1] Verify `flutter_admin_app/lib/screens/captains_tab.dart` cash settlement dialog and `DigitalVoucherDialog` trigger

---

## Phase 4: Quality Gate & Full Ecosystem Verification

- [x] T007 Run `node backend/test_server.js` to ensure 100% backend test pass
- [x] T008 Run `flutter analyze flutter_admin_app flutter_merchant_app` to verify 0 warnings and 0 errors
- [x] T009 Run `flutter test` in `flutter_admin_app` and `flutter_merchant_app`
- [x] T010 Commit and push all changes to git
