import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TransactionOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const TransactionOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 10,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Modified Container to match the input fields exactly
            Container(
              height: 36,
              width: 36,
              decoration: const BoxDecoration(
                color: Colors.black, // Changed from AppColors.cardLight to black
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: Colors.white, // Changed from AppColors.purple to white
              ),
            ),

            const SizedBox(width: 14),

            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16, // Upgraded from 15 to match input field text size
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),

            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary, // Changed from textSecondary to textPrimary (White)
                fontSize: 14,
                fontWeight: FontWeight.w500, // Optio
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}