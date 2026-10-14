import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';
import 'add_transaction_screen.dart';
import '../widgets/transaction_card.dart';
import '../constants/app_colors.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

import '../constants/expense_categories.dart'; // Adjust path if located elsewhere, e.g., '../models/default_categories.dart'
import '../database/database_helper.dart';

import '../services/preference_service.dart'; // Adjust path if located elsewhere
import '../constants/currency_constants.dart';
import '../widgets/app_snackbar.dart';
import '../services/sync_service.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => TransactionListScreenState();
}

class TransactionListScreenState extends State<TransactionListScreen> {
  final TransactionService transactionService = TransactionService();

  List<TransactionModel> allTransactions = [];
  String selectedRange = "This Month";
  String selectedSort = "Newest First";
  String selectedTypeFilter = "All"; // "All", "Expense", "Income", "Transfer"
  String selectedProfileFilter = "All"; // "All", "Personal", "Business"
  List<String> selectedCategories = [
    "All",
  ]; // "All" or a list of category names
  double? minAmountFilter;
  double? maxAmountFilter;

  DateTime? customFromDate;
  DateTime? customToDate;

  String activeCurrencyCode = "USD";
  String activeCurrencySymbol = "\$";
  double activeCurrencyRate = 1.0;

  // Active focused date on the horizontal wheel
  DateTime activeDate = DateTime.now();

  bool _isAddButtonHovered = false; // 👈 Add it here
  bool _isRangeDropdownHovered = false;

  bool _isFilterHovered = false;
  bool _isSortHovered = false;

  static const List<String> months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  static const int baseIndex =
      12000; // 👈 Divisible by 12 so month 0 maps exactly to January

  PageController? _dayPageController;
  PageController? _monthPageController;
  PageController? _yearPageController;

  final List<String> rangeOptions = [
    "Today",
    "This Week",
    "This Month",
    "This Year",
    "All Time",
    "Custom Date",
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    loadTransactions();
    loadCurrency();

    // 🔔 Listen for remote data sync/hydration events
    SyncService.onDataChanged.addListener(_onSyncComplete);
  }

  void _onSyncComplete() {
    if (mounted) {
      loadTransactions();
      loadCurrency();
    }
  }

  void _initControllers() {
    _dayPageController?.dispose();
    _monthPageController?.dispose();
    _yearPageController?.dispose();

    _dayPageController = PageController(
      initialPage: baseIndex,
      viewportFraction: 0.22,
    );
    _monthPageController = PageController(
      initialPage: (activeDate.year * 12) + (activeDate.month - 1),
      viewportFraction: 0.22,
    );
    _yearPageController = PageController(
      initialPage: baseIndex + (activeDate.year - 2000),
      viewportFraction: 0.22,
    );
  }

  @override
  void dispose() {
    SyncService.onDataChanged.removeListener(_onSyncComplete);
    _dayPageController?.dispose();
    _monthPageController?.dispose();
    _yearPageController?.dispose();
    super.dispose();
  }

  Future<void> loadTransactions() async {
    final data = await transactionService.getTransactions();
    if (!mounted) return;
    setState(() {
      allTransactions = data;
    });
  }

