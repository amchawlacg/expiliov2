import '../database/database_helper.dart';
import '../models/transaction.dart';

class TransactionService {
  final DatabaseHelper _database = DatabaseHelper.instance;

  Future<int> addTransaction(TransactionModel transaction) async {
    final now = DateTime.now();

    final newTransaction = TransactionModel(
      userId: transaction.userId,
      amount: transaction.amount,
      transactionType: transaction.transactionType,
      profileType: transaction.profileType,
      category: transaction.category,
      note: transaction.note,
      paymentMethod: transaction.paymentMethod,
      paymentName: transaction.paymentName,
      merchant: transaction.merchant,
      date: transaction.date,
      source: transaction.source,
      isSynced: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );

    return await _database.insertTransaction(newTransaction);
  }

  Future<List<TransactionModel>> getTransactions() async {
    return await _database.getTransactions();
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final updatedTransaction = TransactionModel(
      id: transaction.id,
      userId: transaction.userId,
      amount: transaction.amount,
      transactionType: transaction.transactionType,
      profileType: transaction.profileType,
      category: transaction.category,
      note: transaction.note,
      paymentMethod: transaction.paymentMethod,
      paymentName: transaction.paymentName,
      merchant: transaction.merchant,
      date: transaction.date,
      source: transaction.source,
      isSynced: false, // important for sync later
      isDeleted: transaction.isDeleted,
      createdAt: transaction.createdAt, // keep original created date
      updatedAt: DateTime.now(), // update modification time
    );

    return await _database.updateTransaction(updatedTransaction);
  }

  Future<List<TransactionModel>> getTransactionsByDate(DateTime date) async {
    return await _database.getTransactionsByDate(date);
  }

  Future<int> deleteTransaction(int id) async {
    return await _database.deleteTransaction(id);
  }

  Future<Map<String, double>> getMonthlySummary(int month, int year) async {
    return await _database.getMonthlySummary(month, year);
  }

  Future<Map<String, double>> getCategorySummary(int month, int year) async {
    return await _database.getCategorySummary(month, year);
  }

  Future<Map<String, double>> getProfileSummary(int month, int year) async {
    return await _database.getProfileSummary(month, year);
  }

  // --- NEW METHOD FOR CALENDAR HIGH-LIGHTING ---
  /// Fetches all transactions and filters/aggregates net totals for a given month.
  // Replace the prior memory-heavy method with this clean pass-through:
  Future<Map<DateTime, double>> getDailyTotalsForMonth(DateTime month) async {
    return await _database.getDailyTotalsForMonth(month);
  }
}