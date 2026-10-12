# Original User Request

## 2026-09-12T21:16:40Z

Resolve the launch unresponsiveness and freezing in the Wasel Customer App (`flutter_mobile_app`), eliminate all startup blocking calls and infinite reconnect loops, and conduct a thorough end-to-end audit and fix across all features (guest mode, store catalog, tactile animations, checkout, order tracking, and wallet).

Working directory: c:\Users\kalifa\Desktop\wasel-app\flutter_mobile_app
Integrity mode: development

## Requirements

### R1. Eliminate Startup Freeze & Asynchronous Deadlocks (إزالة التعليق والتجميد عند التشغيل)
- Prevent any platform deadlock during app launch by safeguarding Firebase initialization, ensuring `FirebaseMessaging.instance` is never queried before `Firebase.initializeApp()`.
- Replace hardcoded `ws://localhost:3000` in `SocketService` with cloud-resilient WebSocket endpoints or graceful passive fallback so the event loop is never choked by infinite 3-second reconnect loops on physical Android devices.
- Streamline `SplashScreen` to `MainNavigationShell` / `OnboardingScreen` transition so the UI thread renders immediately without waiting for sleeping backend cold starts.

### R2. Responsive Touch & Gesture Architecture (استجابة فورية لكافة اللمسات والحركات)
- Verify that `WaselBouncyPressable` does not swallow or delay scroll gestures or navigation taps in `HomeScreen`, store cards, and category items.
- Ensure hit-test behavior (`HitTestBehavior.opaque`) and `GestureDetector` hierarchy allow simultaneous vertical scrolling and snappy card tapping.
- Guarantee 60/120 FPS fluid frame rates across all tactile motion elements.

### R3. Resilient Store Catalog & Instant Nalut Data Ingestion
- Ensure store catalog loads instantly with cached authentic Nalut stores (قصر نالوت للمشويات، بيتزا القلعة، أسواق نالوت المركزية) while asynchronously syncing with cloud backends.
- Eliminate any UI freezes caused by synchronous JSON parsing or heavy rebuilds in `_fetchLiveStores()`.

### R4. Complete Customer Flow Verification (التدقيق الشامل لكافة نواحي التطبيق)
- Guest exploration mode: zero phantom orders, clean browsing, and seamless Libyan phone entry upon checkout.
- Cart & Checkout: correct LYD (`د.ل`) calculations, coupon validation, and instant order placement.
- Live Order Tracking: accurate Nalut map coordinates (`31.8687, 10.9818`) and stepper animation.
- Profile & Settings: seamless theme toggle, session persistence, and clean logout dialog.

## Acceptance Criteria

### Startup & Touch Responsiveness
- [ ] The application launches, completes splash, and displays interactive home screen in < 2.5 seconds with ZERO ANR (Application Not Responding) hangs.
- [ ] Every button, store card, category pill, and bottom navigation tab responds instantly to touch with tactile visual feedback.
- [ ] Zero uncaught exceptions during startup services initialization (`Firebase`, `SocketService`, `ApiService`).

### End-to-End Functionality
- [ ] Guest users can browse stores, view dishes, and add items to cart without forced login.
- [ ] Checkout prompts for Libyan contact number only if missing, places the order, and opens tracking.
- [ ] Orders history and Wallet tabs load and render cleanly without blocking the main navigation shell.

### Build & Analysis Standards
- [ ] `flutter analyze lib` reports 0 errors and 0 warnings.
- [ ] A fresh, verified release APK (`Wasel_Customer_App.apk`) is built and deployed to `C:\Users\kalifa\Desktop\Wasel_Android_APKs`.


## 2026-10-03T19:56:29Z

# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Comprehensive UI/UX Redesign & Signature Motion Overhaul across all Wasel Nalut Apps
> Requested team: Full team (Specialized Flutter UI & Motion Agents)
> Visual Prototype: [wasel_interactive_showcase.html](file:///C:/Users/kalifa/.gemini/antigravity/brain/72d6fead-508f-4b81-b4ae-a52bbac848d0/wasel_interactive_showcase.html)

Execute a complete visual redesign and signature motion overhaul across all four Wasel Nalut Flutter applications (Customer, Captain/Driver, Merchant/Kitchen, and Super Admin) backed by a shared `packages/wasel_ui` package, achieving a cohesive, high-performance identity with Cairo/Outfit typography, fluid animations, and zero theme overrides.

Working directory: c:\Users\kalifa\Desktop\wasel-app
Integrity mode: development

## Requirements

### R1. Shared Design System & Motion Engine (`packages/wasel_ui`)
- Establish a standalone shared package `packages/wasel_ui` linked via `path:` in all 4 apps.
- Embed local offline fonts (Cairo 400/500/600/700/800 for Arabic, Outfit 500/600/700/800 for numbers/codes) in `packages/wasel_ui/assets/fonts/` with full `pubspec.yaml` declarations.
- Implement `WaselTheme` supporting Light and Dark modes with semantic `ColorScheme` (Amber `#F59E0B`, Emerald `#10B981`, Slate surfaces `#F8FAFC`), full `TextTheme` scale, and standard Material 3 `pageTransitionsTheme` (SharedAxis and FadeThrough).
- Implement `WaselMotion` physics engine (`quick: 150ms`, `standard: 280ms`, `slow: 450ms`, `signature: Cubic(0.05, 0.7, 0.1, 1.0)`, `joy: Cubic(0.175, 0.885, 0.32, 1.275)`), with mandatory `MediaQuery.of(context).disableAnimations` accessibility bypass.
- Provide core reusable components: `WaselBouncyPressable`, `WaselCard`, `WaselButton`, `StatusPill`, `CountdownRing`, `OdometerCounter`, `ShimmerSkeleton`, and `ReceiptAuditSheet`.

### R2. Complete Theme Purge & Unified Architecture across All 4 Apps
- Purge all ~390 hardcoded dark theme colors (`darkBg`, `0xFF0F172A`, `Colors.white70`, manual background overrides) from screen widgets across:
  - Customer App (`flutter_mobile_app`)
  - Captain App (`flutter_driver_app`)
  - Kitchen App (`flutter_merchant_app`)
  - Super Admin App (`flutter_admin_app`)
- Replace existing duplicated motion files (`motion_widgets.dart`, `driver_motion_widgets.dart`, `merchant_motion_widgets.dart`, `admin_motion_widgets.dart`) by consuming the shared `wasel_ui` package without breaking existing imports.

### R3. Customer App Redesign & Motion Overhaul (`flutter_mobile_app`)
- **Splash & Onboarding**: Lightweight animated logo reveal (≤900ms) transitioning cleanly into Home, with smooth parallax onboarding.
- **Home & Catalog**: Clean header hierarchy, category pills with spring bounce, staggered card entrance, shimmer skeletons for loading states, and active order floating pill.
- **Menu & Cart Interaction**: Fluid sheet/container transition from store card to menu, animated fly-to-cart particle/arc feedback on dish addition, and dynamic odometer price updating.
- **Checkout & Order Tracking**: Clear LYD (`د.ل`) bill breakdown, interactive timeline drawing itself between order states, and live tracking map marker smoothing.

### R4. Captain App Redesign & Strict Delivery Logic (`flutter_driver_app`)
- **Online/Offline Switch**: High-tactile circular ripple toggle between standby and active modes with smooth background transitions.
- **Order Radar Dialog**: Urgency-colored animated countdown ring (green → amber → red) with haptic feedback on final 5 seconds.
- **Strict Bill Audit Flow (تجريد الفاتورة)**: Enforce the mandatory operational sequence: Captain arrives at merchant → reviews interactive itemized checklist ("تجريد الفاتورة") → checks off verified items → taps approve/pickup → order transitions to active delivery.
- **Swipe-to-Confirm & COD**: Elastic rubber-band slider with completion flash and clear COD cash collection dialog with Libyan currency formatting.

### R5. Kitchen KDS & Store Self-Identification (`flutter_merchant_app`)
- **Store Self-Identification**: Store auto-detects and binds its credentials seamlessly without manual ID confusion.
- **KDS Board (نظام عرض المطبخ)**: Crisp Google Stitch-inspired light cards, smooth `AnimatedList` ticket additions and dismissals, cooking duration countdown rings, and isolated timer widgets preventing full-screen rebuilds.
- **Retail Picking & Inventory**: Check-off micro-animations for retail item picking, intuitive stock toggle switches, and animated revenue KPI charts.

### R6. Super Admin Portal Modernization (`flutter_admin_app`)
- **Master PIN Security Shield**: Elegant PIN authentication screen (PIN: `7788`) with pulse feedback and error shake.
- **Dashboard & KPIs**: Odometer numeric tickers for GMV, cash-in-hand, and commissions, alongside animated daily Z-Audit financial breakdown.
- **Live Dispatch Radar**: Real-time interactive fleet map centered on Nalut (`31.8687, 10.9818`) with store, captain, and active delivery overlays.

### R7. Business Continuity & Libyan Operational Integrity
- Preserve authentic Libyan support contact (WhatsApp `0918207786`).
- Guarantee seamless cash-on-delivery calculations and 100% Arabic RTL layout perfection across all screens.

## Acceptance Criteria

### Shared Package & Typography
- [ ] `packages/wasel_ui` compiles cleanly with full export of themes, typography, tokens, and motion widgets.
- [ ] Both Cairo and Outfit fonts render correctly offline across all 4 apps without network calls or font fallback clipping.

### Code Quality & Theme Integrity
- [ ] Automated grep confirms ZERO hardcoded theme override colors (`darkBg`, `0xFF0F172A`) remaining inside screen widgets.
- [ ] `flutter analyze` reports 0 errors and 0 fatal warnings across `wasel_ui`, `flutter_mobile_app`, `flutter_driver_app`, `flutter_merchant_app`, and `flutter_admin_app`.
- [ ] All existing business logic tests (`active_order_persistence_test.dart`, `merchant_isolation_test.dart`, etc.) pass without regression.

### User Flow & Motion Verification
- [ ] Captain delivery flow enforces the itemized receipt audit checklist before allowing order pickup.
- [ ] Kitchen KDS receives and updates tickets with smooth animations and zero ANR/frame stutter.
- [ ] Customer cart exhibits animated fly-to-cart feedback and dynamic price counters.
- [ ] Turning on system "Remove animations" (`disableAnimations`) instantly disables all motion curves across all 4 apps.

### Build & Deliverables
- [ ] Production-ready release APKs built and copied to `C:\Users\kalifa\Desktop\Wasel_Android_APKs\`:
  - `Wasel_Customer_App.apk`
  - `Wasel_Captain_App.apk`
  - `Wasel_Kitchen_App.apk`
  - `Wasel_Admin_App.apk`


## 2026-10-04T11:19:41Z

Server restarted; all subagents/crons stopped. Please resume: Milestone 1 (wasel_ui) is complete & hardened (112 tests passing). Check .agents/teamwork state/progress.md, re-create monitoring crons, revive or re-dispatch the orchestrator, and continue from Milestone 2 (Customer App redesign) through Milestones 3-6 and APK builds per the original prompt.

## 2026-10-04T14:31:27Z

Server restarted. Milestone 2 (Customer App redesign & motion overhaul) has been fully completed and verified:
- flutter analyze lib: No issues found! (0 errors, 0 warnings)
- flutter test: 52/52 tests passed!
- Screens updated: main.dart, design_system.dart, splash_screen.dart, onboarding_screen.dart, home_screen.dart, store_menu_screen.dart, product_detail_sheet.dart, fly_to_cart_overlay.dart, cart_checkout_screen.dart, order_tracking_screen.dart, orders_history_screen.dart, profile_screen.dart.
- All theme overrides purged and linked to packages/wasel_ui.

Please resume/revive the orchestrator to mark Milestone 2 completed, re-create monitoring crons, and immediately advance to Milestone 3: Captain / Driver App (flutter_driver_app: tactile ripple online switch, order radar countdown ring dialog, mandatory receipt audit checklist before pickup, slide-to-confirm, delivery COD) and continue through Milestones 4-6 and APK builds.

## 2026-10-04T14:48:58Z

Server restarted. Please resume immediately: continue Milestone 3 (Captain / Driver App: flutter_driver_app). Re-create monitoring crons and drive Milestone 3 through completion.

