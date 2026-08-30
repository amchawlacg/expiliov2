import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';
import 'add_transaction_screen.dart';
import '../widgets/transaction_card.dart';
import '../constants/app_colors.dart';

import 'package:flutter_svg/flutter_svg.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final TransactionService transactionService = TransactionService();

  List<TransactionModel> allTransactions = [];
  String selectedRange = "This Month";
  String selectedSort = "Newest First";
  String selectedTypeFilter = "All"; // "All", "Expense", "Income", "Transfer"
  double? minAmountFilter;
  double? maxAmountFilter;

  DateTime? customFromDate;
  DateTime? customToDate;

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
      viewportFraction: 0.32,
    );
    _yearPageController = PageController(
      initialPage: baseIndex + (activeDate.year - 2000),
      viewportFraction: 0.22,
    );
  }

  @override
  void dispose() {
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

    // Amount Range Filter
    if (minAmountFilter != null) {
      list = list.where((t) => t.amount >= minAmountFilter!).toList();
    }
    if (maxAmountFilter != null) {
      list = list.where((t) => t.amount <= maxAmountFilter!).toList();
    }

    // Sorting
    if (selectedSort == "Newest First") {
      list.sort((a, b) => b.date.compareTo(a.date));
    } else if (selectedSort == "Oldest First") {
      list.sort((a, b) => a.date.compareTo(b.date));
    } else if (selectedSort == "Amount: High to Low") {
      list.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (selectedSort == "Amount: Low to High") {
      list.sort((a, b) => a.amount.compareTo(b.amount));
    }

    return list;
  }

  double get totalAmount {
    return filteredTransactions.fold(0.0, (sum, item) {
      final type = item.transactionType.toLowerCase();
      if (type == "income") {
        return sum + item.amount;
      } else if (type == "expense") {
        return sum - item.amount;
      }
      return sum;
    });
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
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: isCustomApplyHovered
                                    ? Color.alphaBlend(
                                        Colors.black.withValues(alpha: 0.25),
                                        colors.purple,
                                      )
                                    : colors.purple,
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
    final options = ["All", "Expense", "Income", "Transfer"];

    String tempTypeFilter = selectedTypeFilter;
    final minController = TextEditingController(
      text: minAmountFilter != null ? minAmountFilter!.toStringAsFixed(0) : "",
    );
    final maxController = TextEditingController(
      text: maxAmountFilter != null ? maxAmountFilter!.toStringAsFixed(0) : "",
    );

    bool isApplyFilterHovered = false; // 👈 Add this line here

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
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 16,
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
                      "Filter Transactions",
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: options.map((type) {
                        final isSelected = tempTypeFilter == type;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              tempTypeFilter = type;
                            });
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
                                  type,
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
                                  Icon(
                                    Icons.check,
                                    color: colors.purple,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: "Min (₹)",
                              hintStyle: TextStyle(
                                color: colors.textSecondary.withOpacity(0.5),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: "Max (₹)",
                              hintStyle: TextStyle(
                                color: colors.textSecondary.withOpacity(0.5),
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
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                kMinInteractiveDimension,
                              ),
                              side: BorderSide(
                                color: colors.textSecondary.withOpacity(0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                selectedTypeFilter = "All";
                                minAmountFilter = null;
                                maxAmountFilter = null;
                              });
                              Navigator.pop(ctx);
                            },
                            child: Text(
                              "Reset",
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MouseRegion(
                            onEnter: (_) => setModalState(
                              () => isApplyFilterHovered = true,
                            ),
                            onExit: (_) => setModalState(
                              () => isApplyFilterHovered = false,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: isApplyFilterHovered
                                    ? Color.alphaBlend(
                                        Colors.black.withValues(alpha: 0.25),
                                        colors.purple,
                                      )
                                    : colors.purple,
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
                                  setState(() {
                                    selectedTypeFilter = tempTypeFilter;
                                    minAmountFilter = double.tryParse(
                                      minController.text.trim(),
                                    );
                                    maxAmountFilter = double.tryParse(
                                      maxController.text.trim(),
                                    );
                                  });
                                  Navigator.pop(ctx);
                                },
                                child: const Text(
                                  "Apply Filter",
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
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
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
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  fontWeight: FontWeight.bold,
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
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalDays() {
    final colors = context.colors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SizedBox(
      height: 44,
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

          return Center(
            child: Text(
              "${date.day} ${months[date.month - 1].substring(0, 3)}",
              style: TextStyle(
                fontSize: isSelected ? 16 : 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: colors.textPrimary.withOpacity(isSelected ? 1.0 : 0.35),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalMonths() {
    final colors = context.colors;

    return SizedBox(
      height: 44,
      child: PageView.builder(
        key: const ValueKey("months_slider"),
        controller: _monthPageController,
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
          final displayText = isCurrentYear
              ? months[monthIndex]
              : "${months[monthIndex].substring(0, 3)} '$year";

          return Center(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: isSelected ? 16 : 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: colors.textPrimary.withOpacity(isSelected ? 1.0 : 0.35),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalYears() {
    final colors = context.colors;

    return SizedBox(
      height: 44,
      child: PageView.builder(
        key: const ValueKey("years_slider"),
        controller: _yearPageController,
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

          return Center(
            child: Text(
              "$year",
              style: TextStyle(
                fontSize: isSelected ? 16 : 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: colors.textPrimary.withOpacity(isSelected ? 1.0 : 0.35),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentList = filteredTransactions;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

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
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: _isRangeDropdownHovered
                                ? Color.alphaBlend(
                                    Colors.black.withValues(alpha: 0.25),
                                    colors.purple,
                                  )
                                : colors.purple,
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
                              overlayColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
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
                                                ? colors.purple
                                                : colors.textPrimary,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check,
                                            color: colors.purple,
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
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Filter & Sort SVG Icons pinned to the right
                  // Filter & Sort SVG Icons pinned to the right
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Filter Button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setState(() => _isFilterHovered = true),
                          onExit: (_) =>
                              setState(() => _isFilterHovered = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openFilterSheet,
                            child: SvgPicture.asset(
                              'assets/icons/components/filter.svg',
                              width: 22,
                              height: 22,
                              colorFilter: ColorFilter.mode(
                                _isFilterHovered
                                    ? Color.alphaBlend(
                                        Colors.black.withValues(alpha: 0.35),
                                        colors.textPrimary,
                                      )
                                    : (selectedTypeFilter != "All" ||
                                              minAmountFilter != null ||
                                              maxAmountFilter != null
                                          ? colors.purple
                                          : colors.textPrimary),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Sort Button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isSortHovered = true),
                          onExit: (_) => setState(() => _isSortHovered = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openSortSheet,
                            child: SvgPicture.asset(
                              'assets/icons/components/sort.svg',
                              width: 22,
                              height: 22,
                              colorFilter: ColorFilter.mode(
                                _isSortHovered
                                    ? Color.alphaBlend(
                                        Colors.black.withValues(alpha: 0.35),
                                        colors.textPrimary,
                                      )
                                    : (selectedSort != "Newest First"
                                          ? colors.purple
                                          : colors.textPrimary),
                                BlendMode.srcIn,
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

            // 2. Dynamic Total for Range
            Text(
              "₹ ${totalAmount.abs().toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),

            const SizedBox(height: 6),
            _buildTimeframeSlider(),
            const SizedBox(height: 8),

            // 4. Transaction List
            Expanded(
              child: currentList.isEmpty
                  ? Center(
                      child: Text(
                        "No transactions in this period",
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 0),
                      itemCount: currentList.length,
                      itemBuilder: (context, index) {
                        final transaction = currentList[index];

                        return TransactionCard(
                          transaction: transaction,
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
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: MouseRegion(
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
          child: SvgPicture.asset(
            'assets/icons/components/add-square.svg',
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(
              colors.purple.withOpacity(_isAddButtonHovered ? 0.75 : 0.35),
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
