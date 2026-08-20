import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TransactionOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailingWidget;
  final VoidCallback onTap;

  const TransactionOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.trailingWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: colors.iconCircle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: colors.textPrimary,
              ),
            ),

            const SizedBox(width: 14),

            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),

            if (trailingWidget != null)
              trailingWidget!
            else if (value != null)
              Text(
                value!,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

            const SizedBox(width: 8),

            Icon(
              Icons.chevron_right,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}