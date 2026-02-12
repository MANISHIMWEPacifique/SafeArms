// Firearm Detail View Modal - Slide-in Panel
// SafeArms Frontend

import 'package:flutter/material.dart';
import '../models/firearm_model.dart';

class FirearmDetailModal extends StatelessWidget {
  final FirearmModel firearm;
  final VoidCallback onClose;
  final VoidCallback? onEdit;

  const FirearmDetailModal({
    Key? key,
    required this.firearm,
    required this.onClose,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1F2E).withValues(alpha: 0.95),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onClose,
              child: Container(color: Colors.transparent),
            ),
          ),
          Container(
            width: 500,
            decoration: const BoxDecoration(
              color: Color(0xFF252A3A),
              boxShadow: [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 20,
                  offset: Offset(-4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileSection(),
                        const SizedBox(height: 32),
                        _buildSpecificationsSection(),
                        const SizedBox(height: 32),
                        _buildAcquisitionSection(),
                        const SizedBox(height: 32),
                        _buildStatusSection(),
                        const SizedBox(height: 32),
                        _buildBallisticSection(),
                        const SizedBox(height: 32),
                        _buildQuickActions(),
                      ],
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Row(
        children: [
          const Text(
            'Firearm Details',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF78909C)),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            color: Color(0xFF2A3040),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getFirearmIcon(firearm.firearmType),
            color: const Color(0xFF42A5F5),
            size: 60,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${firearm.manufacturer} ${firearm.model}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              firearm.serialNumber,
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 16, color: Color(0xFF78909C)),
              onPressed: () {
                // Copy to clipboard
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatusBadge(firearm.currentStatus),
            const SizedBox(width: 8),
            _buildRegistrationLevelBadge(firearm.registrationLevel),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specifications',
          style: TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard([
          _buildInfoRow('Type', _formatFirearmType(firearm.firearmType)),
          _buildInfoRow('Caliber', firearm.caliber ?? 'N/A'),
          _buildInfoRow(
              'Manufacture Year', firearm.manufactureYear?.toString() ?? 'N/A'),
          _buildInfoRow('Manufacturer', firearm.manufacturer),
          _buildInfoRow('Model', firearm.model),
        ]),
      ],
    );
  }

  Widget _buildAcquisitionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acquisition Details',
          style: TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard([
          _buildInfoRow(
              'Acquisition Date', _formatDate(firearm.acquisitionDate)),
          _buildInfoRow('Source', firearm.acquisitionSource ?? 'N/A'),
          _buildInfoRow('Registered By', firearm.registeredBy),
        ]),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Status',
          style: TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard([
          _buildInfoRow('Status', firearm.currentStatus.toUpperCase()),
          _buildInfoRow('Assigned Unit', firearm.unitDisplayName),
          _buildInfoRow(
              'Registration Level', firearm.registrationLevel.toUpperCase()),
          _buildInfoRow('Active', firearm.isActive ? 'Yes' : 'No'),
        ]),
      ],
    );
  }

  Widget _buildBallisticSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Ballistic Profile',
              style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            Icon(Icons.fingerprint, color: Color(0xFF3CCB7F), size: 20),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            border: Border.all(color: const Color(0xFF37404F)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF3CCB7F), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ballistic profile available - Click to view forensic details',
                  style: TextStyle(color: Color(0xFF3CCB7F), fontSize: 14),
                ),
              ),
              Icon(Icons.chevron_right, color: Color(0xFF78909C)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit Firearm Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // View custody history
            },
            icon: const Icon(Icons.history, size: 18),
            label: const Text('View Custody History'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E88E5),
              side: const BorderSide(color: Color(0xFF1E88E5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // Generate report
            },
            icon: const Icon(Icons.description, size: 18),
            label: const Text('Generate Report'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB0BEC5),
              side: const BorderSide(color: Color(0xFF37404F)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: rows,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Color(0xFF37404F), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    String displayText;

    switch (status) {
      case 'available':
        backgroundColor = const Color(0xFF3CCB7F);
        displayText = 'AVAILABLE';
        break;
      case 'in_custody':
        backgroundColor = const Color(0xFF42A5F5);
        displayText = 'IN CUSTODY';
        break;
      case 'maintenance':
        backgroundColor = const Color(0xFFFFC857);
        displayText = 'MAINTENANCE';
        break;
      case 'lost':
      case 'stolen':
        backgroundColor = const Color(0xFFE85C5C);
        displayText = status.toUpperCase();
        break;
      default:
        backgroundColor = const Color(0xFF78909C);
        displayText = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRegistrationLevelBadge(String level) {
    final isHQ = level == 'hq';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: isHQ ? const Color(0xFF1E88E5) : const Color(0xFF3CCB7F),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHQ ? Icons.domain : Icons.business,
            size: 14,
            color: isHQ ? const Color(0xFF1E88E5) : const Color(0xFF3CCB7F),
          ),
          const SizedBox(width: 4),
          Text(
            isHQ ? 'HQ REGISTERED' : 'UNIT REGISTERED',
            style: TextStyle(
              color: isHQ ? const Color(0xFF1E88E5) : const Color(0xFF3CCB7F),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFirearmIcon(String type) {
    switch (type) {
      case 'pistol':
        return Icons.sports_martial_arts;
      case 'rifle':
        return Icons.yard;
      case 'shotgun':
        return Icons.wifi_protected_setup;
      default:
        return Icons.hardware;
    }
  }

  String _formatFirearmType(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
