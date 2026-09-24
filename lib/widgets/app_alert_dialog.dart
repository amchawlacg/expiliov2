import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppAlertDialog {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String cancelText = "Cancel",
    bool isDestructive = true,
  }) {
    final colors = context.colors;

    bool isCancelHovered = false;
    bool isConfirmHovered = false;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final confirmBaseColor = isDestructive
              ? colors.redLight
              : colors.purple.withValues(alpha: 0.15);
          final confirmTextColor = isDestructive ? colors.red : colors.purple;

          return AlertDialog(
            backgroundColor: colors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            title: Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            content: Text(
              message,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
            actions: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel Button (cardLight pill)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => isCancelHovered = true),
                    onExit: (_) => setState(() => isCancelHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isCancelHovered
                            ? Color.alphaBlend(
                                Colors.black.withValues(alpha: 0.15),
                                colors.cardLight,
                              )
                            : colors.cardLight,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18, // 👈 Increased internal vertical padding
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: Colors.transparent,
                          overlayColor: Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          cancelText,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Confirm Button (redLight / purple pill)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => isConfirmHovered = true),
                    onExit: (_) => setState(() => isConfirmHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isConfirmHovered
                            ? Color.alphaBlend(
                                Colors.black.withValues(alpha: 0.15),
                                confirmBaseColor,
                              )
                            : confirmBaseColor,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18, // 👈 Increased internal vertical padding
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: Colors.transparent,
                          overlayColor: Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          confirmText,
                          style: TextStyle(
                            color: confirmTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}