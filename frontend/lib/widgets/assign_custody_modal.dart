// Assign Custody Modal - Station Commander Level
// Modal for assigning firearm custody to officers within the unit
// SafeArms Frontend

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/custody_provider.dart';
import '../providers/auth_provider.dart';
import '../services/firearm_service.dart';
import '../services/officer_service.dart';
import '../services/officer_verification_service.dart';
import '../models/firearm_model.dart';
import '../models/officer_model.dart';
import 'searchable_dropdown.dart';

class AssignCustodyModal extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const AssignCustodyModal({
    super.key,
    required this.onClose,
    required this.onSuccess,
  });

  @override
  State<AssignCustodyModal> createState() => _AssignCustodyModalState();
}

class _AssignCustodyModalState extends State<AssignCustodyModal> {
  final _formKey = GlobalKey<FormState>();
  final FirearmService _firearmService = FirearmService();
  final OfficerService _officerService = OfficerService();
  final OfficerVerificationService _verificationService =
      OfficerVerificationService();

  // State
  List<FirearmModel> _availableFirearms = [];
  List<OfficerModel> _officers = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLoadingOfficerDevices = false;

  // Form state
  String? _selectedFirearmId;
  String? _selectedOfficerId;
  String? _selectedVerificationDeviceKey;
  String? _resolvedVerificationDeviceLabel;
  String _custodyType = 'permanent';
  String? _selectedDurationType;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _expectedReturnDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _onOfficerChanged(String? officerId) {
    setState(() {
      _selectedOfficerId = officerId;
      _selectedVerificationDeviceKey = null;
      _resolvedVerificationDeviceLabel = null;
    });

    if (officerId == null || officerId.isEmpty) {
      return;
    }

    _loadOfficerDevices(officerId);
  }

