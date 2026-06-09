import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../core/database/database_helper.dart';

/// Service managing user authentication and profile
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final Uuid _uuid = const Uuid();
  final DatabaseHelper _db = DatabaseHelper.instance;

  UserModel? _currentUser;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isGuest => _currentUser?.isGuest ?? true;
  bool get isInitialized => _isInitialized;

  /// Initialize auth service. Creates guest session if no user exists.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final users = await _db.query('users', limit: 1);
    if (users.isNotEmpty) {
      _currentUser = UserModel.fromJson(users.first);
    } else {
      // Create guest user
      _currentUser = await _createGuestUser();
    }

    _isInitialized = true;
  }

  /// Create a guest user session
  Future<UserModel> _createGuestUser() async {
    final deviceId = 'device_${_uuid.v4().substring(0, 8)}';
    final guest = UserModel(
      id: _uuid.v4(),
      username: 'Guest User',
      deviceId: deviceId,
      deviceName: 'My Device',
      isGuest: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _db.insert('users', guest.toJson());
    return guest;
  }

  /// Register a new user account
  Future<UserModel> register({
    required String username,
    String? email,
    String? phone,
    String? deviceName,
  }) async {
    final deviceId = _currentUser?.deviceId ?? 'device_${_uuid.v4().substring(0, 8)}';
    final user = UserModel(
      id: _uuid.v4(),
      username: username,
      email: email,
      phone: phone,
      deviceId: deviceId,
      deviceName: deviceName ?? _currentUser?.deviceName ?? 'My Device',
      isGuest: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _db.insert('users', user.toJson());
    _currentUser = user;

    return user;
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    String? username,
    String? email,
    String? phone,
    String? profilePicture,
    String? deviceName,
  }) async {
    if (_currentUser == null) throw Exception('No user logged in');

    final updated = _currentUser!.copyWith(
      username: username,
      email: email,
      phone: phone,
      profilePicture: profilePicture,
      deviceName: deviceName,
    );

    await _db.update(
      'users',
      updated.toJson(),
      'id = ?',
      [updated.id],
    );
    _currentUser = updated;

    return updated;
  }

  /// Set profile picture
  Future<String?> setProfilePicture(String imagePath) async {
    if (_currentUser == null) return null;

    // In production, copy image to app's profile directory
    final profilePicture = imagePath;

    await updateProfile(profilePicture: profilePicture);
    return profilePicture;
  }

  /// Logout current user and create new guest session
  Future<void> logout() async {
    _currentUser = await _createGuestUser();
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    final result = await _db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (result.isNotEmpty) {
      return UserModel.fromJson(result.first);
    }
    return null;
  }

  /// Update device name
  Future<void> updateDeviceName(String deviceName) async {
    if (_currentUser == null) return;
    await updateProfile(deviceName: deviceName);
  }

  /// Get current user ID
  String get userId {
    if (_currentUser == null) {
      throw Exception('No user logged in');
    }
    return _currentUser!.id;
  }

  /// Get current user device ID
  String get deviceId {
    if (_currentUser == null) {
      throw Exception('No user logged in');
    }
    return _currentUser!.deviceId;
  }

  void dispose() {
    _currentUser = null;
    _isInitialized = false;
  }
}
