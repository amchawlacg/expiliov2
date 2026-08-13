class TransactionModel {
  final int? id;
  final String userId;
  final double amount;
  final String transactionType; // expense, income, transfer
  final String profileType; // personal, business
  final String? category;
  final String? subCategory;
  final String? note;
  final String? paymentMethod;
  final String? paymentName;
  final String? merchant;
  final DateTime date;
  final String source; // manual, chat, voice, receipt
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionModel({
    this.id,
    required this.userId,
    required this.amount,
    required this.transactionType,
    required this.profileType,
    this.category,
    this.subCategory,
    this.note,
    this.paymentMethod,
    this.paymentName,
    this.merchant,
    required this.date,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  TransactionModel copyWith({
    int? id,
    String? userId,
    double? amount,
    String? transactionType,
    String? profileType,
    String? category,
    String? subCategory,
    String? note,
    String? paymentMethod,
    String? paymentName,
    String? merchant,
    DateTime? date,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      profileType: profileType ?? this.profileType,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentName: paymentName ?? this.paymentName,
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'transaction_type': transactionType,
      'profile_type': profileType,
      'category': category,
      'subcategory': subCategory,
      'note': note,
      'payment_method': paymentMethod,
      'payment_name': paymentName,
      'merchant': merchant,
      'date': date.toIso8601String(),
      'source': source,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      userId: map['user_id'],
      amount: map['amount'],
      transactionType: map['transaction_type'],
      profileType: map['profile_type'],
      category: map['category'],
      subCategory: map['subcategory'],
      note: map['note'],
      paymentMethod: map['payment_method'],
      paymentName: map['payment_name'],
      merchant: map['merchant'],
      date: DateTime.parse(map['date']),
      source: map['source'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}