# Tasks: Order Lifecycle Handover Audit & Modern Kitchen App Redesign

**Spec**: [spec.md](file:///c:/Users/kalifa/Desktop/wasel-app/specs/006-order-handover-audit-and-kds-redesign/spec.md) | **Plan**: [plan.md](file:///c:/Users/kalifa/Desktop/wasel-app/specs/006-order-handover-audit-and-kds-redesign/plan.md)

---

## 📋 Task List

### Phase 1: Captain Order Handover & Bill Audit Flow (Driver App)
- [x] **Task 1.1**: Update `flutter_driver_app/lib/active_delivery_flow_screen.dart` with state variable `_isBillAuditApproved`.
- [x] **Task 1.2**: Implement `_showBillAuditSheet(BuildContext context)`:
  - Header: Store name, order number, timestamp.
  - Interactive items checklist with checkmarks for each dish/beverage.
  - Detailed price breakdown (Meal total, Delivery fee, COD to collect in `د.ل`).
  - Formal agreement checkbox: *"أوافق وأقر بأنني فحصت الفاتورة واستلمت كامل أصناف الطلب بحالة سليمة من المطبخ ✅"*.
  - Action button: `"اعتماد الفاتورة والموافقة على الاستلام"` which sets approval and closes sheet.
- [x] **Task 1.3**: Update Step 2 bottom action button:
  - If bill not audited/approved: show `"استلام الطلب وتجريد الفاتورة 📋"` (triggers `_showBillAuditSheet`).
  - If approved: show `"تأكيد الاستلام ونقل العهدة للانطلاق 🛵"` which triggers custody transfer to `out_for_delivery` and advances step.

### Phase 2: Kitchen App Auto-Identification & Store Switcher (Merchant App)
- [x] **Task 2.1**: Update `flutter_merchant_app/lib/merchant_theme.dart` to define rich light theme tokens (`lightBg = #F8FAFC`, `lightSurface = #FFFFFF`, `lightBorder = #E2E8F0`, `lightText = #0F172A`, status badge colors, and Stitch shadows).
- [x] **Task 2.2**: Redesign `flutter_merchant_app/lib/merchant_login_screen.dart`:
  - Modern light aesthetic with clean white surface and warm amber highlights.
  - Interactive 1-click Store Cards (مطعم رانشيلو نالوت 🌯, قصر نالوت للمشويات 🥩, ريكسوس ماركت 🛒, مخبز الجبل 🥐).
  - Instant auto-login & local storage lock upon clicking any store.
  - Compatibility with manual phone/PIN login and test suites.
- [x] **Task 2.3**: In `flutter_merchant_app/lib/main.dart`:
  - Use `MerchantTheme.lightTheme` by default.
  - Add active store header badge with 1-tap "تبديل" button allowing effortless switching between Nalut stores.

### Phase 3: KDS Kitchen Display System Modern Visual Redesign (Merchant App)
- [x] **Task 3.1**: Redesign `flutter_merchant_app/lib/kds_screen.dart`:
  - Change canvas background to clean `#F8FAFC`.
  - Transform order ticket cards to modern white elevated cards (`#FFFFFF`) with rounded-2xl geometry.
  - Update status headers:
    - New order: Vibrant Warm Amber (`#FEF3C7` background, `#B45309` text).
    - In prep: Clean Sky Blue (`#E0F2FE` background, `#0369A1` text).
    - Ready: Mint Green (`#D1FAE5` background, `#047857` text).
    - Completed: Clean Slate (`#F1F5F9` background, `#475569` text).
  - Update item list display to clear high-contrast typography with notes in amber badges.
  - Update action buttons: Large touch-friendly buttons for kitchen chefs.

### Phase 4: Verification, Builds & Deployment
- [x] **Task 4.1**: Run `flutter analyze` across `flutter_driver_app` and `flutter_merchant_app` to verify 0 errors / 0 warnings.
- [x] **Task 4.2**: Run driver and merchant tests to verify all regression and lifecycle checks pass.
- [x] **Task 4.3**: Rebuild release APKs: `Wasel_Captain_App.apk` and `Wasel_Merchant_App.apk` into `C:\Users\kalifa\Desktop\Wasel_Android_APKs\`.
- [x] **Task 4.4**: Commit & push all changes to GitHub repository.
