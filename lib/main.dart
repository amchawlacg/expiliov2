import 'dart:io';
import 'package:flutter/foundation.dart'; // Adds kIsWeb check
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // Web SQLite support

import 'database/database_helper.dart';
import 'screens/main_screen.dart';
import 'screens/transaction_list_screen.dart';
import 'services/sync_service.dart'; // Added SyncService import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up the correct SQLite factory depending on platform
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize SQLite Database
  await DatabaseHelper.instance.database;

  // Initialize and run SyncService
  final syncService = SyncService();
  syncService.initializeAutoSync(); // Starts listening for network reconnections
  await syncService.processSyncQueue(); // Initial sync run on startup

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
    );
  }
}