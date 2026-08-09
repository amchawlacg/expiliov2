import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart';
import '../models/attachment.dart';
import '../models/message.dart';

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
      version: 5,
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
        
        date TEXT NOT NULL,
        
        source TEXT NOT NULL,
        
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future _upgradeDB(
      Database db,
      int oldVersion,
      int newVersion,
      ) async {

    if (oldVersion < 2) {

      await db.execute(
          '''
      ALTER TABLE transactions 
      ADD COLUMN payment_method TEXT
      '''
      );


      await db.execute(
          '''
      ALTER TABLE transactions 
      ADD COLUMN payment_name TEXT
      '''
      );


      await db.execute(
          '''
      ALTER TABLE transactions 
      ADD COLUMN merchant TEXT
      '''
      );

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

      await db.execute(
          '''
      ALTER TABLE transactions 
      ADD COLUMN subcategory TEXT
      '''
      );

    }

  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;

    return await db.insert(
      'transactions',
      transaction.toMap(),
    );
  }

  Future<List<TransactionModel>> getTransactions() async {
    final db = await instance.database;

    final result = await db.query(
      'transactions',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'date DESC',
    );

    return result.map((map) {
      return TransactionModel.fromMap(map);
    }).toList();
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await instance.database;

    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;

    return await db.update(
      'transactions',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertAttachment(
      AttachmentModel attachment,
      ) async {

    final db = await instance.database;


    return await db.insert(
      'attachments',
      attachment.toMap(),
    );

  }

  Future<List<AttachmentModel>> getAttachments(
      int transactionId,
      ) async {

    final db = await instance.database;


    final result = await db.query(

      'attachments',

      where:
      'transaction_id = ? AND is_deleted = ?',

      whereArgs: [
        transactionId,
        0,
      ],

      orderBy: 'created_at DESC',

    );


    return result.map((map) {

      return AttachmentModel.fromMap(
        map,
      );

    }).toList();

  }

  Future<int> deleteAttachment(
      int id,
      ) async {

    final db = await instance.database;


    return await db.update(

      'attachments',

      {

        'is_deleted': 1,

        'is_synced': 0,

        'updated_at':
        DateTime.now().toIso8601String(),

      },

      where: 'id = ?',

      whereArgs: [
        id,
      ],

    );

  }

  Future<int> insertMessage(
      MessageModel message,
      ) async {

    final db = await instance.database;


    return await db.insert(
      'messages',
      message.toMap(),
    );

  }


  Future<List<MessageModel>> getMessages() async {

    final db = await instance.database;


    final result = await db.query(

      'messages',

      orderBy: 'created_at ASC',

    );


    return result.map((map) {

      return MessageModel.fromMap(
        map,
      );

    }).toList();

  }

  // --- ADD THIS METHOD INSIDE DATABASEHELPER ---
  Future<Map<DateTime, double>> getDailyTotalsForMonth(DateTime month) async {
    final db = await instance.database;

    // Format the prefix target (e.g., "2026-06") to capture the entire month
    final String monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";

    // Query to pull the date portion and aggregate totals cleanly in SQLite
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        substr(date, 1, 10) as day_string,
        SUM(CASE WHEN LOWER(transaction_type) = 'income' THEN amount ELSE -amount END) as net_balance
      FROM transactions
      WHERE date LIKE ? AND is_deleted = 0
      GROUP BY substr(date, 1, 10)
    ''', ['$monthStr%']);

    final Map<DateTime, double> dailyBalances = {};

    for (var row in result) {
      final String? dayStr = row['day_string'] as String?;
      final double? balance = row['net_balance'] as double?;

      if (dayStr != null && balance != null) {
        final parsedDate = DateTime.parse(dayStr);
        // Normalize the key to local time at midnight for exact Map lookups
        final normalizedKey = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        dailyBalances[normalizedKey] = balance;
      }
    }

    return dailyBalances;
  }

  // 1. Get Monthly summary (Income, Expenses, Net)
  Future<Map<String, double>> getMonthlySummary(int month, int year) async {
    final db = await instance.database;
    final String monthStr = "$year-${month.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN LOWER(transaction_type) = 'income' THEN amount ELSE 0 END) as total_income,
        SUM(CASE WHEN LOWER(transaction_type) = 'expense' THEN amount ELSE 0 END) as total_expense
      FROM transactions
      WHERE date LIKE ? AND is_deleted = 0
    ''', ['$monthStr%']);

    double income = 0.0;
    double expense = 0.0;

    if (result.isNotEmpty && result.first['total_income'] != null) {
      income = (result.first['total_income'] as num).toDouble();
    }
    if (result.isNotEmpty && result.first['total_expense'] != null) {
      expense = (result.first['total_expense'] as num).toDouble();
    }

    return {
      'income': income,
      'expense': expense,
      'net': income - expense,
    };
  }

  // 2. Get Expenses grouped by Category
  Future<Map<String, double>> getCategorySummary(int month, int year) async {
    final db = await instance.database;
    final String monthStr = "$year-${month.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT category, SUM(amount) as total_amount
      FROM transactions
      WHERE date LIKE ? AND LOWER(transaction_type) = 'expense' AND is_deleted = 0
      GROUP BY category
      ORDER BY total_amount DESC
    ''', ['$monthStr%']);

    final Map<String, double> categoryMap = {};
    for (var row in result) {
      final String category = (row['category'] as String? ?? 'Uncategorized');
      final double total = (row['total_amount'] as num).toDouble();
      categoryMap[category] = total;
    }
    return categoryMap;
  }

  // 3. Get Expenses grouped by Profile (Business vs Personal)
  Future<Map<String, double>> getProfileSummary(int month, int year) async {
    final db = await instance.database;
    final String monthStr = "$year-${month.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT profile_type, SUM(amount) as total_amount
      FROM transactions
      WHERE date LIKE ? AND LOWER(transaction_type) = 'expense' AND is_deleted = 0
      GROUP BY profile_type
    ''', ['$monthStr%']);

    final Map<String, double> profileMap = {};
    for (var row in result) {
      final String profile = (row['profile_type'] as String? ?? 'Personal');
      final double total = (row['total_amount'] as num).toDouble();
      profileMap[profile] = total;
    }
    return profileMap;
  }

  Future<List<TransactionModel>> getTransactionsByDate(
      DateTime date,
      ) async {


    final db = await instance.database;


    final startDate = DateTime(
      date.year,
      date.month,
      date.day,
    );


    final endDate = startDate.add(
      const Duration(days: 1),
    );



    final result = await db.query(

      'transactions',


      where:
      'date >= ? AND date < ? AND is_deleted = ?',


      whereArgs: [

        startDate.toIso8601String(),

        endDate.toIso8601String(),

        0,

      ],


      orderBy:
      'date DESC',

    );



    return result.map((map) {

      return TransactionModel.fromMap(
        map,
      );

    }).toList();

  }
}