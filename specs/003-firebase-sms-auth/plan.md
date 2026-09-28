# Implementation Plan: Firebase Phone SMS Authentication & Hybrid Fallback

**Branch**: `003-firebase-sms-auth` | **Date**: 2026-09-28 | **Spec**: [spec.md](file:///c:/Users/kalifa/Desktop/wasel-app/specs/003-firebase-sms-auth/spec.md)

---

## 🏗️ 1. Technical Architecture & Decisions

### Decision 1: Firebase Auth SDK Integration
- **Component**: `flutter_mobile_app/pubspec.yaml`, `flutter_driver_app/pubspec.yaml`
- **Design**:
  - Add `firebase_auth: ^5.4.0` (paired with existing `firebase_core: ^3.10.0` and `firebase_messaging: ^15.2.0`).
  - Android already has `google-services.json` registered under `com.wasel.nalut` / `com.wasel.driver`.

### Decision 2: Libyan Phone Number Formatting & E.164 Normalization
- **Component**: `flutter_mobile_app/lib/services/firebase_auth_service.dart`
- **Design**:
  - Implement a dedicated parser for Libyan mobile numbers:
    - Strips spaces, dashes, leading zeroes, and language-specific numerals.
    - Handles standard prefixes: `091`, `092`, `094`, `095`, `093`.
    - Produces valid E.164 formatted string: `+2189XXXXXXXX`.
    - Rejects invalid lengths (< 9 digits) with localized Arabic user feedback.

### Decision 3: Firebase SMS Verification Service with Quota Shield
- **Component**: `flutter_mobile_app/lib/services/firebase_auth_service.dart`
- **Design**:
  - Wrapper around `FirebaseAuth.instance.verifyPhoneNumber`.
  - Listeners:
    - `verificationCompleted`: Automatic instantaneous credential resolution on Android (zero-tap sign in).
    - `codeSent`: Returns `verificationId` and `resendToken` to UI.
    - `verificationFailed`: Detects quota exhaustion (`quota-exceeded`, `too-many-requests`) and automatically flags the UI to trigger the WhatsApp fallback.
    - `codeAutoRetrievalTimeout`: Safe fallback for manual OTP input.

### Decision 4: Dual-Channel UI (SMS Primary + WhatsApp Instant Fallback)
- **Component**: `flutter_mobile_app/lib/login_screen.dart`, `otp_verification_screen.dart`
- **Design**:
  - In `LoginScreen`:
    - Clean Libyan mobile input with `+218` flag prefix.
    - Primary CTA: "تسجيل الدخول عبر رسالة SMS ⚡".
    - Secondary CTA: "الدخول السريع عبر واتساب 💬".
  - In `OtpVerificationScreen`:
    - Configurable pin code length (6 digits for SMS, 4 digits for WhatsApp).
    - Auto-fill upon Android SMS detection.
    - 60-second countdown for SMS resend.
    - Clear, prominent secondary action: "لم تستلم رمز SMS؟ اضغط هنا للإرسال عبر واتساب" (prevents user drop-off on network delays).

### Decision 5: Session & Supabase Sync
- **Component**: `flutter_mobile_app/lib/services/api_service.dart`
- **Design**:
  - On successful Firebase sign-in (`UserCredential`), extract verified phone number.
  - Store phone in `ApiService.userPhone` and cache in `SharedPreferences`.
  - Maintain session consistency with Supabase profiles and existing cart/order flows.

---

## 🧪 2. Verification & Test Plan
1. **Unit Testing**:
   - Create `flutter_mobile_app/test/firebase_auth_service_test.dart` to verify:
     - Libyan phone number normalization (e.g., `0911234567` -> `+218911234567`).
     - Error mapping & quota detection.
     - Fallback flag triggering.
2. **Static Analysis**:
   - Run `flutter analyze lib test` on `flutter_mobile_app` and `flutter_driver_app` (0 issues).
3. **App Execution**:
   - Run `flutter test` across the suites.
4. **Binary Generation**:
   - Rebuild production APKs in `release_apks/`.
