# Implementation Plan - Authenticator | Juego Responsable (MVP 30% - 15 Use Cases)

This implementation plan outlines the architecture, code structure, visual UI/UX compliance, local business logic, and backend foundation for the first 30% (15 Use Cases) of the **Authenticator | Juego Responsable** system.

The solution accommodates the requirement for Flutter cross-platform architecture with native Android bindings (Jetpack Compose / BiometricPrompt / CameraX / OpenCV) and Spring Boot backend microservices.

---

## 1. Scope of Use Cases (15 Use Cases)

| Category | ID & Use Case Name | Responsibilities |
|---|---|---|
| **Setup & UI Security** | **CU-0036**: Dynamic Permissions Request<br>**CU-0021**: Screen Lock Validation<br>**CU-0046**: Mandatory Update UI | Request Camera/Location permissions gracefully; verify device lock status (PIN/Pattern/Biometrics); render mandatory version update screen when deprecated. |
| **DNI Capture Flow** | **CU-0001**: DNI Front Capture<br>**CU-0002**: DNI Back Capture<br>**CU-0041**: Camera Hardware Error Handling<br>**CU-0042**: Manual OCR Fallback UI | Live camera preview with document framing overlay; capture front and back; handle camera hardware exceptions; fallback form for manual DNI metadata entry. |
| **Local DNI Logic** | **CU-0003**: OCR Data Extraction<br>**CU-0005**: Document Validity Check<br>**CU-0007**: Legal Age Calculation (18+) | Extract biographical data (Name, Surname, DOB, Expiration); validate document non-expiration; verify age >= 18 for Responsible Gaming rules. |
| **Facial Biometrics UI** | **CU-0011**: Facial Interface Init<br>**CU-0012**: Facial Vector Capture<br>**CU-0013**: Active Liveness Detection | Front camera initialization with oval guide; facial vector mapping simulation/extraction; interactive random liveness challenges (blink, turn head, smile). |
| **Fingerprint UI & Native** | **CU-0017**: BiometricPrompt Init<br>**CU-0018**: Local Fingerprint Capture | Native Android `BiometricPrompt` call / Flutter Biometric bridge integration; local fingerprint prompt handling and result status callback. |

---

## 2. Design System & UI/UX Guidelines

- **Typography**: Montserrat (`Montserrat-Bold`, `Montserrat-SemiBold`, `Montserrat-Medium`, `Montserrat-Regular`).
- **Color Palette**:
  - **Primary Call to Action**: Industrial Safety Blue (`#0288D1`)
  - **Text & Dark Containers**: Deep Graphite Mine (`#263238`)
  - **Success / Validation**: Validation Green (`#2E7D32`)
  - **Warning / Moderate Risk**: Warning Yellow (`#FBC02D`)
  - **Alerts / Fraud / Block**: Fraud Red (`#C62828`)
  - **Backgrounds**: White (`#FFFFFF`) and Light Neutral Gray (`#F5F7F8`)
- **Shapes & Elevation**:
  - `BorderRadius`: 8px (`RoundedCornerShape(8.dp)` in Compose / `BorderRadius.circular(8)` in Flutter)
  - `Elevation`: Soft elevation (2dp - 4dp) with custom shadows.
  - Linear iconography with descriptive labels.

---

## 3. Project Architecture & Structure

```
Auth - Aplicativo/
├── android_module/
│   ├── build.gradle.kts                      # Android build script with Compose, CameraX, Biometric, OpenCV
│   └── src/main/java/com/authenticator/
│       ├── biometric/
│       │   └── BiometricAuthenticator.kt     # Native BiometricPrompt wrapper (CU-0017 / CU-0018)
│       └── ui/
│           ├── DniCaptureScreen.kt           # Jetpack Compose DNI Capture (CU-0001 / CU-0002)
│           └── OcrManualFallbackScreen.kt    # Jetpack Compose Manual Fallback (CU-0042)
├── flutter_app/
│   ├── pubspec.yaml                          # Flutter manifest with Google Fonts (Montserrat), camera, local_auth
│   └── lib/
│       ├── core/
│       │   ├── theme/
│       │   │   └── app_theme.dart            # Theme definition with exact hex colors & Montserrat font
│       │   └── security/
│       │       ├── permission_service.dart   # Dynamic Permissions (CU-0036)
│       │       └── screen_lock_service.dart  # Screen Lock Validation (CU-0021)
│       ├── logic/
│       │   ├── ocr_processor.dart            # Local OCR extraction & sanitization (CU-0003)
│       │   ├── document_validator.dart       # Validity check (CU-0005)
│       │   └── age_calculator.dart           # 18+ Legal Age Verification (CU-0007)
│       └── presentation/
│           ├── screens/
│           │   ├── mandatory_update_screen.dart # Forced Update UI (CU-0046)
│           │   ├── dni_capture_screen.dart      # DNI Front & Back Capture UI (CU-0001, CU-0002, CU-0041)
│           │   ├── manual_ocr_screen.dart       # Manual OCR Fallback Form UI (CU-0042)
│           │   ├── face_liveness_screen.dart    # Facial Capture & Random Liveness UI (CU-0011, CU-0012, CU-0013)
│           │   └── biometric_fingerprint_screen.dart # Fingerprint Prompt UI (CU-0017, CU-0018)
│           └── widgets/
│               ├── custom_button.dart
│               └── status_badge.dart
└── backend_service/
    ├── pom.xml                               # Spring Boot Maven POM with Web, Security, JWT, Validation dependencies
    └── src/main/java/com/authenticator/backend/
        ├── AuthenticatorBackendApplication.java
        └── dto/
            ├── IdentityValidationRequest.java
            └── IdentityValidationResponse.java
```

