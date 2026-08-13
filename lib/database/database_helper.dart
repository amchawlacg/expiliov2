import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart';
import '../models/attachment.dart';
import '../models/message.dart';
import '../models/sync_queue_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('expilio.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 6, // Upgraded to v6 for sync_queue
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        amount REAL NOT NULL,
        transaction_type TEXT NOT NULL,
        profile_type TEXT NOT NULL,
        category TEXT,
        subcategory TEXT,
        note TEXT,
        payment_method TEXT,
        payment_name TEXT,
        merchant TEXT,
        date TEXT NOT NULL,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _createSyncQueueTable(db);
  }

  Future _createSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        payload TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN payment_method TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN payment_name TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN merchant TEXT');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE attachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL,
          file_name TEXT NOT NULL,
          local_path TEXT,
          cloud_url TEXT,
          file_type TEXT,
          is_synced INTEGER DEFAULT 0,
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          role TEXT NOT NULL,
          message TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE transactions ADD COLUMN subcategory TEXT');
    }

    if (oldVersion < 6) {
      await _createSyncQueueTable(db);
    }
  }

  // --- ATOMIC TRANSACTION MUTATIONS WITH SYNC QUEUE ---

  Future<int> insertTransaction(TransactionModel transaction) async {
  final db = await instance.database;

  return await db.transaction((txn) async {
    final id = await txn.insert('transactions', transaction.toMap());

    // Call smart queue helper instead of direct insertion
    await _enqueueSyncAction(
      txn,
      entityId: id,
      action: 'CREATE',
      payload: transaction.copyWith(id: id).toMap(),
    );

    return id;
  });
}

Future<int> updateTransaction(TransactionModel transaction) async {
  final db = await instance.database;

  return await db.transaction((txn) async {
    final rows = await txn.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );

    // Call smart queue helper
    if (transaction.id != null) {
      await _enqueueSyncAction(
        txn,
        entityId: transaction.id!,
        action: 'UPDATE',
        payload: transaction.toMap(),
      );
    }

    return rows;
  });
}

