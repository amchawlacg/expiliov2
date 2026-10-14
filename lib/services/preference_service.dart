import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global notifier that any widget (like MaterialApp) can listen to.
final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

class PreferencesService {
  static const String _themeKey = 'selected_app_theme';
  static const String _keySyncWifiOnly = 'sync_wifi_only';

  static const String _keyDailyReminderEnabled = 'daily_reminder_enabled';
  static const String _keyReminderHour = 'reminder_hour';
  static const String _keyReminderMinute = 'reminder_minute';

  static const String _keyLastSyncedAt = 'last_synced_at';

  /// Converts a theme string representation to Flutter's ThemeMode enum.
  static ThemeMode stringToThemeMode(String theme) {
    switch (theme) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Converts a ThemeMode enum back to a user-friendly string.
  static String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  /// Saves the theme string to persistent storage and updates the global notifier.
  static Future<void> saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);

    // Update the live notifier immediately
    appThemeNotifier.value = stringToThemeMode(theme);
  }

  /// Retrieves the saved theme string from storage.
  static Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'System Default';
  }

  /// Initializes the appThemeNotifier from disk during app launch.
  static Future<void> initTheme() async {
    final savedTheme = await getTheme();
    appThemeNotifier.value = stringToThemeMode(savedTheme);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clears all saved key-value pairs
  }

  

static Future<bool> getSyncWifiOnly() async {
  final prefs = await SharedPreferences.getInstance();
  // Default to true (safe default to conserve cellular data)
  return prefs.getBool(_keySyncWifiOnly) ?? true;
}

static Future<void> setSyncWifiOnly(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keySyncWifiOnly, value);
}



// Toggle state
  static Future<void> setDailyReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDailyReminderEnabled, enabled);
  }

  static Future<bool> getDailyReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDailyReminderEnabled) ?? true;
  }

  // Reminder time
  static Future<void> saveReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderHour, hour);
    await prefs.setInt(_keyReminderMinute, minute);
  }

  static Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_keyReminderHour) ?? 21; // Default: 9 PM
    final minute = prefs.getInt(_keyReminderMinute) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static Future<void> saveLastSyncedAt(int epochMillis) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_keyLastSyncedAt, epochMillis);
}

static Future<int?> getLastSyncedAt() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_keyLastSyncedAt);
}

static Future<void> setBaseCurrency(String currency) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('base_currency', currency);
}

static Future<String> getBaseCurrency() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('base_currency') ?? 'USD (\$)';
}

static Future<void> setBiometricEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('biometric_enabled', enabled);
}

static Future<bool> getBiometricEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('biometric_enabled') ?? false;
}


static Future<String> getBaseCurrencySymbol() async {
  final base = await getBaseCurrency(); // e.g. "USD ($)" or "EUR (€)"
  final match = RegExp(r'\((.*?)\)').firstMatch(base);
  if (match != null && match.group(1) != null) {
    return match.group(1)!; // Returns "$", "₹", "€", etc.
  }
  // Fallback: If only a 3-letter code was saved like "USD", return that with a space
  return base.split(' ').first;
}
}