---

## 4. Proposed Deliverables & Files to Create

### [Component 1] Gradle & Maven Configuration Files
- `android_module/build.gradle.kts`: Gradle Kotlin DSL config declaring Jetpack Compose, CameraX, AndroidX Biometric, OpenCV, and Kotlin coroutines dependencies.
- `backend_service/pom.xml`: Maven configuration for Java/Spring Boot microservices architecture.
- `flutter_app/pubspec.yaml`: Flutter dependencies declaration for camera, local_auth, google_fonts, permission_handler.

### [Component 2] Core UI Theme & Utilities (Design System Strict Adherence)
- `flutter_app/lib/core/theme/app_theme.dart`: Centralized theme palette with Hex colors (`#0288D1`, `#263238`, `#2E7D32`, `#FBC02D`, `#C62828`, `#FFFFFF`, `#F5F7F8`), 8px rounded corners, and Montserrat text styling.

### [Component 3] Dynamic Permissions, Screen Lock & Update UI
- `flutter_app/lib/core/security/permission_service.dart`: Implementation for CU-0036.
- `flutter_app/lib/core/security/screen_lock_service.dart`: Implementation for CU-0021.
- `flutter_app/lib/presentation/screens/mandatory_update_screen.dart`: UI implementation for CU-0046.

### [Component 4] DNI Capture & Manual OCR Fallback UI
- `flutter_app/lib/presentation/screens/dni_capture_screen.dart`: Document capture UI (CU-0001, CU-0002, CU-0041).
- `flutter_app/lib/presentation/screens/manual_ocr_screen.dart`: Fallback manual entry UI with mask validation (CU-0042).
- `android_module/src/main/java/com/authenticator/ui/DniCaptureScreen.kt`: Jetpack Compose implementation for DNI capture.
- `android_module/src/main/java/com/authenticator/ui/OcrManualFallbackScreen.kt`: Jetpack Compose implementation for OCR Fallback.

### [Component 5] Local DNI Business Logic
- `flutter_app/lib/logic/ocr_processor.dart`: Local OCR parser (CU-0003).
- `flutter_app/lib/logic/document_validator.dart`: Document expiration validator (CU-0005).
- `flutter_app/lib/logic/age_calculator.dart`: Strict 18+ age verification logic (CU-0007).

### [Component 6] Facial Biometrics & Liveness UI
- `flutter_app/lib/presentation/screens/face_liveness_screen.dart`: Camera frame, oval guide, facial vector extraction simulation, and interactive random liveness instructions (CU-0011, CU-0012, CU-0013).

### [Component 7] Fingerprint Biometrics & BiometricPrompt
- `android_module/src/main/java/com/authenticator/biometric/BiometricAuthenticator.kt`: Kotlin class invoking native `BiometricPrompt` API (CU-0017, CU-0018).
- `flutter_app/lib/presentation/screens/biometric_fingerprint_screen.dart`: Flutter UI component interfacing with BiometricPrompt (CU-0017, CU-0018).

---

## 5. Verification Plan

### Automated & Static Verification
- Check Flutter project compilation and structure integrity using `flutter analyze` or Dart code validation.
- Verify Kotlin syntax correctness for Android modules.
- Check Maven `pom.xml` schema validity.

### Manual Verification & Visual UX Inspection
- Verify exact hex color code compliance in themes and UI components.
- Confirm Montserrat typography configuration.
- Verify exact 8px border radius on buttons, inputs, and cards.
- Test age calculation and document expiration logic against unit test scenarios (under 18, expired DNI, valid DNI).
