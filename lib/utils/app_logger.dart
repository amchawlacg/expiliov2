import 'package:flutter/foundation.dart';

/// Prints logs only in debug mode; completely silent in production/release builds
void appLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}