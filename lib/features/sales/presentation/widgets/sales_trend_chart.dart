import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/sale_model.dart';

class SalesTrendChart extends StatelessWidget {
  final List<SaleModel> sales;

  const SalesTrendChart({
    super.key,
    required this.sales,
  });

  @override
  Widget build(BuildContext context) {
    // Group sales by date for the last 7 days
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (i) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
    });

    final Map<String, double> revenueByDay = {};
    for (final day in last7Days) {
      final key = day.toIso8601String().split('T')[0];
      revenueByDay[key] = 0.0;
    }

    for (final s in sales) {
      if (s.isCompleted && revenueByDay.containsKey(s.date)) {
        revenueByDay[s.date] = (revenueByDay[s.date] ?? 0.0) + s.grandTotal;
      }
    }

    final spots = <FlSpot>[];
    double maxRevenue = 1000.0;
    int index = 0;

    for (final day in last7Days) {
      final key = day.toIso8601String().split('T')[0];
      final rev = revenueByDay[key] ?? 0.0;
      if (rev > maxRevenue) maxRevenue = rev;
      spots.add(FlSpot(index.toDouble(), rev));
      index++;
    }

    final maxY = (maxRevenue * 1.2).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '7-Day Sales Trend',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Text(
                'Peak: ${CurrencyFormatter.format(maxRevenue)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.borderLight, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox.shrink();
                        return Text(
                          CurrencyFormatter.formatCompact(val),
                          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < last7Days.length) {
                          final d = last7Days[idx];
                          final label = '${d.day}/${d.month}';
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

