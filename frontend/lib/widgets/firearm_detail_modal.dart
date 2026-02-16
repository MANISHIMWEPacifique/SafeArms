// Firearm Detail View Modal - Slide-in Panel
// SafeArms Frontend

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/firearm_model.dart';
import '../services/custody_service.dart';

class FirearmDetailModal extends StatefulWidget {
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
  State<FirearmDetailModal> createState() => _FirearmDetailModalState();
}

class _FirearmDetailModalState extends State<FirearmDetailModal> {
  final CustodyService _custodyService = CustodyService();

  void _showCustodyHistory() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5))),
    );

    try {
      final history = await _custodyService.getCustodyHistory(
          firearmId: widget.firearm.firearmId);
      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2A3040),
          title: Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF1E88E5)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Custody History - ${widget.firearm.serialNumber}',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 400,
            child: history.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, size: 48, color: Color(0xFF78909C)),
                        SizedBox(height: 16),
                        Text('No custody history found',
                            style: TextStyle(color: Color(0xFF78909C))),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final record = history[index];
                      final assignedDate = record['assigned_at'] != null
                          ? DateFormat('MMM dd, yyyy HH:mm')
                              .format(DateTime.parse(record['assigned_date']))
                          : 'N/A';
                      final returnedDate = record['returned_at'] != null
                          ? DateFormat('MMM dd, yyyy HH:mm')
                              .format(DateTime.parse(record['returned_at']))
                          : 'Active';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF37404F)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person,
                                    size: 16, color: Color(0xFF1E88E5)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    record['officer_name'] ?? 'Unknown Officer',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: record['returned_at'] == null
                                        ? const Color(0xFF3CCB7F)
                                            .withValues(alpha: 0.2)
                                        : const Color(0xFF78909C)
                                            .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    record['returned_at'] == null
                                        ? 'Active'
                                        : 'Returned',
                                    style: TextStyle(
                                      color: record['returned_at'] == null
                                          ? const Color(0xFF3CCB7F)
                                          : const Color(0xFF78909C),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('Assigned: $assignedDate',
                                    style: const TextStyle(
                                        color: Color(0xFF78909C),
                                        fontSize: 12)),
                                const SizedBox(width: 16),
                                Text('Returned: $returnedDate',
                                    style: const TextStyle(
                                        color: Color(0xFF78909C),
                                        fontSize: 12)),
                              ],
                            ),
                            if (record['custody_type'] != null) ...[
                              const SizedBox(height: 4),
                              Text('Type: ${record['custody_type']}',
                                  style: const TextStyle(
                                      color: Color(0xFF78909C), fontSize: 12)),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error loading custody history: $e'),
            backgroundColor: const Color(0xFFE85C5C)),
      );
    }
  }

  void _generateReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title: const Row(
          children: [
            Icon(Icons.description, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Generate Report', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption('Firearm Summary Report', Icons.summarize, () {
              Navigator.pop(context);
              _showReportPreview('summary');
            }),
            const SizedBox(height: 12),
            _buildReportOption('Custody Chain Report', Icons.link, () {
              Navigator.pop(context);
              _showReportPreview('custody');
            }),
            const SizedBox(height: 12),
            _buildReportOption('Ballistic Profile Report', Icons.fingerprint,
                () {
              Navigator.pop(context);
              _showReportPreview('ballistic');
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF78909C))),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF37404F)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1E88E5)),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Text(title, style: const TextStyle(color: Colors.white))),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Color(0xFF78909C)),
          ],
        ),
      ),
    );
  }

  void _showReportPreview(String type) {
    final reportContent = _generateReportContent(type);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title: Row(
          children: [
            const Icon(Icons.preview, color: Color(0xFF1E88E5)),
            const SizedBox(width: 12),
            Text(
              type == 'summary'
                  ? 'Firearm Summary'
                  : type == 'custody'
                      ? 'Custody Chain'
                      : 'Ballistic Profile',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                reportContent,
                style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Report ready for print'),
                    backgroundColor: Color(0xFF3CCB7F)),
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5)),
          ),
        ],
      ),
    );
  }

  String _generateReportContent(String type) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final now = dateFormat.format(DateTime.now());

    if (type == 'summary') {
      return '''
RWANDA NATIONAL POLICE
FIREARM SUMMARY REPORT
Generated: $now

═══════════════════════════════════════════
FIREARM IDENTIFICATION
═══════════════════════════════════════════
Serial Number: ${widget.firearm.serialNumber}
Manufacturer: ${widget.firearm.manufacturer}
Model: ${widget.firearm.model}
Type: ${_formatFirearmType(widget.firearm.firearmType)}
Caliber: ${widget.firearm.caliber ?? 'N/A'}

═══════════════════════════════════════════
ACQUISITION DETAILS
═══════════════════════════════════════════
Source: ${widget.firearm.acquisitionSource ?? 'N/A'}
Date: ${dateFormat.format(widget.firearm.acquisitionDate)}

═══════════════════════════════════════════
CURRENT STATUS
═══════════════════════════════════════════
Status: ${widget.firearm.currentStatus.toUpperCase()}
Unit: ${widget.firearm.unitDisplayName}

═══════════════════════════════════════════
This is an official document of the RNP.
''';
    } else if (type == 'custody') {
      return '''
RWANDA NATIONAL POLICE
CUSTODY CHAIN REPORT
Generated: $now

═══════════════════════════════════════════
FIREARM DETAILS
═══════════════════════════════════════════
Serial Number: ${widget.firearm.serialNumber}
Manufacturer/Model: ${widget.firearm.manufacturer} ${widget.firearm.model}

═══════════════════════════════════════════
CURRENT CUSTODY
═══════════════════════════════════════════
Unit: ${widget.firearm.unitDisplayName}
Status: ${widget.firearm.currentStatus.toUpperCase()}

═══════════════════════════════════════════
CHAIN OF CUSTODY
═══════════════════════════════════════════
[View full history in Custody History section]

═══════════════════════════════════════════
This report certifies the custody chain.
''';
    } else {
      return '''
RWANDA NATIONAL POLICE
BALLISTIC PROFILE REPORT
Generated: $now

═══════════════════════════════════════════
FIREARM IDENTIFICATION
═══════════════════════════════════════════
Serial Number: ${widget.firearm.serialNumber}
Manufacturer: ${widget.firearm.manufacturer}
Model: ${widget.firearm.model}
Caliber: ${widget.firearm.caliber ?? 'N/A'}

═══════════════════════════════════════════
BALLISTIC PROFILE STATUS
═══════════════════════════════════════════
Status: PENDING PROFILE

═══════════════════════════════════════════
This is an official forensic document.
''';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1F2E).withValues(alpha: 0.95),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onClose,
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
            onPressed: widget.onClose,
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
            _getFirearmIcon(widget.firearm.firearmType),
            color: const Color(0xFF42A5F5),
            size: 60,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${widget.firearm.manufacturer} ${widget.firearm.model}',
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
              widget.firearm.serialNumber,
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
            _buildStatusBadge(widget.firearm.currentStatus),
            const SizedBox(width: 8),
            _buildRegistrationLevelBadge(widget.firearm.registrationLevel),
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
          _buildInfoRow('Type', _formatFirearmType(widget.firearm.firearmType)),
          _buildInfoRow('Caliber', widget.firearm.caliber ?? 'N/A'),
          _buildInfoRow('Manufacture Year',
              widget.firearm.manufactureYear?.toString() ?? 'N/A'),
          _buildInfoRow('Manufacturer', widget.firearm.manufacturer),
          _buildInfoRow('Model', widget.firearm.model),
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
              'Acquisition Date', _formatDate(widget.firearm.acquisitionDate)),
          _buildInfoRow('Source', widget.firearm.acquisitionSource ?? 'N/A'),
          _buildInfoRow('Registered By', widget.firearm.registeredBy),
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
          _buildInfoRow('Status', widget.firearm.currentStatus.toUpperCase()),
          _buildInfoRow('Assigned Unit', widget.firearm.unitDisplayName),
          _buildInfoRow('Registration Level',
              widget.firearm.registrationLevel.toUpperCase()),
          _buildInfoRow('Active', widget.firearm.isActive ? 'Yes' : 'No'),
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
        if (widget.onEdit != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onEdit,
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
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showCustodyHistory,
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
            onPressed: _generateReport,
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
