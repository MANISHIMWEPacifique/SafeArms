// Anomaly Card Widget
// Display anomaly information in card format

import 'package:flutter/material.dart';
import '../utils/helpers.dart';
import '../utils/date_formatter.dart';

class AnomalyCardWidget extends StatelessWidget {
  final Map<String, dynamic> anomaly;
  final VoidCallback? onTap;

  const AnomalyCardWidget({
    super.key,
    required this.anomaly,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final severity = anomaly['severity']?.toString() ?? 'low';
    final sevColor = Helpers.severityColor(severity);
    final status = anomaly['status']?.toString() ?? 'open';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3040),
          border: Border.all(color: sevColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    severity.toUpperCase(),
                    style: TextStyle(
                      color: sevColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    Helpers.statusLabel(status),
                    style:
                        const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormatter.timeAgo(anomaly['detected_at']?.toString()),
                  style:
                      const TextStyle(color: Color(0xFF78909C), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              anomaly['anomaly_type']?.toString() ?? 'Unknown Anomaly',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDetail(
                    Icons.gps_fixed, anomaly['firearm_id']?.toString() ?? ''),
                const SizedBox(width: 16),
                _buildDetail(
                    Icons.person,
                    anomaly['officer_name']?.toString() ??
                        anomaly['officer_id']?.toString() ??
                        ''),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildDetail(
                    Icons.business,
                    anomaly['unit_name']?.toString() ??
                        anomaly['unit_id']?.toString() ??
                        ''),
                const Spacer(),
                Text(
                  'Score: ${(double.tryParse(anomaly['anomaly_score']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                      color: sevColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF78909C), size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
        ),
      ],
    );
  }
}
