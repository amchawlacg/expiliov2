import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/attachment_service.dart';
import 'auth_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

import '../services/preference_service.dart';
import '../widgets/app_alert_dialog.dart';
import '../constants/currency_constants.dart';

// Import at top:
import '../services/export_service.dart';

import '../widgets/app_snackbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  // Identity & Account (Loaded dynamically)
  String userFullName = "User";
  String userEmail = "";
  String userPhone = "";
  String accountId = "---";
  String planTier = "Free";
  String? photoUrl;

  // Preferences & App Experience
  String baseCurrency = CurrencyConstants.supportedCurrencies.first;
  String selectedTheme = "System Default";
  bool isBiometricEnabled = true;
  bool isDailyReminderEnabled = true;
  TimeOfDay reminderTime = const TimeOfDay(hour: 21, minute: 0);

  // Sync & Storage
  double storageUsedMB = 42.5;
  double storageLimitMB = 500.0;
  String lastSyncedText = "Just now";
  bool isSyncing = false;
  bool syncWifiOnly = true;

  // Hover states
  String? _hoveredKey;
  bool _isSignOutHovered = false; // <-- ADD THIS LINE
  bool _isInitialLoadDone = false;

  // State variables inside your State class
  TimePickerEntryMode _timeEntryMode = TimePickerEntryMode.dial;
  bool _isModeToggleHovered = false;
  bool _isDeleteAccountHovered = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    AttachmentService.onAttachmentsChanged.addListener(_onAttachmentsChanged);
  }

  @override
  void dispose() {
    AttachmentService.onAttachmentsChanged.removeListener(
      _onAttachmentsChanged,
    );
    super.dispose();
  }

  void _onAttachmentsChanged() {
    // Reload profile/storage when attachments are added, deleted, or cleared
    _loadUserProfile();
  }

  void _selectField(TextEditingController controller) {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  String _formatSyncTime(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;

    // Format hour & minute (12-hour format)
    final hourOfPeriod = dt.hour == 0
        ? 12
        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timeString = '$hourOfPeriod:$minute $period';

    if (isToday) {
      return timeString; // e.g. "5:15 PM"
    } else {
      // e.g. "Oct 2, 5:15 PM"
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, $timeString';
    }
  }

  String _formatCurrencyLabel(String code) {
    final symbol = CurrencyConstants.getSymbol(code);
    return symbol.isNotEmpty ? '$code ($symbol)' : code;
  }

  Future<void> _loadUserProfile() async {
    // 1. Load saved preferences from SharedPreferences
    final savedTheme = await PreferencesService.getTheme();
    final savedSyncWifi = await PreferencesService.getSyncWifiOnly();
    final savedReminderEnabled =
        await PreferencesService.getDailyReminderEnabled();
    final savedReminderTime = await PreferencesService.getReminderTime();

    // Load saved sync timestamp & format it
    final savedSyncTimestamp = await PreferencesService.getLastSyncedAt();
    final formattedSync = savedSyncTimestamp != null
        ? _formatSyncTime(
            DateTime.fromMillisecondsSinceEpoch(savedSyncTimestamp),
          )
        : "Never";

    // 2. Try local SQLite session first (instant & offline)
    final localSession = await DatabaseHelper.instance.getActiveUserSession();

    // 3. Check live Firebase Auth as fallback/enhancement
    final firebaseUser = FirebaseAuth.instance.currentUser;

    final savedCurrency = await PreferencesService.getBaseCurrency();
    // Extracts clean code (e.g., "USD" from legacy "USD ($)"), falling back to first supported
    final cleanCurrency = savedCurrency.isNotEmpty
        ? savedCurrency.split(' ').first.trim()
        : CurrencyConstants.supportedCurrencies.first;
    final savedBiometrics = await PreferencesService.getBiometricEnabled();

    if (!mounted) return;

    setState(() {
      baseCurrency = cleanCurrency;
      isBiometricEnabled = savedBiometrics;
      selectedTheme = savedTheme;
      syncWifiOnly = savedSyncWifi;
      isDailyReminderEnabled = savedReminderEnabled;
      reminderTime = savedReminderTime;
      lastSyncedText = formattedSync; // <-- Updates the sync tile text
      userEmail = localSession?['email'] ?? firebaseUser?.email ?? "No Email";
      userFullName =
          localSession?['display_name'] ??
          firebaseUser?.displayName ??
          (userEmail.contains('@') ? userEmail.split('@').first : "User");
      photoUrl = localSession?['photo_url'] ?? firebaseUser?.photoURL;

      // Load dynamic storage values from SQLite session
      if (localSession != null) {
        storageUsedMB =
            (localSession['storage_used_mb'] as num?)?.toDouble() ?? 0.0;
        storageLimitMB =
            (localSession['storage_limit_mb'] as num?)?.toDouble() ?? 500.0;
      }

      final rawUid = localSession?['id'] ?? firebaseUser?.uid ?? "";
      accountId = rawUid.isNotEmpty
          ? (rawUid.length > 8
                ? "EXP-${rawUid.substring(0, 8).toUpperCase()}"
                : "EXP-$rawUid")
          : "EXP-LOCAL";

      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isInitialLoadDone = true);
      }
    });
  }

