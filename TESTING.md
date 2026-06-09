# AfriShare Testing Guide

## Overview

This guide covers testing strategies for the AfriShare offline file-sharing application. Tests cover unit, widget, and integration levels.

## Prerequisites

- Flutter SDK installed
- Project dependencies installed (`flutter pub get`)
- Android emulator or physical device for integration tests

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/models/user_model_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
# View coverage: genhtml coverage/lcov.info -o coverage/html
```

### Run Integration Tests
```bash
flutter test integration_test/
```

## Test Categories

### 1. Model Tests

Test data models for:
- Serialization (toJson/fromJson)
- CopyWith methods
- Default values
- Edge cases (empty strings, null values)

**Example test file:** `test/models/user_model_test.dart`

```dart
void main() {
  group('UserModel', () {
    test('should serialize and deserialize correctly', () {
      final user = UserModel(
        id: '1',
        username: 'TestUser',
        deviceId: 'device_123',
        deviceName: 'Test Device',
        isGuest: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final json = user.toJson();
      final deserialized = UserModel.fromJson(json);
      
      expect(deserialized.id, user.id);
      expect(deserialized.username, user.username);
    });
    
    test('copyWith should update fields', () {
      // Test copyWith behavior
    });
  });
}
```

### 2. Service Tests

Test business logic services:
- AuthService: guest creation, registration, profile updates
- TransferService: queue management, status updates
- ChatService: message sending, conversation loading
- EncryptionService: encrypt/decrypt operations

Use Mockito or Mocktail for mocking database dependencies.

**Example:**
```dart
test('AuthService should create guest user', () async {
  final authService = AuthService.instance;
  await authService.initialize();
  
  expect(authService.currentUser, isNotNull);
  expect(authService.isGuest, isTrue);
});
```

### 3. Provider Tests

Test Riverpod state management:
- State initialization
- State updates through notifier methods
- Error handling
- Loading states

**Example:**
```dart
test('TransferListNotifier should load transfers', () async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  
  final provider = container.read(transferListProvider.notifier);
  expect(container.read(transferListProvider).isLoading, isTrue);
});
```

### 4. Widget Tests

Test UI components:
- All screens render without errors
- Widgets display correct data
- User interactions trigger expected callbacks
- Empty states show when no data

**Example:**
```dart
testWidgets('DashboardScreen shows quick actions', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: DashboardScreen())),
  );
  
  expect(find.text('Send Files'), findsOneWidget);
  expect(find.text('Receive Files'), findsOneWidget);
});
```

### 5. Integration Tests

Test complete user flows:
- File selection → send to device
- QR code generation → scanning → pairing
- Message sending → receiving → display
- Resource browsing → download

## Manual Testing Checklist

### Authentication
- [ ] App launches in guest mode
- [ ] Guest user created automatically
- [ ] Username editing works
- [ ] Profile picture selection works
- [ ] Account creation works
- [ ] Logout → new guest session

### Device Discovery
- [ ] Discovery starts automatically
- [ ] Nearby devices appear in list
- [ ] Manual search works
- [ ] Discovery toggle on/off
- [ ] Device status updates correctly

### QR Code Pairing
- [ ] QR code generates correctly
- [ ] QR code contains valid data
- [ ] Scanner detects and processes codes
- [ ] Pairing completes successfully

### File Transfer
- [ ] File picker opens and selects files
- [ ] Multiple file selection works
- [ ] Transfer queue processes files
- [ ] Progress updates in real-time
- [ ] Pause/Resume works
- [ ] Cancel stops transfer
- [ ] Retry restarts failed transfer
- [ ] Large files (10GB+) handled

### Offline Chat
- [ ] Conversations list loads
- [ ] Messages send and display
- [ ] Emoji sending works
- [ ] File attachments send
- [ ] Read receipts work
- [ ] Message history persists

### Community Library
- [ ] Categories display correctly
- [ ] Resource search works
- [ ] Category filtering works
- [ ] Resource details show
- [ ] Download increments count

### Settings
- [ ] Theme switching (light/dark/system)
- [ ] Device name editing
- [ ] Profile updates save
- [ ] Toggle switches work
- [ ] Storage stats display

### Admin Analytics
- [ ] Stats load correctly
- [ ] Charts display data
- [ ] Most shared content shows
- [ ] Transfer status distribution shows

### Security
- [ ] All transfers show as encrypted
- [ ] Connection verification works
- [ ] Device blocking works
- [ ] Privacy toggle works

### Performance
- [ ] App launches within 3 seconds
- [ ] Transfer list scrolls smoothly
- [ ] Chat messages load quickly
- [ ] Memory usage stays under 200MB
- [ ] Battery impact minimal during transfers

## Test Environment Setup

### Android Emulator
```bash
# Create emulator
flutter emulators --create [name]

# Launch emulator
flutter emulators --launch [name]

# OR use Android Studio AVD Manager
```

### Two-Device Testing
For testing transfers between devices:
1. Launch two emulator instances
2. OR use one emulator + one physical device
3. Ensure both devices are on the same network

## Debugging Tips

### View Logs
```bash
flutter logs
```

### Debug Network
```bash
# Enable network logging
flutter run --verbose
```

### Performance Profiling
```bash
flutter run --profile
# Use Flutter DevTools for timeline analysis
```

## Continuous Integration

### GitHub Actions Example
```yaml
name: AfriShare CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.11.x'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
```

## Reporting Issues

When reporting test failures, include:
1. Test name and file
2. Full error message and stack trace
3. Device/emulator details
4. Flutter version (`flutter --version`)
5. Steps to reproduce