  Future<void> _loadOfficerDevices(String officerId) async {
    setState(() => _isLoadingOfficerDevices = true);

    try {
      final devices = await _verificationService.getOfficerDevices(officerId);
      if (!mounted || _selectedOfficerId != officerId) {
        return;
      }

      final selectedDevice = devices.isNotEmpty ? devices.first : null;
      final selectedDeviceKey = selectedDevice?['device_key']?.toString();
      final selectedDeviceName =
          selectedDevice?['device_name']?.toString().trim() ?? '';
      final selectedDevicePlatform =
          selectedDevice?['platform']?.toString().toUpperCase() ?? 'UNKNOWN';
      final resolvedLabel = selectedDeviceKey == null
          ? null
          : selectedDeviceName.isNotEmpty
              ? '$selectedDeviceName ($selectedDevicePlatform)'
              : selectedDeviceKey;

      setState(() {
        _selectedVerificationDeviceKey = selectedDeviceKey;
        _resolvedVerificationDeviceLabel = resolvedLabel;
        _isLoadingOfficerDevices = false;
      });
    } catch (_) {
      if (!mounted || _selectedOfficerId != officerId) {
        return;
      }

      setState(() {
        _selectedVerificationDeviceKey = null;
        _resolvedVerificationDeviceLabel = null;
        _isLoadingOfficerDevices = false;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final unitId = authProvider.currentUser?['unit_id']?.toString();

    try {
      // Load firearms and officers in parallel for faster loading
      final results = await Future.wait([
        _firearmService.getAllFirearms(
          unitId: unitId,
          status: 'available',
        ),
        _officerService.getAllOfficers(
          unitId: unitId,
          activeStatus: 'true',
        ),
      ]);

      setState(() {
        _availableFirearms = (results[0] as List<dynamic>).cast<FirearmModel>();
        _officers = (results[1] as List<dynamic>).cast<OfficerModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: const Color(0xFFE85C5C),
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFirearmId == null || _selectedOfficerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a firearm and officer'),
          backgroundColor: Color(0xFFE85C5C),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final custodyProvider = context.read<CustodyProvider>();
    final result = await custodyProvider.assignCustody(
      firearmId: _selectedFirearmId!,
      officerId: _selectedOfficerId!,
      custodyType: _custodyType,
      assignmentReason: _reasonController.text.trim(),
      expectedReturnDate: _expectedReturnDate,
      durationType: _custodyType == 'temporary' ? _selectedDurationType : null,
      notes: _notesController.text.trim(),
      verificationDeviceKey: _selectedVerificationDeviceKey,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (result != null) {
      final verificationRaw = result['verification'];
      final verification = verificationRaw is Map
          ? Map<String, dynamic>.from(verificationRaw)
          : <String, dynamic>{};
      final verificationCreated = verification['created'] == true;

      if (verificationCreated) {
        final verificationId =
            verification['verification_id']?.toString() ?? '';
        final challengeCode = verification['challenge_code']?.toString() ?? '';
        final targetDeviceKey =
            verification['target_device_key']?.toString().trim() ?? '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              verificationId.isEmpty
                  ? 'Custody assigned. Officer verification request created.'
                  : targetDeviceKey.isEmpty
                      ? 'Custody assigned. Verification $verificationId created and sent to officer mobile device (code: $challengeCode).'
                      : 'Custody assigned. Verification $verificationId created for device $targetDeviceKey.',
            ),
            backgroundColor: const Color(0xFF3CCB7F),
          ),
        );
      } else {
        final verificationMessage = verification['message']?.toString() ??
            'Mobile verification request was not created.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Custody assigned. $verificationMessage'),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
      }

      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(custodyProvider.errorMessage ?? 'Failed to assign custody'),
          backgroundColor: const Color(0xFFE85C5C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final unitName =
        authProvider.currentUser?['unit_name']?.toString() ?? 'Your Unit';

    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          width: 650,
          constraints: const BoxConstraints(maxHeight: 700),
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
              _buildHeader(unitName),
              Flexible(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E88E5),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFirearmSelection(),
                              const SizedBox(height: 24),
                              _buildOfficerSelection(),
                              const SizedBox(height: 24),
                              _buildVerificationDeliveryStatus(),
                              const SizedBox(height: 24),
                              _buildCustodyTypeSelection(),
                              const SizedBox(height: 24),
                              _buildAssignmentDetails(),
                            ],
                          ),
                        ),
                      ),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String unitName) {
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
            child: const Icon(
              Icons.assignment_ind,
              color: Color(0xFF1E88E5),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assign Custody',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assign firearm to an officer in $unitName',
                  style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF78909C)),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildFirearmSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Select Firearm',
              style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
          ],
        ),
        const SizedBox(height: 12),
        if (_availableFirearms.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: const Center(
              child: Text(
                'No available firearms in your unit',
                style: TextStyle(color: Color(0xFF78909C)),
              ),
            ),
          )
        else
          SearchableDropdown<String>(
            items: _availableFirearms.map((firearm) {
              return SearchableDropdownItem<String>(
                value: firearm.firearmId,
                label:
                    '${firearm.serialNumber} - ${firearm.manufacturer} ${firearm.model}',
                subtitle:
                    '${firearm.firearmType} • ${firearm.caliber ?? 'N/A'}',
                icon: Icons.gps_fixed,
              );
            }).toList(),
            value: _selectedFirearmId,
            hintText: 'Search by serial number, manufacturer, model...',
            prefixIcon: Icons.gps_fixed,
            onChanged: (value) => setState(() => _selectedFirearmId = value),
            validator: (v) => v == null ? 'Please select a firearm' : null,
          ),
      ],
    );
  }

  Widget _buildOfficerSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Assign to Officer',
              style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
          ],
        ),
        const SizedBox(height: 12),
        if (_officers.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: const Center(
              child: Text(
                'No active officers in your unit',
                style: TextStyle(color: Color(0xFF78909C)),
              ),
            ),
          )
        else
          SearchableDropdown<String>(
            items: _officers.map((officer) {
              return SearchableDropdownItem<String>(
                value: officer.officerId,
                label: '${officer.fullName} (${officer.rank})',
                subtitle: officer.officerNumber,
                icon: Icons.person,
              );
            }).toList(),
            value: _selectedOfficerId,
            hintText: 'Search by name, rank, or officer number...',
            prefixIcon: Icons.person_search,
            onChanged: _onOfficerChanged,
            validator: (v) => v == null ? 'Please select an officer' : null,
          ),
      ],
    );
  }

  Widget _buildVerificationDeliveryStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verification Delivery',
          style: TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Automatically uses the officer active enrolled phone.',
          style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (_selectedOfficerId == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: const Text(
              'Select an officer first.',
              style: TextStyle(color: Color(0xFF78909C)),
            ),
          )
        else if (_isLoadingOfficerDevices)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Resolving enrolled device...',
                  style: TextStyle(color: Color(0xFF78909C)),
                ),
              ],
            ),
          )
        else if (_selectedVerificationDeviceKey == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: const Text(
              'No active enrolled device found for this officer. Custody assignment can continue, but mobile verification request may not be delivered.',
              style: TextStyle(color: Color(0xFFFFC857)),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _resolvedVerificationDeviceLabel ?? 'Enrolled device',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Device key: ${_selectedVerificationDeviceKey!}',
                  style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCustodyTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Custody Type',
              style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildCustodyTypeChip(
              'permanent',
              'Permanent',
              Icons.lock,
              const Color(0xFF3CCB7F),
            ),
            _buildCustodyTypeChip(
              'temporary',
              'Temporary',
              Icons.schedule,
              const Color(0xFFFFC857),
            ),
            _buildCustodyTypeChip(
              'personal_long_term',
              'Personal Long-term',
              Icons.person,
              const Color(0xFF42A5F5),
            ),
          ],
        ),
        if (_custodyType == 'temporary') ...[
          const SizedBox(height: 16),
          _buildDurationTypeSelection(),
          if (_selectedDurationType != null) ...[
            const SizedBox(height: 12),
            _buildExpectedReturnInfo(),
          ],
        ],
      ],
    );
  }

  Widget _buildCustodyTypeChip(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _custodyType == value;
    return InkWell(
      onTap: () => setState(() => _custodyType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : const Color(0xFF2A3040),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF37404F),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : const Color(0xFF78909C),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFFB0BEC5),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Duration type helpers
  static const Map<String, int> _durationHours = {
    '6_hours': 6,
    '8_hours': 8,
    '12_hours': 12,
    '1_day': 24,
  };

  static const Map<String, String> _durationLabels = {
    '6_hours': '6 Hours',
    '8_hours': '8 Hours',
    '12_hours': '12 Hours',
    '1_day': '1 Day (24h)',
  };

  static const Map<String, IconData> _durationIcons = {
    '6_hours': Icons.looks_6,
    '8_hours': Icons.looks,
    '12_hours': Icons.timelapse,
    '1_day': Icons.today,
  };

  DateTime? _computeExpectedReturn() {
    if (_selectedDurationType == null) return null;
    final hours = _durationHours[_selectedDurationType!];
    if (hours == null) return null;
    return DateTime.now().add(Duration(hours: hours));
  }

  Widget _buildDurationTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Custody Duration',
              style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the shift-based duration for this temporary custody',
          style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: _durationHours.keys.map((type) {
            final isSelected = _selectedDurationType == type;
            final label = _durationLabels[type]!;
            final icon = _durationIcons[type]!;
            const color = Color(0xFFFFC857);

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: type != '1_day' ? 8.0 : 0.0,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDurationType = type;
                      _expectedReturnDate = _computeExpectedReturn();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.2)
                          : const Color(0xFF2A3040),
                      border: Border.all(
                        color: isSelected ? color : const Color(0xFF37404F),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? color : const Color(0xFF78909C),
                          size: 22,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? color : const Color(0xFFB0BEC5),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExpectedReturnInfo() {
    final expectedReturn = _computeExpectedReturn();
    if (expectedReturn == null) return const SizedBox.shrink();

    final hours = _durationHours[_selectedDurationType!] ?? 0;
    final label = _durationLabels[_selectedDurationType!] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFFFFC857), width: 3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Color(0xFFFFC857), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duration: $label ($hours hours)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Expected return: ${_formatDateTime(expectedReturn)}',
                  style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
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
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:$minute $amPm';
  }

  Widget _buildAssignmentDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assignment Details',
          style: TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _reasonController,
          label: 'Reason for Assignment',
          hint: 'e.g., Patrol duty, Special operation',
          required: true,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _notesController,
          label: 'Additional Notes',
          hint: 'Any additional information...',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: widget.onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF37404F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed:
                _isSubmitting || _availableFirearms.isEmpty || _officers.isEmpty
                    ? null
                    : _submitForm,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.assignment_turned_in, size: 18),
            label: const Text(
              'Assign Custody',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF78909C)),
            filled: true,
            fillColor: const Color(0xFF2A3040),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF37404F)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF37404F)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE85C5C), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
