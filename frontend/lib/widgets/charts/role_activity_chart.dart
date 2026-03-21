import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/dashboard_provider.dart';

class RoleActivityChart extends StatefulWidget {
  const RoleActivityChart({super.key});

  @override
  State<RoleActivityChart> createState() => _RoleActivityChartState();
}

class _RoleActivityChartState extends State<RoleActivityChart> {
  String _selectedPeriod = 'Weekly';

  final Map<String, Color> _roleColors = {
    'admin': const Color(0xFF185FA5), // Blue
    'hq_firearm_commander': const Color(0xFF0F6E56), // Green
    'station_commander': const Color(0xFFBA7517), // Amber
    'investigator': const Color(0xFF534AB7), // Purple
  };

  final Map<String, String> _roleNames = {
    'admin': 'System Admin',
    'hq_firearm_commander': 'HQ Commander',
    'station_commander': 'Station Commander',
    'investigator': 'Investigator',
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashProvider, _) {
        final activityData = dashProvider.roleActivity;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Period Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'User Role Activity',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildPeriodSelector(),
                ],
              ),
              const SizedBox(height: 32),

              // Chart Body
              SizedBox(
                height: 300,
                child: dashProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                        color: Color(0xFF1E88E5),
                      ))
                    : activityData.isEmpty
                        ? const Center(
                            child: Text(
                              'No activity recorded.',
                              style: TextStyle(color: Color(0xFF78909C)),
                            ),
                          )
                        : _buildLineChart(activityData),
              ),

              const SizedBox(height: 24),
              // Custom Legend
              _buildLegend(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Daily', 'Weekly', 'Monthly'].map((period) {
          final isSelected = _selectedPeriod == period;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                period,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFB0BEC5),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart(List<dynamic> rawData) {
    // Determine cutoff based on period
    final now = DateTime.now();
    late DateTime cutoff;
    if (_selectedPeriod == 'Daily') {
      cutoff = now.subtract(const Duration(days: 14)); // Last 14 days
    } else if (_selectedPeriod == 'Weekly') {
      cutoff = now.subtract(const Duration(days: 42)); // Last 6 weeks
    } else {
      cutoff = now.subtract(const Duration(days: 90)); // Last 3 months
    }

    // Process data points directly in memory
    final parsedMap = <String, Map<String, double>>{};

    // Initialize required roles
    for (var r in _roleColors.keys) {
      parsedMap[r] = {};
    }

    final periodLabels = <String>{};

    for (var item in rawData) {
      if (item['activity_date'] == null || item['actor_role'] == null) continue;

      final date = DateTime.tryParse(item['activity_date'].toString());
      if (date == null || date.isBefore(cutoff)) continue;

      final role = item['actor_role'].toString();
      if (!_roleColors.containsKey(role)) continue;

      final val = double.tryParse(item['actions_count'].toString()) ?? 0;
      final timeKey = _formatDateKey(date);

      periodLabels.add(timeKey);
      parsedMap[role]![timeKey] = (parsedMap[role]![timeKey] ?? 0) + val;
    }

    final sortedLabels = periodLabels.toList()..sort();

    final lineBarsData = <LineChartBarData>[];
    double maxY = 10; // Baseline max

    parsedMap.forEach((role, pointsMap) {
      final spots = <FlSpot>[];
      for (int i = 0; i < sortedLabels.length; i++) {
        final val = pointsMap[sortedLabels[i]] ?? 0;
        if (val > maxY) maxY = val;
        spots.add(FlSpot(i.toDouble(), val));
      }

      lineBarsData.add(LineChartBarData(
        spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
        isCurved: true,
        color: _roleColors[role],
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: _roleColors[role]!.withOpacity(0.1),
        ),
      ));
    });

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 50 ? maxY / 5 : 5,
          getDrawingHorizontalLine: (value) => const FlLine(
            color: Color(0xFF37404F),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedLabels.length)
                  return const SizedBox();
                // show every 2nd label if there are too many (e.g. daily view)
                if (sortedLabels.length > 8 && index % 2 != 0)
                  return const SizedBox();

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    sortedLabels[index],
                    style:
                        const TextStyle(color: Color(0xFF78909C), fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY > 50 ? maxY / 5 : 5,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (sortedLabels.length - 1).toDouble().clamp(0.0, double.infinity),
        minY: 0,
        maxY: maxY * 1.1, // Gives some breathing room at the top
        lineBarsData: lineBarsData,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            // Specify exact colors and shapes for the tooltip
            tooltipBgColor: const Color(0xFF1A1F2E).withOpacity(0.9),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final roleIndex = lineBarsData.indexOf(spot.bar);
                final roleKey = _roleColors.keys.elementAt(roleIndex);
                final color = _roleColors[roleKey]!;
                return LineTooltipItem(
                  '${_roleNames[roleKey]}: ${spot.y.toInt()}',
                  TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  String _formatDateKey(DateTime date) {
    if (_selectedPeriod == 'Daily') {
      return DateFormat('MMM d').format(date);
    } else if (_selectedPeriod == 'Weekly') {
      // Group by Week of Year
      int week = ((date.day - date.weekday + 10) / 7).floor();
      return 'Wk $week, ${DateFormat('MMM').format(date)}';
    } else {
      return DateFormat('MMM yyyy').format(date); // Monthly
    }
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: _roleColors.entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: entry.value, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              _roleNames[entry.key]!,
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }
}
