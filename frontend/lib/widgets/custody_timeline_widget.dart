// Custody Timeline Widget
// Displays chronological chain-of-custody events (READ-ONLY)
// SafeArms Frontend
//
// IMPORTANT: This widget presents FACTUAL data only.
// No judgmental indicators (red/green verdicts) are used.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A read-only timeline view of custody events
/// Displays factual, chronological custody chain
class CustodyTimelineWidget extends StatelessWidget {
  final List<Map<String, dynamic>> timeline;
  final Map<String, dynamic>? summary;
  final bool isLoading;
  final String? errorMessage;
  final String? incidentDate;

  const CustodyTimelineWidget({
    Key? key,
    required this.timeline,
    this.summary,
    this.isLoading = false,
    this.errorMessage,
    this.incidentDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
        ),
      );
    }

    if (errorMessage != null) {
      return _buildErrorState(errorMessage!);
    }

    if (timeline.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null) _buildSummaryHeader(summary!),
        const SizedBox(height: 16),
        _buildTimelineList(),
      ],
    );
  }

  Widget _buildSummaryHeader(Map<String, dynamic> summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildSummaryItem(
            'Total Events',
            '${summary['total_events'] ?? timeline.length}',
            Icons.timeline,
          ),
          const SizedBox(width: 24),
          _buildSummaryItem(
            'Officers',
            '${summary['unique_officers'] ?? '-'}',
            Icons.person,
          ),
          const SizedBox(width: 24),
          _buildSummaryItem(
            'Units',
            '${summary['unique_units'] ?? '-'}',
            Icons.business,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF78909C), size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF78909C),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final event = timeline[index];
        final isLast = index == timeline.length - 1;
        return _buildTimelineEvent(event, isLast, index + 1);
      },
    );
  }

  bool _isEventDuringIncident(Map<String, dynamic> event) {
    if (incidentDate == null) return false;
    final incident = DateTime.tryParse(incidentDate!);
    if (incident == null) return false;
    final issuedAt = _parseDateTime(event['issued_at']);
    final returnedAt = event['returned_at'] != null
        ? _parseDateTime(event['returned_at'])
        : null;
    if (issuedAt == null) return false;
    if (issuedAt.isAfter(incident.add(const Duration(days: 1)))) return false;
    if (returnedAt != null && returnedAt.isBefore(incident)) return false;
    return true;
  }

  Widget _buildTimelineEvent(
      Map<String, dynamic> event, bool isLast, int sequence) {
    final issuedAt = _parseDateTime(event['issued_at']);
    final returnedAt = event['returned_at'] != null
        ? _parseDateTime(event['returned_at'])
        : null;
    final isCrossUnit = event['is_cross_unit_transfer'] == true;
    final isIncidentHolder = _isEventDuringIncident(event);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isIncidentHolder
                        ? const Color(0xFFFFA726).withValues(alpha: 0.25)
                        : const Color(0xFF42A5F5).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isIncidentHolder
                          ? const Color(0xFFFFA726)
                          : const Color(0xFF42A5F5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isIncidentHolder
                        ? const Icon(Icons.priority_high,
                            color: Color(0xFFFFA726), size: 16)
                        : Text(
                            '$sequence',
                            style: const TextStyle(
                              color: Color(0xFF42A5F5),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFF37404F),
                    ),
                  ),
              ],
            ),
          ),
          // Event content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isIncidentHolder
                    ? const Color(0xFFFFA726).withValues(alpha: 0.04)
                    : const Color(0xFF2A3040),
                border: Border.all(
                  color: isIncidentHolder
                      ? const Color(0xFFFFA726).withValues(alpha: 0.35)
                      : const Color(0xFF37404F),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with date
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatEventTitle(event),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isIncidentHolder)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFA726).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'HOLDER AT INCIDENT',
                            style: TextStyle(
                              color: Color(0xFFFFA726),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      if (isCrossUnit)
                        Container(
                          margin:
                              EdgeInsets.only(left: isIncidentHolder ? 6 : 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF42A5F5).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CROSS-UNIT',
                            style: TextStyle(
                              color: Color(0xFF42A5F5),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Officer info
                  _buildEventDetailRow(
                    Icons.person,
                    'Officer',
                    event['officer_name'] ?? 'Unknown',
                    subtitle: event['officer_rank'],
                  ),
                  // Unit info
                  _buildEventDetailRow(
                    Icons.business,
                    'Unit',
                    event['unit_name'] ?? 'Unknown',
                  ),
                  // Custody type
                  _buildEventDetailRow(
                    Icons.category,
                    'Type',
                    _formatCustodyType(event['custody_type']),
                  ),
                  // Dates
                  _buildEventDetailRow(
                    Icons.calendar_today,
                    'Issued',
                    _formatDateTime(issuedAt),
                  ),
                  if (returnedAt != null)
                    _buildEventDetailRow(
                      Icons.event_available,
                      'Returned',
                      _formatDateTime(returnedAt),
                    ),
                  // Duration if available
                  if (event['duration_seconds'] != null)
                    _buildEventDetailRow(
                      Icons.access_time,
                      'Duration',
                      _formatDuration(event['duration_seconds']),
                    ),
                  // Return condition if available
                  if (event['return_condition'] != null)
                    _buildEventDetailRow(
                      Icons.check_circle_outline,
                      'Condition',
                      _formatCondition(event['return_condition']),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetailRow(
    IconData icon,
    String label,
    String value, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF78909C), size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              subtitle != null ? '$value ($subtitle)' : value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: const [
          Icon(Icons.timeline, color: Color(0xFF78909C), size: 48),
          SizedBox(height: 16),
          Text(
            'No custody records',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'This firearm has no custody history',
            style: TextStyle(color: Color(0xFF546E7A), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF78909C), size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM d, yyyy HH:mm').format(date);
  }

  String _formatEventTitle(Map<String, dynamic> event) {
    final type = event['custody_type']?.toString() ?? 'custody';
    return 'Custody ${_formatCustodyType(type)}';
  }

  String _formatCustodyType(String? type) {
    if (type == null) return 'Assignment';
    return type
        .split('_')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return 'N/A';
    final sec =
        seconds is int ? seconds : int.tryParse(seconds.toString()) ?? 0;
    if (sec < 3600) {
      return '${(sec / 60).round()} minutes';
    } else if (sec < 86400) {
      return '${(sec / 3600).toStringAsFixed(1)} hours';
    } else {
      return '${(sec / 86400).toStringAsFixed(1)} days';
    }
  }

  String _formatCondition(String? condition) {
    if (condition == null) return 'N/A';
    return condition
        .split('_')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }
}
