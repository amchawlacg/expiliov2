import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart'; // 👈 ADD THIS IMPORT
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class AppPieChart extends StatefulWidget {
  final Map<String, double> data;
  final double totalAmount;
  final String centerLabel;
  final String currencySymbol;
  final List<Color>? customColors;
  final Map<String, Color>? colorMap;
  final Duration animationDuration;
  final bool showCategoryList;
  final EdgeInsetsGeometry padding; // 👈 Allows manual control of outer padding/margin

  const AppPieChart({
    super.key,
    required this.data,
    required this.totalAmount,
    this.centerLabel = "Total",
    this.currencySymbol = "₹",
    this.customColors,
    this.colorMap,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.showCategoryList = true,
    this.padding = EdgeInsets.zero, // Default: zero padding
  });

  @override
  State<AppPieChart> createState() => _AppPieChartState();
}

class _AppPieChartState extends State<AppPieChart>
    with SingleTickerProviderStateMixin {
  int touchedIndex = -1;
  late AnimationController _controller;
  late Animation<double> _animation;

  static const List<Color> _defaultPalette = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF06B6D4), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF3B82F6), // Blue
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.forward();
  }

  // WITH THIS:
  @override
  void didUpdateWidget(covariant AppPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dataChanged = !mapEquals(oldWidget.data, widget.data);
    final totalChanged = oldWidget.totalAmount != widget.totalAmount;

    if (dataChanged || totalChanged) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getSliceColor(String key, int index, List<Color> palette) {
    if (widget.colorMap != null && widget.colorMap!.containsKey(key)) {
      return widget.colorMap![key]!;
    }
    return palette[index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (widget.data.isEmpty || widget.totalAmount <= 0) {
      return const SizedBox.shrink();
    }

    final palette = widget.customColors ?? _defaultPalette;
    final entries = widget.data.entries.toList();

    // Dynamically match container height to the exact circle diameter
    const double centerRadius = 55.0;
    const double maxSliceRadius = 38.5; // Max expanded radius on touch
    const double chartDiameter = (centerRadius + maxSliceRadius) * 2; // 187px

    return Padding(
      padding: widget.padding, // 👈 Outer manual padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pie Chart Area with Sweep Animation
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final currentAnimatedTotal = widget.totalAmount * _animation.value;
              double accumulated = 0.0;
              double drawnAmountSoFar = 0.0;

              final List<PieChartSectionData> sections = [];

              for (int i = 0; i < entries.length; i++) {
                final targetValue = entries[i].value;
                final sectionStart = accumulated;
                final sectionEnd = accumulated + targetValue;
                accumulated += targetValue;

                double animatedValue = 0.0;
                if (currentAnimatedTotal >= sectionEnd) {
                  animatedValue = targetValue;
                } else if (currentAnimatedTotal > sectionStart) {
                  animatedValue = currentAnimatedTotal - sectionStart;
                }

                if (animatedValue > 0) {
                  drawnAmountSoFar += animatedValue;

                  final isTouched = i == touchedIndex;
                  final fontSize = 10.0;
                  final radius = isTouched ? maxSliceRadius : 36.0;
                  final percentage = (targetValue / widget.totalAmount) * 100;
                  final sliceColor = _getSliceColor(entries[i].key, i, palette);

                  final isFullyExtended = (animatedValue / targetValue) > 0.85;

                  sections.add(
                    PieChartSectionData(
                      color: sliceColor,
                      value: animatedValue,
                      title: (percentage >= 5 && isFullyExtended)
                          ? "${percentage.toStringAsFixed(0)}%"
                          : "",
                      radius: radius,
                      titleStyle: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                }
              }

              // Fill remainder to hold scale and sweep sequence
              final remainingAmount = widget.totalAmount - drawnAmountSoFar;
              if (remainingAmount > 0.0001) {
                sections.add(
                  PieChartSectionData(
                    value: remainingAmount,
                    color: Colors.transparent,
                    radius: 36.0,
                    showTitle: false,
                  ),
                );
              }

              // Calculate hovered metadata for the donut hole
              final isSliceHovered =
                  touchedIndex >= 0 && touchedIndex < entries.length;
              final hoveredEntry = isSliceHovered ? entries[touchedIndex] : null;

              final topCenterText = hoveredEntry != null
                  ? "${hoveredEntry.key} (${((hoveredEntry.value / widget.totalAmount) * 100).toStringAsFixed(0)}%)"
                  : widget.centerLabel;

              final centerAmountText = hoveredEntry != null
                  ? "${widget.currencySymbol}${hoveredEntry.value.toStringAsFixed(0)}"
                  : "${widget.currencySymbol}${(widget.totalAmount * _animation.value).toStringAsFixed(0)}";

              return SizedBox(
                height: chartDiameter, // 👈 Snugs tight to 187px, removing the vertical dead zone
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                touchedIndex = -1;
                                return;
                              }
                              final targetIdx = pieTouchResponse
                                  .touchedSection!.touchedSectionIndex;
                              if (targetIdx >= 0 && targetIdx < entries.length) {
                                touchedIndex = targetIdx;
                              } else {
                                touchedIndex = -1;
                              }
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 3,
                        centerSpaceRadius: centerRadius,
                        startDegreeOffset: -90,
                        sections: sections,
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 250),
                      swapAnimationCurve: Curves.easeOutCubic,
                    ),
                    SizedBox(
                      width: 82,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            topCenterText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              centerAmountText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Bottom Category Rows with Color Indicator Boxes
          if (widget.showCategoryList) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: colors.divider?.withValues(alpha: 0.5) ?? Colors.grey.shade200,
            ),
            ListView.separated(
              itemCount: entries.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final sliceColor = _getSliceColor(entry.key, index, palette);
                final percentage = widget.totalAmount > 0
                    ? (entry.value / widget.totalAmount * 100).toStringAsFixed(0)
                    : "0";

                final isThisHovered = index == touchedIndex;
                final hasActiveHover =
                    touchedIndex >= 0 && touchedIndex < entries.length;
                final itemOpacity =
                    hasActiveHover ? (isThisHovered ? 1.0 : 0.35) : 1.0;

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  opaque: true,
                  onEnter: (_) => setState(() => touchedIndex = index),
                  onExit: (_) => setState(() => touchedIndex = -1),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: itemOpacity,
                    child: Row(
                      children: [
                        // Rectangular Color Indicator Box
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: sliceColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Category Name & Percentage
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  entry.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isThisHovered
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "$percentage%",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Amount
                        Text(
                          "${widget.currencySymbol}${entry.value.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}                                                                                         