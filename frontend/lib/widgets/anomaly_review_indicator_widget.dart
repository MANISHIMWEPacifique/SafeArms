// Anomaly Review Indicator Widget
// Displays a "Requires Review" indicator for pending anomalies
// SafeArms Frontend
//
// IMPORTANT: This widget presents FACTUAL information only.
// - Labels use "Requires Review" NOT "Suspicious" or "Warning"
// - No red/green judgmental indicators
// - Anomalies indicate events requiring human review, NOT wrongdoing
// - Severity indicates review urgency only

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A non-judgmental indicator for pending anomaly reviews
/// Uses neutral styling and factual language only
class AnomalyReviewIndicatorWidget extends StatelessWidget {
  final List<Map<String, dynamic>> anomalies;
  final bool isLoading;
  final bool isCompact;
  final VoidCallback? onViewDetails;

  const AnomalyReviewIndicatorWidget({
    Key? key,
    required this.anomalies,
    this.isLoading = false,
    this.isCompact = false,
    this.onViewDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF78909C),
        ),
      );
    }

    if (anomalies.isEmpty) {
      return const SizedBox.shrink();
    }

    return isCompact ? _buildCompactBadge() : _buildExpandedView();
  }

  /// Compact badge for use in headers/cards
  Widget _buildCompactBadge() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            // Use blue color - neutral, not judgmental
            color: const Color(0xFF42A5F5).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: const Color(0xFF42A5F5).withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.rate_review_outlined,
                color: Color(0xFF42A5F5),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Requires Review (${anomalies.length})',
                style: const TextStyle(
                  color: Color(0xFF42A5F5),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Expanded view with anomaly details
  Widget _buildExpandedView() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(color: Color(0xFF37404F), height: 1),
          ...anomalies.asMap().entries.map((entry) {
            final isLast = entry.key == anomalies.length - 1;
            return Column(
              children: [
                _buildAnomalyItem(entry.value),
                if (!isLast) const Divider(color: Color(0xFF37404F), height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // Group by urgency level
    final urgencyCounts = <String, int>{};
    for (final anomaly in anomalies) {
      final urgency = _getUrgencyLevel(anomaly);
      urgencyCounts[urgency] = (urgencyCounts[urgency] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              color: Color(0xFF42A5F5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Events Requiring Review',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${anomalies.length} event${anomalies.length != 1 ? 's' : ''} pending review',
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onViewDetails != null)
            TextButton(
              onPressed: onViewDetails,
              child: const Text(
                'View All',
                style: TextStyle(color: Color(0xFF42A5F5), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnomalyItem(Map<String, dynamic> anomaly) {
    final type = anomaly['anomaly_type']?.toString() ?? 'unknown';
    final description =
        anomaly['description']?.toString() ?? 'Event requires review';
    final detectedAt = _parseDateTime(anomaly['detected_at']);
    final urgency = _getUrgencyLevel(anomaly);
    final isMandatory = anomaly['is_mandatory_review'] == true;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type and urgency
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatAnomalyType(type),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildUrgencyBadge(urgency),
            ],
          ),
          // Description
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF78909C),
                  fontSize: 13,
                ),
              ),
            ),
          // Timestamp and mandatory flag
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                if (detectedAt != null) ...[
                  const Icon(
                    Icons.access_time,
                    color: Color(0xFF546E7A),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, yyyy h:mm a').format(detectedAt),
                    style: const TextStyle(
                      color: Color(0xFF546E7A),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (isMandatory) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF78909C).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.policy_outlined,
                          color: Color(0xFF78909C),
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Policy',
                          style: TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge(String urgency) {
    // All urgency levels use neutral blue/gray colors
    // No red/yellow/green indicators that imply judgment
    final Color color;
    switch (urgency.toLowerCase()) {
      case 'high':
        color = const Color(0xFF42A5F5);
        break;
      case 'medium':
        color = const Color(0xFF78909C);
        break;
      default:
        color = const Color(0xFF546E7A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Review: ${urgency.toUpperCase()}',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getUrgencyLevel(Map<String, dynamic> anomaly) {
    // Urgency indicates review priority, not severity of wrongdoing
    final severity = anomaly['severity']?.toString().toLowerCase();
    switch (severity) {
      case 'critical':
      case 'high':
        return 'high';
      case 'medium':
        return 'medium';
      default:
        return 'standard';
    }
  }

  String _formatAnomalyType(String type) {
    // Present types in neutral, factual language
    switch (type.toLowerCase()) {
      case 'cross_unit_transfer':
        return 'Cross-Unit Transfer Event';
      case 'ballistic_timing':
        return 'Ballistic Access Timing Event';
      case 'custody_pattern':
        return 'Custody Pattern Event';
      case 'access_frequency':
        return 'Access Frequency Event';
      case 'statistical':
        return 'Statistical Outlier Event';
      case 'ml_ensemble':
        return 'ML-Detected Event';
      default:
        return 'Event Requiring Review';
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

/// A simple chip-style badge for inline use
class AnomalyReviewBadge extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const AnomalyReviewBadge({
    Key? key,
    required this.count,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.rate_review_outlined,
                color: Color(0xFF42A5F5),
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFF42A5F5),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
