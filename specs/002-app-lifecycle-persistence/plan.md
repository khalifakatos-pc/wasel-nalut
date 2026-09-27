# Implementation Plan: Cross-App State Loss & Lifecycle Persistence

**Branch**: `002-app-lifecycle-persistence` | **Date**: 2026-09-27 | **Spec**: [spec.md](file:///c:/Users/kalifa/Desktop/wasel-app/specs/002-app-lifecycle-persistence/spec.md)

---

## 🏗️ 1. Technical Architecture & Architecture Decisions

### Decision 1: Customer Cart Local Persistence
- **Component**: `flutter_mobile_app/lib/services/cart_service.dart`
- **Design**:
  - Implement `Map<String, dynamic> toJson()` and `factory CartItem.fromJson(Map<String, dynamic> json)` on `CartItem`.
  - Maintain an asynchronous persistence pipeline: whenever the cart contents change (`addItem`, `incrementItem`, `decrementItem`, `removeItem`, `clear`, `setItems`), serialize to JSON string and save to `SharedPreferences` under `'wasel_customer_cart_v1'`.
  - Provide `static Future<void> loadFromStorage()` called in `HomeScreen.initState` or `main.dart` to restore cart on boot.

### Decision 2: Customer Active Order Status Whitelist Expansion
- **Component**: `flutter_mobile_app/lib/home_screen.dart`
- **Design**:
  - Replace naive `isOngoing` check with complete non-terminal array:
    `const nonTerminalStatuses = ['placed', 'assigned', 'accepted', 'preparing', 'ready_for_pickup', 'arrived_at_store', 'picked_up', 'out_for_delivery', 'delivering'];`
  - Only execute `ApiService.clearActiveOrderId()` when order status is explicitly terminal: `delivered`, `cancelled`, or `rejected`.
  - Provide a sticky "متابعة الطلب النشط" top banner on `HomeScreen` that directly opens `OrderTrackingScreen`.

### Decision 3: Merchant Main Shell Dispose Safety
- **Component**: `flutter_merchant_app/lib/main.dart`
- **Design**:
  - In `_MerchantMainShellState.dispose()`:
    REMOVE `MerchantSupabaseService.toggleStoreStatus(_currentStore.id, false);`.
    The store status must remain controlled by the merchant's explicit online/offline switch in the app header and by the server's heartbeat freshness window (2 minutes timeout). Disposing a widget (e.g. on orientation change or backgrounding) must NEVER close a physical business.
  - Implement local ticket caching for KDS so that orders are retained offline.

### Decision 4: Captain Order Mutex & Lifecycle Protection
- **Component**: `flutter_driver_app/lib/main.dart`, `driver_home_screen.dart`, `active_delivery_flow_screen.dart`
- **Status**: Core persistence implemented and verified. Ensure settlement receipt modal returns safely.

### Decision 5: Admin Settlement Concurrency Lock
- **Component**: `flutter_admin_app/lib/screens/captains_tab.dart`
- **Design**:
  - Add `bool _isSettling = false;` guard to `_showSettleDialog` to prevent double-tap submissions resulting in duplicate receipt vouchers.

---

## 🧪 2. Verification & Test Plan
1. Unit tests for `CartService` persistence in `flutter_mobile_app/test/cart_persistence_test.dart`.
2. Static analysis across all 4 apps via `flutter analyze`.
3. Execution of unit tests via `flutter test`.
4. Production release builds for all apps.
