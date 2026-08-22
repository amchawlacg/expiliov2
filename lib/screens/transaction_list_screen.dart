import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';
import 'add_transaction_screen.dart';
import 'chat_screen.dart';
import 'calendar_screen.dart';
import 'insights_screen.dart';
import '../widgets/transaction_card.dart';
import '../constants/app_colors.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final TransactionService transactionService = TransactionService();

  List<TransactionModel> transactions = [];

  @override
  void initState() {
    super.initState();

    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final data = await transactionService.getTransactions();

    setState(() {
      transactions = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          "Transactions",
          style: TextStyle(color: colors.textPrimary),
        ),

        actions: [
          // 1. NEW INSIGHTS BUTTON
          IconButton(
            icon: Icon(Icons.bar_chart, color: colors.textSecondary),
            tooltip: "Insights",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InsightsScreen()),
              );
              // Refreshing data when returning just in case
              loadTransactions();
            },
          ),

          // Existing Chat Button
          IconButton(
            icon: Icon(Icons.chat, color: colors.textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatScreen()),
              );
            },
          ),

          // Existing Calendar Button
          IconButton(
            icon: Icon(Icons.calendar_month, color: colors.textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              );
            },
          ),
        ],
      ),

      body: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: transactions.length,

        itemBuilder: (context, index) {
          final transaction = transactions[index];

          return TransactionCard(
            transaction: transaction,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddTransactionScreen(transaction: transaction),
                ),
              );
              loadTransactions();
            },

            onDelete: () async {
              await transactionService.deleteTransaction(transaction.id!);
              loadTransactions();
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.purple,
        child: Icon(Icons.add, color: colors.background),

        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
          loadTransactions();
        },
      ),
    );
  }
}
