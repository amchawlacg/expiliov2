import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart';
import '../models/attachment.dart';
import '../models/message.dart';
import '../models/sync_queue_item.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expilio.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    String path;
    if (kIsWeb) {
      path = fileName;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, fileName);
    }

    return await openDatabase(
      path,
      version: 1, // Reset clean baseline to v1
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Transactions
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'USD',
        exchange_rate REAL NOT NULL DEFAULT 1.0,
        base_amount REAL NOT NULL,
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

    // 2. Attachments
    await db.execute('''
      CREATE TABLE attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT,
        file_name TEXT NOT NULL,
        local_path TEXT,
        local_thumbnail_path TEXT,
        cloud_url TEXT,
        cloud_thumbnail_url TEXT,
        file_type TEXT,
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    // 3. Messages / Chat
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL,
        metadata TEXT
      )
    ''');

    // 4. Currencies
    await db.execute('''
      CREATE TABLE currencies (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        symbol TEXT NOT NULL,
        rate_to_base REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 5. Categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        subcategories TEXT NOT NULL,
        icon_name TEXT,
        is_custom INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 6. Users / Offline Session
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT,
        display_name TEXT,
        photo_url TEXT,
        is_logged_in INTEGER DEFAULT 1,
        storage_used_mb REAL DEFAULT 0.0,
        storage_limit_mb REAL DEFAULT 500.0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 7. Sync Queue
    await _createSyncQueueTable(db);

    // 8. Seed baseline currencies
    await _seedDefaultCurrencies(db);
  }

  Future<void> _createSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedDefaultCurrencies(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaultCurrencies = [
      {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$', 'rate_to_base': 1.0, 'updated_at': now},
      {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹', 'rate_to_base': 0.012, 'updated_at': now},
      {'code': 'EUR', 'name': 'Euro', 'symbol': '€', 'rate_to_base': 1.08, 'updated_at': now},
      {'code': 'GBP', 'name': 'British Pound', 'symbol': '£', 'rate_to_base': 1.27, 'updated_at': now},
      {'code': 'AED', 'name': 'UAE Dirham', 'symbol': 'د.إ', 'rate_to_base': 0.27, 'updated_at': now},
      {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$', 'rate_to_base': 0.73, 'updated_at': now},
      {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$', 'rate_to_base': 0.65, 'updated_at': now},
    ];

    final batch = db.batch();
    for (var c in defaultCurrencies) {
      batch.insert('currencies', c, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // --- ATOMIC MUTATIONS & SYNC QUEUE ---

  Future<String> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    final String id = transaction.id ?? const Uuid().v4();
    final finalTransaction = transaction.copyWith(id: id);

    print("the next expected transaction id is " + id);

    return await db.transaction((txn) async {
      await txn.insert('transactions', finalTransaction.toMap());
      await _enqueueSyncAction(
        txn,
        entityType: 'transaction',
        entityId: id,
        action: 'CREATE',
        payload: finalTransaction.toMap(),
      );
      print("the id changed to " + id);
      return id;
    });
  }

  Future<String> insertTransactionWithAttachments(
    TransactionModel transaction,
    List<AttachmentModel> attachments,
  ) async {
    final db = await instance.database;
    final String transId = transaction.id ?? const Uuid().v4();
    final savedTransaction = transaction.copyWith(id: transId);

    return await db.transaction((txn) async {
      await txn.insert('transactions', savedTransaction.toMap());
      await _enqueueSyncAction(
        txn,
        entityType: 'transaction',
        entityId: transId,
        action: 'CREATE',
        payload: savedTransaction.toMap(),
      );

      for (var attachment in attachments) {
  final updatedAttachment = attachment.copyWith(transactionId: transId);
  final attachId = await txn.insert('attachments', updatedAttachment.toMap());
  final savedAttachment = updatedAttachment.copyWith(id: attachId);

  // Inject the parent transaction's userId into the payload map
  final Map<String, dynamic> payload = savedAttachment.toMap();
  payload['user_id'] = savedTransaction.userId; // ✅ Injected

  await _enqueueSyncAction(
    txn,
    entityType: 'attachment',
    entityId: attachId.toString(),
    action: 'CREATE',
    payload: payload,
  );
}
      return transId;
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

      if (transaction.id != null) {
        await _enqueueSyncAction(
          txn,
          entityType: 'transaction',
          entityId: transaction.id!,
          action: 'UPDATE',
          payload: transaction.toMap(),
        );
      }
      return rows;
    });
  }

  Future<int> deleteTransaction(String id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final rows = await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );

      await _enqueueSyncAction(
        txn,
        entityType: 'transaction',
        entityId: id,
        action: 'DELETE',
      );
      return rows;
    });
  }

  // --- READ QUERIES ---

  Future<List<TransactionModel>> getTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');

    List<TransactionModel> transactions = [];
    for (var map in result) {
      final transId = map['id']?.toString();
      List<AttachmentModel> attachments = [];
      if (transId != null) {
        attachments = await getAttachments(transId);
      }
      transactions.add(TransactionModel.fromMap(map, attachments: attachments));
    }
    return transactions;
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

    List<TransactionModel> transactions = [];
    for (var map in result) {
      final transId = map['id']?.toString();
      List<AttachmentModel> attachments = [];
      if (transId != null) {
        attachments = await getAttachments(transId);
      }
      transactions.add(TransactionModel.fromMap(map, attachments: attachments));
    }
    return transactions;
  }

  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    final attachments = await getAttachments(id);
    return TransactionModel.fromMap(result.first, attachments: attachments);
  }

  // --- QUEUE MANAGEMENT ---

  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    final db = await instance.database;
    final result = await db.query('sync_queue', orderBy: 'id ASC');
    return result.map((map) => SyncQueueItem.fromMap(map)).toList();
  }

  Future<int> deleteSyncQueueItem(int id) async {
    final db = await instance.database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearStuckSyncQueueItem(int entityId) async {
    final db = await instance.database;
    return await db.delete(
      'sync_queue',
      where: 'entity_id = ?',
      whereArgs: [entityId],
    );
  }

  // --- ATTACHMENTS ---

  Future<List<Map<String, dynamic>>> getInvoicesWithMetadataRaw() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        a.id, 
        a.transaction_id,
        a.file_name,
        a.local_path, 
        a.local_thumbnail_path,
        a.cloud_url,
        a.cloud_thumbnail_url,
        a.file_type,
        a.is_synced,
        a.is_deleted,
        a.created_at, 
        a.updated_at,
        t.category, 
        t.date 
      FROM attachments a
      LEFT JOIN transactions t ON a.transaction_id = t.id
      WHERE a.is_deleted = 0
      ORDER BY COALESCE(t.date, a.created_at) DESC
    ''');
  }

  Future<int> insertAttachment(AttachmentModel attachment) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final id = await txn.insert('attachments', attachment.toMap());
      final savedAttachment = attachment.copyWith(id: id);

      if (savedAttachment.transactionId != null && savedAttachment.transactionId!.isNotEmpty) {
        await _enqueueSyncAction(
          txn,
          entityType: 'attachment',
          entityId: id.toString(),
          action: 'CREATE',
          payload: savedAttachment.toMap(),
        );
      }
      return id;
    });
  }

  Future<List<AttachmentModel>> getAttachments(String transactionId) async {
    final db = await instance.database;
    final result = await db.query(
      'attachments',
      where: 'transaction_id = ? AND is_deleted = ?',
      whereArgs: [transactionId, 0],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => AttachmentModel.fromMap(map)).toList();
  }

  Future<int> updateAttachmentSyncStatus({
    required int id,
    required String cloudUrl,
    String? cloudThumbnailUrl,
  }) async {
    final db = await instance.database;
    return await db.update(
      'attachments',
      {
        'cloud_url': cloudUrl,
        'cloud_thumbnail_url': cloudThumbnailUrl,
        'is_synced': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateAttachmentLocalPath({
    required int id,
    required String localPath,
  }) async {
    final db = await instance.database;
    return await db.update(
      'attachments',
      {'local_path': localPath, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateAttachmentLocalThumbnailPath({
    required int id,
    required String localThumbnailPath,
  }) async {
    final db = await instance.database;
    return await db.update(
      'attachments',
      {'local_thumbnail_path': localThumbnailPath, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAttachment(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final rows = await txn.update(
        'attachments',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await _enqueueSyncAction(
        txn,
        entityType: 'attachment',
        entityId: id.toString(),
        action: 'DELETE',
      );
      return rows;
    });
  }

  // --- ANALYTICS & SUMMARIES ---

  Future<Map<DateTime, double>> getDailyTotalsForMonth(DateTime month) async {
    final db = await instance.database;
    final String monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT 
        substr(date, 1, 10) as day_string,
        SUM(CASE WHEN LOWER(transaction_type) = 'income' THEN base_amount ELSE -base_amount END) as net_balance
      FROM transactions
      WHERE date LIKE ?
      GROUP BY substr(date, 1, 10)
    ''',
      ['$monthStr%'],
    );

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

    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT 
        SUM(CASE WHEN LOWER(transaction_type) = 'income' THEN base_amount ELSE 0 END) as total_income,
        SUM(CASE WHEN LOWER(transaction_type) = 'expense' THEN base_amount ELSE 0 END) as total_expense
      FROM transactions
      WHERE date LIKE ?
    ''',
      ['$monthStr%'],
    );

    double income = (result.first['total_income'] as num?)?.toDouble() ?? 0.0;
    double expense = (result.first['total_expense'] as num?)?.toDouble() ?? 0.0;

    return {'income': income, 'expense': expense, 'net': income - expense};
  }

  Future<Map<String, double>> getCategorySummary(int month, int year) async {
    final db = await instance.database;
    final String monthStr = "$year-${month.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT category, SUM(base_amount) as total_amount
      FROM transactions
      WHERE date LIKE ? AND LOWER(transaction_type) = 'expense'
      GROUP BY category
      ORDER BY total_amount DESC
    ''',
      ['$monthStr%'],
    );

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

    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT profile_type, SUM(base_amount) as total_amount
      FROM transactions
      WHERE date LIKE ? AND LOWER(transaction_type) = 'expense'
      GROUP BY profile_type
    ''',
      ['$monthStr%'],
    );

    final Map<String, double> profileMap = {};
    for (var row in result) {
      profileMap[row['profile_type'] as String? ?? 'Personal'] =
          (row['total_amount'] as num).toDouble();
    }
    return profileMap;
  }

  // --- MESSAGES ---

  Future<int> insertMessage(MessageModel message) async {
    final db = await instance.database;
    return await db.insert('messages', message.toMap());
  }

  Future<List<MessageModel>> getMessages() async {
    final db = await instance.database;
    final result = await db.query('messages', orderBy: 'created_at ASC');
    return result.map((map) => MessageModel.fromMap(map)).toList();
  }

  Future<void> clearAllMessages() async {
    final db = await instance.database;
    await db.delete('messages');
  }

  // --- CATEGORIES ---

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query('categories', orderBy: 'id ASC');
  }

  Future<int> insertCategory(Map<String, dynamic> categoryMap) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final id = await txn.insert('categories', categoryMap);
      final payload = Map<String, dynamic>.from(categoryMap)..['id'] = id;

      await _enqueueSyncAction(
        txn,
        entityType: 'category',
        entityId: id.toString(),
        action: 'CREATE',
        payload: payload,
      );
      return id;
    });
  }

  Future<int> updateCategory(int id, Map<String, dynamic> categoryMap) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final rows = await txn.update(
        'categories',
        categoryMap,
        where: 'id = ?',
        whereArgs: [id],
      );

      await _enqueueSyncAction(
        txn,
        entityType: 'category',
        entityId: id.toString(),
        action: 'UPDATE',
        payload: categoryMap,
      );
      return rows;
    });
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final rows = await txn.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );

      await _enqueueSyncAction(
        txn,
        entityType: 'category',
        entityId: id.toString(),
        action: 'DELETE',
      );
      return rows;
    });
  }

  Future<void> seedInitialCategories(List<Map<String, dynamic>> defaultCategories) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var category in defaultCategories) {
      batch.insert('categories', category, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // --- CURRENCIES ---

  Future<List<Map<String, dynamic>>> getCurrencies() async {
    final db = await instance.database;
    return await db.query('currencies', orderBy: 'code ASC');
  }

  Future<void> updateCurrencyRate(String code, double rateToBase) async {
    final db = await instance.database;
    await db.update(
      'currencies',
      {
        'rate_to_base': rateToBase,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'code = ?',
      whereArgs: [code],
    );
  }

  // --- SYNC QUEUE HELPER ---

  Future<void> _enqueueSyncAction(
    DatabaseExecutor txn, {
    String entityType = 'transaction',
    required String entityId,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    final existingQueue = await txn.query(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'id ASC',
    );

    if (existingQueue.isEmpty) {
      await txn.insert('sync_queue', {
        'entity_type': entityType,
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
        await txn.update(
          'sync_queue',
          {'payload': jsonEncode(payload)},
          where: 'id = ?',
          whereArgs: [existingId],
        );
      }
    } else if (action == 'DELETE') {
      if (existingAction == 'CREATE') {
        await txn.delete('sync_queue', where: 'id = ?', whereArgs: [existingId]);
      } else if (existingAction == 'UPDATE') {
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

  // --- USER SESSION (OFFLINE AUTH) ---

  Future<void> saveUserSession({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
    double? storageUsedMb,
    double? storageLimitMb,
  }) async {
    final db = await instance.database;
    await db.insert(
      'users',
      {
        'id': uid,
        'email': email,
        'display_name': displayName,
        'photo_url': photoUrl,
        'is_logged_in': 1,
        if (storageUsedMb != null) 'storage_used_mb': storageUsedMb,
        if (storageLimitMb != null) 'storage_limit_mb': storageLimitMb,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateUserStorageStats({
    required String uid,
    required double storageUsedMb,
    double? storageLimitMb,
  }) async {
    final db = await instance.database;
    final Map<String, dynamic> values = {
      'storage_used_mb': storageUsedMb,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (storageLimitMb != null) {
      values['storage_limit_mb'] = storageLimitMb;
    }

    await db.update('users', values, where: 'id = ?', whereArgs: [uid]);
  }

  Future<Map<String, dynamic>?> getActiveUserSession() async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'is_logged_in = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> clearUserSession() async {
    final db = await instance.database;
    await db.delete('users');
  }

  Future<void> deleteEntireDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    String path;
    if (kIsWeb) {
      path = 'expilio.db';
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, 'expilio.db');
    }

    await deleteDatabase(path);
  }

  /// Bulk insert/update transactions and attachments from the cloud without triggering sync_queue entries
  Future<void> hydrateDatabaseFromRemote({
    required List<TransactionModel> transactions,
    required List<AttachmentModel> attachments,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final tx in transactions) {
        batch.insert(
          'transactions',
          tx.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final att in attachments) {
        batch.insert(
          'attachments',
          att.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });
  }

  /// Clears user-specific tables upon logout so new sessions start clean
  Future<void> clearAllUserData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('attachments');
      await txn.delete('sync_queue');
      await txn.delete('messages');
      await txn.delete('users');
    });
  }

}