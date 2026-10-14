import 'dart:io' show Platform;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'constants/app_colors.dart';
import 'database/database_helper.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'services/preference_service.dart';
import 'services/sync_service.dart';

/// -------------------------------------------------------------
/// DEV TESTING HELPER:
/// Completely resets local storage, stops sync listeners, and signs out of Firebase.
/// -------------------------------------------------------------
Future<void> devResetAllAppData() async {
  debugPrint('🧹 [DEV RESET] Starting full app wipe...');

  try {
    await SyncService().stopAndReset();
  } catch (e) {
    debugPrint('⚠️ [DEV RESET] Sync service reset error: $e');
  }

  try {
    final googleSignIn = GoogleSignIn();
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    debugPrint('⚠️ [DEV RESET] Auth sign-out error: $e');
  }

  try {
    await PreferencesService.saveLastSyncedAt(0);
  } catch (_) {}

  try {
    await DatabaseHelper.instance.deleteEntireDatabase();
  } catch (e) {
    debugPrint('⚠️ [DEV RESET] Database delete error: $e');
  }

  debugPrint('✅ [DEV RESET] Reset complete. Restart or sign in again.');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PreferencesService.initTheme();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  // -------------------------------------------------------------
  // ⚠️ DEV ONLY: Uncomment to wipe state
  //await devResetAllAppData();
  // -------------------------------------------------------------

  await DatabaseHelper.instance.database;

  final syncService = SyncService();
  if (!kIsWeb) {
    syncService.initializeAutoSync();
  }

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
              PointerDeviceKind.unknown,
            },
          ),
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColorScheme.light.background,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            extensions: const [AppColorScheme.light],
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColorScheme.dark.background,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            extensions: const [AppColorScheme.dark],
          ),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: SizedBox.shrink(),
                );
              }

              // If signed in, render MainScreen directly
              if (snapshot.hasData && snapshot.data != null) {
                return const MainScreen();
              }

              // Otherwise, render AuthScreen
              return const AuthScreen();
            },
          ),
        );
      },
    );
  }
}