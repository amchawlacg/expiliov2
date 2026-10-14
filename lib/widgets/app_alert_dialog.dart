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
              //: colors.purple.withValues(alpha: 0.15); aman
              : colors.heroShadow;
          final confirmTextColor = isDestructive ? colors.red : colors.hero;

          return AlertDialog(
            backgroundColor: colors.card,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24), // 👈 ADD THIS
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            title: Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            content: SizedBox( // 👈 WRAP IN SIZEDBOX
              width: 320,
              child: Text(
                message,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                ),
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
                        /*color: isCancelHovered
                            ? Color.alphaBlend(
                                Colors.black.withValues(alpha: 0.15),
                                colors.cardLight,
                              )
                            : colors.cardLight,*/
                        color: isCancelHovered
                                        ? colors.cardLight
                                        : colors.cardLight.withValues(alpha: 0),
                                    borderRadius: BorderRadius.circular(999),
                        
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
                            fontWeight: FontWeight.w500,
                            //fontSize: 13,
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
                                        ? confirmBaseColor
                                        : confirmBaseColor.withValues(alpha: 0),
                                    borderRadius: BorderRadius.circular(999),
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
                            //fontSize: 13,
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