// Officer Card Widget
// Display officer information in card format

import 'package:flutter/material.dart';

class OfficerCardWidget extends StatelessWidget {
  final Map<String, dynamic> officer;
  final VoidCallback? onTap;

  const OfficerCardWidget({
    super.key,
    required this.officer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = officer['is_active'] == true;

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
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      const Color(0xFF1E88E5).withValues(alpha: 0.2),
                  child: Text(
                    (officer['full_name']?.toString() ?? 'O')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF1E88E5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        officer['full_name']?.toString() ?? 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        officer['officer_number']?.toString() ?? '',
                        style: const TextStyle(
                            color: Color(0xFF78909C), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF3CCB7F)
                        : const Color(0xFF78909C),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
                Icons.military_tech, officer['rank']?.toString() ?? 'N/A'),
            _buildInfoRow(
                Icons.business,
                officer['unit_name']?.toString() ??
                    officer['unit_id']?.toString() ??
                    'N/A'),
            if (officer['phone_number'] != null)
              _buildInfoRow(Icons.phone, officer['phone_number'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF78909C), size: 14),
          const SizedBox(width: 8),
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
