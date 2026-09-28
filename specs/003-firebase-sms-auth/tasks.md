# Tasks: Firebase Phone SMS Authentication & Hybrid Fallback

**Spec**: [spec.md](file:///c:/Users/kalifa/Desktop/wasel-app/specs/003-firebase-sms-auth/spec.md) | **Plan**: [plan.md](file:///c:/Users/kalifa/Desktop/wasel-app/specs/003-firebase-sms-auth/plan.md)

---

## 📋 Task List

### Phase 1: Dependencies & Core Service (P1)
- [x] **Task 1.1**: Add `firebase_auth: ^5.4.0` to `flutter_mobile_app/pubspec.yaml` and `flutter_driver_app/pubspec.yaml` and run `flutter pub get`.
- [x] **Task 1.2**: Implement `FirebaseAuthService` in `flutter_mobile_app/lib/services/firebase_auth_service.dart` with Libyan phone normalization, SMS OTP dispatch, auto-retrieval, and quota exception detection.
- [x] **Task 1.3**: Write unit tests in `flutter_mobile_app/test/firebase_auth_service_test.dart` covering normalization, phone validation, and state handling.

### Phase 2: Customer App UI & Flow Integration (P1)
- [x] **Task 2.1**: Update `LoginScreen` (`flutter_mobile_app/lib/login_screen.dart`) to provide SMS OTP as the primary channel with WhatsApp as secondary.
- [x] **Task 2.2**: Update `OtpVerificationScreen` (`flutter_mobile_app/lib/otp_verification_screen.dart`) to support 6-digit SMS codes, Android auto-fill, countdown timer, and seamless WhatsApp fallback button.
- [x] **Task 2.3**: Verify session persistence in `ApiService` and `SharedPreferences` upon Firebase sign-in.

### Phase 3: Driver App Alignment (P2)
- [x] **Task 3.1**: Implement `DriverFirebaseAuthService` in `flutter_driver_app/lib/services/driver_firebase_auth_service.dart`.
- [x] **Task 3.2**: Add captain phone normalization and unit tests in `flutter_driver_app/test/driver_firebase_auth_service_test.dart`.

### Phase 4: Quality Assurance, Verification & Builds (P1)
- [x] **Task 4.1**: Run `flutter test` across apps (50/50 mobile passed, 7/7 driver passed).
- [x] **Task 4.2**: Run `flutter analyze` on modified apps to ensure 0 errors/warnings.
- [x] **Task 4.3**: Rebuild release APKs into `release_apks/`.
- [x] **Task 4.4**: Commit & push all changes to GitHub repository.
