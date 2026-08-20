import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'constants/app_colors.dart';
import 'database/database_helper.dart';
import 'screens/main_screen.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize SQLite Database Engine
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  // 2. Open SQLite Database
  await DatabaseHelper.instance.database;

  // 3. Initialize SyncService safely
  final syncService = SyncService();

  if (!kIsWeb) {
    syncService.initializeAutoSync();
  }

  // Initial sync attempt
  try {
    await syncService.processSyncQueue();
  } catch (e) {
    debugPrint('Initial sync skipped/failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Automatically follows system dark/light mode
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColorScheme.light.background,
        extensions: const [AppColorScheme.light],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColorScheme.dark.background,
        extensions: const [AppColorScheme.dark],
      ),
      home: const MainScreen(),
    );
  }
}