// Firearm Card Widget
// Display firearm information in card format

import 'package:flutter/material.dart';
import '../utils/helpers.dart';

class FirearmCardWidget extends StatelessWidget {
  final Map<String, dynamic> firearm;
  final VoidCallback? onTap;

  const FirearmCardWidget({
    super.key,
    required this.firearm,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = firearm['current_status']?.toString() ?? 'unknown';
    final statusColor = Helpers.statusColor(status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3040),
          border: Border.all(color: const Color(0xFF37404F)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Helpers.firearmTypeIcon(firearm['firearm_type']?.toString()),
                  color: const Color(0xFF1E88E5),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    firearm['serial_number']?.toString() ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    Helpers.statusLabel(status),
                    style: TextStyle(color: statusColor, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Type',
                Helpers.statusLabel(firearm['firearm_type']?.toString())),
            _buildInfoRow('Model',
                '${firearm['manufacturer'] ?? ''} ${firearm['model'] ?? ''}'),
            _buildInfoRow('Caliber', firearm['caliber']?.toString() ?? 'N/A'),
            if (firearm['unit_name'] != null)
              _buildInfoRow('Unit', firearm['unit_name'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
