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

  final bool isSynced;
  final bool isDeleted;

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
    this.isSynced = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });


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
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
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
      isSynced: map['is_synced'] == 1,
      isDeleted: map['is_deleted'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}