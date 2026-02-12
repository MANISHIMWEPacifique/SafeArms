// Helper Functions
// General utility and helper functions

import 'package:flutter/material.dart';

class Helpers {
  /// Get a display-friendly status label
  static String statusLabel(String? status) {
    if (status == null || status.isEmpty) return 'Unknown';
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
            (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  /// Get color for firearm status
  static Color statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return const Color(0xFF3CCB7F);
      case 'in_custody':
        return const Color(0xFF42A5F5);
      case 'maintenance':
        return const Color(0xFFFFC857);
      case 'lost':
      case 'stolen':
        return const Color(0xFFE85C5C);
      case 'destroyed':
        return const Color(0xFF78909C);
      default:
        return const Color(0xFFB0BEC5);
    }
  }

  /// Get color for anomaly severity
  static Color severityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return const Color(0xFFE85C5C);
      case 'high':
        return const Color(0xFFFF8A65);
      case 'medium':
        return const Color(0xFFFFC857);
      case 'low':
        return const Color(0xFF42A5F5);
      default:
        return const Color(0xFF78909C);
    }
  }

  /// Get color for approval status
  static Color approvalStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return const Color(0xFF3CCB7F);
      case 'pending':
        return const Color(0xFFFFC857);
      case 'rejected':
        return const Color(0xFFE85C5C);
      default:
        return const Color(0xFF78909C);
    }
  }

  /// Get icon for firearm type
  static IconData firearmTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'pistol':
        return Icons.gps_fixed;
      case 'rifle':
        return Icons.straighten;
      case 'shotgun':
        return Icons.line_weight;
      case 'submachine_gun':
        return Icons.flash_on;
      default:
        return Icons.shield;
    }
  }

  /// Display role in human-readable format
  static String roleLabel(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'System Administrator';
      case 'hq_firearm_commander':
        return 'HQ Firearm Commander';
      case 'station_commander':
        return 'Station Commander';
      case 'investigator':
        return 'Investigator';
      default:
        return role ?? 'Unknown';
    }
  }

  /// Show a styled snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    final bgColor = isError
        ? const Color(0xFFE85C5C)
        : isSuccess
            ? const Color(0xFF3CCB7F)
            : const Color(0xFF2A3040);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Truncate text with ellipsis
  static String truncate(String? text, int maxLength) {
    if (text == null || text.length <= maxLength) return text ?? '';
    return '${text.substring(0, maxLength)}...';
  }
}
