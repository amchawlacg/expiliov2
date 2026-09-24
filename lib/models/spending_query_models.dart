import '../models/transaction.dart';

/// Action classification emitted by Gemini
enum AiActionType {
  query,
  addDraft,
  none,
}

/// The target query intent determined by Gemini
enum SpendingIntentType {
  spendingSummary,
  periodOverview,
  topCategories,
  topMerchants,
  listTransactions,
  unknown,
}

/// The structured filter extracted from the natural language prompt
class SpendingQueryIntent {
  final SpendingIntentType intent;
  final List<String> keywords;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? transactionType; // 'expense', 'income', or null
  final String? profileType;     // 'Personal', 'Business', or null
  final String? paymentMethod;
  final double? minAmount;
  final double? maxAmount;
  final int limit;

  SpendingQueryIntent({
    required this.intent,
    this.keywords = const [],
    this.startDate,
    this.endDate,
    this.transactionType,
    this.profileType,
    this.paymentMethod,
    this.minAmount,
    this.maxAmount,
    this.limit = 5,
  });

  factory SpendingQueryIntent.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic dateVal) {
      if (dateVal == null || dateVal is! String || dateVal.trim().isEmpty) {
        return null;
      }
      return DateTime.tryParse(dateVal.trim());
    }

    SpendingIntentType parseIntent(String? raw) {
      switch (raw?.toLowerCase()) {
        case 'spending_summary':
          return SpendingIntentType.spendingSummary;
        case 'period_overview':
          return SpendingIntentType.periodOverview;
        case 'top_categories':
          return SpendingIntentType.topCategories;
        case 'top_merchants':
          return SpendingIntentType.topMerchants;
        case 'list_transactions':
          return SpendingIntentType.listTransactions;
        default:
          return SpendingIntentType.unknown;
      }
    }

    return SpendingQueryIntent(
      intent: parseIntent(json['intent'] as String?),
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      transactionType: json['transaction_type'] as String?,
      profileType: json['profile_type'] as String?,
      paymentMethod: json['payment_method'] as String?,
      minAmount: (json['min_amount'] as num?)?.toDouble(),
      maxAmount: (json['max_amount'] as num?)?.toDouble(),
      limit: (json['limit'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intent': intent.name,
      'keywords': keywords,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'transaction_type': transactionType,
      'profile_type': profileType,
      'payment_method': paymentMethod,
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'limit': limit,
    };
  }
}

/// Unified container returned by GeminiService
class GeminiChatResult {
  final String message;
  final AiActionType actionType;
  final SpendingQueryIntent? queryIntent;
  final TransactionModel? draftTransaction;

  GeminiChatResult({
    required this.message,
    required this.actionType,
    this.queryIntent,
    this.draftTransaction,
  });
}

/// Result of a targeted spending query (e.g., "coffee and tea in late May")
class SpendingSummary {
  final double totalAmount;
  final int transactionCount;
  final List<TransactionModel> transactions;

  SpendingSummary({
    required this.totalAmount,
    required this.transactionCount,
    this.transactions = const [],
  });

  factory SpendingSummary.fromMap(
    Map<String, dynamic> map, {
    List<TransactionModel> transactions = const [],
  }) {
    return SpendingSummary(
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (map['transaction_count'] as num?)?.toInt() ?? 0,
      transactions: transactions,
    );
  }
}

/// Cash flow comparison (Income vs Expense)
class CashFlowSummary {
  final double totalExpense;
  final double totalIncome;
  final double netSavings;

  CashFlowSummary({
    required this.totalExpense,
    required this.totalIncome,
  }) : netSavings = totalIncome - totalExpense;

  factory CashFlowSummary.fromMap(Map<String, dynamic> map) {
    final expense = (map['total_expense'] as num?)?.toDouble() ?? 0.0;
    final income = (map['total_income'] as num?)?.toDouble() ?? 0.0;
    return CashFlowSummary(
      totalExpense: expense,
      totalIncome: income,
    );
  }
}

/// Grouped category aggregation
class CategoryBreakdown {
  final String category;
  final double total;
  final int count;

  CategoryBreakdown({
    required this.category,
    required this.total,
    required this.count,
  });

  factory CategoryBreakdown.fromMap(Map<String, dynamic> map) {
    return CategoryBreakdown(
      category: map['category'] as String? ?? 'Uncategorized',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Grouped merchant/vendor aggregation
class MerchantBreakdown {
  final String merchant;
  final double total;
  final int count;

  MerchantBreakdown({
    required this.merchant,
    required this.total,
    required this.count,
  });

  factory MerchantBreakdown.fromMap(Map<String, dynamic> map) {
    return MerchantBreakdown(
      merchant: map['merchant'] as String? ?? 'Unknown',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}