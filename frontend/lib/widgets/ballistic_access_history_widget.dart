// Ballistic Access History Widget
// Displays chronological audit trail of profile accesses (READ-ONLY)
// SafeArms Frontend
//
// IMPORTANT: This widget presents FACTUAL data only.
// No judgmental indicators (red/green verdicts) are used.
// This is an audit trail showing who accessed data and when.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A read-only audit trail of ballistic profile accesses
/// Shows factual records of when and by whom the profile was accessed
class BallisticAccessHistoryWidget extends StatelessWidget {
  final List<Map<String, dynamic>> accessHistory;
  final bool isLoading;
  final String? errorMessage;
  final bool accessDenied;

  const BallisticAccessHistoryWidget({
    Key? key,
    required this.accessHistory,
    this.isLoading = false,
    this.errorMessage,
    this.accessDenied = false,
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

    if (accessDenied) {
      return _buildAccessDeniedState();
    }

    if (errorMessage != null) {
      return _buildErrorState(errorMessage!);
    }

    if (accessHistory.isEmpty) {
      return _buildEmptyState();
    }

    return _buildHistoryContent();
  }

  Widget _buildHistoryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryHeader(),
        const SizedBox(height: 16),
        _buildAccessList(),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    final accessTypes = <String, int>{};
    for (final record in accessHistory) {
      final type = record['access_type']?.toString() ?? 'unknown';
      accessTypes[type] = (accessTypes[type] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildStatItem(
            Icons.visibility,
            '${accessHistory.length}',
            'Total Accesses',
          ),
          const SizedBox(width: 24),
          _buildStatItem(
            Icons.person,
            '${_getUniqueAccessors().length}',
            'Unique Accessors',
          ),
          const SizedBox(width: 24),
          _buildStatItem(
            Icons.category,
            '${accessTypes.length}',
            'Access Types',
          ),
        ],
      ),
    );
  }

  Set<String> _getUniqueAccessors() {
    final accessors = <String>{};
    for (final record in accessHistory) {
      final accessor = record['accessed_by']?.toString();
      if (accessor != null) accessors.add(accessor);
    }
    return accessors;
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF42A5F5), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: const [
                Icon(Icons.history, color: Color(0xFF42A5F5), size: 18),
                SizedBox(width: 8),
                Text(
                  'Access Log',
                  style: TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF37404F), height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: accessHistory.length,
            separatorBuilder: (_, __) => const Divider(
              color: Color(0xFF37404F),
              height: 1,
            ),
            itemBuilder: (context, index) => _buildAccessRecord(
              accessHistory[index],
              index + 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessRecord(Map<String, dynamic> record, int sequence) {
    final accessType = record['access_type']?.toString() ?? 'unknown';
    final accessedBy = record['accessed_by']?.toString() ?? 'Unknown';
    final accessorRole = record['accessor_role']?.toString();
    final accessorUnit = record['accessor_unit']?.toString();
    final accessedAt = _parseDateTime(record['accessed_at']);
    final accessReason = record['access_reason']?.toString();
    final accessMethod = record['access_method']?.toString();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sequence number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$sequence',
              style: const TextStyle(
                color: Color(0xFF42A5F5),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Access details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accessor and type
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        accessedBy,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _buildAccessTypeBadge(accessType),
                  ],
                ),
                // Role and unit
                if (accessorRole != null || accessorUnit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        if (accessorRole != null) accessorRole,
                        if (accessorUnit != null) accessorUnit,
                      ].join(' • '),
                      style: const TextStyle(
                        color: Color(0xFF78909C),
                        fontSize: 12,
                      ),
                    ),
                  ),
                // Timestamp
                if (accessedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Color(0xFF546E7A),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, yyyy h:mm a').format(accessedAt),
                          style: const TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Access reason
                if (accessReason != null && accessReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F2E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.comment_outlined,
                            color: Color(0xFF546E7A),
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              accessReason,
                              style: const TextStyle(
                                color: Color(0xFF78909C),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Access method
                if (accessMethod != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'via $accessMethod',
                      style: const TextStyle(
                        color: Color(0xFF546E7A),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessTypeBadge(String type) {
    // Use neutral colors for all access types
    // No judgmental red/green indicators
    final color = const Color(0xFF78909C);

    String label;
    switch (type.toLowerCase()) {
      case 'view':
        label = 'VIEW';
        break;
      case 'compare':
        label = 'COMPARE';
        break;
      case 'export':
        label = 'EXPORT';
        break;
      case 'api':
        label = 'API';
        break;
      default:
        label = type.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: const [
          Icon(Icons.history, color: Color(0xFF546E7A), size: 48),
          SizedBox(height: 16),
          Text(
            'No Access Records',
            style: TextStyle(
              color: Color(0xFF78909C),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No access to this ballistic profile has been recorded',
            style: TextStyle(color: Color(0xFF546E7A), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: const [
          Icon(Icons.lock_outline, color: Color(0xFF78909C), size: 48),
          SizedBox(height: 16),
          Text(
            'Access Restricted',
            style: TextStyle(
              color: Color(0xFF78909C),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your role does not have access to view the access log',
            style: TextStyle(color: Color(0xFF546E7A), fontSize: 14),
            textAlign: TextAlign.center,
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
}
