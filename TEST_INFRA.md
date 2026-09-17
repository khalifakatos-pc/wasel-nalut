# WASEL Customer App - Test Infrastructure & Strategy Specification

## 1. Test Philosophy & Principles
The testing framework for the Wasel Customer App (`flutter_mobile_app`) is designed around deterministic, behavior-driven, opaque-box validation. It verifies that user-facing behaviors, business rules, Libyan localization constraints, and tactile interactions adhere to `PROJECT.md` and `ORIGINAL_REQUEST.md` without coupling tests to internal implementation details.

Key testing principles:
- **Opaque-Box Testing**: Validate observable outputs, UI renderings, state transitions, and error messages rather than private state variables.
- **Hermetic & Independent Execution**: Every test suite establishes its own state via mock initialization (`SharedPreferences.setMockInitialValues({})`), in-memory data resets, and scoped widget trees. No test depends on execution order or side effects from preceding tests.
- **Deterministic Asynchronous Control**: Eliminate flakiness and mock deadlocks by controlling fake asynchronous timers (`pump`, `pumpAndSettle`, simulated timeouts) and bypassing live cloud network sockets during automated unit and widget runs.
- **Progressive Testability**: Every test exercises verified Milestone deliverables (M1 through M4) with clear traceability to the Feature Inventory in `PROJECT.md`.
- **Adversarial Boundary Validation**: Thoroughly stress input combinations, such as malformed Libyan phone numbers, coupon variations, and boundary cart values.

---

## 2. Feature Inventory Mapping

| Feature # | Feature Name | Test Tier | Primary Test File | Verification Scope |
|---|---|---|---|---|
| F1 | Guarded Startup & Firebase | Tier 1 | `tier1_feature_test.dart` | Verify app boots without hanging on uninitialized Firebase services |
| F2 | Resilient SocketService | Tier 1 | `tier1_feature_test.dart` | Verify fallback mode when socket endpoint is offline |
| F3 | Fast Splash & Session Routing | Tier 1 | `tier1_feature_test.dart` | Verify splash duration, brand elements, and transition to Onboarding/Home |
| F4 | Frame-0 Store Rendering | Tier 1 | `tier1_feature_test.dart` | Instant store catalog rendering from authentic Nalut cached stores |
| F5 | Tactile WaselBouncyPressable | Tier 1 | `tier1_feature_test.dart` | Bouncy pressable scale transformation and tap gesture propagation |
| F6 | Interactive Category & Cards | Tier 1 | `tier1_feature_test.dart` | Category switcher and store card selection triggers |
| F7 | HitTest & Minimum Target Sizes | Tier 1 | `tier1_feature_test.dart` | Validate opaque hit testing on pressables and navigation targets |
| F8 | 60/120 FPS Scroll Architecture | Tier 1 | `tier1_feature_test.dart` | Sliver scrolling in store menus and catalog without gesture blocking |
| F9 | Authentic Nalut Stores Cache | Tier 1, Tier 4 | `tier1_feature_test.dart`, `tier4_scenario_test.dart` | Presence of "مطعم قصر نالوت للمشويات", "بيتزا القلعة", "أسواق نالوت" |
| F10 | Instant Nalut Menus | Tier 1, Tier 4 | `tier1_feature_test.dart`, `tier4_scenario_test.dart` | Menu loading for authentic Nalut stores without latency cascades |
| F11 | In-Memory & Local Storage Cache | Tier 1 | `tier1_feature_test.dart` | Session caching for active address and preferences |
| F12 | Clean Guest Mode | Tier 1, Tier 3 | `tier1_feature_test.dart`, `tier3_cross_feature_test.dart` | Guest browsing without phantom orders or forced login on startup |
| F13 | Shared Cart State (`CartService`) | Tier 1, Tier 3 | `tier1_feature_test.dart`, `tier3_cross_feature_test.dart` | Item addition, quantity increments/decrements, subtotal in LYD (`د.ل`) |
| F14 | Checkout & Libyan Phone Input | Tier 2, Tier 3 | `tier2_boundary_test.dart`, `tier3_cross_feature_test.dart` | Validation of 9-digit Libyan phone prefixes (091/092/094/093) |
| F15 | Live Order Tracking & Stepper | Tier 1, Tier 3, Tier 4 | `tier1_feature_test.dart`, `tier3_cross_feature_test.dart`, `tier4_scenario_test.dart` | Nalut coordinates (31.8687, 10.9818), order stages, and tracking UI |
| F16 | Profile & Theme Persistence | Tier 1 | `tier1_feature_test.dart` | Dark/light theme toggling and profile settings presentation |

---

## 3. Architecture & Test Harness

