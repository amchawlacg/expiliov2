import 'package:flutter/material.dart';
import '../services/transaction_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final TransactionService transactionService = TransactionService();

  DateTime selectedMonth = DateTime.now();

  // Data states
  Map<String, double> monthlySummary = {'income': 0, 'expense': 0, 'net': 0};
  Map<String, double> categorySummary = {};
  Map<String, double> profileSummary = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllInsights();
  }

  Future<void> _loadAllInsights() async {
    setState(() => isLoading = true);

    final summary = await transactionService.getMonthlySummary(selectedMonth.month, selectedMonth.year);
    final categories = await transactionService.getCategorySummary(selectedMonth.month, selectedMonth.year);
    final profiles = await transactionService.getProfileSummary(selectedMonth.month, selectedMonth.year);

    setState(() {
      monthlySummary = summary;
      categorySummary = categories;
      profileSummary = profiles;
      isLoading = false;
    });
  }

  String _getMonthYearString(DateTime date) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return "${months[date.month - 1]} ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Insights")),
      body: Column(
        children: [
          // UNIFIED POPUP MENU HEADER SELECTOR
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
                      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
                    });
                    _loadAllInsights();
                  },
                ),

                // Unified Pop-up Menu Selector
                PopupMenuButton<DateTime>(
                  initialValue: DateTime(selectedMonth.year, selectedMonth.month, 1),
                  tooltip: "Select Month",
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getMonthYearString(selectedMonth),
                          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 24),
                      ],
                    ),
                  ),
                  onSelected: (DateTime selectedDate) {
                    setState(() {
                      selectedMonth = selectedDate;
                    });
                    _loadAllInsights();
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
                            fontWeight: (date.year == selectedMonth.year && date.month == selectedMonth.month)
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
                      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                    });
                    _loadAllInsights();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // INSIGHTS CONTENT AREA
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // SECTION 1: METRICS CARD
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSummaryRow("Income", "₹${monthlySummary['income']!.toStringAsFixed(2)}", Colors.green),
                        const SizedBox(height: 12),
                        _buildSummaryRow("Expenses", "₹${monthlySummary['expense']!.toStringAsFixed(2)}", Colors.red),
                        const Divider(height: 24),
                        _buildSummaryRow(
                            "Net Balance",
                            "₹${monthlySummary['net']!.toStringAsFixed(2)}",
                            monthlySummary['net']! >= 0 ? Colors.blue : Colors.orange
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 2: BREAKDOWN BY CATEGORY
                Text("Expenses by Category", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                categorySummary.isEmpty
                    ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No expenses logged this month.")))
                    : Card(
                  child: Column(
                    children: categorySummary.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.key),
                        trailing: Text("₹${entry.value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 3: BREAKDOWN BY PROFILE
                Text("Profile Breakdown", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                profileSummary.isEmpty
                    ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No profile data mapped.")))
                    : Card(
                  child: Column(
                    children: profileSummary.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.key),
                        trailing: Text("₹${entry.value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}