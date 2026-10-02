# Implementation Plan: Unified Next-Gen App Redesign

**Branch**: `005-unified-app-redesign` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

---

## 1. Summary

Redesign and elevate the visual aesthetics, micro-interactions, ergonomics, and responsiveness of the 4 Wasel Nalut applications (Customer, Captain, Merchant, Admin) into a unified "Royal Berber & Mediterranean Luxury" theme. Deliver interactive live mockups for user inspection before initiating full code changes.

---

## 2. Technical Context

- **Framework**: Flutter 3.x / Dart 3.x (Material 3 with custom luxury design tokens)
- **Palette**: Deep Emerald (`#041710`), Antique Gold (`#D4AF37`), Radiant Amber (`#F59E0B`), Champagne Ivory (`#F8F5EE`), Neon Green (`#10B981`)
- **Typography**: Cairo (Arabic primary), Outfit (tabular currency & figures), Playfair Display (editorial luxury display)
- **Component Styling**: Glassmorphic frosted cards, animated gradient borders, haptic feedback triggers, bottom floating dock.

---

## 3. Implementation Phases

### Phase 0: Interactive Visual Prototype & Screen Mockups (Current Step)
- Create a comprehensive, responsive, interactive HTML screen mockup widget showcasing:
  1. **Customer App**: Home Discovery screen, Flash Deals countdown banner, Restaurant cards, and Floating Tracking pill.
  2. **Captain App**: Tactical Dark Radar dashboard, Incoming Delivery offer dialog with pulse counter, and Step-by-Step Delivery Flow.
  3. **Merchant KDS App**: Live Kitchen Ticket Kanban columns, Preparation Timer gauges, and Handover Code modal.
  4. **Admin Dashboard**: Executive KPI widgets, Real-time Fleet map, and Driver settlement ledger.

### Phase 1: Shared Design Tokens Refactor
- Unify color constants and theme builders across:
  - `flutter_mobile_app/lib/theme/`
  - `flutter_driver_app/lib/driver_theme.dart`
  - `flutter_merchant_app/lib/merchant_theme.dart`
  - `flutter_admin_app/lib/admin_theme.dart`

### Phase 2: Customer App Transformation
- Redesign `HomeScreen`, `StoreDetailScreen`, `CartSheet`, and `OrderTrackingScreen`.

### Phase 3: Captain & Merchant App Modernization
- Upgrade `ActiveDeliveryFlowScreen`, `DriverRadarScreen`, and `KdsScreen`.

### Phase 4: Final Verification & APK Rebuilds
- Execute static analysis and automated test suites, then compile updated APKs.