### 3.1 Test Harness (`test_harness.dart`)
To ensure reliable, non-flaky execution under `flutter test`, all widget tests wrap target components in a unified `TestAppHarness`:
- **MaterialApp & RTL Localization**: Configured with `Locale('ar')`, `GlobalMaterialLocalizations.delegate`, and `AppTheme.lightTheme`.
- **Directionality**: Directionality forced to `TextDirection.rtl` matching Arabic UX expectations.
- **Timer Management**: Handles pending animation and periodic timers gracefully via explicit controller disposal and simulated virtual clock advances.
- **Hermetic Mock Services**: Sets up mock `SharedPreferences` keys (`is_guest`, `user_phone`, `user_name`, `auth_token`, `wasel_loyalty_points`) prior to each test case.

### 3.2 Directory Structure
```
flutter_mobile_app/test/
├── e2e/
│   ├── test_harness.dart             # Shared test harness and helper utilities
│   ├── tier1_feature_test.dart       # Tier 1: Core single-feature verification
│   ├── tier2_boundary_test.dart      # Tier 2: Boundary, negative, and input validation
│   ├── tier3_cross_feature_test.dart # Tier 3: Multi-screen and cross-feature interactions
│   └── tier4_scenario_test.dart      # Tier 4: Real-world Nalut ordering workflow
└── widget_test.dart                  # Basic root smoke test
```

---

## 4. Test Tiers & Scenario Definitions

### Tier 1: Feature Verification (`tier1_feature_test.dart`)
- **T1.1 Startup & Splash Flow**: Verifies `SplashScreen` mounts with logo, brand title "واصل | WASEL", and successfully navigates.
- **T1.2 Frame-0 Store Catalog**: Verifies `HomeScreen` loads the authentic Nalut stores ("مطعم قصر نالوت للمشويات", "بيتزا ومعجنات القلعة نالوت", "أسواق نالوت المركزية للمواد الغذائية") synchronously or with fallback cache.
- **T1.3 Tactile WaselBouncyPressable**: Verifies `WaselBouncyPressable` scales down upon `tapDown` and triggers callbacks on tap release.
- **T1.4 Cart Manipulation**: Verifies adding items, updating quantities, recalculating totals in LYD (`د.ل`), and removing items.
- **T1.5 Live Order Tracking**: Verifies `OrderTrackingScreen` renders Nalut delivery coordinates (`31.8687, 10.9818`), status pill, and map canvas.
- **T1.6 Profile & Theme Toggle**: Verifies `ProfileScreen` renders customer details and theme switch.

### Tier 2: Boundary Conditions & Negative Testing (`tier2_boundary_test.dart`)
- **T2.1 Empty Cart Checkout Rejection**: Verifies that tapping checkout on an empty cart is blocked and displays empty state UI.
- **T2.2 Libyan Phone Validation - Incomplete Digits**: Rejects numbers with length < 9 digits with appropriate validation feedback.
- **T2.3 Libyan Phone Validation - Invalid Characters**: Rejects phone inputs containing alphabetic or special characters.
- **T2.4 Libyan Phone Validation - Valid Prefixes**: Accepts valid Libyan prefixes (`091`, `092`, `094`, `093`) and updates guest profile.
- **T2.5 Coupon Code Validation & Rejection**:
  - Validates discount code `WASEL2026` applies a 5.00 LYD discount.
  - Validates free delivery codes (`FREEDELIVERY` or `FREE-*`) waive delivery fee.
  - Rejects unknown/expired coupon codes with descriptive error messages.
- **T2.6 Extreme Quantities & Prices**: Validates subtotal calculation with high quantity items and zero prices without numeric overflow.

### Tier 3: Cross-Feature Pairwise Interactions (`tier3_cross_feature_test.dart`)
- **T3.1 Guest Browsing to Customization**: Guest explores `HomeScreen`, opens `StoreMenuScreen`, selects dish to launch `ProductDetailSheet`.
- **T3.2 Customization to Cart**: Selects dish size (عادي / دبل / جامبو) and add-ons, adjusts stepper quantity, and commits to cart.
- **T3.3 Cart to Guest Checkout Phone Prompt**: Cart displays items with accurate LYD calculations; initiating checkout triggers the Libyan contact info bottom sheet for unauthenticated guests.
- **T3.4 Phone Entry to Order Placement**: Guest inputs phone `0912345678`, proceeds to order placement, triggering successful order confirmation dialog.
- **T3.5 Transition to Live Order Tracking**: Clicking track order pushes `OrderTrackingScreen`, displaying the generated order number, Nalut coordinates, and stepper status.

### Tier 4: Real-World Nalut Ordering Workflow (`tier4_scenario_test.dart`)
- **T4.1 Authentic Nalut Grilled Meat Order**:
  1. Customer starts at Nalut home view.
  2. Selects "مطعم قصر نالوت للمشويات".
  3. Browses menu and picks "صحن مشكل كباب وشقف لحم وطني" (34.00 LYD).
  4. Customizes size and adds garlic sauce and extra fries in `ProductDetailSheet`.
  5. Navigates to `CartCheckoutScreen`.
  6. Applies promotional coupon `WASEL2026` and verifies subtotal, discount, and grand total.
  7. Confirms order and transitions to live tracking in Nalut.
  8. Verifies status progresses and shows driver contact and OTP code.
