enum TransferDirection { sent, received }
enum TransferStatus {
  queued,
  connecting,
  transferring,
  paused,
  completed,
  failed,
  cancelled,
  retrying
}

class TransferModel {
  final String id;
  final String fileName;
  final String? filePath;
  final int fileSize;
  final String fileType;
  final String? mimeType;
  final String senderId;
  final String? senderName;
  final String receiverId;
  final String? receiverName;
  final TransferDirection direction;
  TransferStatus status;
  double progress;
  double speed;
  final String? encryptionKey;
  final String? encryptionIv;
  final bool isEncrypted;
  final String? errorMessage;
  final DateTime createdAt;
  DateTime updatedAt;
  final DateTime? completedAt;

  TransferModel({
    required this.id,
    required this.fileName,
    this.filePath,
    required this.fileSize,
    required this.fileType,
    this.mimeType,
    required this.senderId,
    this.senderName,
    required this.receiverId,
    this.receiverName,
    required this.direction,
    this.status = TransferStatus.queued,
    this.progress = 0,
    this.speed = 0,
    this.encryptionKey,
    this.encryptionIv,
    this.isEncrypted = true,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  String get statusText {
    switch (status) {
      case TransferStatus.queued:
        return 'Queued';
      case TransferStatus.connecting:
        return 'Connecting';
      case TransferStatus.transferring:
        return 'Transferring';
      case TransferStatus.paused:
        return 'Paused';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
      case TransferStatus.retrying:
        return 'Retrying';
    }
  }

  bool get isActive =>
      status == TransferStatus.transferring ||
      status == TransferStatus.connecting ||
      status == TransferStatus.queued;

  bool get isTerminal =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;

  double get progressFraction => progress / 100.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'file_name': fileName,
        'file_path': filePath,
        'file_size': fileSize,
        'file_type': fileType,
        'mime_type': mimeType,
        'sender_id': senderId,
        'sender_name': senderName,
        'receiver_id': receiverId,
        'receiver_name': receiverName,
        'direction': direction.name,
        'status': status.name,
        'progress': progress,
        'speed': speed,
        'encryption_key': encryptionKey,
        'encryption_iv': encryptionIv,
        'is_encrypted': isEncrypted ? 1 : 0,
        'error_message': errorMessage,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  factory TransferModel.fromJson(Map<String, dynamic> json) => TransferModel(
        id: json['id'] as String,
        fileName: json['file_name'] as String,
        filePath: json['file_path'] as String?,
        fileSize: json['file_size'] as int,
        fileType: json['file_type'] as String,
        mimeType: json['mime_type'] as String?,
        senderId: json['sender_id'] as String,
        senderName: json['sender_name'] as String?,
        receiverId: json['receiver_id'] as String,
        receiverName: json['receiver_name'] as String?,
        direction: TransferDirection.values.firstWhere(
            (d) => d.name == json['direction'],
            orElse: () => TransferDirection.received),
        status: TransferStatus.values.firstWhere(
            (s) => s.name == json['status'],
            orElse: () => TransferStatus.queued),
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        speed: (json['speed'] as num?)?.toDouble() ?? 0,
        encryptionKey: json['encryption_key'] as String?,
        encryptionIv: json['encryption_iv'] as String?,
        isEncrypted: (json['is_encrypted'] as int?) == 1,
        errorMessage: json['error_message'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
      );

  TransferModel copyWith({
    String? filePath,
    TransferStatus? status,
    double? progress,
    double? speed,
    String? errorMessage,
    DateTime? completedAt,
  }) =>
      TransferModel(
        id: id,
        fileName: fileName,
        filePath: filePath ?? this.filePath,
        fileSize: fileSize,
        fileType: fileType,
        mimeType: mimeType,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        receiverName: receiverName,
        direction: direction,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        speed: speed ?? this.speed,
        encryptionKey: encryptionKey,
        encryptionIv: encryptionIv,
        isEncrypted: isEncrypted,
        errorMessage: errorMessage ?? this.errorMessage,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        completedAt: completedAt ?? this.completedAt,
      );
}
