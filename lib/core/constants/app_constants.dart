class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'AfriShare';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'Offline Community File Sharing System';
  static const String organizationName = 'AfriShare Community';

  // Storage
  static const String dbName = 'afrishare.db';
  static const int dbVersion = 1;
  static const String transferDirectory = 'afrishare_transfers';
  static const String cacheDirectory = 'afrishare_cache';
  static const String sharedResourcesDirectory = 'afrishare_resources';
  static const String profileImagesDirectory = 'afrishare_profiles';

  // Transfer Limits
  static const int maxSimultaneousTransfers = 5;
  static const int maxTransferQueueSize = 100;
  static const int maxFileSizeBytes = 1099511627776; // 1TB
  static const int chunkSizeBytes = 262144; // 256KB chunks
  static const int connectionTimeoutSeconds = 30;
  static const int transferTimeoutSeconds = 3600;

  // Discovery
  static const String serviceType = '_afrishare._tcp';
  static const int discoveryPort = 47808;
  static const int discoveryIntervalMs = 3000;
  static const int deviceTimeoutSeconds = 60;

  // Encryption
  static const int keyLength = 256;
  static const int ivLength = 16;
  static const String encryptionAlgorithm = 'AES-256-CBC';

  // QR Code
  static const Duration qrCodeRefreshDuration = Duration(seconds: 30);
  static const int qrCodeSize = 250;

  // UI
  static const double borderRadius = 12.0;
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // File Size Limits Display
  static const double maxProgressValue = 100.0;

  // Categories
  static const List<String> resourceCategories = [
    'Education',
    'Agriculture',
    'Health',
    'Business',
    'Technology',
    'Community',
    'Entertainment',
    'Other',
  ];

  // Sub-categories for Community Library
  static const Map<String, List<String>> resourceSubCategories = {
    'Education': ['Notes', 'Books', 'Past Papers', 'Tutorials', 'Reference'],
    'Agriculture': [
      'Crop Guides',
      'Livestock Guides',
      'Market Information',
      'Farming Tips',
    ],
    'Health': [
      'Nutrition Guides',
      'Vaccination Information',
      'First Aid Resources',
      'Wellness Tips',
    ],
    'Business': [
      'Entrepreneurship Guides',
      'Financial Literacy',
      'Market Analysis',
      'Business Plans',
    ],
  };

  // Supported File Types
  static const List<String> supportedImageTypes = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp'
  ];
  static const List<String> supportedVideoTypes = [
    'mp4',
    'avi',
    'mkv',
    'mov',
    'wmv',
    'flv'
  ];
  static const List<String> supportedAudioTypes = [
    'mp3',
    'wav',
    'aac',
    'ogg',
    'flac',
    'wma'
  ];
  static const List<String> supportedDocumentTypes = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
  ];
  static const List<String> supportedArchiveTypes = ['zip', 'rar', '7z', 'tar', 'gz'];
  static const List<String> supportedAppTypes = ['apk', 'aab'];

  static const List<String> allSupportedTypes = [
    ...supportedImageTypes,
    ...supportedVideoTypes,
    ...supportedAudioTypes,
    ...supportedDocumentTypes,
    ...supportedArchiveTypes,
    ...supportedAppTypes,
  ];
}
