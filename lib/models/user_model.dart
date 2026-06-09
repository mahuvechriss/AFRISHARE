class UserModel {
  final String id;
  final String username;
  final String? email;
  final String? phone;
  final String? profilePicture;
  final String deviceId;
  final String deviceName;
  final bool isGuest;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.username,
    this.email,
    this.phone,
    this.profilePicture,
    required this.deviceId,
    required this.deviceName,
    this.isGuest = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'phone': phone,
        'profile_picture': profilePicture,
        'device_id': deviceId,
        'device_name': deviceName,
        'is_guest': isGuest ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        profilePicture: json['profile_picture'] as String?,
        deviceId: json['device_id'] as String,
        deviceName: json['device_name'] as String,
        isGuest: (json['is_guest'] as int?) == 1,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  UserModel copyWith({
    String? username,
    String? email,
    String? phone,
    String? profilePicture,
    String? deviceName,
    bool? isGuest,
  }) =>
      UserModel(
        id: id,
        username: username ?? this.username,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        profilePicture: profilePicture ?? this.profilePicture,
        deviceId: deviceId,
        deviceName: deviceName ?? this.deviceName,
        isGuest: isGuest ?? this.isGuest,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
