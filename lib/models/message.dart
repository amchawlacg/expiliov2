import 'dart:convert';

class MessageModel {
  final int? id;
  final String role;
  final String message;
  final DateTime createdAt;
  final List<int> transactionIds;
  final String status; // 'sent', 'failed'

  MessageModel({
    this.id,
    required this.role,
    required this.message,
    required this.createdAt,
    this.transactionIds = const [],
    this.status = 'sent',
  });

  MessageModel copyWith({
    int? id,
    String? role,
    String? message,
    DateTime? createdAt,
    List<int>? transactionIds,
    String? status,
  }) {
    return MessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      transactionIds: transactionIds ?? this.transactionIds,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'role': role,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'metadata': jsonEncode({
        'transaction_ids': transactionIds,
        'status': status,
      }),
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    List<int> parsedTransactionIds = [];
    String parsedStatus = 'sent';

    final rawMetadata = map['metadata'];
    if (rawMetadata != null && rawMetadata is String && rawMetadata.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMetadata);
        if (decoded is Map<String, dynamic>) {
          if (decoded['transaction_ids'] is List) {
            parsedTransactionIds = (decoded['transaction_ids'] as List)
                .map((id) => (id as num).toInt())
                .toList();
          }
          if (decoded['status'] is String) {
            parsedStatus = decoded['status'] as String;
          }
        }
      } catch (_) {
        // Fallback gracefully if metadata isn't valid JSON
      }
    }

    return MessageModel(
      id: map['id'] as int?,
      role: map['role'] as String,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      transactionIds: parsedTransactionIds,
      status: parsedStatus,
    );
  }
}