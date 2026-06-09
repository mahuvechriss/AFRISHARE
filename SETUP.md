# AfriShare Setup Guide

## Prerequisites

1. **Install Flutter SDK** (version 3.11.5 or higher)
   - Download from: https://docs.flutter.dev/get-started/install
   - Add Flutter to your PATH

2. **Install Dart SDK** (version 3.11.5 or higher)
   - Comes bundled with Flutter SDK

3. **Install Android Studio** (for Android development)
   - Download from: https://developer.android.com/studio
   - Install Android SDK (API 21+)
   - Set up Android emulator or connect physical device

4. **Install VS Code** (recommended) with extensions:
   - Flutter
   - Dart
   - Material Icon Theme

## Environment Verification

```bash
# Check Flutter installation
flutter doctor

# Ensure all checks pass:
# - Flutter ✓
# - Android toolchain ✓
# - Android Studio ✓
# - VS Code ✓
# - Connected device ✓
```

## Project Setup

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/afrishare.git
cd afrishare
```

### 2. Get Dependencies
```bash
flutter pub get
```

### 3. Generate Code (if using code generation)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Configure Android

**Update `android/app/build.gradle`:**
```gradle
android {
    compileSdk 34
    
    defaultConfig {
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

**Update `android/app/src/main/AndroidManifest.xml`:**
Add the permissions listed in README.md.

### 5. Run the Application

**Development Mode:**
```bash
# Run on connected device/emulator
flutter run

# Run with debug mode
flutter run --debug

# Run with specific device
flutter run -d device_id
```

**Profile Mode (performance testing):**
```bash
flutter run --profile
```

## Build for Distribution

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Windows
```bash
flutter build windows --release
# Output: build/windows/runner/Release/
```

### Linux
```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

## Running on Physical Android Device

1. Enable Developer Options on your Android device:
   - Settings → About Phone → Tap "Build Number" 7 times

2. Enable USB Debugging:
   - Settings → Developer Options → USB Debugging

3. Connect device via USB

4. Verify device is detected:
   ```bash
   flutter devices
   ```

5. Run the app:
   ```bash
   flutter run
   ```

## Common Issues

### Issue: Permission denied for Nearby Devices
**Solution:** Ensure location permissions are granted in Android settings.

### Issue: Gradle build fails
**Solution:** Update Gradle wrapper:
```bash
cd android
./gradlew wrapper --gradle-version=8.0
```

### Issue: "flutter pub get" fails
**Solution:** Clear cache and retry:
```bash
flutter pub cache clean
flutter pub get
```

## Development Workflow

1. **Hot Reload** for UI changes: `r` in running app
2. **Hot Restart** for state changes: `R` in running app
3. **Debug Paint**: `flutter run --debug`
4. **Performance**: `flutter run --profile`

## Additional Resources

- Flutter Documentation: https://docs.flutter.dev/
- Dart Documentation: https://dart.dev/guides
- Riverpod: https://riverpod.dev/
- sqflite: https://pub.dev/packages/sqflite
