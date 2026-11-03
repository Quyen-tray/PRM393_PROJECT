# Android Warnings and Google Login Implementation Plan

**Status:** Implemented and verified on the Android emulator.

**Goal:** Remove Flutter's Android toolchain version warnings and ensure Google login receives the configured web client ID when launched from Android Studio.

**Architecture:** Use Gradle 9.3.1 and AGP 9.1.1 for API 37. Enable AGP built-in Kotlin, supply KGP 2.4.10 without applying the legacy Kotlin Android plugin, and keep `android.newDsl=false` for Flutter Gradle plugin compatibility. Upgrade Android Flutter plugins that still apply legacy KGP. Add an Android Studio run configuration that loads the existing local `env.json`.

**Tech Stack:** Flutter 3.47.2, Gradle 9.3.1, AGP 9.1.1, KGP 2.4.10, built-in Kotlin.

**Spec:** User request (2026-11-03): remove the quoted Flutter version warnings and restore Google ID token configuration for self-testing.

## Constraints

- Preserve `compileSdk = 37`.
- Keep the Google OAuth client ID in the existing `env.json`; do not print it.
- Do not run Git or GitHub commands.

## Implementation

- [x] Update Gradle wrapper and AGP versions; retain KGP 2.4.10 as a classpath version only.
- [x] Enable built-in Kotlin and remove the app's legacy Kotlin plugin application.
- [x] Upgrade `camera`, `device_info_plus`, and `flutter_secure_storage` to compatible releases; resolve `package_info_plus` through the updated Linux geolocator plugin.
- [x] Add an Android Studio run configuration using `--dart-define-from-file=env.json`.
- [x] Build and launch on `emulator-5554` (Android 17/API 37).

## Verification

- `flutter pub upgrade camera device_info_plus flutter_secure_storage geolocator_linux` completed successfully.
- `flutter run -d emulator-5554 --dart-define-from-file=env.json` built, installed, and launched the app. The app is running in the emulator.
- The three quoted Gradle, AGP, and Kotlin version warnings no longer appear.
- The build still reports an Android SDK XML version mismatch warning from the installed Android Studio command-line tools; it does not prevent build or launch.

## Google Login Diagnosis

`AuthRepository` reads `GOOGLE_CLIENT_ID` using `String.fromEnvironment`. A normal Android Studio/Flutter launch did not pass the value from root `env.json`, leaving `serverClientId` empty and causing the ID token to be null. The run configuration now passes that file. The configured web client ID matches the backend's Google audience setting.
