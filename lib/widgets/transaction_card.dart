import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // 👈 Added flutter_svg
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

  Color _getAmountColor(BuildContext context, String type) {
    final colors = context.colors;
    switch (type.toLowerCase()) {
      case 'income':
        return colors.income;
      case 'expense':
        return colors.expense;
      case 'transfer':
      default:
        return colors.textPrimary;
    }
  }

  String _getAmountText(TransactionModel transaction) {
    final type = transaction.transactionType.toLowerCase();
    if (type == 'income') {
      return "+₹${transaction.amount}";
    } else if (type == 'expense') {
      return "-₹${transaction.amount}";
    } else {
      return "⇄ ₹${transaction.amount}";
    }
  }

  String _getTitle(TransactionModel transaction) {
    if (transaction.merchant?.trim().isNotEmpty == true) {
      return transaction.merchant!.trim();
    }
    if (transaction.subCategory?.trim().isNotEmpty == true) {
      return transaction.subCategory!.trim();
    }
    return transaction.category ?? "Unknown";
  }

  String _getCategoryIconPath(String? category, String? subCategory) {
    const String baseCat = 'assets/icons/categories';
    const String baseSub = 'assets/icons/subcategories';

    // Normalize name to snake_case format (e.g. "Public Transport" -> "public_transport")
    final sub = subCategory?.trim().toLowerCase().replaceAll(' ', '_');
    final cat = category?.trim().toLowerCase().replaceAll(' ', '_');

    // 1. Check Subcategory (exclude generic "other")
    if (sub != null && sub.isNotEmpty && sub != 'other') {
      return '$baseSub/$sub.svg';
    }

    // 2. Fall back to Parent Category
    if (cat != null && cat.isNotEmpty && cat != 'other') {
      return '$baseCat/$cat.svg';
    }

    // 3. Ultimate Fallback
    return '$baseCat/other.svg';
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final colors = context.colors;

    final bool isTitleSubCategory =
        (transaction.merchant?.trim().isEmpty ?? true) &&
        (transaction.subCategory?.trim().isNotEmpty ?? false);

    final bool showSubCategoryInMeta =
        !isTitleSubCategory &&
        (transaction.subCategory?.trim().isNotEmpty ?? false);

    final categoryColor = _getCategoryColor(transaction.category ?? "");

    return InkWell(
      onTap: widget.onTap,
      onHover: (hovering) {
        setState(() {
          isHovering = hovering;
        });
      },
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: BoxDecoration(
          color: isHovering ? colors.cardLight : colors.card,
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),

            // Circular SVG Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: categoryColor.withOpacity(0.15),
              child: SvgPicture.asset(
                _getCategoryIconPath(
                  transaction.category,
                  transaction.subCategory,
                ),
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(
                  categoryColor,
                  BlendMode.srcIn,
                ),
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
                    _getTitle(transaction),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Horizontal meta row (Date | Subcategory)
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
                      if (showSubCategoryInMeta) ...[
                        Text(
                          "  |  ",
                          style: TextStyle(
                            color: colors.textSecondary.withOpacity(0.3),
                            fontSize: 11,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            transaction.subCategory!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
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
                    _getAmountText(transaction),
                    style: TextStyle(
                      color: _getAmountColor(
                        context,
                        transaction.transactionType,
                      ),
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case "food":
      case "dinner with friends":
        return AppColors.food;
      case "shopping":
        return AppColors.shopping;
      case "travel":
      case "transport":
        return AppColors.transport;
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
      case "loan":
        return AppColors.loan;
      case "other":
        return AppColors.other;
      case "investments":
        return AppColors.investments;
      case "gifts":
        return AppColors.gifts;
      case "rent":
        return AppColors.rent;
      default:
        return AppColors.defaultCategory;
    }
  }
}