Future<void> _handleSignOut() async {
  final confirm = await AppAlertDialog.show(
    context,
    title: "Sign Out",
    message:
        "Are you sure you want to sign out? Your offline data will remain on this device.",
    confirmText: "Sign Out",
    cancelText: "Cancel",
    isDestructive: true,
  );

  if (confirm != true) return;

  // 1. Pop any modal dialogs or sub-screens if needed so you're on the root route
  Navigator.of(context).popUntil((route) => route.isFirst);

  // 2. Sign out - StreamBuilder will automatically swap MainScreen for AuthScreen
  await _authService.signOut();
}

  Future<void> _handleDeleteAccount() async {
    final confirm = await AppAlertDialog.show(
      context,
      title: "Delete Account & Data?",
      message:
          "This will permanently delete your account, local records, and synced backups. This action cannot be undone.",
      confirmText: "Delete Account",
      cancelText: "Cancel",
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      // 1. Delete Firebase Auth user FIRST
      // If the session is stale, Firebase throws 'requires-recent-login' here
      // BEFORE any local data or files get wiped.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
      }

      // 2. Stop background sync so it doesn't try to access the DB while deleting
      await SyncService().stopAndReset();

      // 3. Clear cached attachment image/PDF files from device storage
      await AttachmentService().clearAllLocalFiles();

      // 4. Delete the entire local SQLite database file
      await DatabaseHelper.instance.deleteEntireDatabase();

      // 5. Clear all preferences / stored settings
      await PreferencesService.clearAll();

      // 6. Navigate to login / auth screen
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'requires-recent-login') {
        context.showSnackBar(
          "For security, please sign out and sign back in before deleting your account.",
          type: SnackBarType.error,
        );
      } else {
        context.showSnackBar(
          e.message ?? "Failed to delete account.",
          type: SnackBarType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      context.showSnackBar(
        "An error occurred while deleting your account.",
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _selectReminderTime(BuildContext context) async {
    final colors = context.colors;

    int hour = reminderTime.hourOfPeriod == 0 ? 12 : reminderTime.hourOfPeriod;
    int minute = reminderTime.minute;
    DayPeriod period = reminderTime.period;
    bool isDialMode = true;
    bool selectingHour = true;
    bool isToggleHovered = false;
    bool isCancelHovered = false;
    bool isOkHovered = false;

    final TextEditingController hourController = TextEditingController(
      text: hour.toString().padLeft(2, '0'),
    );
    final TextEditingController minuteController = TextEditingController(
      text: minute.toString().padLeft(2, '0'),
    );

    final picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Dialog(
              backgroundColor: colors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select time",
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Digits & AM/PM Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hour Display / Input
                        GestureDetector(
                          onTap: () => setModal(() => selectingHour = true),
                          child: Container(
                            width: 68,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selectingHour
                                  ? colors.hero
                                  : colors.cardLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selectingHour
                                    ? colors.hero
                                    : colors.hero.withValues(alpha: 0),
                                width: 1.5,
                              ),
                            ),
                            child: isDialMode
                                ? Text(
                                    hour.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      color: selectingHour
                                          ? colors.secondary
                                          : colors.textPrimary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : TextField(
                                    controller: hourController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    cursorColor: selectingHour
                                        ? colors.secondary
                                        : colors.hero,
                                    onTap: () {
                                      setModal(() => selectingHour = true);
                                      _selectField(
                                        hourController,
                                      ); // Auto-selects so you don't need backspace
                                    },
                                    style: TextStyle(
                                      color: selectingHour
                                          ? colors.secondary
                                          : colors.textPrimary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      _ClampingRangeFormatter(min: 1, max: 12),
                                    ],
                                    onChanged: (val) {
                                      final p = int.tryParse(val);
                                      if (p != null && p >= 1 && p <= 12) {
                                        hour = p;
                                      }
                                    },
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            ":",
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Minute Display / Input
                        GestureDetector(
                          onTap: () => setModal(() => selectingHour = false),
                          child: Container(
                            width: 68,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !selectingHour
                                  ? colors.hero
                                  : colors.cardLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: !selectingHour
                                    ? colors.hero
                                    : colors.hero.withValues(alpha: 0),
                                width: 1.5,
                              ),
                            ),
                            child: isDialMode
                                ? Text(
                                    minute.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      color: !selectingHour
                                          ? colors.secondary
                                          : colors.textPrimary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : TextField(
                                    controller: minuteController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    cursorColor: !selectingHour
                                        ? colors.secondary
                                        : colors.hero,
                                    onTap: () {
                                      setModal(() => selectingHour = false);
                                      _selectField(
                                        minuteController,
                                      ); // Auto-selects so you don't need backspace
                                    },
                                    style: TextStyle(
                                      color: !selectingHour
                                          ? colors.secondary
                                          : colors.textPrimary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      _ClampingRangeFormatter(min: 0, max: 59),
                                    ],
                                    onChanged: (val) {
                                      final p = int.tryParse(val);
                                      if (p != null && p >= 0 && p <= 59) {
                                        minute = p;
                                      }
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // AM / PM Column
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setModal(() => period = DayPeriod.am),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: period == DayPeriod.am
                                      ? colors.hero
                                      : colors.cardLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "AM",
                                  style: TextStyle(
                                    color: period == DayPeriod.am
                                        ? Colors.white
                                        : colors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () =>
                                  setModal(() => period = DayPeriod.pm),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: period == DayPeriod.pm
                                      ? colors.hero
                                      : colors.cardLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "PM",
                                  style: TextStyle(
                                    color: period == DayPeriod.pm
                                        ? Colors.white
                                        : colors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Dial View (interactive circular clock face)
                    if (isDialMode) ...[
                      Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const double dialSize = 220;
                            final double center = dialSize / 2;
                            final double radius = center - 24;

                            final int currentValue = selectingHour
                                ? hour
                                : minute;
                            final double currentAngle = selectingHour
                                ? (hour % 12) * (2 * math.pi / 12) -
                                      (math.pi / 2)
                                : minute * (2 * math.pi / 60) - (math.pi / 2);

                            void updateFromPosition(Offset localPos) {
                              final dx = localPos.dx - center;
                              final dy = localPos.dy - center;
                              double angle = math.atan2(dy, dx) + (math.pi / 2);
                              if (angle < 0) angle += 2 * math.pi;

                              if (selectingHour) {
                                int h = (angle / (2 * math.pi / 12)).round();
                                if (h == 0) h = 12;
                                setModal(() {
                                  hour = h;
                                  hourController.text = h.toString().padLeft(
                                    2,
                                    '0',
                                  );
                                });
                              } else {
                                int m = (angle / (2 * math.pi / 60)).round();
                                if (m == 60) m = 0;
                                setModal(() {
                                  minute = m;
                                  minuteController.text = m.toString().padLeft(
                                    2,
                                    '0',
                                  );
                                });
                              }
                            }

                            return GestureDetector(
                              onPanUpdate: (d) =>
                                  updateFromPosition(d.localPosition),
                              onTapDown: (d) =>
                                  updateFromPosition(d.localPosition),
                              child: Container(
                                width: dialSize,
                                height: dialSize,
                                decoration: BoxDecoration(
                                  color: colors.cardLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Stack(
                                  children: [
                                    // Pointer Hand & Selected Circle Indicator
                                    CustomPaint(
                                      size: const Size(dialSize, dialSize),
                                      painter: _ClockHandPainter(
                                        center: Offset(center, center),
                                        angle: currentAngle,
                                        radius: radius,
                                        handColor: colors.hero,
                                      ),
                                    ),
                                    // Dial Numbers
                                    ...List.generate(12, (index) {
                                      final int numVal = selectingHour
                                          ? (index == 0 ? 12 : index)
                                          : index * 5;
                                      final double itemAngle =
                                          (index * (2 * math.pi / 12)) -
                                          (math.pi / 2);
                                      final double x =
                                          center +
                                          radius * math.cos(itemAngle) -
                                          14;
                                      final double y =
                                          center +
                                          radius * math.sin(itemAngle) -
                                          14;
                                      final bool isSelected = selectingHour
                                          ? (hour % 12 == (numVal % 12))
                                          : (minute ~/ 5 == index);

                                      return Positioned(
                                        left: x,
                                        top: y,
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: Center(
                                            child: Text(
                                              selectingHour
                                                  ? "$numVal"
                                                  : numVal.toString().padLeft(
                                                      2,
                                                      '0',
                                                    ),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? colors.hero
                                                    : colors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action Row: Custom SVG button on left, Cancel / OK on right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Toggle Icon Button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setModal(() => isToggleHovered = true),
                          onExit: (_) =>
                              setModal(() => isToggleHovered = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setModal(() {
                                isDialMode = !isDialMode;
                                hourController.text = hour.toString().padLeft(
                                  2,
                                  '0',
                                );
                                minuteController.text = minute
                                    .toString()
                                    .padLeft(2, '0');
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isToggleHovered
                                    ? colors.cardLight
                                    : colors.cardLight.withValues(alpha: 0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: SvgPicture.asset(
                                isDialMode
                                    ? 'assets/icons/components/keyboard.svg'
                                    : 'assets/icons/components/clock.svg',
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  colors.textPrimary,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Cancel & OK Buttons
                        Row(
                          children: [
                            // Cancel Button
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setModal(() => isCancelHovered = true),
                              onExit: (_) =>
                                  setModal(() => isCancelHovered = false),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Navigator.pop(dialogCtx),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCancelHovered
                                        ? colors.cardLight
                                        : colors.cardLight.withValues(alpha: 0),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // OK Button
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setModal(() => isOkHovered = true),
                              onExit: (_) =>
                                  setModal(() => isOkHovered = false),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  int finalHour = hour % 12;
                                  if (period == DayPeriod.pm) {
                                    finalHour += 12;
                                  }
                                  Navigator.pop(
                                    dialogCtx,
                                    TimeOfDay(hour: finalHour, minute: minute),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isOkHovered
                                        ? colors.heroShadow
                                        : colors.heroShadow.withValues(
                                            alpha: 0,
                                          ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    "OK",
                                    style: TextStyle(
                                      color: colors.hero,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null && picked != reminderTime) {
      setState(() => reminderTime = picked);
      await PreferencesService.saveReminderTime(picked.hour, picked.minute);

      if (!mounted) return;
      context.showSnackBar(
        "Reminder set for ${picked.format(context)}",
        type: SnackBarType.success,
      );
    }
  }

  Future<void> _triggerManualSync() async {
    if (isSyncing) return;

    setState(() => isSyncing = true);

    try {
      final result = await SyncService().processSyncQueue(force: false);

      if (!mounted) return;

      final bool isSuccess = result['success'] == true;

      if (isSuccess) {
        final now = DateTime.now();
        setState(() {
          lastSyncedText = _formatSyncTime(now);
        });
        // Also recalculate storage to ensure UI shows latest cloud/local footprint
        await AttachmentService().recalculateAndPersistStorageUsed();
        await _loadUserProfile();
      }

      if (!mounted) return;
      context.showSnackBar(
        result['message'] as String? ?? "Sync process finished.",
        type: isSuccess ? SnackBarType.success : SnackBarType.info,
      );
    } catch (_) {
      if (mounted) {
        context.showSnackBar(
          "Failed to complete sync.",
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  void _openSelectionSheet({
    required String title,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) {
    final colors = context.colors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 👈 1. Allows bottom sheet to expand up to its height constraint
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // 👈 2. Makes list scrollable and caps height to 45% of the screen
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = currentValue == option;

                      return InkWell(
                        onTap: () {
                          onSelected(option);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                option,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check,
                                  color: colors.textPrimary,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(),
              const SizedBox(height: 20),

              // Card 1: Preferences
              _buildSectionHeader("Preferences"),
              _buildCardContainer([
                _buildSettingTile(
                  keyId: "currency",
                  svgAsset: "assets/profile/currency.svg",
                  title: "Base Currency",
                  trailingText: _formatCurrencyLabel(baseCurrency),
                  onTap: () {
                    _openSelectionSheet(
                      title: "Select Base Currency",
                      options: CurrencyConstants.supportedCurrencies
                          .map((code) => _formatCurrencyLabel(code))
                          .toList(),
                      currentValue: _formatCurrencyLabel(baseCurrency),
                      onSelected: (val) async {
  final code = val.split(' ').first.trim();
  setState(() => baseCurrency = code);
  await PreferencesService.setBaseCurrency(code);

  // 🔔 Notify all screens (Insights, Transactions, etc.) to reload currency
  SyncService.onDataChanged.notifyListeners();
},
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "theme",
                  svgAsset: "assets/profile/theme.svg",
                  title: "App Theme",
                  trailingText: selectedTheme,
                  onTap: () {
                    _openSelectionSheet(
                      title: "Select App Theme",
                      options: ["System Default", "Light", "Dark"],
                      currentValue: selectedTheme,
                      onSelected: (val) async {
                        setState(() => selectedTheme = val);

                        // 1. Persist to device storage
                        await PreferencesService.saveTheme(val);

                        // 2. Broadcast change to appThemeNotifier so the whole app updates
                        switch (val) {
                          case 'Light':
                            appThemeNotifier.value = ThemeMode.light;
                            break;
                          case 'Dark':
                            appThemeNotifier.value = ThemeMode.dark;
                            break;
                          default:
                            appThemeNotifier.value = ThemeMode.system;
                            break;
                        }
                      },
                    );
                  },
                ),
              ]),
              const SizedBox(height: 20),

              // Card 2: Cloud Sync & Storage
              _buildSectionHeader("Sync & Storage"),
              _buildCardContainer([
                _buildStorageProgressTile(),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "cloud_sync",
                  svgAsset: "assets/profile/sync.svg",
                  title: "Cloud Database Sync",
                  trailingText: lastSyncedText,
                  trailingIcon: Icons.chevron_right_rounded,
                  onTap: isSyncing ? null : _triggerManualSync,
                ),
                _buildDivider(),
                _buildSwitchTile(
                  svgAsset: "assets/profile/wifi.svg",
                  title: "Sync Over Wi-Fi Only",
                  value: syncWifiOnly,
                  onChanged: (val) async {
                    setState(() => syncWifiOnly = val);
                    await PreferencesService.setSyncWifiOnly(val);
                  },
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "clear_cache",
                  svgAsset: "assets/profile/cache.svg",
                  title: "Clear Local Image Cache",
                  trailingText: "Frees device space",
                  onTap: () async {
                    await AttachmentService().clearImageCacheOnly();
                    if (!mounted) return;
                    // Image cache cleared:
                    context.showSnackBar(
                      "Local image cache cleared.",
                      type: SnackBarType.success,
                    );
                  },
                ),
              ]),

              const SizedBox(height: 20),

              // Card 3: Security & Data Management
              _buildSectionHeader("Security & Data"),
              _buildCardContainer([
                _buildSwitchTile(
                  svgAsset: "assets/profile/fingerprint.svg",
                  title: "Biometric App Lock",
                  value: isBiometricEnabled,
                  onChanged: (val) async {
                    setState(() => isBiometricEnabled = val);
                    await PreferencesService.setBiometricEnabled(val);
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  svgAsset: "assets/profile/notification.svg",
                  title: "Daily Expense Reminder",
                  subtitle: isDailyReminderEnabled
                      ? "Remind at ${reminderTime.format(context)} (Tap to edit)"
                      : null,
                  onSubtitleTap: isDailyReminderEnabled
                      ? () => _selectReminderTime(context)
                      : null,
                  value: isDailyReminderEnabled,
                  onChanged: (val) async {
                    setState(() => isDailyReminderEnabled = val);
                    await PreferencesService.setDailyReminderEnabled(val);

                    // Optional: cancel or schedule the notification service accordingly
                  },
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "export_csv",
                  svgAsset: "assets/profile/export.svg",
                  title: "Export to CSV (Spreadsheet)", // <-- Updated title
                  trailingIcon: Icons.chevron_right_rounded,
                  onTap:
                      _handleExportCsv, // <-- We will implement this handler next
                ),
                _buildDivider(),
                // Dedicated Danger Tile
                _buildDangerSettingTile(
                  keyId: "delete_account",
                  svgAsset: "assets/icons/components/trash.svg",
                  title: "Delete Account & Data",
                  onTap: _handleDeleteAccount,
                ),
              ]),

              const SizedBox(height: 20),

              // Card 4: Support & Legal
              _buildSectionHeader("Support & About"),
              _buildCardContainer([
                _buildSettingTile(
                  keyId: "feedback",
                  svgAsset: "assets/profile/help.svg",
                  title: "Help & Feedback",
                  trailingIcon: Icons.chevron_right_rounded,
                  onTap: () {},
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "privacy",
                 svgAsset: "assets/profile/privacy.svg",
                  title: "Privacy Policy",
                  trailingIcon: Icons.chevron_right_rounded,
                  onTap: () {},
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "version",
                  svgAsset: "assets/profile/version.svg",
                  title: "App Version",
                  trailingText: "v1.0.4 (24)",
                  onTap: null,
                ),
              ]),

              const SizedBox(height: 28),

              _buildDestructiveActions(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- Components & Builders ---

  // Reusable SVG button matching your back button style
  Widget _buildModeIconButton({
    required String assetPath,
    required VoidCallback onTap,
    required bool isHovered,
    required ValueChanged<bool> onHoverChanged,
    required BuildContext context,
  }) {
    final colors = context.colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHovered
                ? colors.cardLight
                : colors.cardLight.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: SvgPicture.asset(
            assetPath,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final colors = context.colors;
    final initials = userFullName
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  /*color: colors.purple.withValues(alpha: 0.15), aman
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.purple, width: 1.5),*/
                  color: colors.heroShadow,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.hero, width: 1.5),
                  image: photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoUrl == null
                    ? Center(
                        child: Text(
                          initials.isNotEmpty ? initials : "U",
                          style: TextStyle(
                            color: colors.hero,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userFullName,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.hero,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            planTier.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (userPhone.isNotEmpty)
                      Text(
                        userPhone,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          /*const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "Account ID: ",
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      accountId,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: accountId));
                    // Clipboard copy:
context.showSnackBar("Account ID copied to clipboard.", type: SnackBarType.info);
                  },
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: colors.purple,
                  ),
                ),
              ],
            ),
          ),
          */
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: context.colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.colors.cardLight.withValues(alpha: 0.6),
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildDangerSettingTile({
    required String keyId,
    required String svgAsset, // Changed from: required IconData icon
    required String title,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final isHovered = _hoveredKey == keyId;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredKey = keyId),
      onExit: (_) => setState(() => _hoveredKey = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          //aman
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isHovered
                ? colors.redLight
                : colors.redLight.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
    svgAsset,
    width: 20,
    height: 20,
    colorFilter: ColorFilter.mode(colors.red, BlendMode.srcIn),
  ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String keyId,
    required String svgAsset, // Changed from: required IconData icon
    required String title,
    String? trailingText,
    IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    final colors = context.colors;
    final isHovered = _hoveredKey == keyId;

    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hoveredKey = keyId),
      onExit: (_) => setState(() => _hoveredKey = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isHovered && onTap != null
                ? colors.cardLight.withValues(alpha: 0.5)
                : colors.cardLight.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                svgAsset,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  colors.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (trailingIcon != null)
                Icon(trailingIcon, size: 18, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String svgAsset,
    required String title,
    String? subtitle,
    VoidCallback? onSubtitleTap,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = context.colors;
    final animationDuration = _isInitialLoadDone
        ? const Duration(milliseconds: 180)
        : Duration.zero;
    final switchColor = _isInitialLoadDone && value
        ? colors.hero
        : (!value ? colors.cardLight : colors.hero);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SvgPicture.asset(
    svgAsset,
    width: 20,
    height: 20,
    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
  ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: onSubtitleTap,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: onSubtitleTap != null
                            ? colors.hero
                            : colors.textSecondary,
                        fontSize: 11,
                        fontWeight: onSubtitleTap != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!value),
              child: AnimatedContainer(
                duration: animationDuration,
                curve: Curves.easeInOut,
                width: 40,
                height: 24,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: switchColor,
                ),
                child: AnimatedAlign(
                  duration: animationDuration,
                  curve: Curves.easeInOut,
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? colors.card : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageProgressTile() {
    final colors = context.colors;
    final progress = (storageUsedMB / storageLimitMB).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
  'assets/profile/attachment.svg',
  width: 20,
  height: 20,
  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
),
                  const SizedBox(width: 12),
                  Text(
                    "Cloud Attachments",
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                "${storageUsedMB.toStringAsFixed(1)} MB / ${storageLimitMB.toStringAsFixed(0)} MB",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.cardLight,
              valueColor: AlwaysStoppedAnimation<Color>(colors.hero),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusTile() {
    final colors = context.colors;
    final isHovered = _hoveredKey == "cloud_sync";

    return MouseRegion(
      cursor: isSyncing ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) {
        if (!isSyncing) setState(() => _hoveredKey = "cloud_sync");
      },
      onExit: (_) => setState(() => _hoveredKey = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isSyncing ? null : _triggerManualSync,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isHovered && !isSyncing
                ? colors.cardLight.withValues(alpha: 0.5)
                : colors.cardLight.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.sync_rounded, size: 20, color: colors.textPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Cloud Database Sync",
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isSyncing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.hero),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lastSyncedText,
                      style: TextStyle(
                        color: colors.hero,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.hero.withValues(alpha: 0.8),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestructiveActions() {
    final colors = context.colors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sign Out Button (fit to content width)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isSignOutHovered = true),
            onExit: (_) => setState(() => _isSignOutHovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleSignOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  //aman sign out
                  color: _isSignOutHovered
                      ? colors.redLight
                      : colors.redLight.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: colors.red),
                    const SizedBox(width: 8),
                    Text(
                      "Sign Out",
                      style: TextStyle(
                        color: colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Delete Account & Wipe Data Button (fit to content width with hover)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isDeleteAccountHovered = true),
            onExit: (_) => setState(() => _isDeleteAccountHovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleDeleteAccount,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isDeleteAccountHovered
                      ? colors.cardLight
                      : colors.cardLight.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "Delete Account & Wipe Data",
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Inside _ProfileScreenState:
  Future<void> _handleExportCsv() async {
    context.showSnackBar(
      "Preparing transaction export...",
      type: SnackBarType.info,
    );

    final transactions = await DatabaseHelper.instance.getTransactions();

    if (!mounted) return;

    if (transactions.isEmpty) {
      context.showSnackBar(
        "No transactions found to export.",
        type: SnackBarType.info,
      );
      return;
    }

    try {
      await ExportService.exportTransactionsToCsv(
        transactions: transactions,
        context: context,
      );
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          "Failed to generate export.",
          type: SnackBarType.error,
        );
      }
    }
  }
}

class _ClockHandPainter extends CustomPainter {
  final Offset center;
  final double angle;
  final double radius;
  final Color handColor;

  _ClockHandPainter({
    required this.center,
    required this.angle,
    required this.radius,
    required this.handColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = handColor
      ..style = PaintingStyle.fill;

    final Paint linePaint = Paint()
      ..color = handColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 1. Center pivot dot
    canvas.drawCircle(center, 4, fillPaint);

    // 2. Stop the arm tip just short of the numbers
    final double pointerLength = 10.0; // Arrowhead length
    final double arrowHalfWidth = 4.5; // Arrowhead half-width at the base
    final double gapFromNumber = 18.0; // Distance short of the number's center

    final double tipRadius = radius - gapFromNumber;
    final double baseRadius = tipRadius - pointerLength;

    final Offset tipPoint = Offset(
      center.dx + tipRadius * math.cos(angle),
      center.dy + tipRadius * math.sin(angle),
    );

    final Offset basePoint = Offset(
      center.dx + baseRadius * math.cos(angle),
      center.dy + baseRadius * math.sin(angle),
    );

    // 3. Draw line from center to base of arrow
    canvas.drawLine(center, basePoint, linePaint);

    // 4. Draw pointer arrowhead pointing outward
    final double normalAngle = angle + (math.pi / 2);
    final Path arrowPath = Path()
      ..moveTo(tipPoint.dx, tipPoint.dy)
      ..lineTo(
        basePoint.dx + arrowHalfWidth * math.cos(normalAngle),
        basePoint.dy + arrowHalfWidth * math.sin(normalAngle),
      )
      ..lineTo(
        basePoint.dx - arrowHalfWidth * math.cos(normalAngle),
        basePoint.dy - arrowHalfWidth * math.sin(normalAngle),
      )
      ..close();

    canvas.drawPath(arrowPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ClockHandPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.handColor != handColor ||
        oldDelegate.radius != radius;
  }
}

class _ClampingRangeFormatter extends TextInputFormatter {
  final int min;
  final int max;

  _ClampingRangeFormatter({required this.min, required this.max});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Keep only digits
    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final int? parsed = int.tryParse(cleanText);
    if (parsed == null) return oldValue;

    // If typed value exceeds max, clamp it to max
    String clampedText = cleanText;
    if (parsed > max) {
      clampedText = max.toString();
    }

    // Enforce 2 digits max
    if (clampedText.length > 2) {
      clampedText = clampedText.substring(clampedText.length - 2);
    }

    return TextEditingValue(
      text: clampedText,
      selection: TextSelection.collapsed(offset: clampedText.length),
    );
  }
}
