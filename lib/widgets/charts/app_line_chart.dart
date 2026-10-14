import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class AppLineChart extends StatefulWidget {
  /// Key: X label | Value: Pre-converted display amount in active currency
  final Map<String, double> data;
  final String currencySymbol;
  final Color? lineColor;
  final double height;
  final bool showCurvedLine;
  final Duration animationDuration;
  final EdgeInsetsGeometry padding;
  final bool showBottomTitles;

  const AppLineChart({
    super.key,
    required this.data,
    required this.currencySymbol, // 👈 Required: makes currency explicit and reusable
    this.lineColor,
    this.height = 220,
    this.showCurvedLine = true,
    this.animationDuration = const Duration(milliseconds: 1400),
    this.padding = EdgeInsets.zero,
    this.showBottomTitles = false,
  });

  @override
  State<AppLineChart> createState() => _AppLineChartState();
}

class _AppLineChartState extends State<AppLineChart>
    with SingleTickerProviderStateMixin {
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
      curve: Curves.easeInOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AppLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data)) {
      _controller.forward(from: 0.0);
    }
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
    final activeColor = widget.lineColor ?? colors.primary;
    final double maxY = values.reduce((a, b) => a > b ? a : b);
    final double minY = values.reduce((a, b) => a < b ? a : b);
    final int totalPoints = values.length;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        List<FlSpot> currentSpots = [];

        if (totalPoints == 1) {
          currentSpots = [FlSpot(0, values[0] * _animation.value)];
        } else {
          final currentXProgress = (totalPoints - 1) * _animation.value;

          for (int i = 0; i < totalPoints; i++) {
            if (i <= currentXProgress) {
              currentSpots.add(FlSpot(i.toDouble(), values[i]));
            } else if (i - 1 < currentXProgress && i > 0) {
              final fraction = currentXProgress - (i - 1);
              final interpolatedY =
                  values[i - 1] + (values[i] - values[i - 1]) * fraction;

              // Clamps intermediate edge to prevent drawing below the starting base value
              final clampedY = values[i] > values[i - 1]
                  ? math.max(values[i - 1], interpolatedY)
                  : math.min(values[i - 1], interpolatedY);

              currentSpots.add(FlSpot(currentXProgress, clampedY));
              break;
            }
          }
        }

        return Padding(
          padding: widget.padding,
          child: SizedBox(
            height: widget.height,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (totalPoints - 1).toDouble() > 0
                    ? (totalPoints - 1).toDouble()
                    : 1.0,
                minY: minY > 0 ? 0 : minY,
                maxY: maxY == 0 ? 10 : maxY,
                lineTouchData: LineTouchData(
                  enabled: _animation.isCompleted,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => colors.cardLight,
                    tooltipBorder: BorderSide(color: colors.border, width: 1),
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.round();
                        if (index < 0 || index >= keys.length) return null;
                        return LineTooltipItem(
                          '${keys[index]}\n',
                          TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${widget.currencySymbol}${spot.y.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 3 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colors.divider.withOpacity(0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: widget.showBottomTitles,
                      reservedSize: widget.showBottomTitles ? 28 : 0,
                      getTitlesWidget: (value, meta) {
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
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: currentSpots.isEmpty
                        ? [const FlSpot(0, 0)]
                        : currentSpots,
                    isCurved: widget.showCurvedLine,
                    curveSmoothness: 0.18,
                    preventCurveOverShooting: true,
                    preventCurveOvershootingThreshold: 2.0,
                    color: activeColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: values.length <= 10,
                      checkToShowDot: (spot, barData) {
                        return spot.x == spot.x.roundToDouble() &&
                            spot.x <= (totalPoints - 1) * _animation.value;
                      },
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: activeColor,
                        strokeWidth: 2,
                        strokeColor: colors.card,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          activeColor.withOpacity(0.28),
                          activeColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
        );
      },
    );
  }
}