Future<int> deleteTransaction(int id) async {
  final db = await instance.database;

  return await db.transaction((txn) async {
    // Local hard delete
    final rows = await txn.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Call smart queue helper
    await _enqueueSyncAction(
      txn,
      entityId: id,
      action: 'DELETE',
    );

    return rows;
  });
}

  // --- READ QUERIES (NO LONGER FILTER ON IS_DELETED) ---

  Future<List<TransactionModel>> getTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByDate(DateTime date) async {
    final db = await instance.database;
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = startDate.add(const Duration(days: 1));

    final result = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );

    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // --- QUEUE MANAGEMENT FUNCTIONS ---

  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    final db = await instance.database;
    final result = await db.query('sync_queue', orderBy: 'id ASC');
    return result.map((map) => SyncQueueItem.fromMap(map)).toList();
  }

  Future<int> deleteSyncQueueItem(int id) async {
    final db = await instance.database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // --- OTHER DATABASE FUNCTIONS ---

  Future<Map<DateTime, double>> getDailyTotalsForMonth(DateTime month) async {
    final db = await instance.database;
    final String monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        substr(date, 1, 10) as day_string,
        SUM(CASE WHEN LOWER(transaction_type) = 'income' THEN amount ELSE -amount END) as net_balance
      FROM transactions
      WHERE date LIKE ?
      GROUP BY substr(date, 1, 10)
    ''', ['$monthStr%']);

    final Map<DateTime, double> dailyBalances = {};
    for (var row in result) {
      final String? dayStr = row['day_string'] as String?;
      final double? balance = row['net_balance'] as double?;

      if (dayStr != null && balance != null) {
        final parsedDate = DateTime.parse(dayStr);
        final normalizedKey = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        dailyBalances[normalizedKey] = balance;
      }
    }
    return dailyBalances;
  }

  Future<Map<String, double>> getMonthlySummary(int month, int year) async {
    final db = await instance.database;
    final String monthStr = "$year-${month.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN LOWER(transaction_type) = 'income' THEN amount ELSE 0 END) as total_income,
        SUM(CASE WHEN LOWER(transaction_type) = 'expense' THEN amount ELSE 0 END) as total_expense
      FROM transactions
      WHERE date LIKE ?
    ''', ['$monthStr%']);

    double income = (result.first['total_income'] as num?)?.toDouble() ?? 0.0;
    double expense = (result.first['total_expense'] as num?)?.toDouble() ?? 0.0;

    return {'income': income, 'expense': expense, 'net': income - expense};
  }

  Future<Map<String, double>> getCategorySummary(int month, int year) async {
    final db = await instance.database;
    final String monthStr = "$year-${month.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT category, SUM(amount) as total_amount
      FROM transactions
      WHERE date LIKE ? AND LOWER(transaction_type) = 'expense'
      GROUP BY category
      ORDER BY total_amount DESC
    ''', ['$monthStr%']);

    final Map<String, double> categoryMap = {};
    for (var row in result) {
      categoryMap[row['category'] as String? ?? 'Uncategorized'] =
          (row['total_amount'] as num).toDouble();
    }
    return categoryMap;
  }

  Future<Map<String, double>> getProfileSummary(int month, int year) async {
    final db = await instance.database;
    final String monthStr = "$year-${month.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT profile_type, SUM(amount) as total_amount
      FROM transactions
      WHERE date LIKE ? AND LOWER(transaction_type) = 'expense'
      GROUP BY profile_type
    ''', ['$monthStr%']);

    final Map<String, double> profileMap = {};
    for (var row in result) {
      profileMap[row['profile_type'] as String? ?? 'Personal'] =
          (row['total_amount'] as num).toDouble();
    }
    return profileMap;
  }

  Future<int> insertAttachment(AttachmentModel attachment) async {
    final db = await instance.database;
    return await db.insert('attachments', attachment.toMap());
  }

  Future<List<AttachmentModel>> getAttachments(int transactionId) async {
    final db = await instance.database;
    final result = await db.query(
      'attachments',
      where: 'transaction_id = ? AND is_deleted = ?',
      whereArgs: [transactionId, 0],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => AttachmentModel.fromMap(map)).toList();
  }

  Future<int> deleteAttachment(int id) async {
    final db = await instance.database;
    return await db.update(
      'attachments',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertMessage(MessageModel message) async {
    final db = await instance.database;
    return await db.insert('messages', message.toMap());
  }

  Future<List<MessageModel>> getMessages() async {
    final db = await instance.database;
    final result = await db.query('messages', orderBy: 'created_at ASC');
    return result.map((map) => MessageModel.fromMap(map)).toList();
  }

  Future<void> _enqueueSyncAction(
  DatabaseExecutor txn, {
  required int entityId,
  required String action,
  Map<String, dynamic>? payload,
}) async {
  // Check if there is already an un-synced operation for this transaction
  final existingQueue = await txn.query(
    'sync_queue',
    where: 'entity_type = ? AND entity_id = ?',
    whereArgs: ['transaction', entityId],
    orderBy: 'id ASC',
  );

  if (existingQueue.isEmpty) {
    // Standard insert if no pending operations exist
    await txn.insert('sync_queue', {
      'entity_type': 'transaction',
      'entity_id': entityId,
      'action': action,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': DateTime.now().toIso8601String(),
    });
    return;
  }

  final existingItem = existingQueue.first;
  final int existingId = existingItem['id'] as int;
  final String existingAction = existingItem['action'] as String;

  if (action == 'UPDATE') {
    if (existingAction == 'CREATE' || existingAction == 'UPDATE') {
      // Keep action type, but overwrite payload with latest data
      await txn.update(
        'sync_queue',
        {'payload': jsonEncode(payload)},
        where: 'id = ?',
        whereArgs: [existingId],
      );
    }
  } else if (action == 'DELETE') {
    if (existingAction == 'CREATE') {
      // Created and deleted offline -> Purge queue item (no cloud request needed)
      await txn.delete(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [existingId],
      );
    } else if (existingAction == 'UPDATE') {
      // Replace pending UPDATE with a DELETE action
      await txn.update(
        'sync_queue',
        {
          'action': 'DELETE',
          'payload': null,
          'created_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
    }
  }
}
}