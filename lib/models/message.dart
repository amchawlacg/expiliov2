class MessageModel {
  final int? id;

  final String role;

  final String message;

  final DateTime createdAt;

  MessageModel({
    this.id,

    required this.role,

    required this.message,

    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,

      'role': role,

      'message': message,

      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],

      role: map['role'],

      message: map['message'],

      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
