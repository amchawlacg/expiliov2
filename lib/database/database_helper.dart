import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart';
import '../models/attachment.dart';
import '../models/message.dart';
import '../models/sync_queue_item.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    String path;

    if (kIsWeb) {
      // In web browsers, sqflite_common_ffi_web uses the filename directly as the IndexedDB store key
      path = fileName;
    } else {
      // On iOS, Android, and Desktop, use the system databases directory path
      final dbPath = await getDatabasesPath();
      path = join(dbPath, fileName);
    }

    return await openDatabase(
      path,
      version: 8, // Upgraded to v8 for custom categories
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

    await db.execute('''
      CREATE TABLE attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER,
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

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
  CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    subcategories TEXT NOT NULL, -- Stored as JSON string
    icon_name TEXT,
    is_custom INTEGER DEFAULT 0,
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

    if (oldVersion < 7) {
      await db.execute('ALTER TABLE attachments ADD COLUMN local_thumbnail_path TEXT');
      await db.execute('ALTER TABLE attachments ADD COLUMN cloud_thumbnail_url TEXT');
    }

    if (oldVersion < 8) {
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
}
  }

  // --- ATOMIC TRANSACTION & ATTACHMENT MUTATIONS WITH SYNC QUEUE ---

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      final id = await txn.insert('transactions', transaction.toMap());

      await _enqueueSyncAction(
        txn,
        entityType: 'transaction',
        entityId: id,
        action: 'CREATE',
        payload: transaction.copyWith(id: id).toMap(),
      );

      return id;
    });
  }

  /// Inserts a transaction and its associated attachments inside a single atomic DB transaction
  Future<int> insertTransactionWithAttachments(
    TransactionModel transaction,
    List<AttachmentModel> attachments,
  ) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      // 1. Insert Transaction
      final transId = await txn.insert('transactions', transaction.toMap());
      final savedTransaction = transaction.copyWith(id: transId);

      // 2. Queue Transaction CREATE
      await _enqueueSyncAction(
        txn,
        entityType: 'transaction',
        entityId: transId,
        action: 'CREATE',
        payload: savedTransaction.toMap(),
      );

      // 3. Insert and queue each attachment
      for (var attachment in attachments) {
        final updatedAttachment = attachment.copyWith(transactionId: transId);
        final attachId = await txn.insert('attachments', updatedAttachment.toMap());
        final savedAttachment = updatedAttachment.copyWith(id: attachId);

        await _enqueueSyncAction(
          txn,
          entityType: 'attachment',
          entityId: attachId,
          action: 'CREATE',
          payload: savedAttachment.toMap(),
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

  Future<int> deleteTransaction(int id) async {
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

  // --- READ QUERIES WITH ATTACHMENT HYDRATION ---

  Future<List<TransactionModel>> getTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');

    List<TransactionModel> transactions = [];
    for (var map in result) {
      final transId = map['id'] as int?;
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
      final transId = map['id'] as int?;
      List<AttachmentModel> attachments = [];
      if (transId != null) {
        attachments = await getAttachments(transId);
      }
      transactions.add(TransactionModel.fromMap(map, attachments: attachments));
    }

    return transactions;
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

  // --- ATTACHMENT MANAGEMENT FUNCTIONS ---

  Future<int> insertAttachment(AttachmentModel attachment) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      final id = await txn.insert('attachments', attachment.toMap());
      final savedAttachment = attachment.copyWith(id: id);

      await _enqueueSyncAction(
        txn,
        entityType: 'attachment',
        entityId: id,
        action: 'CREATE',
        payload: savedAttachment.toMap(),
      );

      return id;
    });
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

  Future<int> updateAttachmentSyncStatus({
    required int id,
    required String cloudUrl,
    required String cloudThumbnailUrl,
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

  Future<int> deleteAttachment(int id) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      final rows = await txn.update(
        'attachments',
        {'is_deleted': 1, 'is_synced': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );

      await _enqueueSyncAction(
        txn,
        entityType: 'attachment',
        entityId: id,
        action: 'DELETE',
      );

      return rows;
    });
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

  Future<int> insertMessage(MessageModel message) async {
    final db = await instance.database;
    return await db.insert('messages', message.toMap());
  }

  Future<List<MessageModel>> getMessages() async {
    final db = await instance.database;
    final result = await db.query('messages', orderBy: 'created_at ASC');
    return result.map((map) => MessageModel.fromMap(map)).toList();
  }

  // --- GENERIC SYNC QUEUE HELPER ---

  Future<void> _enqueueSyncAction(
    DatabaseExecutor txn, {
    String entityType = 'transaction',
    required int entityId,
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
        await txn.delete(
          'sync_queue',
          where: 'id = ?',
          whereArgs: [existingId],
        );
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


  // --- CATEGORY CRUD OPERATIONS ---

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
      entityId: id,
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
      entityId: id,
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
      entityId: id,
      action: 'DELETE',
    );
    return rows;
  });
}

Future<void> seedInitialCategories(List<Map<String, dynamic>> defaultCategories) async {
  final db = await instance.database;
  final batch = db.batch();
  for (var category in defaultCategories) {
    batch.insert(
      'categories',
      category,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
  await batch.commit(noResult: true);
}
}