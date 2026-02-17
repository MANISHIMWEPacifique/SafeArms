// Register Firearm Modal - HQ Level with Ballistic Profile
// SafeArms Frontend

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/firearm_provider.dart';
import '../providers/unit_provider.dart';
import '../models/firearm_model.dart';

class RegisterFirearmModal extends StatefulWidget {
  final FirearmModel? firearm; // null for create, not null for edit
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const RegisterFirearmModal({
    Key? key,
    this.firearm,
    required this.onClose,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<RegisterFirearmModal> createState() => _RegisterFirearmModalState();
}

class _RegisterFirearmModalState extends State<RegisterFirearmModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Basic Info Controllers
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _manufacturerController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _caliberController = TextEditingController();
  final TextEditingController _manufactureYearController =
      TextEditingController();
  final TextEditingController _acquisitionSourceController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Ballistic Profile Controllers
  final TextEditingController _testLocationController = TextEditingController();
  final TextEditingController _riflingController = TextEditingController();
  final TextEditingController _firingPinController = TextEditingController();
  final TextEditingController _ejectorMarksController = TextEditingController();
  final TextEditingController _extractorMarksController =
      TextEditingController();
  final TextEditingController _chamberMarksController = TextEditingController();
  final TextEditingController _testConductedByController =
      TextEditingController();
  final TextEditingController _forensicLabController = TextEditingController();
  final TextEditingController _testAmmunitionController =
      TextEditingController();
  final TextEditingController _ballisticNotesController =
      TextEditingController();

  // State
  String _firearmType = 'pistol';
  String? _assignedUnitId;
  DateTime _acquisitionDate = DateTime.now();
  DateTime _testDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load units for the dropdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UnitProvider>().loadUnits();
    });

    if (widget.firearm != null) {
      _serialNumberController.text = widget.firearm!.serialNumber;
      _manufacturerController.text = widget.firearm!.manufacturer;
      _modelController.text = widget.firearm!.model;
      _caliberController.text = widget.firearm!.caliber ?? '';
      _firearmType = widget.firearm!.firearmType;
      _manufactureYearController.text =
          widget.firearm!.manufactureYear?.toString() ?? '';
      _acquisitionDate = widget.firearm!.acquisitionDate;
      _assignedUnitId = widget.firearm!.assignedUnitId;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _serialNumberController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _caliberController.dispose();
    _manufactureYearController.dispose();
    _acquisitionSourceController.dispose();
    _notesController.dispose();
    _testLocationController.dispose();
    _riflingController.dispose();
    _firingPinController.dispose();
    _ejectorMarksController.dispose();
    _extractorMarksController.dispose();
    _chamberMarksController.dispose();
    _testConductedByController.dispose();
    _forensicLabController.dispose();
    _testAmmunitionController.dispose();
    _ballisticNotesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate unit selection - required for HQ registration
    if (_assignedUnitId == null || _assignedUnitId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select a unit. Firearms must be assigned to a unit at registration.'),
          backgroundColor: Color(0xFFE85C5C),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Build ballistic profile data if any fields are filled
    Map<String, dynamic>? ballisticProfile;
    if (_riflingController.text.trim().isNotEmpty ||
        _firingPinController.text.trim().isNotEmpty ||
        _ejectorMarksController.text.trim().isNotEmpty ||
        _extractorMarksController.text.trim().isNotEmpty) {
      ballisticProfile = {
        'rifling_characteristics': _riflingController.text.trim().isNotEmpty
            ? _riflingController.text.trim()
            : null,
        'firing_pin_impression': _firingPinController.text.trim().isNotEmpty
            ? _firingPinController.text.trim()
            : null,
        'ejector_marks': _ejectorMarksController.text.trim().isNotEmpty
            ? _ejectorMarksController.text.trim()
            : null,
        'extractor_marks': _extractorMarksController.text.trim().isNotEmpty
            ? _extractorMarksController.text.trim()
            : null,
        'chamber_marks': _chamberMarksController.text.trim().isNotEmpty
            ? _chamberMarksController.text.trim()
            : null,
        'test_ammunition': _testAmmunitionController.text.trim().isNotEmpty
            ? _testAmmunitionController.text.trim()
            : null,
        'test_conducted_by': _testConductedByController.text.trim().isNotEmpty
            ? _testConductedByController.text.trim()
            : null,
        'forensic_lab': _forensicLabController.text.trim().isNotEmpty
            ? _forensicLabController.text.trim()
            : null,
        'notes': _ballisticNotesController.text.trim().isNotEmpty
            ? _ballisticNotesController.text.trim()
            : null,
      };
    }

    final firearmProvider = context.read<FirearmProvider>();
    bool success;

    if (widget.firearm != null) {
      // Edit mode — update existing firearm
      final updates = <String, dynamic>{
        'serial_number': _serialNumberController.text.trim(),
        'manufacturer': _manufacturerController.text.trim(),
        'model': _modelController.text.trim(),
        'firearm_type': _firearmType,
        'caliber': _caliberController.text.trim(),
        'manufacture_year': int.tryParse(_manufactureYearController.text),
        'acquisition_date': _acquisitionDate.toIso8601String(),
        'acquisition_source': _acquisitionSourceController.text.trim(),
        'assigned_unit_id': _assignedUnitId,
        'notes': _notesController.text.trim(),
      };
      success = await firearmProvider.updateFirearm(
        firearmId: widget.firearm!.firearmId,
        updates: updates,
      );
    } else {
      // Create mode — register new firearm
      success = await firearmProvider.registerFirearm(
        serialNumber: _serialNumberController.text.trim(),
        manufacturer: _manufacturerController.text.trim(),
        model: _modelController.text.trim(),
        firearmType: _firearmType,
        caliber: _caliberController.text.trim(),
        manufactureYear: int.tryParse(_manufactureYearController.text),
        acquisitionDate: _acquisitionDate,
        acquisitionSource: _acquisitionSourceController.text.trim(),
        assignedUnitId: _assignedUnitId!,
        notes: _notesController.text.trim(),
        ballisticProfile: ballisticProfile,
      );
    }

    setState(() => _isLoading = false);

    if (success) {
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.firearm != null
              ? 'Firearm updated successfully'
              : ballisticProfile != null
                  ? 'Firearm and ballistic profile registered successfully'
                  : 'Firearm registered successfully'),
          backgroundColor: const Color(0xFF3CCB7F),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(firearmProvider.errorMessage ?? 'Registration failed'),
          backgroundColor: const Color(0xFFE85C5C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1F2E).withValues(alpha: 0.95),
      child: Center(
        child: Container(
          width: 900,
          height: 700,
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicInfoTab(),
                    _buildBallisticProfileTab(),
                  ],
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.firearm == null
                    ? 'Register New Firearm (HQ)'
                    : 'Edit Firearm',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Firearm must be assigned to a unit during HQ registration',
                style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
              ),
            ],
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

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF1E88E5),
        indicatorWeight: 3,
        labelColor: const Color(0xFF1E88E5),
        unselectedLabelColor: const Color(0xFF78909C),
        tabs: const [
          Tab(text: 'Basic Information'),
          Tab(text: 'Ballistic Profile'),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identification',
              style: TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _serialNumberController,
                    label: 'Serial Number',
                    hint: 'Unique serial number',
                    required: true,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _manufacturerController,
                    label: 'Manufacturer',
                    hint: 'e.g., Glock, Beretta',
                    required: true,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _modelController,
                    label: 'Model',
                    hint: 'e.g., 17, 92FS',
                    required: true,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField(
                    label: 'Firearm Type',
                    value: _firearmType,
                    items: const [
                      {'value': 'pistol', 'label': 'Pistol'},
                      {'value': 'rifle', 'label': 'Rifle'},
                      {'value': 'shotgun', 'label': 'Shotgun'},
                      {'value': 'submachine_gun', 'label': 'Submachine Gun'},
                      {'value': 'other', 'label': 'Other'},
                    ],
                    onChanged: (value) => setState(() => _firearmType = value!),
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Specifications',
              style: TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _caliberController,
                    label: 'Caliber',
                    hint: '9mm, .45 ACP, etc.',
                    required: true,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _manufactureYearController,
                    label: 'Manufacture Year',
                    hint: 'YYYY',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Acquisition Details',
              style: TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Acquisition Date',
                    value: _acquisitionDate,
                    onChanged: (date) =>
                        setState(() => _acquisitionDate = date),
                    required: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _acquisitionSourceController,
                    label: 'Acquisition Source',
                    hint: 'Supplier name or source',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<UnitProvider>(
              builder: (context, unitProvider, child) {
                if (unitProvider.isLoading) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final unitItems =
                    unitProvider.units.map<Map<String, String>>((unit) {
                  return {
                    'value': unit['unit_id']?.toString() ?? '',
                    'label': unit['unit_name']?.toString() ?? 'Unknown Unit',
                  };
                }).toList();
                return _buildDropdownField(
                  label: 'Assign to Unit',
                  value: _assignedUnitId,
                  items: unitItems,
                  onChanged: (value) => setState(() => _assignedUnitId = value),
                  required: true,
                );
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _notesController,
              label: 'Notes',
              hint: 'Additional information...',
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            _buildInfoBox(
              'HQ Registration: Firearms must be assigned to a unit at registration time. Ballistic profile data can be captured in the next tab.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBallisticProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Information',
            style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'Test Date',
                  value: _testDate,
                  onChanged: (date) => setState(() => _testDate = date),
                  required: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _testLocationController,
                  label: 'Test Location',
                  hint: 'e.g., RNP Forensic Lab',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Ballistic Characteristics',
            style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _riflingController,
            label: 'Rifling Characteristics',
            hint: 'Describe rifling pattern, twist rate...',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _firingPinController,
            label: 'Firing Pin Impression',
            hint: 'Describe firing pin marks...',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _ejectorMarksController,
                  label: 'Ejector Marks',
                  hint: 'Ejector characteristics...',
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _extractorMarksController,
                  label: 'Extractor Marks',
                  hint: 'Extractor characteristics...',
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _chamberMarksController,
            label: 'Chamber Marks',
            hint: 'Chamber markings...',
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          const Text(
            'Test Details',
            style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _testConductedByController,
                  label: 'Test Conducted By',
                  hint: 'Forensic expert name',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _forensicLabController,
                  label: 'Forensic Lab',
                  hint: 'Laboratory name',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _testAmmunitionController,
            label: 'Test Ammunition',
            hint: 'Ammunition type used for testing',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _ballisticNotesController,
            label: 'Additional Notes',
            hint: 'Any additional ballistic observations...',
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          _buildInfoBox(
            'Ballistic Profile: This data will be used for forensic tracing and criminal investigation support. Accuracy is critical.',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: widget.onClose,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB0BEC5),
              side: const BorderSide(color: Color(0xFF37404F)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _submitForm,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle, size: 18),
            label: const Text(
              'Register Firearm',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
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
          keyboardType: keyboardType,
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
            if (required) ...[
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            border: Border.all(color: const Color(0xFF37404F)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: const Text('Select...',
                  style: TextStyle(color: Color(0xFF78909C))),
              dropdownColor: const Color(0xFF2A3040),
              style: const TextStyle(color: Colors.white),
              items: items
                  .map((item) => DropdownMenuItem<String>(
                        value: item['value'],
                        child: Text(item['label']!),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required Function(DateTime) onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
            if (required) ...[
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
            ],
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(1990),
              lastDate: DateTime.now(),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              border: Border.all(color: const Color(0xFF37404F)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: Color(0xFF78909C), size: 16),
                const SizedBox(width: 12),
                Text(
                  '${value.day}/${value.month}/${value.year}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(8),
        border:
            const Border(left: BorderSide(color: Color(0xFF42A5F5), width: 4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: Color(0xFF42A5F5), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Color(0xFFE3F2FD), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
