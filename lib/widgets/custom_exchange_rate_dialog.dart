import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class CustomExchangeRateDialog {
  static Future<String?> show(
    BuildContext context, {
    required String initialRate,
    required String sourceCurrency,
    required String baseCurrency,
  }) {
    final colors = context.colors;
    final controller = TextEditingController(text: initialRate);

    bool isCancelHovered = false;
    bool isApplyHovered = false;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final confirmBaseColor = colors.heroBackground;//colors.heroShadow;
          final confirmTextColor = colors.hero;

          return AlertDialog(
            backgroundColor: colors.card,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            title: Text(
              "Custom Exchange Rate",
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            content: SizedBox(
              width: 320,
              child: Row(
                children: [
                  Text(
                    "1 $sourceCurrency =",
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.cardLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: "0.00",
                          hintStyle: TextStyle(
                            color: colors.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    baseCurrency,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
            actions: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel Pill
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => isCancelHovered = true),
                    onExit: (_) => setState(() => isCancelHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isCancelHovered
                            ? colors.cardLight
                            : colors.cardLight.withValues(alpha: 0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: Colors.transparent,
                          overlayColor: Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => Navigator.pop(ctx, null),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Apply Pill
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => isApplyHovered = true),
                    onExit: (_) => setState(() => isApplyHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isApplyHovered
                            ? confirmBaseColor
                            : confirmBaseColor.withValues(alpha: 0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: Colors.transparent,
                          overlayColor: Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          final trimmed = controller.text.trim();
                          Navigator.pop(ctx, trimmed.isNotEmpty ? trimmed : null);
                        },
                        child: Text(
                          "Apply",
                          style: TextStyle(
                            color: confirmTextColor,
                            fontWeight: FontWeight.w600,
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