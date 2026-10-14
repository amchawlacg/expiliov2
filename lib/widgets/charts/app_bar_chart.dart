import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class AppBarChart extends StatefulWidget {
  /// Key: "Mon", "Tue" etc. | Value: Final display amount in the active currency
  final Map<String, double> data;
  final String currencySymbol;
  final Color? barColor;
  final Color? touchedBarColor;
  final double height;
  final Duration animationDuration;

  const AppBarChart({
    super.key,
    required this.data,
    required this.currencySymbol, // 👈 Required: makes currency explicit
    this.barColor,
    this.touchedBarColor,
    this.height = 220,
    this.animationDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<AppBarChart> createState() => _AppBarChartState();
}

class _AppBarChartState extends State<AppBarChart>
    with SingleTickerProviderStateMixin {
  int touchedIndex = -1;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AppBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data)) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void disposeWidget() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (widget.data.isEmpty) return const SizedBox.shrink();

    final keys = widget.data.keys.toList();
    final values = widget.data.values.toList();
    final activeBarColor = widget.barColor ?? colors.primary;
    final activeTouchedColor =
        widget.touchedBarColor ?? colors.primary.withOpacity(0.7);

    final double maxY = values.reduce((a, b) => a > b ? a : b);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 10 : maxY * 1.15,
              minY: 0,
              barTouchData: BarTouchData(
                enabled: _animation.isCompleted,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => colors.cardLight,
                  tooltipBorder: BorderSide(color: colors.border, width: 1),
                  tooltipBorderRadius: BorderRadius.circular(8),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final index = group.x.toInt();
                    if (index < 0 || index >= keys.length) return null;

                    return BarTooltipItem(
                      '${keys[index]}\n',
                      TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${widget.currencySymbol}${values[index].toStringAsFixed(2)}',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                touchCallback: (FlTouchEvent event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.spot == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = response.spot!.touchedBarGroupIndex;
                  });
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index >= 0 &&
                          index < keys.length &&
                          value == index.toDouble()) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            keys[index],
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(keys.length, (i) {
                final animatedY = values[i] * _animation.value;

                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: animatedY,
                      color: i == touchedIndex
                          ? activeTouchedColor
                          : activeBarColor,
                      width: 14,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                  ],
                );
              }),
            ),
            duration: Duration.zero,
          ),
        );
      },
    );
  }
}