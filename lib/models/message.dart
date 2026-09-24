import 'dart:convert';

class MessageModel {
  final int? id;
  final String role;
  final String message;
  final DateTime createdAt;
  final List<int> transactionIds;

  MessageModel({
    this.id,
    required this.role,
    required this.message,
    required this.createdAt,
    this.transactionIds = const [],
  });

  MessageModel copyWith({
    int? id,
    String? role,
    String? message,
    DateTime? createdAt,
    List<int>? transactionIds,
  }) {
    return MessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      transactionIds: transactionIds ?? this.transactionIds,
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
      }),
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    List<int> parsedTransactionIds = [];

    final rawMetadata = map['metadata'];
    if (rawMetadata != null && rawMetadata is String && rawMetadata.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMetadata);
        if (decoded is Map<String, dynamic> && decoded['transaction_ids'] is List) {
          parsedTransactionIds = (decoded['transaction_ids'] as List)
              .map((id) => (id as num).toInt())
              .toList();
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
    );
  }
}