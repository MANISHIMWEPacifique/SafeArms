// Ballistic Profile View Widget
// Displays ballistic profile details (READ-ONLY)
// SafeArms Frontend
//
// IMPORTANT: This widget presents FACTUAL data only.
// No judgmental indicators (red/green verdicts) are used.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A read-only view of ballistic profile data
/// Displays factual forensic identification data
class BallisticProfileViewWidget extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final bool isLoading;
  final String? errorMessage;
  final bool accessDenied;
  final VoidCallback? onViewAccessHistory;

  const BallisticProfileViewWidget({
    Key? key,
    this.profile,
    this.isLoading = false,
    this.errorMessage,
    this.accessDenied = false,
    this.onViewAccessHistory,
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

    if (profile == null) {
      return _buildNoProfileState();
    }

    return _buildProfileContent();
  }

  Widget _buildProfileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileHeader(),
        const SizedBox(height: 16),
        _buildCharacteristicsSection(),
        const SizedBox(height: 16),
        _buildTestInfoSection(),
        if (onViewAccessHistory != null) ...[
          const SizedBox(height: 16),
          _buildAccessHistoryButton(),
        ],
      ],
    );
  }

  Widget _buildProfileHeader() {
    final isLocked = profile?['is_locked'] == true;
    final testDate = _parseDateTime(profile?['test_date']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fingerprint,
              color: Color(0xFF42A5F5),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ballistic Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  testDate != null
                      ? 'Test Date: ${DateFormat('MMM d, yyyy').format(testDate)}'
                      : 'Test date not recorded',
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF78909C).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock, color: Color(0xFF78909C), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'IMMUTABLE',
                    style: TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharacteristicsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Identification Characteristics',
            style: TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildCharacteristicRow(
            'Rifling Characteristics',
            profile?['rifling_characteristics'],
            Icons.track_changes,
          ),
          const Divider(color: Color(0xFF37404F), height: 24),
          _buildCharacteristicRow(
            'Firing Pin Impression',
            profile?['firing_pin_impression'],
            Icons.radio_button_checked,
          ),
          const Divider(color: Color(0xFF37404F), height: 24),
          _buildCharacteristicRow(
            'Ejector Marks',
            profile?['ejector_marks'],
            Icons.arrow_forward,
          ),
          const Divider(color: Color(0xFF37404F), height: 24),
          _buildCharacteristicRow(
            'Extractor Marks',
            profile?['extractor_marks'],
            Icons.arrow_back,
          ),
          if (profile?['chamber_marks'] != null) ...[
            const Divider(color: Color(0xFF37404F), height: 24),
            _buildCharacteristicRow(
              'Chamber Marks',
              profile?['chamber_marks'],
              Icons.circle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCharacteristicRow(String label, String? value, IconData icon) {
    final hasValue = value != null && value.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: hasValue ? const Color(0xFF42A5F5) : const Color(0xFF546E7A),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF78909C),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasValue ? value : 'Not recorded',
                style: TextStyle(
                  color: hasValue ? Colors.white : const Color(0xFF546E7A),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Information',
            style: TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Test Ammunition', profile?['test_ammunition']),
          _buildInfoRow('Conducted By', profile?['test_conducted_by']),
          _buildInfoRow('Forensic Lab', profile?['forensic_lab']),
          if (profile?['notes'] != null &&
              profile!['notes'].toString().isNotEmpty)
            _buildInfoRow('Notes', profile?['notes']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF78909C),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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

  Widget _buildAccessHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onViewAccessHistory,
        icon: const Icon(Icons.history, size: 18),
        label: const Text('View Access History'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF78909C),
          side: const BorderSide(color: Color(0xFF37404F)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildNoProfileState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: const [
          Icon(Icons.fingerprint, color: Color(0xFF546E7A), size: 48),
          SizedBox(height: 16),
          Text(
            'No Ballistic Profile',
            style: TextStyle(
              color: Color(0xFF78909C),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This firearm does not have a ballistic profile recorded',
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
            'Your role does not have access to ballistic profile data',
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
