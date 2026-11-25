# Tasks: Unified Next-Gen App Redesign & Signature Motion System

**Branch / Identifier**: `specs/005-unified-app-redesign` | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)  
**Last Updated**: 2026-10-22 | **Target Ecosystem**: `packages/wasel_ui` & All 4 Flutter Apps

---

## Task List

### Phase 0: Interactive Prototype & Preview (Mandatory Pre-requisite)
- [x] **TASK-001**: Build rich interactive HTML screen mockups for Customer, Captain, Merchant, and Admin screens with live tab navigation.
- [x] **TASK-002**: Solicit user review and feedback on the proposed visual direction.

### Phase 1: Shared Design Tokens & Motion Physics (packages/wasel_ui)
- [x] **TASK-003**: Centralize Royal Berber Emerald & Antique Gold design tokens in `packages/wasel_ui/lib/src/theme/wasel_colors.dart`.
- [x] **TASK-004**: Implement `WaselMotion` physics engine (`signature`, `joy`, `pulseCurve`, duration palette, and `isAnimationDisabled` a11y bypass).
- [x] **TASK-005**: Build shared tactile motion widgets (`WaselBouncyPressable`, `SwipeToConfirmSlider`, `CountdownRing`, `OdometerCounter`, `WaselPulseGlow`, `WaselRadarSweep`).
- [x] **TASK-006**: Configure backward-compatibility re-export layers in all 4 apps (`motion_widgets.dart`) to guarantee zero regression and seamless symbol resolution.

### Phase 2: App Screen Upgrades & Motion Choreography
- [x] **TASK-007**: Upgrade Customer App (`flutter_mobile_app`): Smart Header greeting & address selector, Stories countdown, Magazine store cards, and Floating Dock.
- [x] **TASK-008**: Upgrade Captain App (`flutter_driver_app`): Tactical radar card, pulsing countdown ring, and $\ge 85\%$ latch swipe-to-accept slider.
- [x] **TASK-009**: Upgrade Merchant App (`flutter_merchant_app`): KDS tickets with dynamic color states and handover cards.
- [x] **TASK-010**: Upgrade Admin App (`flutter_admin_app`): Executive cockpit KPI cards, real-time fleet radar map, and PIN `7788` order purge integration.

### Phase 3: Accessibility, Verification & Distribution
- [x] **TASK-011**: Execute accessibility stress tests validating animation bypass under `disableAnimations: true` in `packages/wasel_ui`.
- [x] **TASK-012**: Run static analysis (`flutter analyze lib`) across `wasel_ui` and all 4 apps (Enforcing the mandatory 0 errors gate).
- [x] **TASK-013**: Run comprehensive test suites (`flutter test`) verifying 100% pass rate.
- [x] **TASK-014**: Build, verify, and export universal release APKs to `C:\Users\kalifa\Desktop\Wasel_Android_APKs\`.
