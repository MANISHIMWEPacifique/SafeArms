// Officer Detail Modal
// View officer details
// SafeArms Frontend

import 'package:flutter/material.dart';
import '../models/officer_model.dart';

class OfficerDetailModal extends StatelessWidget {
  final OfficerModel officer;
  final VoidCallback onClose;

  const OfficerDetailModal({
    Key? key,
    required this.officer,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          width: 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOfficerAvatar(),
                      const SizedBox(height: 24),
                      _buildInfoSection('Basic Information', [
                        _buildInfoRow('Officer Number', officer.officerNumber),
                        _buildInfoRow('Full Name', officer.fullName),
                        _buildInfoRow('Rank', officer.rank),
                        _buildInfoRow(
                            'Status', officer.isActive ? 'Active' : 'Inactive'),
                      ]),
                      const SizedBox(height: 24),
                      _buildInfoSection('Contact Information', [
                        _buildInfoRow('Phone', officer.phoneNumber ?? 'N/A'),
                        _buildInfoRow('Email', officer.email ?? 'N/A'),
                      ]),
                      const SizedBox(height: 24),
                      _buildInfoSection('Employment Details', [
                        _buildInfoRow(
                            'Date of Birth',
                            officer.dateOfBirth != null
                                ? '${officer.dateOfBirth!.day}/${officer.dateOfBirth!.month}/${officer.dateOfBirth!.year}'
                                : 'N/A'),
                        _buildInfoRow(
                            'Employment Date',
                            officer.employmentDate != null
                                ? '${officer.employmentDate!.day}/${officer.employmentDate!.month}/${officer.employmentDate!.year}'
                                : 'N/A'),
                      ]),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.person, color: Color(0xFF1E88E5), size: 24),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Officer Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'View officer information',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white54),
            hoverColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerAvatar() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFF1E88E5).withValues(alpha: 0.2),
            child: Text(
              officer.fullName.isNotEmpty
                  ? officer.fullName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Color(0xFF1E88E5),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            officer.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: officer.isActive
                  ? const Color(0xFF3CCB7F).withValues(alpha: 0.15)
                  : const Color(0xFFE85C5C).withValues(alpha: 0.15),
            ),
            child: Text(
              officer.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: officer.isActive
                    ? const Color(0xFF3CCB7F)
                    : const Color(0xFFE85C5C),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF37404F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
