import 'dart:convert';

class SyncQueueItem {
  final int? id;
  final String entityType; // 'transaction', 'attachment', etc.
  final int entityId;
  final String action; // 'CREATE', 'UPDATE', 'DELETE'
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
      id: map['id'],
      entityType: map['entity_type'],
      entityId: map['entity_id'],
      action: map['action'],
      payload: map['payload'] != null ? jsonDecode(map['payload']) : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}