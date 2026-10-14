import 'dart:convert';

class SyncQueueItem {
  final int? id;
  final String entityType; // 'transaction', 'attachment', etc.
  final String entityId;   // CHANGED from int to String
  final String action;     // 'CREATE', 'UPDATE', 'DELETE'
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  SyncQueueItem({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int?,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'].toString(), // Safely handles both String and int
      action: map['action'] as String,
      payload: map['payload'] != null ? jsonDecode(map['payload'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}