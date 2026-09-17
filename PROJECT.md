# Project: Wasel Customer App (`flutter_mobile_app`)

## Architecture
- **Framework**: Flutter 3.x / Dart 3.x (Android target, Null-Safety)
- **State & Service Layer**: Singleton / Service-locator pattern (`ApiService`, `CartService`, `CustomerNotificationService`, `SocketService`)
- **UI Architecture**:
  - `SplashScreen` -> `MainNavigationShell` / `OnboardingScreen` / `LoginScreen`
  - `MainNavigationShell`: Indexed bottom navigation tabs (Home, Orders, Cart, Wallet, Profile)
  - `HomeScreen`: Nalut localized store catalog, category switcher, promotional carousels, active order tracker pill
  - `StoreMenuScreen` & `ProductDetailSheet`: Categorized dishes, options/extras, instant add-to-cart
  - `CartCheckoutScreen`: LYD calculations, coupon application, Libyan phone validation, order placement
  - `OrderTrackingScreen`: OpenStreetMap Flutter map centered on Nalut (`31.8687, 10.9818`), timeline stepper
- **Data Flow**:
  - Offline-first cache-first: Authentic Nalut stores and menus available synchronously on frame 0
  - Background async reconciliation with cloud backend (`https://wasel-nalut.onrender.com` / Supabase)

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Guarded Startup & Firebase | Non-blocking Firebase initialization, lazy `_fcm` getter, unconditional local notifications | M1 | Survey R1 |
| 2 | Resilient SocketService | Cloud WebSocket endpoint fallback, remove 3s infinite reconnect loop | M1 | Survey R1 |
| 3 | Fast Splash & Session Routing | Splash duration < 2.0s, async session check before route resolution | M1 | Survey R1 |
| 4 | Frame-0 Store Rendering | Instant cache render on launch without waiting for cold backend | M1 | Survey R1 |
| 5 | Tactile WaselBouncyPressable | Instant visual compression without scroll delay, haptics on press-up/tap | M2 | Survey R2 |
| 6 | Interactive Category & Cards | Tap handlers for categories, dish cards, promo banners | M2 | Survey R2 |
| 7 | HitTest & Minimum Target Sizes | `HitTestBehavior.opaque` on tabs, steppers, filters (>=48dp touch targets) | M2 | Survey R2 |
| 8 | 60/120 FPS Scroll Architecture | Sliver-based virtualization, eliminate nested `shrinkWrap` grids, reduce root `setState` | M2 | Survey R2 |
| 9 | Authentic Nalut Stores Cache | Unified Nalut stores (قصر نالوت للمشويات، بيتزا القلعة، أسواق نالوت المركزية) in `ApiService` & UI | M3 | Survey R3 |
| 10 | Instant Nalut Menus | Zero-delay local menu cache for authentic Nalut stores, eliminate 8s-12s cascade | M3 | Survey R3 |
| 11 | In-Memory & Local Storage Cache | Resilient store & menu caching, memoized filtering | M3 | Survey R3 |
| 12 | Clean Guest Mode | Zero phantom orders for guest, clean order history without mock active delivery | M4 | Survey R4 |
| 13 | Shared Cart State (`CartService`) | Single source of truth for cart across Home, Menu, Sheet, Shell Cart Tab, and Checkout | M4 | Survey R4 |
| 14 | Checkout & Libyan Phone Input | Valid Libyan phone (091/092/094/093) input, coupon retention, unified LYD delivery fees | M4 | Survey R4 |
| 15 | Live Order Tracking & Stepper | Nalut coordinates (31.8687, 10.9818), animated stepper, clean polling/socket updates | M4 | Survey R4 |
| 16 | Profile & Theme Persistence | Save dark/light mode preference in SharedPreferences, clean logout dialog | M4 | Survey R4 |
| 17 | Static Analysis Verification | `flutter analyze lib` clean with 0 errors and 0 warnings | M5 | Acceptance |
| 18 | E2E Test Suite Pass | 100% pass on comprehensive Tiers 1-4 E2E test suite | M5 | Acceptance |
| 19 | Release APK Build & Deployment | Fresh release APK built and copied to `C:\Users\kalifa\Desktop\Wasel_Android_APKs\Wasel_Customer_App.apk` | M5 | Acceptance |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Startup & Async Elimination | R1: Firebase guard, SocketService backoff, Splash < 2.0s, Frame-0 render | none | DONE |
| M2 | Touch & Gesture Architecture | R2: WaselBouncyPressable, dead target fixes, HitTest opaque, sliver scroll | M1 | DONE |
| M3 | Resilient Store Catalog & Nalut Data | R3: Authentic Nalut stores & menus unification, eliminate timeout cascades | M1 | DONE |
| M4 | Customer Flows & Cart Integration | R4: Shared CartService, guest mode isolation, Libyan phone, checkout coupons, tracking, theme | M2, M3 | DONE |
| M5 | Quality Gates, E2E Pass & Release APK | 0 analyzer warnings, 100% test pass, release APK build & deploy | M4 | DONE |

## Interface Contracts
### `CartService` Singleton Contract
- `List<CartItem> get items`
- `void addItem(Map<String, dynamic> product, {int quantity, List<String> selectedOptions, String? notes})`
- `void updateQuantity(String productId, int newQuantity)`
- `void removeItem(String productId)`
- `void clear()`
- `double get subtotal`
- `ValueNotifier<int> get itemCountNotifier`

### `CustomerNotificationService` Contract
- `Future<void> initialize()`: Guarded by `Firebase.apps.isNotEmpty`, local notifications initialized first
- `FirebaseMessaging? get _fcm`: Nullable lazy getter

### `SocketService` Contract
- `static void connect({String? authToken})`: Capped exponential backoff (max 3 retries), passive fallback
- `static void disconnect()`
- `static bool get isConnected`

### `ApiService` Nalut Store IDs Contract
- `store_nalut_01`: "مطعم قصر نالوت للمشويات" (Restaurant)
- `store_nalut_02`: "بيتزا ومعجنات القلعة نالوت" (Fast Food)
- `store_nalut_03`: "أسواق نالوت المركزية" (Grocery)

## Code Layout
- `lib/main.dart`: App entry point, theme management, initial routing
- `lib/splash_screen.dart`: Animated splash, session-driven navigation (< 2.0s)
- `lib/home_screen.dart`: Main discovery screen, Nalut store catalog, sliver layout
- `lib/store_menu_screen.dart`: Store menus and dish customization
- `lib/product_detail_sheet.dart`: Modal bottom sheet for dish options
- `lib/cart_checkout_screen.dart`: Cart review, coupon entry, Libyan phone entry, checkout
- `lib/order_tracking_screen.dart`: Nalut map tracking and timeline
- `lib/orders_history_screen.dart`: Customer order history
- `lib/profile_screen.dart`: Customer profile and theme preferences
- `lib/wallet_screen.dart`: Wasel wallet balance and transactions
- `lib/services/cart_service.dart`: Shared in-memory cart service
- `lib/services/api_service.dart`: Backend API integration, local Nalut cache & menus
- `lib/services/socket_service.dart`: WebSocket connection with passive fallback
- `lib/services/customer_notification_service.dart`: Local & FCM notifications
- `lib/widgets/motion_widgets.dart`: `WaselBouncyPressable` tactile gesture widget
- `test/e2e/`: Requirement-driven test suite (Tiers 1-4)
