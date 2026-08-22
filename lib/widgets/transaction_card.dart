import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../constants/app_colors.dart';

class TransactionCard extends StatefulWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<TransactionCard> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final isExpense = transaction.transactionType.toLowerCase() == "expense";
    final colors = context.colors;

    // 1. Setup colors & indicators based on income/expense dynamic
    final accentColor = isExpense ? colors.expense : colors.income;

    return InkWell(
  onTap: widget.onTap,
  hoverColor: Colors.transparent,
  splashColor: Colors.transparent,
  highlightColor: Colors.transparent,
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
    decoration: BoxDecoration(
      color: colors.card,
    ),
    child: Row(
      children: [
        // Left-edge Type Indicator Bar
        const SizedBox(width: 12),

        // Circular Icon Avatar
        CircleAvatar(
          radius: 22,
          backgroundColor: _getCategoryColor(
            transaction.category ?? "",
          ).withOpacity(0.15),
          child: Icon(
            _categoryIcon(transaction.category ?? ""),
            color: _getCategoryColor(transaction.category ?? ""),
            size: 20,
          ),
        ),

        const SizedBox(width: 14),

        // Middle details cluster
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                transaction.category ?? "Unknown",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (transaction.merchant?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  transaction.merchant!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              // Horizontal meta row (Date | Method | Source)
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${transaction.date.day} ${_getMonthName(transaction.date.month)} ${transaction.date.year}",
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    "  |  ",
                    style: TextStyle(
                      color: colors.textSecondary.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                  Icon(
                    _getPaymentIcon(transaction.paymentMethod),
                    size: 12,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    transaction.paymentMethod ?? "Cash",
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Right Action / Amount Layout Block
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${isExpense ? "-" : "+"}\$${transaction.amount}",
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
  }

  // Helper parsing methods
  String _getMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }

  IconData _getPaymentIcon(String? method) {
    switch (method?.toLowerCase()) {
      case 'credit card':
      case 'debit card':
        return Icons.credit_card;
      case 'bank transfer':
        return Icons.account_balance;
      default:
        return Icons.payments;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case "grocery shopping":
      case "shopping":
        return Icons.shopping_cart;
      case "fuel":
      case "travel":
        return Icons.local_gas_station;
      case "salary":
      case "business":
        return Icons.work;
      case "dinner with friends":
      case "food":
        return Icons.restaurant;
      default:
        return Icons.account_balance_wallet;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case "food":
      case "dinner with friends":
        return AppColors.food;
      case "shopping":
        return AppColors.shopping;
      case "travel":
        return AppColors.travel;
      case "entertainment":
        return AppColors.entertainment;
      case "business":
        return AppColors.business;
      case "salary":
        return AppColors.salary;
      case "fuel":
        return AppColors.fuel;
      case "health":
        return AppColors.health;
      case "grocery shopping":
      case "groceries":
        return AppColors.groceries;
      case "education":
        return AppColors.education;
      case "bills":
        return AppColors.bills;
      case "investments":
        return AppColors.investments;
      case "gifts":
        return AppColors.gifts;
      case "transport":
        return AppColors.transport;
      case "rent":
        return AppColors.rent;
      default:
        return AppColors.defaultCategory;
    }
  }
}
