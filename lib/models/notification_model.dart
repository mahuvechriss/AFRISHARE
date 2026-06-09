enum NotificationType {
  connectionRequest,
  incomingTransfer,
  transferCompleted,
  transferFailed,
  newMessage,
  pairingRequest,
  system,
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? data;
  bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'data': data,
        'is_read': isRead ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        type: NotificationType.values.firstWhere(
            (n) => n.name == json['type'],
            orElse: () => NotificationType.system),
        title: json['title'] as String,
        body: json['body'] as String,
        data: json['data'] as String?,
        isRead: (json['is_read'] as int?) == 1,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  NotificationModel copyWith({
    bool? isRead,
  }) =>
      NotificationModel(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
