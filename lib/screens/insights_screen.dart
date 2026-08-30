import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

import '../widgets/charts/app_pie_chart.dart';
import '../widgets/charts/app_bar_chart.dart';
import '../widgets/charts/app_line_chart.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final TransactionService transactionService = TransactionService();

  List<TransactionModel> allTransactions = [];
  bool isLoading = true;

  String selectedRange = "This Month";
  DateTime activeDate = DateTime.now();

  DateTime? customFromDate;
  DateTime? customToDate;

  // Active breakdown tab for the pie chart: "expense" or "income"
  String activeBreakdownTab = "expense";

  static const List<String> months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  static const int baseIndex = 12000;

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
      initialPage: baseIndex + (activeDate.month - 1),
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
    setState(() => isLoading = true);
    final data = await transactionService.getTransactions();
    if (!mounted) return;
    setState(() {
      allTransactions = data;
      isLoading = false;
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

    return allTransactions.where((t) {
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
  }

  Map<String, double> get monthlySummary {
    double income = 0.0;
    double expense = 0.0;

    for (final t in filteredTransactions) {
      final type = t.transactionType.trim().toLowerCase();
      if (type == "income") {
        income += t.amount;
      } else if (type == "expense") {
        expense += t.amount;
      }
    }

    return {'income': income, 'expense': expense, 'net': income - expense};
  }

  Map<String, double> get categorySummary {
    final Map<String, double> map = {};
    for (final t in filteredTransactions) {
      final type = t.transactionType.trim().toLowerCase();
      if (type == "expense") {
        final category = t.category;
        final cat = (category != null && category.trim().isNotEmpty)
            ? category.trim()
            : "Uncategorized";
        map[cat] = (map[cat] ?? 0.0) + t.amount;
      }
    }
    return map;
  }

  Map<String, double> get incomeSourceSummary {
    final Map<String, double> map = {};
    for (final t in filteredTransactions) {
      final type = t.transactionType.trim().toLowerCase();
      if (type == "income") {
        final category = t.category;
        final cat = (category != null && category.trim().isNotEmpty)
            ? category.trim()
            : "General Income";
        map[cat] = (map[cat] ?? 0.0) + t.amount;
      }
    }
    return map;
  }

  Map<String, double> get profileSummary {
    final Map<String, double> map = {};
    for (final t in filteredTransactions) {
      final rawProfile = t.profileType;
      final profile = rawProfile.isNotEmpty
          ? rawProfile[0].toUpperCase() + rawProfile.substring(1)
          : "Default";
      map[profile] = (map[profile] ?? 0.0) + t.amount;
    }
    return map;
  }

  // Generate spending points for AppLineChart based on current view
  Map<String, double> get lineChartTrendData {
    final Map<String, double> trend = {};

    if (selectedRange == "This Month") {
      final daysInMonth = DateUtils.getDaysInMonth(activeDate.year, activeDate.month);
      for (int i = 1; i <= daysInMonth; i++) {
        trend["$i"] = 0.0;
      }
      for (final t in filteredTransactions) {
        if (t.transactionType.trim().toLowerCase() == "expense") {
          final dayKey = "${t.date.day}";
          trend[dayKey] = (trend[dayKey] ?? 0.0) + t.amount;
        }
      }
    } else if (selectedRange == "This Year") {
      const shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      for (final m in shortMonths) {
        trend[m] = 0.0;
      }
      for (final t in filteredTransactions) {
        if (t.transactionType.trim().toLowerCase() == "expense") {
          final monthKey = shortMonths[t.date.month - 1];
          trend[monthKey] = (trend[monthKey] ?? 0.0) + t.amount;
        }
      }
    } else if (selectedRange == "This Week") {
      const weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      for (final d in weekDays) {
        trend[d] = 0.0;
      }
      for (final t in filteredTransactions) {
        if (t.transactionType.trim().toLowerCase() == "expense") {
          final dayIndex = t.date.weekday - 1;
          final dayKey = weekDays[dayIndex];
          trend[dayKey] = (trend[dayKey] ?? 0.0) + t.amount;
        }
      }
    }

    return trend;
  }

  // Get Top 3-5 largest expenses for the period
  List<TransactionModel> get topExpenses {
    final expenses = filteredTransactions
        .where((t) => t.transactionType.trim().toLowerCase() == "expense")
        .toList();
    expenses.sort((a, b) => b.amount.compareTo(a.amount));
    return expenses.take(4).toList();
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
                      Center(
                        child: SizedBox(
                          width: 140,
                          child: GestureDetector(
                            onTap: () {
                              final parsedFrom =
                                  parseDate(fromController.text) ?? tempFrom;
                              final parsedTo =
                                  parseDate(toController.text) ?? tempTo;

                              setState(() {
                                customFromDate = parsedFrom;
                                customToDate = parsedTo;
                                selectedRange = "Custom Date";
                              });
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: colors.purple,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
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

  Widget _buildHorizontalDays() {
    final colors = context.colors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SizedBox(
      height: 44,
      child: PageView.builder(
        key: const ValueKey("insights_days_slider"),
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
        key: const ValueKey("insights_months_slider"),
        controller: _monthPageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (page) {
          final computedMonth = (((page % 12) + 12) % 12) + 1;
          setState(() {
            activeDate = DateTime(activeDate.year, computedMonth, 1);
          });
        },
        itemBuilder: (context, index) {
          final monthIndex = ((index % 12) + 12) % 12;
          final isSelected = (monthIndex + 1) == activeDate.month;

          return Center(
            child: Text(
              months[monthIndex],
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
        key: const ValueKey("insights_years_slider"),
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

  Widget _buildSegmentPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required dynamic colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? colors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : colors.textSecondary,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final summary = monthlySummary;
    final categories = categorySummary;
    final incomes = incomeSourceSummary;
    final profiles = profileSummary;
    final trendData = lineChartTrendData;
    final topSpends = topExpenses;

    final isExpenseTab = activeBreakdownTab == "expense";
    final activeData = isExpenseTab ? categories : incomes;
    final activeTotal =
        isExpenseTab ? (summary['expense'] ?? 0.0) : (summary['income'] ?? 0.0);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Top Date Range Dropdown
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.purple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRange,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                    dropdownColor: colors.card,
                    selectedItemBuilder: (BuildContext context) {
                      return rangeOptions.map((String value) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    items: rangeOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) async {
                      if (newValue == "Custom Date") {
                        await _pickCustomRange();
                      } else if (newValue != null) {
                        setState(() {
                          selectedRange = newValue;
                          activeDate = DateTime.now();
                          _initControllers();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),
            _buildTimeframeSlider(),
            const SizedBox(height: 10),

            const Divider(height: 1, thickness: 1),

            // Main Insights Scroll View
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: colors.purple),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // SECTION 1: METRICS FINANCIAL HEALTH CARD
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _buildSummaryRow(
                                "Income",
                                "₹${summary['income']!.toStringAsFixed(2)}",
                                Colors.greenAccent.shade700,
                                colors,
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryRow(
                                "Expenses",
                                "₹${summary['expense']!.toStringAsFixed(2)}",
                                Colors.redAccent,
                                colors,
                              ),
                              Divider(
                                height: 24,
                                color: colors.textSecondary.withOpacity(0.15),
                              ),
                              _buildSummaryRow(
                                "Net Balance",
                                "₹${summary['net']!.toStringAsFixed(2)}",
                                summary['net']! >= 0
                                    ? colors.purple
                                    : Colors.orangeAccent,
                                colors,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SECTION 2: SPENDING VELOCITY TREND (LINE CHART)
                        if (trendData.isNotEmpty &&
                            (selectedRange == "This Month" ||
                                selectedRange == "This Year" ||
                                selectedRange == "This Week")) ...[
                          Text(
                            "Spending Velocity",
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 18.0,
                            ),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: AppLineChart(
                              key: ValueKey("line_${selectedRange}_${activeDate.month}_${activeDate.year}"),
                              data: trendData,
                              lineColor: colors.purple,
                              height: 190,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // SECTION 3: BREAKDOWN BY CATEGORY / SOURCE (PIE CHART)
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Breakdown",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colors.cardLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildSegmentPill(
                                          label: "Expenses",
                                          isActive: isExpenseTab,
                                          onTap: () {
                                            if (!isExpenseTab) {
                                              setState(() {
                                                activeBreakdownTab = "expense";
                                              });
                                            }
                                          },
                                          colors: colors,
                                        ),
                                        _buildSegmentPill(
                                          label: "Income",
                                          isActive: !isExpenseTab,
                                          onTap: () {
                                            if (isExpenseTab) {
                                              setState(() {
                                                activeBreakdownTab = "income";
                                              });
                                            }
                                          },
                                          colors: colors,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              activeData.isEmpty || activeTotal <= 0
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 32.0,
                                      ),
                                      child: Center(
                                        child: Text(
                                          isExpenseTab
                                              ? "No expenses have been added yet."
                                              : "No income has been added yet.",
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    )
                                  : AppPieChart(
                                      key: ValueKey(activeBreakdownTab),
                                      data: activeData,
                                      totalAmount: activeTotal,
                                      centerLabel:
                                          isExpenseTab ? "Spent" : "Earned",
                                      showCategoryList: true,
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SECTION 4: TOP LARGEST SPENDS
                        if (topSpends.isNotEmpty) ...[
                          Text(
                            "Top Spends",
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: topSpends.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: colors.divider?.withOpacity(0.4) ??
                                    Colors.grey.shade200,
                              ),
                              itemBuilder: (context, i) {
                                final t = topSpends[i];
                                final displayTitle = (t.merchant != null && t.merchant!.trim().isNotEmpty)
                                    ? t.merchant!.trim()
                                    : (t.note != null && t.note!.trim().isNotEmpty)
                                        ? t.note!.trim()
                                        : (t.category != null && t.category!.trim().isNotEmpty)
                                            ? t.category!.trim()
                                            : "Expense";

                                return ListTile(
                                  title: Text(
                                    displayTitle,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatDate(t.date),
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Text(
                                    "₹${t.amount.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // SECTION 5: PROFILE BREAKDOWN
                        if (profiles.isNotEmpty) ...[
                          Text(
                            "Profile Breakdown",
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: profiles.entries.map((entry) {
                                return ListTile(
                                  title: Text(
                                    entry.key,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: Text(
                                    "₹${entry.value.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color valueColor,
    dynamic colors,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}