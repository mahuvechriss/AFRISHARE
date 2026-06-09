enum DeviceStatus { online, offline, connecting, paired }
enum DeviceType { android, windows, linux, unknown }

class DeviceModel {
  final String id;
  final String name;
  final String deviceId;
  final DeviceType deviceType;
  DeviceStatus status;
  final DateTime? lastSeen;
  bool isPaired;
  bool isBlocked;
  bool isHidden;
  final String? publicKey;
  final DateTime createdAt;
  DateTime updatedAt;

  // Connection-specific fields (not persisted)
  int signalStrength;
  String? ipAddress;
  int? port;

  DeviceModel({
    required this.id,
    required this.name,
    required this.deviceId,
    this.deviceType = DeviceType.android,
    this.status = DeviceStatus.offline,
    this.lastSeen,
    this.isPaired = false,
    this.isBlocked = false,
    this.isHidden = false,
    this.publicKey,
    required this.createdAt,
    required this.updatedAt,
    this.signalStrength = 0,
    this.ipAddress,
    this.port,
  });

  String get statusText {
    switch (status) {
      case DeviceStatus.online:
        return 'Online';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.connecting:
        return 'Connecting...';
      case DeviceStatus.paired:
        return 'Paired';
    }
  }

  bool get isConnectable =>
      status == DeviceStatus.online || status == DeviceStatus.paired;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'device_id': deviceId,
        'device_type': deviceType.name,
        'status': status.name,
        'last_seen': lastSeen?.toIso8601String(),
        'is_paired': isPaired ? 1 : 0,
        'is_blocked': isBlocked ? 1 : 0,
        'is_hidden': isHidden ? 1 : 0,
        'public_key': publicKey,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        id: json['id'] as String,
        name: json['name'] as String,
        deviceId: json['device_id'] as String,
        deviceType: DeviceType.values.firstWhere(
            (d) => d.name == json['device_type'],
            orElse: () => DeviceType.unknown),
        status: DeviceStatus.values.firstWhere(
            (s) => s.name == json['status'],
            orElse: () => DeviceStatus.offline),
        lastSeen: json['last_seen'] != null
            ? DateTime.parse(json['last_seen'] as String)
            : null,
        isPaired: (json['is_paired'] as int?) == 1,
        isBlocked: (json['is_blocked'] as int?) == 1,
        isHidden: (json['is_hidden'] as int?) == 1,
        publicKey: json['public_key'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  DeviceModel copyWith({
    String? name,
    DeviceStatus? status,
    DateTime? lastSeen,
    bool? isPaired,
    bool? isBlocked,
    bool? isHidden,
    String? publicKey,
    int? signalStrength,
    String? ipAddress,
    int? port,
  }) =>
      DeviceModel(
        id: id,
        name: name ?? this.name,
        deviceId: deviceId,
        deviceType: deviceType,
        status: status ?? this.status,
        lastSeen: lastSeen ?? this.lastSeen,
        isPaired: isPaired ?? this.isPaired,
        isBlocked: isBlocked ?? this.isBlocked,
        isHidden: isHidden ?? this.isHidden,
        publicKey: publicKey ?? this.publicKey,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        signalStrength: signalStrength ?? this.signalStrength,
        ipAddress: ipAddress ?? this.ipAddress,
        port: port ?? this.port,
      );
}
