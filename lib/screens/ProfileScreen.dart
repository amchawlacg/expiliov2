import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Identity & Account
  String userFullName = "Aman Chawla";
  String userEmail = "aman@example.com";
  String userPhone = "+91 98765 43210";
  String accountId = "EXP-984210";
  String planTier = "Pro";

  // Preferences & App Experience
  String baseCurrency = "USD (\$)";
  String selectedTheme = "System Default";
  bool isBiometricEnabled = true;
  bool isDailyReminderEnabled = true;
  TimeOfDay reminderTime = const TimeOfDay(hour: 21, minute: 0);

  // Sync & Storage
  double storageUsedMB = 42.5;
  double storageLimitMB = 500.0;
  String lastSyncedText = "2 mins ago";
  bool isSyncing = false;
  bool syncWifiOnly = true;

  // Hover states
  String? _hoveredKey;
  bool _isBackHovered = false;
  bool _isSignOutHovered = false;
  bool _isSyncNowHovered = false;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: context.colors.purple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _triggerManualSync() async {
    setState(() => isSyncing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      isSyncing = false;
      lastSyncedText = "Just now";
    });
    _showSnackBar("Sync completed successfully.");
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...options.map((option) {
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
                              color: isSelected
                                  ? colors.purple
                                  : colors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check, color: colors.purple, size: 18),
                        ],
                      ),
                    ),
                  );
                }),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 16),
              _buildProfileCard(),
              const SizedBox(height: 20),

              // Card 1: Preferences
              _buildSectionHeader("Preferences"),
              _buildCardContainer([
                _buildSettingTile(
                  keyId: "currency",
                  icon: Icons.currency_exchange_rounded,
                  title: "Base Currency",
                  trailingText: baseCurrency,
                  onTap: () {
                    _openSelectionSheet(
                      title: "Select Base Currency",
                      options: ["USD (\$)", "EUR (€)", "GBP (£)", "INR (₹)", "CAD (\$)"],
                      currentValue: baseCurrency,
                      onSelected: (val) => setState(() => baseCurrency = val),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "theme",
                  icon: Icons.palette_outlined,
                  title: "App Theme",
                  trailingText: selectedTheme,
                  onTap: () {
                    _openSelectionSheet(
                      title: "Select App Theme",
                      options: ["System Default", "Light", "Dark"],
                      currentValue: selectedTheme,
                      onSelected: (val) => setState(() => selectedTheme = val),
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
                _buildSyncStatusTile(),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.wifi_rounded,
                  title: "Sync Over Wi-Fi Only",
                  value: syncWifiOnly,
                  onChanged: (val) => setState(() => syncWifiOnly = val),
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "clear_cache",
                  icon: Icons.cleaning_services_outlined,
                  title: "Clear Local Image Cache",
                  trailingText: "Frees device space",
                  onTap: () => _showSnackBar("Local image cache cleared."),
                ),
              ]),

              const SizedBox(height: 20),

              // Card 3: Security & Data Management
              _buildSectionHeader("Security & Data"),
              _buildCardContainer([
                _buildSwitchTile(
                  icon: Icons.fingerprint_rounded,
                  title: "Biometric App Lock",
                  value: isBiometricEnabled,
                  onChanged: (val) => setState(() => isBiometricEnabled = val),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: "Daily Expense Reminder",
                  subtitle: isDailyReminderEnabled
                      ? "Remind at ${reminderTime.format(context)}"
                      : null,
                  value: isDailyReminderEnabled,
                  onChanged: (val) => setState(() => isDailyReminderEnabled = val),
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "export_csv",
                  icon: Icons.file_download_outlined,
                  title: "Export Data (CSV / Excel)",
                  trailingIcon: Icons.chevron_right_rounded,
                  onTap: () => _showSnackBar("Exporting transaction records..."),
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "backup_db",
                  icon: Icons.storage_rounded,
                  title: "Backup & Restore Database",
                  trailingIcon: Icons.chevron_right_rounded,
                  onTap: () => _showSnackBar("Generating SQLite backup..."),
                ),
              ]),

              const SizedBox(height: 20),

              // Card 4: Support & Legal
              _buildSectionHeader("Support & About"),
              _buildCardContainer([
                _buildSettingTile(
                  keyId: "feedback",
                  icon: Icons.help_outline_rounded,
                  title: "Help & Feedback",
                  trailingIcon: Icons.chevron_right_rounded,
                  onTap: () {},
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "privacy",
                  icon: Icons.privacy_tip_outlined,
                  title: "Privacy Policy",
                  trailingIcon: Icons.chevron_right_rounded,
                  onTap: () {},
                ),
                _buildDivider(),
                _buildSettingTile(
                  keyId: "version",
                  icon: Icons.info_outline_rounded,
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

  Widget _buildTopBar() {
    final colors = context.colors;
    return Row(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isBackHovered = true),
          onExit: (_) => setState(() => _isBackHovered = false),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isBackHovered
                    ? colors.cardLight
                    : colors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back, size: 20, color: colors.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          "Profile & Settings",
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final colors = context.colors;
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
                  color: colors.purple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.purple, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    userFullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                    style: TextStyle(
                      color: colors.purple,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.purple,
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.cardLight,
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
                    _showSnackBar("Account ID copied to clipboard.");
                  },
                  child: Icon(Icons.copy_rounded, size: 16, color: colors.purple),
                ),
              ],
            ),
          ),
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

  Widget _buildSettingTile({
    required String keyId,
    required IconData icon,
    required String title,
    String? trailingText,
    IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    final colors = context.colors;
    final isHovered = _hoveredKey == keyId;

    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hoveredKey = keyId),
      onExit: (_) => setState(() => _hoveredKey = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            // Matches RGB to eliminate dark midpoint transition flashes
            color: isHovered && onTap != null
                ? colors.cardLight.withValues(alpha: 0.5)
                : colors.cardLight.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.textPrimary),
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
  required IconData icon,
  required String title,
  String? subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final colors = context.colors;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: 20, color: colors.textPrimary),
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
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Compact Toggle with identical thumb size & no hover background
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              width: 40,
              height: 24,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: value ? colors.purple : colors.cardLight,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
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
                  Icon(Icons.cloud_outlined, size: 20, color: colors.textPrimary),
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
              valueColor: AlwaysStoppedAnimation<Color>(colors.purple),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildSyncStatusTile() {
  final colors = context.colors;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.sync_rounded, size: 20, color: colors.textPrimary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cloud Database Sync",
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Last: $lastSyncedText",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        isSyncing
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.purple),
                ),
              )
            : MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isSyncNowHovered = true),
                onExit: (_) => setState(() => _isSyncNowHovered = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _triggerManualSync,
                  child: Text(
                    "Sync Now",
                    style: TextStyle(
                      color: _isSyncNowHovered
                          ? colors.purpleLight
                          : colors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
      ],
    ),
  );
}
 Widget _buildDestructiveActions() {
  final colors = context.colors;

  return Column(
    children: [
      // Sign Out Button
      SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: Colors.transparent,
            overlayColor: Colors.transparent, // kills hover/pressed splash
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: Icon(Icons.logout_rounded, size: 18, color: colors.red),
          label: Text(
            "Sign Out",
            style: TextStyle(
              color: colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () => _showSnackBar("Signed out."),
        ),
      ),
      const SizedBox(height: 10),

      // Delete Account
      SizedBox(
        width: double.infinity,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
            backgroundColor: Colors.transparent,
            overlayColor: Colors.transparent, // kills hover/pressed splash
            shadowColor: Colors.transparent,
          ),
          onPressed: () {},
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
    ],
  );
}
}