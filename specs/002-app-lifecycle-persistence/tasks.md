# Tasks: Cross-App State Loss & Lifecycle Persistence

**Spec**: [spec.md](file:///c:/Users/kalifa/Desktop/wasel-app/specs/002-app-lifecycle-persistence/spec.md) | **Plan**: [plan.md](file:///c:/Users/kalifa/Desktop/wasel-app/specs/002-app-lifecycle-persistence/plan.md)

---

## 📋 Task List

### Phase 1: Customer App Persistence (P1)
- [x] **Task 1.1**: Add `toJson` & `fromJson` to `CartItem` in `flutter_mobile_app/lib/services/cart_service.dart`.
- [x] **Task 1.2**: Implement `_saveCartToStorage()` and `loadFromStorage()` in `CartService` using `SharedPreferences`.
- [x] **Task 1.3**: Call `CartService.loadFromStorage()` in `flutter_mobile_app/lib/main.dart` / `home_screen.dart`.
- [x] **Task 1.4**: Update `HomeScreen._checkActiveOrder()` to support all active statuses (`assigned`, `accepted`, `arrived_at_store`, `picked_up`, etc.) and prevent premature clearing.
- [x] **Task 1.5**: Write unit tests for cart persistence in `flutter_mobile_app/test/cart_persistence_test.dart`.

### Phase 2: Merchant App Continuity & KDS Safety (P1)
- [x] **Task 2.1**: Remove accidental store closure on `dispose()` in `flutter_merchant_app/lib/main.dart`.
- [x] **Task 2.2**: Add persistent local cache for KDS orders in `flutter_merchant_app/lib/services/merchant_supabase_service.dart` so kitchen tickets survive network loss.
- [x] **Task 2.3**: Update `flutter_merchant_app/lib/main.dart` to restore cached orders before network response.

### Phase 3: Admin Settlement Concurrency Lock (P2)
- [x] **Task 3.1**: Add double-submission guard (`_isSettling`) in `flutter_admin_app/lib/screens/captains_tab.dart` settlement modal.
- [x] **Task 3.2**: Preserve search state in `CaptainsTab` and `OrdersTab`.

### Phase 4: Verification & Release Deployment (P1)
- [x] **Task 4.1**: Run `flutter analyze` across all 4 applications.
- [x] **Task 4.2**: Run `flutter test` across all applications.
- [x] **Task 4.3**: Rebuild production release APKs in `release_apks/`.
- [x] **Task 4.4**: Commit & push all changes to GitHub repository.
