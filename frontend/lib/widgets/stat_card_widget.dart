// Stat Card Widget
// Statistics card component for dashboards

import 'package:flutter/material.dart';

class StatCardWidget extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String number;
  final String label;
  final String trend;
  final Color trendColor;
  final bool showUpArrow;
  final bool isLoading;
  final VoidCallback? onTap;

  const StatCardWidget({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.number,
    required this.label,
    this.trend = '',
    this.trendColor = const Color(0xFF78909C),
    this.showUpArrow = false,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3040),
          border: Border.all(color: const Color(0xFF37404F)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 16),
            isLoading
                ? const SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1E88E5),
                    ),
                  )
                : Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
            ),
            if (trend.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (showUpArrow)
                    Icon(Icons.trending_up, color: trendColor, size: 16),
                  if (showUpArrow) const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      trend,
                      style: TextStyle(color: trendColor, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
