// Station Commander Register Firearm Modal
// @deprecated - This widget is no longer used. Firearm registration is now HQ-only.
// Kept for reference. Use RegisterFirearmModal instead (HQ level only).
// SafeArms Frontend
//
// IMPORTANT: Per SafeArms policy, firearms can ONLY be registered at HQ level.
// Station commanders cannot register firearms - they can only view and manage
// custody for firearms assigned to their unit by HQ.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/firearm_provider.dart';
import '../providers/auth_provider.dart';

/// @deprecated Use [RegisterFirearmModal] instead.
/// Firearm registration is restricted to HQ Commanders only.
@Deprecated('Firearm registration is HQ-only. This widget should not be used.')
class StationRegisterFirearmModal extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const StationRegisterFirearmModal({
    Key? key,
    required this.onClose,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<StationRegisterFirearmModal> createState() =>
      _StationRegisterFirearmModalState();
}

class _StationRegisterFirearmModalState
    extends State<StationRegisterFirearmModal> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _manufacturerController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _caliberController = TextEditingController();
  final TextEditingController _manufactureYearController =
      TextEditingController();
  final TextEditingController _acquisitionSourceController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // State
  String _firearmType = 'pistol';
  DateTime _acquisitionDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _serialNumberController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _caliberController.dispose();
    _manufactureYearController.dispose();
    _acquisitionSourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final unitId = authProvider.currentUser?['unit_id']?.toString();
    final unitName =
        authProvider.currentUser?['unit_name']?.toString() ?? 'Your Unit';

    if (unitId == null || unitId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No unit assigned to your account'),
          backgroundColor: Color(0xFFE85C5C),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final firearmProvider = context.read<FirearmProvider>();
    final success = await firearmProvider.registerFirearm(
      serialNumber: _serialNumberController.text.trim(),
      manufacturer: _manufacturerController.text.trim(),
      model: _modelController.text.trim(),
      firearmType: _firearmType,
      caliber: _caliberController.text.trim(),
      manufactureYear: int.tryParse(_manufactureYearController.text),
      acquisitionDate: _acquisitionDate,
      acquisitionSource: _acquisitionSourceController.text.trim(),
      assignedUnitId: unitId, // Auto-assign to commander's unit
      notes: _notesController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (success) {
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firearm registered to $unitName successfully'),
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
    final authProvider = context.watch<AuthProvider>();
    final unitName =
        authProvider.currentUser?['unit_name']?.toString() ?? 'Your Unit';

    return Material(
      color: const Color(0xFF1A1F2E).withOpacity(0.95),
      child: Center(
        child: Container(
          width: 700,
          constraints: const BoxConstraints(maxHeight: 650),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(unitName),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUnitInfoBanner(unitName),
                        const SizedBox(height: 24),
                        _buildIdentificationSection(),
                        const SizedBox(height: 24),
                        _buildSpecificationsSection(),
                        const SizedBox(height: 24),
                        _buildAcquisitionSection(),
                        const SizedBox(height: 24),
                        _buildNotesSection(),
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
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_circle_outline,
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
                  'Register New Firearm',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Registering to: $unitName',
                  style: const TextStyle(
                    color: Color(0xFF3CCB7F),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
          left: BorderSide(color: Color(0xFF3CCB7F), width: 4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Color(0xFF3CCB7F), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unit Assignment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This firearm will be automatically assigned to $unitName. You can only register firearms for your own unit.',
                  style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Identification',
          style: TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
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
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _manufacturerController,
                label: 'Manufacturer',
                hint: 'e.g., Glock, Beretta',
                required: true,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _caliberController,
                label: 'Caliber',
                hint: '9mm, .45 ACP, etc.',
                required: true,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Acquisition Date',
                value: _acquisitionDate,
                onChanged: (date) => setState(() => _acquisitionDate = date),
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
      ],
    );
  }

  Widget _buildNotesSection() {
    return _buildTextField(
      controller: _notesController,
      label: 'Notes',
      hint: 'Additional information...',
      maxLines: 3,
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
                borderRadius: BorderRadius.circular(8),
              ),
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
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
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
                borderRadius: BorderRadius.circular(8),
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
    TextInputType? keyboardType,
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
              hint: const Text(
                'Select...',
                style: TextStyle(color: Color(0xFF78909C)),
              ),
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
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF78909C),
                  size: 16,
                ),
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
}
