class AiAction {
  final String type; // ADD_TRANSACTION, QUERY_TOTAL, etc.
  final String? category;
  final double? amount;
  final String? dateRange;

  AiAction({
    required this.type,
    this.category,
    this.amount,
    this.dateRange,
  });

  factory AiAction.fromJson(Map<String, dynamic> json) {
    return AiAction(
      type: json['type'] as String,
      category: json['category'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      dateRange: json['date_range'] as String?,
    );
  }
}

class AiResponse {
  final String message;
  final AiAction? action;

  AiResponse({required this.message, this.action});

  factory AiResponse.fromJson(Map<String, dynamic> json) {
    return AiResponse(
      message: json['message'] as String? ?? 'No response',
      action: json['action'] != null
          ? AiAction.fromJson(json['action'] as Map<String, dynamic>)
          : null,
    );
  }
}