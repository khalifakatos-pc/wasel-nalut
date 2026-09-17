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
