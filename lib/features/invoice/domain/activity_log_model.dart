import 'package:uuid/uuid.dart';

enum LogEntity { invoice, business, customer, item }
enum LogAction { create, update, delete, upsert, statusChange }

class ActivityLog {
  final String id;

  final LogEntity entity;
  final LogAction action;

  /// Which object was affected (invoice id / customer id etc.)
  final String entityId;

  /// Display
  final String title;
  final String message;

  /// When it happened
  final DateTime createdAt;

  /// Optional extra data for future analytics
  final Map<String, dynamic> meta;

  const ActivityLog({
    required this.id,
    required this.entity,
    required this.action,
    required this.entityId,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.meta,
  });

  factory ActivityLog.create({
    required LogEntity entity,
    required LogAction action,
    required String entityId,
    required String title,
    required String message,
    Map<String, dynamic>? meta,
  }) {
    return ActivityLog(
      id: const Uuid().v4(),
      entity: entity,
      action: action,
      entityId: entityId,
      title: title.trim(),
      message: message.trim(),
      createdAt: DateTime.now(),
      meta: meta ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity': entity.name,
    'action': action.name,
    'entityId': entityId,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'meta': meta,
  };

  factory ActivityLog.fromJson(Map<dynamic, dynamic> json) {
    return ActivityLog(
      id: (json['id'] ?? '').toString(),
      entity: LogEntity.values.firstWhere(
            (e) => e.name == (json['entity'] ?? 'invoice'),
        orElse: () => LogEntity.invoice,
      ),
      action: LogAction.values.firstWhere(
            (e) => e.name == (json['action'] ?? 'create'),
        orElse: () => LogAction.create,
      ),
      entityId: (json['entityId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      meta: (json['meta'] is Map)
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : <String, dynamic>{},
    );
  }
}
