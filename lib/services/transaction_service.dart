import '../database/database_helper.dart';
import '../models/transaction.dart';

class TransactionService {
  final DatabaseHelper _database = DatabaseHelper.instance;

  Future<int> addTransaction(TransactionModel transaction) async {
    final now = DateTime.now();

    // Create new transaction instance setting current timestamps
    final newTransaction = transaction.copyWith(createdAt: now, updatedAt: now);

    return await _database.insertTransaction(newTransaction);
  }

  Future<List<TransactionModel>> getTransactions() async {
    return await _database.getTransactions();
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final updatedTransaction = transaction.copyWith(
      baseAmount:
          transaction.amount *
          (transaction.exchangeRate != 0.0 ? transaction.exchangeRate : 1.0),
      updatedAt: DateTime.now(),
    );

    return await _database.updateTransaction(updatedTransaction);
  }

  Future<List<TransactionModel>> getTransactionsByDate(DateTime date) async {
    return await _database.getTransactionsByDate(date);
  }

  Future<int> deleteTransaction(int id) async {
    // DatabaseHelper performs hard delete locally and enqueues 'DELETE' action
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

  Future<Map<DateTime, double>> getDailyTotalsForMonth(DateTime month) async {
    return await _database.getDailyTotalsForMonth(month);
  }
}
