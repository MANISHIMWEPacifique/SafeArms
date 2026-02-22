// Assign Custody Modal - Station Commander Level
// Modal for assigning firearm custody to officers within the unit
// SafeArms Frontend

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/custody_provider.dart';
import '../providers/auth_provider.dart';
import '../services/firearm_service.dart';
import '../services/officer_service.dart';
import '../models/firearm_model.dart';
import '../models/officer_model.dart';

class AssignCustodyModal extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const AssignCustodyModal({
    Key? key,
    required this.onClose,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<AssignCustodyModal> createState() => _AssignCustodyModalState();
}

class _AssignCustodyModalState extends State<AssignCustodyModal> {
  final _formKey = GlobalKey<FormState>();
  final FirearmService _firearmService = FirearmService();
  final OfficerService _officerService = OfficerService();

  // State
  List<FirearmModel> _availableFirearms = [];
  List<OfficerModel> _officers = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Form state
  String? _selectedFirearmId;
  String? _selectedOfficerId;
  String _custodyType = 'permanent';
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _expectedReturnDate;

  @override
  void initState() {
    super.initState();
    _loadData();
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
          backgroundColor: const Color(0xFFE85C5C),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final custodyProvider = context.read<CustodyProvider>();
    final success = await custodyProvider.assignCustody(
      firearmId: _selectedFirearmId!,
      officerId: _selectedOfficerId!,
      custodyType: _custodyType,
      assignmentReason: _reasonController.text.trim(),
      expectedReturnDate: _expectedReturnDate,
      notes: _notesController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (success) {
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custody assigned successfully'),
          backgroundColor: Color(0xFF3CCB7F),
        ),
      );
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
                              _buildUnitInfoBanner(unitName),
                              const SizedBox(height: 24),
                              _buildFirearmSelection(),
                              const SizedBox(height: 24),
                              _buildOfficerSelection(),
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
                    fontSize: 22,
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

  Widget _buildUnitInfoBanner(String unitName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF42A5F5), width: 4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF42A5F5), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Only firearms and officers from $unitName are shown. Custody assignments are restricted to your unit.',
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 13,
              ),
            ),
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
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedFirearmId,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: InputBorder.none,
                hintText: 'Select a firearm...',
                hintStyle: TextStyle(color: Color(0xFF78909C)),
              ),
              dropdownColor: const Color(0xFF2A3040),
              style: const TextStyle(color: Colors.white),
              items: _availableFirearms.map((firearm) {
                return DropdownMenuItem<String>(
                  value: firearm.firearmId,
                  child: Text(
                    '${firearm.serialNumber} - ${firearm.manufacturer} ${firearm.model}',
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedFirearmId = value),
              validator: (v) => v == null ? 'Please select a firearm' : null,
            ),
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
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedOfficerId,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: InputBorder.none,
                hintText: 'Select an officer...',
                hintStyle: TextStyle(color: Color(0xFF78909C)),
              ),
              dropdownColor: const Color(0xFF2A3040),
              style: const TextStyle(color: Colors.white),
              items: _officers.map((officer) {
                return DropdownMenuItem<String>(
                  value: officer.officerId,
                  child: Text(
                    '${officer.fullName} (${officer.rank})',
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedOfficerId = value),
              validator: (v) => v == null ? 'Please select an officer' : null,
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
          _buildDateField(
            label: 'Expected Return Date',
            value: _expectedReturnDate,
            onChanged: (date) => setState(() => _expectedReturnDate = date),
          ),
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

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required Function(DateTime) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF1E88E5),
                      onPrimary: Colors.white,
                      surface: Color(0xFF252A3A),
                      onSurface: Colors.white,
                    ),
                    dialogTheme: const DialogThemeData(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    datePickerTheme: DatePickerThemeData(
                      backgroundColor: const Color(0xFF252A3A),
                      headerBackgroundColor: const Color(0xFF1A1F2E),
                      headerForegroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      dayStyle: const TextStyle(color: Colors.white),
                      yearStyle: const TextStyle(color: Colors.white),
                      dayForegroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected))
                          return Colors.white;
                        if (states.contains(WidgetState.disabled))
                          return const Color(0xFF546E7A);
                        return Colors.white;
                      }),
                      dayBackgroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected))
                          return const Color(0xFF1E88E5);
                        return Colors.transparent;
                      }),
                      todayForegroundColor:
                          WidgetStateProperty.all(const Color(0xFF42A5F5)),
                      todayBackgroundColor:
                          WidgetStateProperty.all(Colors.transparent),
                      todayBorder: const BorderSide(color: Color(0xFF42A5F5)),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF78909C),
                  size: 16,
                ),
                const SizedBox(width: 12),
                Text(
                  value != null
                      ? '${value.day}/${value.month}/${value.year}'
                      : 'Select date...',
                  style: TextStyle(
                    color:
                        value != null ? Colors.white : const Color(0xFF78909C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
