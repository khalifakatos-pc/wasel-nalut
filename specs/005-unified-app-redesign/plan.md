# Implementation Plan: Unified Next-Gen App Redesign & Signature Motion System

**Branch / Identifier**: `specs/005-unified-app-redesign` | **Spec**: [spec.md](spec.md)  
**Last Updated**: 2026-10-22 | **Target Ecosystem**: `packages/wasel_ui` & All 4 Flutter Apps

---

## 1. Summary

Redesign and elevate the visual aesthetics, micro-interactions, ergonomics, and responsiveness of the 4 Wasel Nalut applications (Customer, Captain, Merchant, Admin) into a unified "Royal Berber & Mediterranean Luxury" theme. Consolidate all shared design tokens, typography, and motion physics centrally inside `packages/wasel_ui` in strict accordance with the project constitution (Principle III: Modular Contracts & Principle V: Offline Resilience).

---

## 2. Technical Context & Constraints

- **Framework**: Flutter 3.x / Dart 3.x (Material 3 with custom luxury design tokens and physics curves).
- **Architecture**: Single Shared UI Package (`packages/wasel_ui`) linked via `path: ../packages/wasel_ui` across all 4 apps.
- **Offline Typography (Strict Rule)**:
  - `Cairo` (weights 400, 500, 600, 700, 800) for all primary Arabic typography.
  - `Outfit` (weights 500, 600, 700, 800) for numbers, codes, and Libyan Dinar (`د.ل`) figures.
  - *No online Google fonts or external web fonts (e.g. Playfair Display removed to maintain 100% offline self-containment).*
- **Design Tokens**:
  - `WaselColors.canvas`: `#041710` (Deep Emerald Night)
  - `WaselColors.goldAccent`: `#D4AF37` / `#F5D061` (Antique Gold)
  - `WaselColors.primaryText`: `#F8F5EE` (Champagne Ivory)
  - `WaselColors.emerald`: `#10B981` (Neon Emerald)
  - `WaselColors.amber`: `#F59E0B` (Radiant Amber)
- **Signature Motion Engine (`WaselMotion`)**:
  - Signature Decisive Entrance Curve: `Cubic(0.05, 0.7, 0.1, 1.0)`
  - Tactile Joy Elasticity Curve: `Cubic(0.175, 0.885, 0.32, 1.275)`
  - Sinusoidal Ambient Pulse Curve: `Curves.easeInOutSine`
  - Durations: Quick `150ms`, Standard `280ms`, Slow `450ms`, Relaxed `800ms`, Extended `1200ms`
  - Mandatory a11y reduced-motion bypass via `isAnimationDisabled(BuildContext context)`

---

## 3. Implementation Phases

### Phase 0: Interactive Visual Prototype & Screen Mockups
- Build responsive, interactive HTML screen mockups showcasing all four applications:
  1. **Customer App**: Home Discovery, Stories flash countdown, Magazine restaurant cards, Floating tracking pill.
  2. **Captain App**: Tactical Dark Radar dashboard, Incoming offer modal with 20s pulse ring, Swipe to Accept slider ($\ge 85\%$).
  3. **Merchant KDS App**: Multi-column live ticket board with time-based dynamic color indicators, handover OTP cards.
  4. **Admin Dashboard**: Executive KPI widgets, Real-time fleet tracking map, and PIN-secured controls.

### Phase 1: Shared Design System & Motion Physics Engine (`packages/wasel_ui`)
- Centralize tokens in `packages/wasel_ui`:
  - `lib/src/theme/wasel_colors.dart` & `wasel_theme.dart`
  - `lib/src/theme/wasel_typography.dart` (Offline Cairo & Outfit)
  - `lib/src/motion/wasel_motion.dart`
  - Tactile reusable components: `WaselBouncyPressable`, `SwipeToConfirmSlider`, `CountdownRing`, `OdometerCounter`, `WaselPulseGlow`, `WaselRadarSweep`.
- Provide zero-regression backward-compatibility re-export layers in all 4 apps:
  - `flutter_mobile_app/lib/widgets/motion_widgets.dart`
  - `flutter_driver_app/lib/widgets/driver_motion_widgets.dart`
  - `flutter_merchant_app/lib/widgets/merchant_motion_widgets.dart`
  - `flutter_admin_app/lib/widgets/admin_motion_widgets.dart`

### Phase 2: App Screen Upgrades & Choreography
- **Customer App (`flutter_mobile_app`)**:
  - Smart Header greeting & address selector, Stories flash sales banner, Magazine restaurant grid, and floating active order tracking dock.
- **Captain App (`flutter_driver_app`)**:
  - Tactical sunlit radar mode, 20s countdown ring, and $\ge 85\%$ latch swipe slider.
- **Merchant App (`flutter_merchant_app`)**:
  - High-speed KDS kitchen tickets with dynamic color states (<5m green, 5-10m blue, 10-15m amber, >15m red pulse).
- **Admin App (`flutter_admin_app`)**:
  - Executive cockpit cards, fleet map tracking, and PIN `7788` order purge integration.

### Phase 3: Accessibility Validation, Multi-Tier Testing & Build Packaging
- Validate full a11y bypass under `disableAnimations: true` across all motion widgets.
- Execute incremental static analysis gate (`flutter analyze lib` = 0 issues across all 4 apps and `wasel_ui`).
- Run widget and integration tests (`flutter test`).
- Compile signed release APKs and export to `C:\Users\kalifa\Desktop\Wasel_Android_APKs\`.
