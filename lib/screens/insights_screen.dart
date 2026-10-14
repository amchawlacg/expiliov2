import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

import '../widgets/charts/app_pie_chart.dart';
import '../widgets/charts/app_bar_chart.dart';
import '../widgets/charts/app_line_chart.dart';

import '../services/preference_service.dart';
import '../constants/currency_constants.dart';
import '../database/database_helper.dart';

import '../services/sync_service.dart';

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

  String activeCurrencyCode = "USD";
  String activeCurrencySymbol = "\$";
  double activeCurrencyRate = 1.0;

  bool _isRangeDropdownHovered = false;
  // Active breakdown tab for the pie chart: "expense" or "income"
  String activeBreakdownTab = "expense";

  // State variable
  String activeVelocityTab = "expense"; // "expense" or "income"

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
    loadCurrency();
    loadTransactions();

    SyncService.onDataChanged.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (mounted) {
      loadCurrency();
      loadTransactions();
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
    SyncService.onDataChanged.removeListener(_onDataChanged);
    _dayPageController?.dispose();
    _monthPageController?.dispose();
    _yearPageController?.dispose();
    super.dispose();
  }

  double _toDisplayAmount(TransactionModel t) {
    if (activeCurrencyRate <= 0) return t.baseAmount;
    return t.baseAmount / activeCurrencyRate;
  }

  Future<void> loadCurrency() async {
    final rawCurrency = await PreferencesService.getBaseCurrency();
    final code = rawCurrency.split(' ').first.trim();
    if (code.isEmpty) return;

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
        activeCurrencyRate =
            (currencyData.first['rate_to_base'] as num?)?.toDouble() ??
            defaultRate;
      });
    } else {
      setState(() {
        activeCurrencyCode = code;
        activeCurrencySymbol = defaultSymbol;
        activeCurrencyRate = defaultRate;
      });
    }
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
      final displayVal = _toDisplayAmount(t);
      if (type == "income") {
        income += displayVal;
      } else if (type == "expense") {
        expense += displayVal;
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
        map[cat] = (map[cat] ?? 0.0) + _toDisplayAmount(t);
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
        map[cat] = (map[cat] ?? 0.0) + _toDisplayAmount(t);
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
      map[profile] = (map[profile] ?? 0.0) + _toDisplayAmount(t);
    }
    return map;
  }

  Map<String, double> get lineChartTrendData {
    final Map<String, double> trend = {};
    final targetType = activeVelocityTab;

    if (selectedRange == "This Month") {
      final daysInMonth = DateUtils.getDaysInMonth(
        activeDate.year,
        activeDate.month,
      );
      for (int i = 1; i <= daysInMonth; i++) {
        trend["$i"] = 0.0;
      }
      for (final t in filteredTransactions) {
        if (t.transactionType.trim().toLowerCase() == targetType) {
          final dayKey = "${t.date.day}";
          trend[dayKey] = (trend[dayKey] ?? 0.0) + _toDisplayAmount(t);
        }
      }
    } else if (selectedRange == "This Year") {
      const shortMonths = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      for (final m in shortMonths) {
        trend[m] = 0.0;
      }
      for (final t in filteredTransactions) {
        if (t.transactionType.trim().toLowerCase() == targetType) {
          final monthKey = shortMonths[t.date.month - 1];
          trend[monthKey] = (trend[monthKey] ?? 0.0) + _toDisplayAmount(t);
        }
      }
    } else if (selectedRange == "This Week") {
      const weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      for (final d in weekDays) {
        trend[d] = 0.0;
      }
      for (final t in filteredTransactions) {
        if (t.transactionType.trim().toLowerCase() == targetType) {
          final dayIndex = t.date.weekday - 1;
          final dayKey = weekDays[dayIndex];
          trend[dayKey] = (trend[dayKey] ?? 0.0) + _toDisplayAmount(t);
        }
      }
    }

    return trend;
  }

  // Computes same-day-to-date run rate vs prior period
  Map<String, dynamic> getVelocityComparison(String targetType) {
    double currentAmount = 0.0;
    double previousAmount = 0.0;

    DateTime curStart;
    DateTime curEnd;
    DateTime prevStart;
    DateTime prevEnd;
    String periodLabel;

    final now = DateTime.now();

    switch (selectedRange) {
      case "Today":
        curStart = DateTime(activeDate.year, activeDate.month, activeDate.day);
        curEnd = DateTime(
          activeDate.year,
          activeDate.month,
          activeDate.day,
          23,
          59,
          59,
          999,
        );
        prevStart = curStart.subtract(const Duration(days: 1));
        prevEnd = DateTime(
          prevStart.year,
          prevStart.month,
          prevStart.day,
          23,
          59,
          59,
          999,
        );
        periodLabel = "yesterday";
        break;

      case "This Week":
        final today = DateTime(now.year, now.month, now.day);
        curStart = today.subtract(Duration(days: today.weekday - 1));
        curEnd = DateTime(
          curStart.year,
          curStart.month,
          curStart.day + 6,
          23,
          59,
          59,
          999,
        );
        prevStart = curStart.subtract(const Duration(days: 7));
        prevEnd = curStart.subtract(const Duration(milliseconds: 1));
        periodLabel = "last week";
        break;

      case "This Month":
        final daysInCurMonth = DateUtils.getDaysInMonth(
          activeDate.year,
          activeDate.month,
        );
        curStart = DateTime(activeDate.year, activeDate.month, 1);
        curEnd = DateTime(
          activeDate.year,
          activeDate.month,
          daysInCurMonth,
          23,
          59,
          59,
          999,
        );

        final prevYear = activeDate.month == 1
            ? activeDate.year - 1
            : activeDate.year;
        final prevMonth = activeDate.month == 1 ? 12 : activeDate.month - 1;
        final daysInPrevMonth = DateUtils.getDaysInMonth(prevYear, prevMonth);

        prevStart = DateTime(prevYear, prevMonth, 1);
        prevEnd = DateTime(
          prevYear,
          prevMonth,
          daysInPrevMonth,
          23,
          59,
          59,
          999,
        );
        periodLabel = "last month";
        break;

      case "This Year":
        curStart = DateTime(activeDate.year, 1, 1);
        curEnd = DateTime(activeDate.year, 12, 31, 23, 59, 59, 999);
        prevStart = DateTime(activeDate.year - 1, 1, 1);
        prevEnd = DateTime(activeDate.year - 1, 12, 31, 23, 59, 59, 999);
        periodLabel = "last year";
        break;

      case "Custom Date":
        if (customFromDate == null || customToDate == null) {
          return {'hasComparison': false};
        }
        curStart = DateTime(
          customFromDate!.year,
          customFromDate!.month,
          customFromDate!.day,
        );
        curEnd = DateTime(
          customToDate!.year,
          customToDate!.month,
          customToDate!.day,
          23,
          59,
          59,
          999,
        );

        final spanDays = curEnd.difference(curStart).inDays + 1;
        prevStart = curStart.subtract(Duration(days: spanDays));
        prevEnd = curStart.subtract(const Duration(milliseconds: 1));
        periodLabel = "prev $spanDays days";
        break;

      case "All Time":
      default:
        return {'hasComparison': false};
    }

    for (final t in allTransactions) {
      if (t.transactionType.trim().toLowerCase() != targetType) continue;

      final displayVal = _toDisplayAmount(t);
      if (!t.date.isBefore(curStart) && !t.date.isAfter(curEnd)) {
        currentAmount += displayVal;
      } else if (!t.date.isBefore(prevStart) && !t.date.isAfter(prevEnd)) {
        previousAmount += displayVal;
      }
    }

    if (currentAmount == 0.0 && previousAmount == 0.0) {
      return {'hasComparison': false};
    }

    if (previousAmount <= 0.0) {
      return {
        'hasComparison': true,
        'percentage': 100.0,
        'isIncrease': true,
        'isNew': true,
        'periodLabel': periodLabel,
      };
    }

    final double diff = currentAmount - previousAmount;
    final double percentage = (diff / previousAmount) * 100;

    return {
      'hasComparison': true,
      'percentage': percentage.abs(),
      'isIncrease': diff > 0,
      'isNew': false,
      'periodLabel': periodLabel,
    };
  }

  Widget _buildVelocityBadge({
    required Map<String, dynamic> comp,
    required dynamic colors,
    required bool isIncome,
  }) {
    if (comp['hasComparison'] != true) return const SizedBox.shrink();

    final bool isIncrease = comp['isIncrease'] == true;
    final bool isNew = comp['isNew'] == true;
    final double percentage = comp['percentage'] as double;
    final String period = comp['periodLabel'] as String;

    final bool isPositive = isIncome ? isIncrease : !isIncrease;
    final badgeColor = isPositive ? colors.income : colors.expense;
    final badgeBg = isPositive
        ? colors.incomeBackground
        : colors.expenseBackground;

    final String text = isNew
        ? "New vs $period"
        : "${percentage.toStringAsFixed(0)}% vs $period";

    return Container(
      margin: const EdgeInsets.only(
        top: 4,
      ), // 👈 Placed cleanly below the title
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIncrease
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 10,
            color: badgeColor,
          ),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Get Top 3-5 largest expenses for the period
  List<TransactionModel> get topExpenses {
    final expenses = filteredTransactions
        .where((t) => t.transactionType.trim().toLowerCase() == "expense")
        .toList();
    // Sort by converted display amount rather than raw heterogeneous amounts
    expenses.sort((a, b) => _toDisplayAmount(b).compareTo(_toDisplayAmount(a)));
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
                                color: colors.hero,
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
      color: context.colors.cardLight.withValues(alpha: 0.6),
    );
  }

  Widget _buildSlidingToggle({
    required String activeType,
    required ValueChanged<String> onChanged,
    required dynamic colors,
    double width = 170,
    double height = 32,
  }) {
    const types = ["expense", "income"];
    final selectedIndex = types.indexOf(activeType).clamp(0, 1);
    String? hoveredTab;

    return StatefulBuilder(
      builder: (context, setToggleState) {
        return SizedBox(
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colors.cardLight.withValues(alpha: 0.8),
                width: 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / types.length;

                  return Stack(
                    children: [
                      // 1. Sliding Active Purple Pill
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOutCubic,
                        left: selectedIndex * tabWidth,
                        top: 0,
                        bottom: 0,
                        width: tabWidth,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: hoveredTab == activeType
                                ? (colors.heroLight ?? colors.hero)
                                : colors.hero,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),

                      // 2. Interactive Buttons & Hover Targets
                      Row(
                        children: types.map((type) {
                          final isSelected = activeType == type;
                          final isHovered = hoveredTab == type;

                          return Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setToggleState(() => hoveredTab = type),
                              onExit: (_) =>
                                  setToggleState(() => hoveredTab = null),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (activeType != type) {
                                    onChanged(type);
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: !isSelected
                                        ? (isHovered
                                              ? colors.secondaryLight
                                              : colors.secondary)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    type == "expense" ? "Expenses" : "Income",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
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
    final activeTotal = isExpenseTab
        ? (summary['expense'] ?? 0.0)
        : (summary['income'] ?? 0.0);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),

            // Top Date Range Dropdown (Matching TransactionListScreen)
            Center(
              child: Builder(
                builder: (context) {
                  bool isHovered = false;
                  return StatefulBuilder(
                    builder: (context, setHoverState) {
                      return Builder(
                        builder: (buttonContext) {
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) =>
                                setHoverState(() => isHovered = true),
                            onExit: (_) =>
                                setHoverState(() => isHovered = false),
                            child: AnimatedContainer(
                              height: 38,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: isHovered
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
                                      buttonContext.findRenderObject()
                                          as RenderBox;
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
                      );
                    },
                  );
                },
              ),
            ),

            _buildTimeframeSlider(),
            // 👇 Full screen width divider directly under the slider
            _buildFullWidthDivider(),

            // Main Insights Scroll View
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.hero))
                  : ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // SECTION 1: METRICS FINANCIAL HEALTH CARD
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                          ), //padding: //EdgeInsets.zero, // 👈 updated here
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _buildSummaryRow(
                                "Income",
                                "$activeCurrencySymbol${summary['income']!.toStringAsFixed(2)}",
                                colors,
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryRow(
                                "Expenses",
                                "$activeCurrencySymbol${summary['expense']!.toStringAsFixed(2)}",
                                colors,
                              ),
                              Divider(
                                height: 24,
                                thickness: 1,
                                color: colors.cardLight.withValues(alpha: 0.6),
                              ),
                              _buildSummaryRow(
                                "Net Balance",
                                "$activeCurrencySymbol${summary['net']!.toStringAsFixed(2)}",
                                colors,
                              ),
                            ],
                          ),
                        ),
                        //const SizedBox(height: 24),

                        // SECTION 2: VELOCITY TREND (LINE CHART)
                        StatefulBuilder(
                          builder: (context, setVelocityState) {
                            final targetType = activeVelocityTab;
                            final Map<String, double> velocityData = {};

                            if (selectedRange == "This Month") {
                              final daysInMonth = DateUtils.getDaysInMonth(
                                activeDate.year,
                                activeDate.month,
                              );
                              for (int i = 1; i <= daysInMonth; i++) {
                                velocityData["$i"] = 0.0;
                              }
                              for (final t in filteredTransactions) {
                                if (t.transactionType.trim().toLowerCase() ==
                                    targetType) {
                                  final dayKey = "${t.date.day}";
                                  if (velocityData.containsKey(dayKey)) {
                                    velocityData[dayKey] =
                                        velocityData[dayKey]! +
                                        _toDisplayAmount(t);
                                  }
                                }
                              }
                            } else if (selectedRange == "This Year") {
                              const shortMonths = [
                                "Jan",
                                "Feb",
                                "Mar",
                                "Apr",
                                "May",
                                "Jun",
                                "Jul",
                                "Aug",
                                "Sep",
                                "Oct",
                                "Nov",
                                "Dec",
                              ];
                              for (final m in shortMonths) {
                                velocityData[m] = 0.0;
                              }
                              for (final t in filteredTransactions) {
                                if (t.transactionType.trim().toLowerCase() ==
                                    targetType) {
                                  final monthKey =
                                      shortMonths[t.date.month - 1];
                                  velocityData[monthKey] =
                                      velocityData[monthKey]! +
                                      _toDisplayAmount(t);
                                }
                              }
                            } else if (selectedRange == "This Week") {
                              const weekDays = [
                                "Mon",
                                "Tue",
                                "Wed",
                                "Thu",
                                "Fri",
                                "Sat",
                                "Sun",
                              ];
                              for (final d in weekDays) {
                                velocityData[d] = 0.0;
                              }
                              for (final t in filteredTransactions) {
                                if (t.transactionType.trim().toLowerCase() ==
                                    targetType) {
                                  final dayIndex = t.date.weekday - 1;
                                  final dayKey = weekDays[dayIndex];
                                  velocityData[dayKey] =
                                      velocityData[dayKey]! +
                                      _toDisplayAmount(t);
                                }
                              }
                            }

                            final isExpenseVelocity =
                                activeVelocityTab == "expense";

                            if (velocityData.isEmpty ||
                                !(selectedRange == "This Month" ||
                                    selectedRange == "This Year" ||
                                    selectedRange == "This Week")) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isExpenseVelocity
                                              ? "Spending Velocity"
                                              : "Earning Velocity",
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        _buildVelocityBadge(
                                          comp: getVelocityComparison(
                                            activeVelocityTab,
                                          ),
                                          colors: colors,
                                          isIncome: !isExpenseVelocity,
                                        ),
                                      ],
                                    ),
                                    _buildSlidingToggle(
                                      activeType: activeVelocityTab,
                                      colors: colors,
                                      onChanged: (val) {
                                        setVelocityState(
                                          () => activeVelocityTab = val,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 12.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.card,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: AppLineChart(
                                    data: velocityData,
                                    currencySymbol: activeCurrencySymbol,
                                    lineColor: isExpenseVelocity
                                        ? colors.hero
                                        : colors.income,
                                    height: 190,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        // SECTION 3: BREAKDOWN BY CATEGORY / SOURCE (PIE CHART)
                        StatefulBuilder(
                          builder: (context, setBreakdownState) {
                            final isExpense = activeBreakdownTab == "expense";

                            // Ensure data and totals are converted to the active currency
                            final rawData = isExpense ? categories : incomes;
                            final Map<String, double> currentData = rawData.map(
                              (k, v) => MapEntry(
                                k,
                                activeCurrencyRate > 0
                                    ? (v / activeCurrencyRate)
                                    : v,
                              ),
                            );

                            final rawTotal = isExpense
                                ? (summary['expense'] ?? 0.0)
                                : (summary['income'] ?? 0.0);
                            final double currentTotal = activeCurrencyRate > 0
                                ? (rawTotal / activeCurrencyRate)
                                : rawTotal;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      isExpense
                                          ? "Expense Breakdown"
                                          : "Income Breakdown",
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    _buildSlidingToggle(
                                      activeType: activeBreakdownTab,
                                      colors: colors,
                                      onChanged: (val) {
                                        setBreakdownState(
                                          () => activeBreakdownTab = val,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.card,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child:
                                      currentData.isEmpty || currentTotal <= 0
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 32.0,
                                          ),
                                          child: Center(
                                            child: Text(
                                              isExpense
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
                                          data: currentData,
                                          totalAmount: currentTotal,
                                          currencySymbol: activeCurrencySymbol,
                                          centerLabel: isExpense
                                              ? "Spent"
                                              : "Earned",
                                          showCategoryList: true,
                                        ),
                                ),
                              ],
                            );
                          },
                        ),
                        //const SizedBox(height: 24),
                        // SECTION 4: TOP LARGEST SPENDS
                        if (topSpends.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            "Top Spends",
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          //const SizedBox(height: 8),
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
                                thickness: 1,
                                color: colors.cardLight.withValues(alpha: 0.6),
                                indent: 16,
                                endIndent: 16,
                              ),
                              itemBuilder: (context, i) {
                                final t = topSpends[i];
                                final displayTitle =
                                    (t.merchant != null &&
                                        t.merchant!.trim().isNotEmpty)
                                    ? t.merchant!.trim()
                                    : (t.note != null &&
                                          t.note!.trim().isNotEmpty)
                                    ? t.note!.trim()
                                    : (t.category != null &&
                                          t.category!.trim().isNotEmpty)
                                    ? t.category!.trim()
                                    : "Expense";

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  title: Text(
                                    displayTitle,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatDate(t.date),
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: Text(
                                    "-$activeCurrencySymbol${_toDisplayAmount(t).toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: colors.expense,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          //const SizedBox(height: 24),
                        ],

                        // SECTION 5: PROFILE BREAKDOWN
                        if (profiles.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            "Profile Breakdown",
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                for (
                                  int i = 0;
                                  i < profiles.entries.length;
                                  i++
                                ) ...[
                                  if (i > 0) const SizedBox(height: 12),
                                  _buildSummaryRow(
                                    profiles.entries.elementAt(i).key,
                                    "$activeCurrencySymbol${profiles.entries.elementAt(i).value.toStringAsFixed(2)}",
                                    colors,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, dynamic colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