  Future<void> loadCurrency() async {
    final rawCurrency = await PreferencesService.getBaseCurrency();
    final code = rawCurrency.split(' ').first.trim();

    if (code.isEmpty) return;

    // Default fallbacks from CurrencyConstants
    final defaultSymbol = CurrencyConstants.getSymbol(code);
    final defaultRate = CurrencyConstants.getDefaultExchangeRate(code);

    final db = await DatabaseHelper.instance.database;
    final currencyData = await db.query(
      'currencies',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );

    if (!mounted) return;

    if (currencyData.isNotEmpty) {
      setState(() {
        activeCurrencyCode = code;
        activeCurrencySymbol =
            currencyData.first['symbol'] as String? ?? defaultSymbol;
        // Always load the true rate to USD anchor from SQLite (EUR = 1.08, CAD = 0.73, USD = 1.0)
        activeCurrencyRate =
            (currencyData.first['rate_to_base'] as num?)?.toDouble() ?? defaultRate;
      });
    } else {
      setState(() {
        activeCurrencyCode = code;
        activeCurrencySymbol = defaultSymbol;
        activeCurrencyRate = defaultRate;
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return "DD/MM/YYYY";
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return "$d/$m/$y";
  }

  List<TransactionModel> get filteredTransactions {
    final now = DateTime.now();

    var list = allTransactions.where((t) {
      final tDate = DateTime(t.date.year, t.date.month, t.date.day);

      switch (selectedRange) {
        case "Today":
          final targetDay = DateTime(
            activeDate.year,
            activeDate.month,
            activeDate.day,
          );
          return tDate.isAtSameMomentAs(targetDay);

        case "This Week":
          final today = DateTime(now.year, now.month, now.day);
          final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
          final endOfWeek = DateTime(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day + 6,
            23,
            59,
            59,
            999,
          );
          return !tDate.isBefore(startOfWeek) && !tDate.isAfter(endOfWeek);

        case "This Month":
          return t.date.year == activeDate.year &&
              t.date.month == activeDate.month;

        case "This Year":
          return t.date.year == activeDate.year;

        case "Custom Date":
          if (customFromDate == null || customToDate == null) return true;
          final start = DateTime(
            customFromDate!.year,
            customFromDate!.month,
            customFromDate!.day,
          );
          final end = DateTime(
            customToDate!.year,
            customToDate!.month,
            customToDate!.day,
            23,
            59,
            59,
            999,
          );
          return !tDate.isBefore(start) && !tDate.isAfter(end);

        case "All Time":
        default:
          return true;
      }
    }).toList();

    // Type Filter
    if (selectedTypeFilter != "All") {
      list = list
          .where(
            (t) =>
                t.transactionType.toLowerCase() ==
                selectedTypeFilter.toLowerCase(),
          )
          .toList();
    }

    // Amount Range Filter (Evaluated against the user's active currency)
    if (minAmountFilter != null || maxAmountFilter != null) {
      list = list.where((t) {
        // Convert transaction's base amount to currently viewed currency
        final convertedAmount = activeCurrencyRate > 0
            ? (t.baseAmount / activeCurrencyRate)
            : t.baseAmount;

        if (minAmountFilter != null && convertedAmount < minAmountFilter!) {
          return false;
        }
        if (maxAmountFilter != null && convertedAmount > maxAmountFilter!) {
          return false;
        }
        return true;
      }).toList();
    }

    // Profile Filter (All, Personal, Business)
    if (selectedProfileFilter != "All") {
      list = list.where((t) {
        return t.profileType.trim().toLowerCase() ==
            selectedProfileFilter.toLowerCase();
      }).toList();
    }

    // Category Multi-Select Filter
    if (!selectedCategories.contains("All") && selectedCategories.isNotEmpty) {
      list = list.where((t) {
        final cat = t.category?.trim();
        if (cat == null) return false;
        return selectedCategories.any(
          (selected) => selected.toLowerCase() == cat.toLowerCase(),
        );
      }).toList();
    }

    // Sorting
    if (selectedSort == "Newest First") {
      list.sort((a, b) => b.date.compareTo(a.date));
    } else if (selectedSort == "Oldest First") {
      list.sort((a, b) => a.date.compareTo(b.date));
    } else if (selectedSort == "Amount: High to Low") {
      list.sort((a, b) => b.baseAmount.compareTo(a.baseAmount));
    } else if (selectedSort == "Amount: Low to High") {
      list.sort((a, b) => a.baseAmount.compareTo(b.baseAmount));
    }

    return list;
  }

  double get totalAmount {
  final rawBaseTotal = filteredTransactions.fold(0.0, (sum, item) {
    final type = item.transactionType.toLowerCase();
    final val = item.baseAmount;
    if (type == "income") return sum + val;
    if (type == "expense") return sum - val;
    return sum;
  });

  // USD total converted to active view currency (e.g. Total USD / 1.08 = EUR)
  return activeCurrencyRate > 0
      ? (rawBaseTotal / activeCurrencyRate)
      : rawBaseTotal;
}

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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

  Future<void> _pickCustomRange() async {
    final colors = context.colors;
    DateTime tempFrom =
        customFromDate ?? DateTime.now().subtract(const Duration(days: 7));
    DateTime tempTo = customToDate ?? DateTime.now();

    final fromController = TextEditingController(text: _formatDate(tempFrom));
    final toController = TextEditingController(text: _formatDate(tempTo));

    DateTime? parseDate(String input) {
      try {
        final parts = input.trim().split('/');
        if (parts.length != 3) return null;
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      } catch (_) {
        return null;
      }
    }

    bool isCustomApplyHovered = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickSingleDate(bool isFrom) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: isFrom ? tempFrom : tempTo,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setModalState(() {
                  if (isFrom) {
                    tempFrom = picked;
                    fromController.text = _formatDate(picked);
                  } else {
                    tempTo = picked;
                    toController.text = _formatDate(picked);
                  }
                });
              }
            }

            Widget buildDateInputField({
              required String label,
              required TextEditingController controller,
              required VoidCallback onPickerTap,
              required ValueChanged<String> onChanged,
            }) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.cardLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.datetime,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: "DD/MM/YYYY",
                            ),
                            onChanged: onChanged,
                          ),
                        ),
                        GestureDetector(
                          onTap: onPickerTap,
                          child: Icon(
                            Icons.edit_calendar_outlined,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle Bar
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        "Custom Date",
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Inputs Row
                      Row(
                        children: [
                          Expanded(
                            child: buildDateInputField(
                              label: "FROM",
                              controller: fromController,
                              onPickerTap: () => pickSingleDate(true),
                              onChanged: (val) {
                                final parsed = parseDate(val);
                                if (parsed != null) tempFrom = parsed;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: buildDateInputField(
                              label: "TO",
                              controller: toController,
                              onPickerTap: () => pickSingleDate(false),
                              onChanged: (val) {
                                final parsed = parseDate(val);
                                if (parsed != null) tempTo = parsed;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Apply Button styled like Apply Filter
                      Center(
                        child: SizedBox(
                          width: 140,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) => setModalState(
                              () => isCustomApplyHovered = true,
                            ),
                            onExit: (_) => setModalState(
                              () => isCustomApplyHovered = false,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: isCustomApplyHovered
                                    ? Color.alphaBlend(
                                        colors.heroLight,
                                        colors.hero,
                                      )
                                    : colors.hero,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  backgroundColor: Colors.transparent,
                                  surfaceTintColor: Colors.transparent,
                                  minimumSize: const Size(
                                    0,
                                    kMinInteractiveDimension,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  final parsedFrom =
                                      parseDate(fromController.text) ??
                                      tempFrom;
                                  final parsedTo =
                                      parseDate(toController.text) ?? tempTo;

                                  setState(() {
                                    customFromDate = parsedFrom;
                                    customToDate = parsedTo;
                                    selectedRange = "Custom Date";
                                  });
                                  Navigator.pop(ctx);
                                },
                                child: const Text(
                                  "Apply",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openFilterSheet() async {
    final colors = context.colors;
    final typeOptions = ["All", "Expense", "Income", "Transfer"];
    final profileOptions = ["All", "Personal", "Business"];

    final sortedCategories =
        DefaultCategories.defaults.map((c) => c.name).toList()..sort();

    // Working state inside the bottom sheet
    String tempTypeFilter = selectedTypeFilter;
    String tempProfileFilter = selectedProfileFilter;
    List<String> tempCategories = List<String>.from(selectedCategories);

    final minController = TextEditingController(
      text: minAmountFilter != null ? minAmountFilter!.toStringAsFixed(0) : "",
    );
    final maxController = TextEditingController(
      text: maxAmountFilter != null ? maxAmountFilter!.toStringAsFixed(0) : "",
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (ctx) {
        bool isResetHovered = false;
        bool isApplyHovered = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isAllCategoriesSelected = tempCategories.contains("All");

            String categoryDisplayText;
            if (isAllCategoriesSelected || tempCategories.isEmpty) {
              categoryDisplayText = "All Categories";
            } else if (tempCategories.length == 1) {
              categoryDisplayText = tempCategories.first;
            } else {
              categoryDisplayText = "${tempCategories.length} selected";
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.textSecondary.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Filter Transactions",
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 1. Payment Profile Dropdown (Height 44, matching Min/Max, with Checkmark)
                        Text(
                          "PAYMENT PROFILE",
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (profileCtx) {
                            return GestureDetector(
                              onTap: () async {
                                final renderBox =
                                    profileCtx.findRenderObject() as RenderBox;
                                final overlay =
                                    Navigator.of(
                                          context,
                                        ).overlay!.context.findRenderObject()
                                        as RenderBox;

                                final position = RelativeRect.fromRect(
                                  Rect.fromPoints(
                                    renderBox.localToGlobal(
                                      Offset.zero,
                                      ancestor: overlay,
                                    ),
                                    renderBox.localToGlobal(
                                      renderBox.size.bottomRight(Offset.zero),
                                      ancestor: overlay,
                                    ),
                                  ),
                                  Offset.zero & overlay.size,
                                );

                                final selected = await showMenu<String>(
                                  context: context,
                                  color: colors.card,
                                  elevation: 6,
                                  constraints: BoxConstraints(
                                    minWidth: renderBox.size.width,
                                    maxWidth: renderBox.size.width,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  position: position,
                                  items: profileOptions.map((opt) {
                                    final isSelected = opt == tempProfileFilter;
                                    return PopupMenuItem<String>(
                                      value: opt,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            opt,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? colors.textPrimary
                                                  : colors.textPrimary,
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.w500
                                                  : FontWeight.w500,
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
                                    );
                                  }).toList(),
                                );

                                if (selected != null) {
                                  setModalState(
                                    () => tempProfileFilter = selected,
                                  );
                                }
                              },
                              child: Container(
                                height: 44,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.cardLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      tempProfileFilter,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: colors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // 2. Categories Multi-Select Dropdown (Height 44, instant toggle, crisp purple checkmark)
                        Text(
                          "CATEGORIES",
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (fieldCtx) {
                            return GestureDetector(
                              onTap: () async {
                                final renderBox =
                                    fieldCtx.findRenderObject() as RenderBox;
                                final overlay =
                                    Navigator.of(
                                          context,
                                        ).overlay!.context.findRenderObject()
                                        as RenderBox;

                                final position = RelativeRect.fromRect(
                                  Rect.fromPoints(
                                    renderBox.localToGlobal(
                                      Offset.zero,
                                      ancestor: overlay,
                                    ),
                                    renderBox.localToGlobal(
                                      renderBox.size.bottomRight(Offset.zero),
                                      ancestor: overlay,
                                    ),
                                  ),
                                  Offset.zero & overlay.size,
                                );

                                await showMenu<void>(
                                  context: context,
                                  color: colors.card,
                                  elevation: 6,
                                  constraints: BoxConstraints(
                                    minWidth: renderBox.size.width,
                                    maxWidth: renderBox.size.width,
                                    maxHeight: 280,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  position: position,
                                  items: [
                                    PopupMenuItem<void>(
                                      enabled: false,
                                      padding: EdgeInsets.zero,
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          disabledColor: colors.textPrimary,
                                        ),
                                        child: StatefulBuilder(
                                          builder: (menuCtx, menuSetState) {
                                            final isAllActive = tempCategories
                                                .contains("All");

                                            return SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // "All" Row
                                                  InkWell(
                                                    onTap: () {
                                                      setModalState(() {
                                                        tempCategories.clear();
                                                        tempCategories.add(
                                                          "All",
                                                        );
                                                      });
                                                      menuSetState(() {});
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            "All",
                                                            style: TextStyle(
                                                              color: isAllActive
                                                                  ? colors
                                                                        .textPrimary
                                                                  : colors
                                                                        .textPrimary,
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  isAllActive
                                                                  ? FontWeight
                                                                        .w500
                                                                  : FontWeight
                                                                        .w500,
                                                            ),
                                                          ),
                                                          if (isAllActive)
                                                            Icon(
                                                              Icons.check,
                                                              color: colors
                                                                  .textPrimary,
                                                              size: 18,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),

                                                  // Individual Category Rows
                                                  ...sortedCategories.map((
                                                    cat,
                                                  ) {
                                                    final isSelected =
                                                        tempCategories.contains(
                                                          cat,
                                                        );
                                                    return InkWell(
                                                      onTap: () {
                                                        setModalState(() {
                                                          tempCategories.remove(
                                                            "All",
                                                          );
                                                          if (isSelected) {
                                                            tempCategories
                                                                .remove(cat);
                                                            if (tempCategories
                                                                .isEmpty) {
                                                              tempCategories
                                                                  .add("All");
                                                            }
                                                          } else {
                                                            tempCategories.add(
                                                              cat,
                                                            );
                                                          }
                                                        });
                                                        menuSetState(() {});
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 12,
                                                            ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                cat,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  color:
                                                                      isSelected
                                                                      ? colors
                                                                            .textPrimary
                                                                      : colors
                                                                            .textPrimary,
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      isSelected
                                                                      ? FontWeight
                                                                            .w500
                                                                      : FontWeight
                                                                            .w500,
                                                                ),
                                                              ),
                                                            ),
                                                            if (isSelected)
                                                              Icon(
                                                                Icons.check,
                                                                color: colors
                                                                    .textPrimary,
                                                                size: 18,
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                              child: Container(
                                height: 44,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.cardLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        categoryDisplayText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: colors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // 3. Transaction Type Dropdown
                        Text(
                          "TYPE",
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (typeCtx) {
                            return GestureDetector(
                              onTap: () async {
                                final renderBox =
                                    typeCtx.findRenderObject() as RenderBox;
                                final overlay =
                                    Navigator.of(
                                          context,
                                        ).overlay!.context.findRenderObject()
                                        as RenderBox;

                                final position = RelativeRect.fromRect(
                                  Rect.fromPoints(
                                    renderBox.localToGlobal(
                                      Offset.zero,
                                      ancestor: overlay,
                                    ),
                                    renderBox.localToGlobal(
                                      renderBox.size.bottomRight(Offset.zero),
                                      ancestor: overlay,
                                    ),
                                  ),
                                  Offset.zero & overlay.size,
                                );

                                final selected = await showMenu<String>(
                                  context: context,
                                  color: colors.card,
                                  elevation: 6,
                                  constraints: BoxConstraints(
                                    minWidth: renderBox.size.width,
                                    maxWidth: renderBox.size.width,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  position: position,
                                  items: typeOptions.map((opt) {
                                    final isSelected = opt == tempTypeFilter;
                                    return PopupMenuItem<String>(
                                      value: opt,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            opt,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? colors.textPrimary
                                                  : colors.textPrimary,
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.w500
                                                  : FontWeight.w500,
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
                                    );
                                  }).toList(),
                                );

                                if (selected != null) {
                                  setModalState(
                                    () => tempTypeFilter = selected,
                                  );
                                }
                              },
                              child: Container(
                                height: 44,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.cardLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      tempTypeFilter,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: colors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // 4. Amount Range (Exact 44 height matching dropdowns)
                        Text(
                          "AMOUNT RANGE",
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: TextField(
                                  controller: minController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*'),
                                    ),
                                  ],
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Min ($activeCurrencySymbol)",
                                    hintStyle: TextStyle(
                                      color: colors.textSecondary.withOpacity(
                                        0.5,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: colors.cardLight,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: TextField(
                                  controller: maxController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*'),
                                    ),
                                  ],
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Max ($activeCurrencySymbol)",
                                    hintStyle: TextStyle(
                                      color: colors.textSecondary.withOpacity(
                                        0.5,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: colors.cardLight,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Reset and Apply Buttons
                        // Reset and Apply Buttons
                        Row(
                          children: [
                            // Reset Button
                            Expanded(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) =>
                                    setModalState(() => isResetHovered = true),
                                onExit: (_) =>
                                    setModalState(() => isResetHovered = false),
                                child: AnimatedContainer(
                                  height: 38,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    color: isResetHovered
                                        ? colors.secondaryLight
                                        : colors.secondary,
                                    /*color: colors.cardLight.withValues(
                                      alpha: isResetHovered ? 0.20 : 0.0,
                                    ),*/
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: colors.cardLight.withValues(
                                        alpha: isResetHovered ? 1.0 : 0.8,
                                      ),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      surfaceTintColor: Colors.transparent,
                                      overlayColor: Colors.transparent,
                                      minimumSize: Size.zero,
                                      side: BorderSide.none,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        tempTypeFilter = "All";
                                        tempProfileFilter = "All";
                                        tempCategories = ["All"];
                                        minController.clear();
                                        maxController.clear();
                                      });
                                    },
                                    child: Text(
                                      "Reset",
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Apply Button
                            Expanded(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) =>
                                    setModalState(() => isApplyHovered = true),
                                onExit: (_) =>
                                    setModalState(() => isApplyHovered = false),
                                child: AnimatedContainer(
                                  height: 38,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    color: isApplyHovered
                                        ? colors.heroLight
                                        : colors.hero,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      surfaceTintColor: Colors.transparent,
                                      overlayColor: Colors.transparent,
                                      minimumSize: Size.zero,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      final parsedMin = double.tryParse(
                                        minController.text.trim(),
                                      );
                                      final parsedMax = double.tryParse(
                                        maxController.text.trim(),
                                      );

                                      // Validation: Check if min is greater than max
                                      if (parsedMin != null &&
                                          parsedMax != null &&
                                          parsedMin > parsedMax) {
                                        HapticFeedback.vibrate();
                                        context.showSnackBar(
                                          "Max amount must be greater than or equal to Min amount.",
                                          type: SnackBarType.error,
                                        );
                                        return;
                                      }

                                      setState(() {
                                        selectedTypeFilter = tempTypeFilter;
                                        selectedProfileFilter =
                                            tempProfileFilter;
                                        selectedCategories = tempCategories;
                                        minAmountFilter = parsedMin;
                                        maxAmountFilter = parsedMax;
                                      });

                                      Navigator.pop(ctx);
                                    },
                                    child: const Text(
                                      "Apply",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openSortSheet() {
    final colors = context.colors;
    final options = [
      "Newest First",
      "Oldest First",
      "Amount: High to Low",
      "Amount: Low to High",
    ];

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
                      color: colors.textSecondary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Sort Transactions",
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: options.map((sort) {
                    final isSelected = selectedSort == sort;
                    return InkWell(
                      onTap: () {
                        setState(() => selectedSort = sort);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sort,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected
                                    ? colors.textPrimary
                                    : colors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.w500,
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
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalDays() {
    final colors = context.colors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: PageView.builder(
        key: const ValueKey("days_slider"),
        controller: _dayPageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (page) {
          final diff = page - baseIndex;
          setState(() {
            activeDate = today.add(Duration(days: diff));
          });
        },
        itemBuilder: (context, index) {
          final diff = index - baseIndex;
          final date = today.add(Duration(days: diff));
          final isSelected =
              date.year == activeDate.year &&
              date.month == activeDate.month &&
              date.day == activeDate.day;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!isSelected) {
                _dayPageController?.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            child: Center(
              child: Text(
                "${date.day} ${months[date.month - 1].substring(0, 3)}",
                style: TextStyle(
                  fontSize: isSelected ? 16 : 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: colors.textPrimary.withOpacity(
                    isSelected ? 1.0 : 0.35,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalMonths() {
    final colors = context.colors;

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: PageView.builder(
        key: const ValueKey("months_slider"),
        controller: _monthPageController,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (page) {
          final year = page ~/ 12;
          final month = (page % 12) + 1;
          setState(() {
            activeDate = DateTime(year, month, 1);
          });
        },
        itemBuilder: (context, index) {
          final year = index ~/ 12;
          final monthIndex = index % 12;
          final isSelected =
              year == activeDate.year && (monthIndex + 1) == activeDate.month;

          final isCurrentYear = year == DateTime.now().year;
          final shortName = months[monthIndex].substring(0, 3);

          final String displayText;
          if (isSelected) {
            displayText = isCurrentYear
                ? months[monthIndex]
                : "${months[monthIndex]} '$year";
          } else {
            displayText = isCurrentYear ? shortName : "$shortName '$year";
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!isSelected) {
                _monthPageController?.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            child: Center(
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: isSelected ? 13 : 10,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                  color: isSelected ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalYears() {
    final colors = context.colors;

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: PageView.builder(
        key: const ValueKey("years_slider"),
        controller: _yearPageController,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (page) {
          final computedYear = 2000 + (page - baseIndex);
          setState(() {
            activeDate = DateTime(computedYear, 1, 1);
          });
        },
        itemBuilder: (context, index) {
          final year = 2000 + (index - baseIndex);
          final isSelected = year == activeDate.year;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!isSelected) {
                _yearPageController?.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            child: Center(
              child: Text(
                "$year",
                style: TextStyle(
                  fontSize: isSelected ? 16 : 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: colors.textPrimary.withOpacity(
                    isSelected ? 1.0 : 0.35,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeframeSlider() {
    if (selectedRange == "Today") {
      return _buildHorizontalDays();
    } else if (selectedRange == "This Month") {
      return _buildHorizontalMonths();
    } else if (selectedRange == "This Year") {
      return _buildHorizontalYears();
    }
    return const SizedBox.shrink();
  }

  Widget _buildFullWidthDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.colors.cardLight.withValues(
        alpha: 0.6,
      ), // Adjust color/opacity to match your theme
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentList = filteredTransactions;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),

            // 1. Top Header Row (Centered Date Dropdown + Right-aligned Action Icons)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Centered Dropdown Button
                  Builder(
                    builder: (buttonContext) {
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) =>
                            setState(() => _isRangeDropdownHovered = true),
                        onExit: (_) =>
                            setState(() => _isRangeDropdownHovered = false),
                        child: AnimatedContainer(
                          height: 38,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: _isRangeDropdownHovered
                                ? colors.heroLight
                                : colors.hero,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              backgroundColor: Colors.transparent,
                              surfaceTintColor: Colors.transparent,
                              minimumSize: Size.zero,
                              overlayColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                            onPressed: () async {
                              final renderBox =
                                  buttonContext.findRenderObject() as RenderBox;
                              final overlay =
                                  Navigator.of(
                                        context,
                                      ).overlay!.context.findRenderObject()
                                      as RenderBox;

                              final target = Rect.fromPoints(
                                renderBox.localToGlobal(
                                  Offset.zero,
                                  ancestor: overlay,
                                ),
                                renderBox.localToGlobal(
                                  renderBox.size.bottomRight(Offset.zero),
                                  ancestor: overlay,
                                ),
                              );

                              final selected = await showMenu<String>(
                                context: context,
                                color: colors.card,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                position: RelativeRect.fromRect(
                                  target,
                                  Offset.zero & overlay.size,
                                ),
                                items: rangeOptions.map((String value) {
                                  final isSelected = value == selectedRange;
                                  return PopupMenuItem<String>(
                                    value: value,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          value,
                                          style: TextStyle(
                                            color: isSelected
                                                ? colors.textPrimary
                                                : colors.textPrimary,
                                            fontWeight: isSelected
                                                ? FontWeight.w500
                                                : FontWeight.w500,
                                            fontSize: 14,
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
                                  );
                                }).toList(),
                              );

                              if (selected == "Custom Date") {
                                await _pickCustomRange();
                              } else if (selected != null) {
                                setState(() {
                                  selectedRange = selected;
                                  activeDate = DateTime.now();
                                  _initControllers();
                                });
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  selectedRange,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Filter & Sort SVG Icons pinned to the right
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Filter Button
                        MouseRegion(
                          //aman
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setState(() => _isFilterHovered = true),
                          onExit: (_) =>
                              setState(() => _isFilterHovered = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openFilterSheet,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isFilterHovered
                                    ? colors.cardLight
                                    : colors.cardLight.withValues(alpha: 0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: SvgPicture.asset(
                                'assets/icons/components/filter.svg',
                                width: 20,
                                height: 20,
                                // REPLACE WITH:
                                colorFilter: ColorFilter.mode(
                                  colors.textPrimary,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // 2. Sort Button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isSortHovered = true),
                          onExit: (_) => setState(() => _isSortHovered = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openSortSheet,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isSortHovered
                                    ? colors.cardLight
                                    : colors.cardLight.withValues(alpha: 0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: SvgPicture.asset(
                                'assets/icons/components/sort.svg',
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
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. Dynamic Total for Range (in active selected currency)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Baseline(
                  baseline: 30, // Scaled for the 32px number size
                  baselineType: TextBaseline.alphabetic,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Text(
                      activeCurrencySymbol,
                      style: TextStyle(
                        fontSize: 20,
                        color:
                            colors.textPrimary, // Keeps the default text color
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Text(
                  totalAmount.abs().toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 0),
            _buildTimeframeSlider(),
            const SizedBox(height: 4),
            // 👇 Full screen width divider directly under the slider
            _buildFullWidthDivider(),

            // 4. Transaction List
            Expanded(
              child: currentList.isEmpty
                  ? Center(
                      child: Text(
                        "No transactions in this period",
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(top: 4, bottom: 0),
                      child: _buildCardContainer(
                        List.generate(currentList.length * 2 - 1, (index) {
                          if (index.isOdd) {
                            return _buildDivider();
                          }
                          final itemIndex = index ~/ 2;
                          final transaction = currentList[itemIndex];
                          return TransactionCard(
                            transaction: transaction,
                            baseCurrency: activeCurrencyCode,
                            currencyRate: activeCurrencyRate,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddTransactionScreen(
                                    transaction: transaction,
                                  ),
                                ),
                              );
                              loadTransactions();
                            },
                            onDelete: () async {
                              await transactionService.deleteTransaction(
                                transaction.id!,
                              );
                              loadTransactions();
                            },
                          );
                        }),
                      ),
                    ),
            ),
          ],
        ),
      ),

      floatingActionButton: MouseRegion(
        //aman
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isAddButtonHovered = true),
        onExit: (_) => setState(() => _isAddButtonHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddTransactionScreen(),
              ),
            );
            loadTransactions();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _isAddButtonHovered
                  ? colors.heroBackground
                  : colors.heroBackground.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: SvgPicture.asset(
              'assets/icons/components/add.svg',
              width: 40,
              height: 40,
              colorFilter: ColorFilter.mode(colors.hero, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
