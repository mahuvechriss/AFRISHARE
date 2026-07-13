# AfriShare - Offline Community File Sharing System

**AfriShare** is a Flutter application that enables fast offline sharing of files, educational content, agricultural resources, health documents, and community information between nearby devices without requiring internet access.

Built as an African-focused alternative to file-sharing apps like Xender and SHAREit, AfriShare is designed to work efficiently in areas with limited or expensive internet connectivity.

## Features

### 📤 File Sharing
- Share images, videos, audio, PDFs, Word/Excel/PowerPoint files, APKs, and ZIP files
- Single and multiple file transfer
- Transfer queue with pause, resume, cancel, and retry
- Real-time progress tracking with speed and ETA
- Large file support (10GB+)

### 🔍 Device Discovery
- Wi-Fi Direct peer discovery
- Nearby Connections API integration
- Local network discovery via mDNS
- QR Code pairing for quick connections
- Manual device search

### 🛡️ End-to-End Encryption
- AES-256 encryption for all file transfers
- Secure device pairing and verification
- Encrypted chat messages

### 💬 Offline Chat
- Text messaging between connected devices
- Emoji support
- File attachments
- Message history
- No internet required

### 📚 Community Library
- Browse and share educational resources
- Categories: Education, Agriculture, Health, Business, Technology
- Resource search and filtering
- Download tracking

### ⚙️ Transfer Management
- Active, completed, and failed transfer tabs
- Transfer progress with speed indicators
- File type categorization
- Storage usage statistics

### 🔐 Privacy Controls
- Hide device from discovery
- Disable discovery mode
- Block devices
- Manual transfer approval
- Auto-cleanup options

### 📊 Admin Analytics
- Total transfers and files shared
- Storage consumption tracking
- Most shared content types
- Active device monitoring
- Transfer status distribution

## Architecture

AfriShare follows **Clean Architecture** with **MVVM** pattern:

```
lib/
├── core/           # Theme, constants, utils, database
├── models/         # Data models
├── services/       # Business logic layer
├── providers/      # Riverpod state management
├── screens/        # UI screens
└── widgets/        # Reusable widgets
```

### State Management
- **Riverpod** for dependency injection and state management
- Provider pattern for services
- StateNotifier for complex state

### Database
- **SQLite** via sqflite for local storage
- Tables: users, devices, transfers, chat_messages, shared_resources, notifications, settings

### Security
- **AES-256-CBC** encryption for file transfers and messages
- Secure key generation and management
- SHA-256 hashing for verification tokens
- Encrypted connection hashing

## Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter (latest stable) |
| Language | Dart (latest stable) |
| State Management | Riverpod |
| Database | SQLite (sqflite) |
| Encryption | AES-256 (encrypt package) |
| Device Discovery | nearby_connections, connectivity_plus |
| QR Codes | qr_flutter, mobile_scanner |
| File Handling | file_picker, open_file, mime |
| UI | Material 3, Google Fonts, shimmer, fl_chart |
| Notifications | flutter_local_notifications |

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Dart SDK (latest stable)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator (API 21+)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/afrishare.git
   cd afrishare
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Build for Production

**Android APK:**
```bash
flutter build apk --release
```

**Android App Bundle:**
```bash
flutter build appbundle --release
```

**Windows:**
```bash
flutter build windows --release
```

**Linux:**
```bash
flutter build linux --release
```

## Project Structure

```
afrishare/
├── lib/
│   ├── main.dart                    # Application entry point
│   ├── app.dart                     # Material app with theming
│   ├── core/
│   │   ├── theme/
│   │   │   ├── app_colors.dart      # Color palette
│   │   │   └── app_theme.dart       # Light/dark theme definitions
│   │   ├── constants/
│   │   │   └── app_constants.dart   # App-wide constants
│   │   ├── utils/
│   │   │   ├── file_utils.dart      # File operations utilities
│   │   │   └── encryption_utils.dart # AES-256 encryption utilities
│   │   └── database/
│   │       └── database_helper.dart # SQLite database manager
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── transfer_model.dart
│   │   ├── device_model.dart
│   │   ├── chat_message_model.dart
│   │   ├── shared_resource_model.dart
│   │   └── notification_model.dart
│   ├── services/
│   │   ├── auth_service.dart        # User authentication
│   │   ├── transfer_service.dart    # File transfer engine
│   │   ├── chat_service.dart        # Offline messaging
│   │   ├── discovery_service.dart   # Device discovery
│   │   ├── encryption_service.dart  # Encryption wrapper
│   │   ├── storage_service.dart     # Storage management
│   │   ├── notification_service.dart # In-app notifications
│   │   ├── qr_service.dart          # QR code pairing
│   │   └── resource_service.dart    # Community library
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── transfer_provider.dart
│   │   ├── chat_provider.dart
│   │   ├── discovery_provider.dart
│   │   ├── theme_provider.dart
│   │   ├── storage_provider.dart
│   │   ├── notification_provider.dart
│   │   └── resource_provider.dart
│   └── screens/ ...                 # UI screens
└── test/                            # Unit tests
```

## Permissions

### Android
Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
```

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built for communities across Africa
- Inspired by Xender, SHAREit, and local file-sharing needs
- Uses Material 3 design guidelines

## Support

For support, email support@afrishare.com or visit our documentation at docs.afrishare.com



READ THIS OPEN AI 
"makes two devices communicate by creating a local peer-to-peer network, usually without needing internet.

Here’s the core idea:

One device becomes a hotspot
The sender often creates a Wi-Fi hotspot.
Or both devices use Wi-Fi Direct (a direct Wi-Fi connection between devices).
The other device connects to it
The receiver joins that temporary network.
This creates a private local LAN between the two phones.
Device discovery & pairing
They identify each other using:
QR code scanning, or
automatic discovery over the local network (broadcast packets).
File transfer happens over standard network protocols
Data is split into packets and sent via:
TCP (reliable transfer) or sometimes UDP (faster but less strict).
The app manages retries, ordering, and reconstruction.
No internet required
Everything stays inside the local Wi-Fi link.
That’s why it’s fast and doesn’t use mobile data.
Extra optimization tricks
Compression before sending (to speed up transfer)
Parallel connections (sending chunks at the same time)
Switching between Wi-Fi Direct and hotspot depending on device support

In short:
👉 Xender turns your phone into a mini local network router and moves files over Wi-Fi protocols instead of the internet."