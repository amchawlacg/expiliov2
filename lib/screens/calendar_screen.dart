import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final TransactionService transactionService = TransactionService();

  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();
  List<TransactionModel> transactions = [];

  // Cache for daily totals: Key is normalized DateTime, Value is net amount
  Map<DateTime, double> dailyTotals = {};

  // Define calendar boundaries
  final DateTime _firstDay = DateTime(2000);
  final DateTime _lastDay = DateTime(2100);

  @override
  void initState() {
    super.initState();
    loadMonthData(focusedDay);
    loadTransactions();
  }

  // Helper to strip time components for accurate Map lookups
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Formats date to "June 2026" text for the custom header
  String _getMonthYearString(DateTime date) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return "${months[date.month - 1]} ${date.year}";
  }

  // Opens the date picker when you click the month/year text
  // Opens a direct, compact dropdown list selector for Month and Year
  Future<void> _selectMonthYear(BuildContext context) async {
    int tempYear = focusedDay.year;
    int tempMonth = focusedDay.month;

    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];

    await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Select Month & Year"),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Month Dropdown Selection List
                  Expanded(
                    child: DropdownButton<int>(
                      value: tempMonth,
                      isExpanded: true,
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text(months[index]),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => tempMonth = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Year Dropdown Selection List
                  Expanded(
                    child: DropdownButton<int>(
                      value: tempYear,
                      isExpanded: true,
                      items: List.generate(101, (index) {
                        int yearValue = 2000 + index; // from 2000 to 2100
                        return DropdownMenuItem(
                          value: yearValue,
                          child: Text("$yearValue"),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => tempYear = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, DateTime(tempYear, tempMonth, 1));
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    ).then((DateTime? picked) {
      // Apply the selected month/year to the calendar view state
      if (picked != null) {
        setState(() {
          focusedDay = picked;
          selectedDay = picked;
        });
        loadMonthData(picked);
        loadTransactions();
      }
    }); // <-- This cleanly terminates the .then structure
  }

  // 1. Fetch transaction metadata for the visible month to highlight days
  Future<void> loadMonthData(DateTime month) async {
    final data = await transactionService.getDailyTotalsForMonth(month);

    setState(() {
      // Ensure all keys in the map are normalized
      dailyTotals = data.map((key, value) => MapEntry(_normalizeDate(key), value));
    });
  }

  // 2. Fetch specific transactions for the selected day list
  Future<void> loadTransactions() async {
    final data = await transactionService.getTransactionsByDate(selectedDay);
    setState(() {
      transactions = data;
    });
  }

  // Helper to determine cell background color based on balance
  Color? _getDayColor(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    if (!dailyTotals.containsKey(normalizedDay)) return null;

    double balance = dailyTotals[normalizedDay]!;
    if (balance > 0) {
      return Colors.green.withOpacity(0.2); // Net Earnings
    } else if (balance < 0) {
      return Colors.red.withOpacity(0.2); // Net Spending
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Calendar"),
      ),
      body: Column(
        children: [
          // 1. THIS IS THE NEW INTERACTIVE HEADER THAT REPLACES THE OLD ONE
          // REPLACE THE ENTIRE FIRST PADDING CHILD INSIDE THE COLUMN WITH THIS:
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Arrow Button
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      focusedDay = DateTime(focusedDay.year, focusedDay.month - 1, 1);
                    });
                    loadMonthData(focusedDay);
                  },
                ),

                // Unified Pop-up Menu Selector
                PopupMenuButton<DateTime>(
                  initialValue: DateTime(focusedDay.year, focusedDay.month, 1),
                  tooltip: "Select Month",
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getMonthYearString(focusedDay),
                          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 24),
                      ],
                    ),
                  ),
                  onSelected: (DateTime selectedDate) {
                    setState(() {
                      focusedDay = selectedDate;
                      selectedDay = selectedDate;
                    });
                    loadMonthData(selectedDate);
                    loadTransactions();
                  },
                  itemBuilder: (BuildContext context) {
                    final int currentYear = DateTime.now().year;
                    final List<DateTime> menuDates = [];

                    // Generates options for last year, current year, and next year
                    for (int y = currentYear - 1; y <= currentYear + 1; y++) {
                      for (int m = 1; m <= 12; m++) {
                        menuDates.add(DateTime(y, m, 1));
                      }
                    }

                    return menuDates.map((DateTime date) {
                      return PopupMenuItem<DateTime>(
                        value: date,
                        child: Text(
                          _getMonthYearString(date),
                          style: TextStyle(
                            fontWeight: (date.year == focusedDay.year && date.month == focusedDay.month)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList();
                  },
                ),

                // Right Arrow Button
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      focusedDay = DateTime(focusedDay.year, focusedDay.month + 1, 1);
                    });
                    loadMonthData(focusedDay);
                  },
                ),
              ],
            ),
          ),

          // 2. THE CALENDAR GRID
          TableCalendar(
            firstDay: _firstDay,
            lastDay: _lastDay,
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),

            // CRITICAL LINE: This hides the built-in header you see in your screenshot
            headerVisible: false,

            onPageChanged: (focused) {
              setState(() {
                focusedDay = focused;
              });
              loadMonthData(focused);
            },

            onDaySelected: (selected, focused) {
              setState(() {
                selectedDay = selected;
                focusedDay = focused;
              });
              loadTransactions();
            },

            calendarBuilders: CalendarBuilders(
              // Custom style for colored unselected days
              defaultBuilder: (context, day, focusedDay) {
                final cellColor = _getDayColor(day);
                if (cellColor != null) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cellColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text('${day.day}'),
                  );
                }
                return null;
              },

              // Custom style for today's date highlighting
              todayBuilder: (context, day, focusedDay) {
                final cellColor = _getDayColor(day);
                return Container(
                  margin: const EdgeInsets.all(4.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cellColor,
                    border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // 3. TRANSACTIONS LIST BELOW
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text("No transactions for this day"))
                : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return ListTile(
                  title: Text("${transaction.category} - ₹${transaction.amount}"),
                  subtitle: Text(transaction.note ?? ""),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}