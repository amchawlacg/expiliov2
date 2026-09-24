import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart';
import '../models/attachment.dart';
import '../models/spending_query_models.dart';

class SpendingQueryService {
  final Database db;

  SpendingQueryService(this.db);

  DateTime _normalizeEndDate(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    );
  }

  // --- 1. GENERAL MULTI-FILTER & MULTI-KEYWORD QUERY ---

  Future<SpendingSummary> querySpending({
    List<String> keywords = const [],
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType = 'expense',
    String? profileType,
    String? paymentMethod,
    double? minAmount,
    double? maxAmount,
    bool includeTransactions = false,
  }) async {
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    // Transaction Type Filter (expense / income)
    if (transactionType != null && transactionType.trim().isNotEmpty) {
      whereClauses.add('LOWER(transaction_type) = ?');
      whereArgs.add(transactionType.trim().toLowerCase());
    }

    // Profile Type Filter (Personal / Business)
    if (profileType != null && profileType.trim().isNotEmpty) {
      whereClauses.add('LOWER(profile_type) = ?');
      whereArgs.add(profileType.trim().toLowerCase());
    }

    // Payment Method Filter
    if (paymentMethod != null && paymentMethod.trim().isNotEmpty) {
      whereClauses.add('LOWER(payment_method) = ?');
      whereArgs.add(paymentMethod.trim().toLowerCase());
    }

    // Date Range Filters
    if (startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(_normalizeEndDate(endDate).toIso8601String());
    }

    // Base Amount Boundary Filters
    if (minAmount != null) {
      whereClauses.add('base_amount >= ?');
      whereArgs.add(minAmount);
    }
    if (maxAmount != null) {
      whereClauses.add('base_amount <= ?');
      whereArgs.add(maxAmount);
    }

    // Multi-Keyword Disjunction ('coffee' OR 'tea') across fields
    if (keywords.isNotEmpty) {
      final keywordClauses = <String>[];
      for (final rawKw in keywords) {
        final kw = '%${rawKw.trim().toLowerCase()}%';
        keywordClauses.add('''
          (
            LOWER(COALESCE(category, '')) LIKE ? OR
            LOWER(COALESCE(subcategory, '')) LIKE ? OR
            LOWER(COALESCE(merchant, '')) LIKE ? OR
            LOWER(COALESCE(note, '')) LIKE ?
          )
        ''');
        whereArgs.addAll([kw, kw, kw, kw]);
      }
      whereClauses.add('(${keywordClauses.join(' OR ')})');
    }

    final whereString = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    // Calculate aggregate totals
    final summaryResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(base_amount), 0.0) AS total_amount,
        COUNT(id) AS transaction_count
      FROM transactions
      $whereString
    ''', whereArgs);

    List<TransactionModel> transactions = [];

    // Optionally hydrate transaction models and attachments
    if (includeTransactions) {
      final rows = await db.rawQuery('''
        SELECT * FROM transactions
        $whereString
        ORDER BY date DESC
      ''', whereArgs);

      for (var row in rows) {
        final transId = row['id'] as int?;
        List<AttachmentModel> attachments = [];
        if (transId != null) {
          final attachRows = await db.query(
            'attachments',
            where: 'transaction_id = ? AND is_deleted = 0',
            whereArgs: [transId],
          );
          attachments = attachRows.map((e) => AttachmentModel.fromMap(e)).toList();
        }
        transactions.add(TransactionModel.fromMap(row, attachments: attachments));
      }
    }

    return SpendingSummary.fromMap(
      summaryResult.first,
      transactions: transactions,
    );
  }

  // --- 2. PERIOD OVERVIEW (INCOME VS EXPENSE) ---

  Future<CashFlowSummary> getPeriodOverview({
    required DateTime startDate,
    required DateTime endDate,
    String? profileType,
  }) async {
    final whereClauses = ['date BETWEEN ? AND ?'];
    final whereArgs = <dynamic>[
      startDate.toIso8601String(),
      _normalizeEndDate(endDate).toIso8601String(),
    ];

    if (profileType != null && profileType.trim().isNotEmpty) {
      whereClauses.add('LOWER(profile_type) = ?');
      whereArgs.add(profileType.trim().toLowerCase());
    }

    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN LOWER(transaction_type) = 'expense' THEN base_amount ELSE 0 END), 0.0) AS total_expense,
        COALESCE(SUM(CASE WHEN LOWER(transaction_type) = 'income' THEN base_amount ELSE 0 END), 0.0) AS total_income
      FROM transactions
      WHERE ${whereClauses.join(' AND ')}
    ''', whereArgs);

    return CashFlowSummary.fromMap(result.first);
  }

  // --- 3. TOP SPENDING CATEGORIES ---

  Future<List<CategoryBreakdown>> getTopCategories({
    required DateTime startDate,
    required DateTime endDate,
    String? profileType,
    int limit = 5,
  }) async {
    final whereClauses = [
      "LOWER(transaction_type) = 'expense'",
      'date BETWEEN ? AND ?',
    ];
    final whereArgs = <dynamic>[
      startDate.toIso8601String(),
      _normalizeEndDate(endDate).toIso8601String(),
    ];

    if (profileType != null && profileType.trim().isNotEmpty) {
      whereClauses.add('LOWER(profile_type) = ?');
      whereArgs.add(profileType.trim().toLowerCase());
    }

    whereArgs.add(limit);

    final results = await db.rawQuery('''
      SELECT 
        COALESCE(category, 'Uncategorized') AS category, 
        COALESCE(SUM(base_amount), 0.0) AS total,
        COUNT(id) AS count
      FROM transactions
      WHERE ${whereClauses.join(' AND ')}
      GROUP BY category
      ORDER BY total DESC
      LIMIT ?
    ''', whereArgs);

    return results.map((e) => CategoryBreakdown.fromMap(e)).toList();
  }

  // --- 4. TOP MERCHANTS ---

  Future<List<MerchantBreakdown>> getTopMerchants({
    required DateTime startDate,
    required DateTime endDate,
    String? profileType,
    int limit = 5,
  }) async {
    final whereClauses = [
      "LOWER(transaction_type) = 'expense'",
      'date BETWEEN ? AND ?',
      'merchant IS NOT NULL',
      "TRIM(merchant) != ''"
    ];
    final whereArgs = <dynamic>[
      startDate.toIso8601String(),
      _normalizeEndDate(endDate).toIso8601String(),
    ];

    if (profileType != null && profileType.trim().isNotEmpty) {
      whereClauses.add('LOWER(profile_type) = ?');
      whereArgs.add(profileType.trim().toLowerCase());
    }

    whereArgs.add(limit);

    final results = await db.rawQuery('''
      SELECT 
        merchant, 
        COALESCE(SUM(base_amount), 0.0) AS total,
        COUNT(id) AS count
      FROM transactions
      WHERE ${whereClauses.join(' AND ')}
      GROUP BY merchant
      ORDER BY total DESC
      LIMIT ?
    ''', whereArgs);

    return results.map((e) => MerchantBreakdown.fromMap(e)).toList();
  }

  // --- 5. INTENT DISPATCHER ---

  Future<dynamic> executeIntent(
    SpendingQueryIntent intent, {
    bool includeTransactions = true,
  }) async {
    switch (intent.intent) {
      case SpendingIntentType.spendingSummary:
        return await querySpending(
          keywords: intent.keywords,
          startDate: intent.startDate,
          endDate: intent.endDate,
          transactionType: intent.transactionType ?? 'expense',
          profileType: intent.profileType,
          paymentMethod: intent.paymentMethod,
          minAmount: intent.minAmount,
          maxAmount: intent.maxAmount,
          includeTransactions: includeTransactions,
        );

      case SpendingIntentType.periodOverview:
        return await getPeriodOverview(
          startDate: intent.startDate ?? DateTime(DateTime.now().year, 1, 1),
          endDate: intent.endDate ?? DateTime.now(),
          profileType: intent.profileType,
        );

      case SpendingIntentType.topCategories:
        return await getTopCategories(
          startDate: intent.startDate ?? DateTime(DateTime.now().year, 1, 1),
          endDate: intent.endDate ?? DateTime.now(),
          profileType: intent.profileType,
          limit: intent.limit,
        );

      case SpendingIntentType.topMerchants:
        return await getTopMerchants(
          startDate: intent.startDate ?? DateTime(DateTime.now().year, 1, 1),
          endDate: intent.endDate ?? DateTime.now(),
          profileType: intent.profileType,
          limit: intent.limit,
        );

      case SpendingIntentType.listTransactions:
        return await querySpending(
          keywords: intent.keywords,
          startDate: intent.startDate,
          endDate: intent.endDate,
          transactionType: intent.transactionType,
          profileType: intent.profileType,
          paymentMethod: intent.paymentMethod,
          minAmount: intent.minAmount,
          maxAmount: intent.maxAmount,
          includeTransactions: true,
        );

      case SpendingIntentType.unknown:
        return null;
    }
  }
}