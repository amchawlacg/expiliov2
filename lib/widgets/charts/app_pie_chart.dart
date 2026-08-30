import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class AppPieChart extends StatefulWidget {
  final Map<String, double> data;
  final double totalAmount;
  final String centerLabel;
  final String currencySymbol;
  final List<Color>? customColors;
  final Map<String, Color>? colorMap; // Optional explicit key -> color mapping
  final Duration animationDuration;
  final bool showCategoryList; // Set to true to show the legend list below the chart

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
  });

  @override
  State<AppPieChart> createState() => _AppPieChartState();
}

class _AppPieChartState extends State<AppPieChart>
    with SingleTickerProviderStateMixin {
  int touchedIndex = -1;
  late AnimationController _controller;
  late Animation<double> _animation;

  // Generic ordered palette: 1st slice gets [0], 2nd gets [1], etc.
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

  @override
  void didUpdateWidget(covariant AppPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.totalAmount != widget.totalAmount) {
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

    return Column(
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
                final fontSize = isTouched ? 13.0 : 10.0;
                final radius = isTouched ? 42.0 : 36.0;
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

            return SizedBox(
              height: 200,
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
                            touchedIndex = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 55,
                      startDegreeOffset: -90, // Starts clockwise from top (12 o'clock)
                      sections: sections,
                    ),
                    swapAnimationDuration: Duration.zero,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.centerLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${widget.currencySymbol}${(widget.totalAmount * _animation.value).toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        // Bottom Category Rows with Color Indicator Boxes
        if (widget.showCategoryList) ...[
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 1,
            color: colors.divider?.withOpacity(0.5) ?? Colors.grey.shade200,
          ),
          const SizedBox(height: 12),
          ListView.separated(
            itemCount: entries.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final sliceColor = _getSliceColor(entry.key, index, palette);
              final percentage = widget.totalAmount > 0
                  ? (entry.value / widget.totalAmount * 100).toStringAsFixed(0)
                  : "0";

              return Row(
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
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}