import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';

class TransactionOptionTile extends StatefulWidget {
  final String? svgAssetPath;
  final IconData? icon;
  final String title;
  final String? value;
  final Widget? trailingWidget;
  final VoidCallback onTap;

  const TransactionOptionTile({
    super.key,
    this.svgAssetPath,
    this.icon,
    required this.title,
    this.value,
    this.trailingWidget,
    required this.onTap,
  }) : assert(
         svgAssetPath != null || icon != null,
         'Either svgAssetPath or icon must be provided',
       );

  @override
  State<TransactionOptionTile> createState() => _TransactionOptionTileState();
}

class _TransactionOptionTileState extends State<TransactionOptionTile> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isHovering ? colors.cardLight : colors.card,
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
              padding: const EdgeInsets.all(8),
              child: Center(
                child: widget.svgAssetPath != null
                    ? SvgPicture.asset(
                        widget.svgAssetPath!,
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                          colors.textPrimary,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        widget.icon,
                        size: 20,
                        color: colors.textPrimary,
                      ),
              ),
            ),

            const SizedBox(width: 14),

            Text(
              widget.title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),

            if (widget.trailingWidget != null)
              widget.trailingWidget!
            else if (widget.value != null)
              Text(
                widget.value!,
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