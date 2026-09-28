# Feature Specification: Firebase Phone SMS Authentication & Hybrid Fallback

**Feature Branch**: `003-firebase-sms-auth`  
**Created**: 2026-09-28  
**Status**: In Progress  
**Input**: "التسجيل عبر اس ام اس عن طريق فاير بيس في الخطه المجانيه فيها تقريبا 1000 نفر كل شهر"

---

## 🎯 Executive Summary
Enable native SMS OTP registration and login across the Wasel Nalut platform using Firebase Phone Authentication (`firebase_auth`). To safeguard against Firebase Spark free-tier quota exhaustion (approx. 1,000 to 10,000 verifications/month) and Libyan carrier SMS delivery delays (Libyana, Al-Madar), the system adopts a **Smart Hybrid Auth Architecture**:
1. **Primary Route**: Firebase Native SMS OTP with automated code detection (Auto-retrieval).
2. **Fallback Route**: One-tap fallback to WhatsApp OTP verification if SMS fails, times out, or triggers quota errors.

---

## 👥 User Scenarios & Acceptance Criteria (Prioritized)

### User Story 1 - Quick Registration via Firebase SMS (Priority: P1)
**User Persona**: New or returning customer/captain in Nalut entering phone number to sign in.  
**Value**: Instant frictionless login via real native SMS message without having to switch apps to WhatsApp manually.

**Independent Test**:
Enter Libyan phone number (e.g. `091xxxxxxx`), tap "إرسال رمز التحقق SMS", receive 6-digit SMS code, enter code, and immediately access the application.

**Acceptance Scenarios**:
1. **Given** a user on the login screen with phone `0912345678`,  
   **When** they tap "تسجيل الدخول عبر SMS",  
   **Then** the number is normalized to E.164 (`+218912345678`), Firebase triggers SMS OTP, and the app transitions to the 6-digit OTP verification screen.
2. **Given** the 6-digit OTP is received via SMS on Android,  
   **When** auto-retrieval detects the SMS code,  
   **Then** the app automatically verifies the credential, sets authenticated state, and directs the user to the home screen.
3. **Given** manual code entry,  
   **When** user types the valid 6-digit SMS code and taps "تأكيد الدخول",  
   **Then** `FirebaseAuth.instance.signInWithCredential(...)` succeeds, user session is persisted, and user profile is synced.

---

### User Story 2 - Hybrid Fallback & Free Quota Protection (Priority: P1)
**User Persona**: User attempting to log in when Firebase SMS quota is exhausted or SMS delivery is delayed.  
**Value**: Ensures business continuity in Nalut; no customer is ever locked out due to telecom network issues or Firebase Spark free tier limits.

**Independent Test**:
Simulate SMS quota error (`too-many-requests` or `quota-exceeded`) or 60-second SMS timeout; verify that the "الإرسال عبر واتساب" (WhatsApp fallback) button appears immediately and allows successful login.

**Acceptance Scenarios**:
1. **Given** Firebase returns `quota-exceeded` or `too-many-requests`,  
   **When** the SMS request fails,  
   **Then** the app displays a clear Arabic notification and immediately offers: "إرسال الرمز عبر واتساب", routing through the existing WhatsApp verification service.
2. **Given** SMS code is delayed (countdown timer reaches 0),  
   **When** user taps "إعادة الإرسال عبر واتساب",  
   **Then** WhatsApp verification chat opens with the pre-filled verification message and fallback verification code.

---

### User Story 3 - Phone Number Normalization & Validation (Priority: P2)
**User Persona**: User typing their number in various local Libyan formats (`091...`, `91...`, `092...`, `094...`, `+2189...`).  
**Value**: Prevents malformed phone errors and Firebase `invalid-phone-number` exceptions.

**Acceptance Scenarios**:
1. **Given** user enters `091 123 4567` or `911234567`,  
   **When** submitted,  
   **Then** format is cleaned and parsed to `+218911234567`.
2. **Given** user enters less than 9 digits or invalid characters,  
   **When** they submit,  
   **Then** an inline Arabic validation warning is shown: "يرجى إدخال رقم هاتف ليبي صحيح (9 أو 10 أرقام)".

---

## 🔒 Edge Cases & Guardrails
1. **Firebase Quota Depletion**: Handled gracefully by switching to WhatsApp fallback without crashing.
2. **Network Offline**: App alerts user with offline banner and prevents sending duplicate requests.
3. **Wrong OTP Entry**: Shows "رمز التحقق غير صحيح، يرجى المحاولة مجدداً" with remaining attempts counter.
4. **App Killed during SMS Receipt**: Verification ID and phone number cached in `SharedPreferences` so reopening the app resumes OTP verification rather than starting over.

---

## 📋 Functional Requirements
- **FR-001**: Add `firebase_auth` dependency to `flutter_mobile_app` and `flutter_driver_app`.
- **FR-002**: Implement `FirebaseAuthService` with `verifyPhoneNumber`, `signInWithSmsCode`, and quota error detection.
- **FR-003**: Provide seamless Libyan phone number parsing (`+218` prefix handling).
- **FR-004**: Update `LoginScreen` and `OtpVerificationScreen` in `flutter_mobile_app` to support dual SMS / WhatsApp verification.
- **FR-005**: Add unit tests verifying phone normalization, error handling, and session state persistence.
