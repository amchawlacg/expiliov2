import 'attachment.dart';

class TransactionModel {
  final String? id;
  final String userId;
  final double amount;
  final String currency;
  final double exchangeRate;
  final double baseAmount;
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
  final List<AttachmentModel> attachments;

  TransactionModel({
    this.id,
    required this.userId,
    required this.amount,
    this.currency = 'USD',
    this.exchangeRate = 1.0,
    double? baseAmount,
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
    this.attachments = const [],
  }) : baseAmount = baseAmount ?? (amount * (exchangeRate != 0.0 ? exchangeRate : 1.0));

  TransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? currency,
    double? exchangeRate,
    double? baseAmount,
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
    List<AttachmentModel>? attachments,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      baseAmount: baseAmount ?? this.baseAmount,
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
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'base_amount': baseAmount,
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

  factory TransactionModel.fromMap(
    Map<String, dynamic> map, {
    List<AttachmentModel> attachments = const [],
  }) {
    final double rawAmount = (map['amount'] as num).toDouble();
    final double rate = (map['exchange_rate'] as num?)?.toDouble() ?? 1.0;
    final double rawBase = (map['base_amount'] as num?)?.toDouble() ?? 0.0;
    final double computedBase = (rawBase > 0)
        ? rawBase
        : (rawAmount * (rate > 0 ? rate : 1.0));

    return TransactionModel(
      id: map['id']?.toString(),
      userId: map['user_id'] as String,
      amount: rawAmount,
      currency: map['currency'] as String? ?? 'USD',
      exchangeRate: rate,
      baseAmount: computedBase,
      transactionType: map['transaction_type'] as String,
      profileType: map['profile_type'] as String,
      category: map['category'] as String?,
      subCategory: map['subcategory'] as String?,
      note: map['note'] as String?,
      paymentMethod: map['payment_method'] as String?,
      paymentName: map['payment_name'] as String?,
      merchant: map['merchant'] as String?,
      date: DateTime.parse(map['date'] as String),
      source: map['source'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      attachments: attachments,
    );
  }
}