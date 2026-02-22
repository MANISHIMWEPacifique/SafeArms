// Add/Edit Officer Modal
// SafeArms Frontend

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/officer_provider.dart';
import '../../models/officer_model.dart';

class AddOfficerModal extends StatefulWidget {
  final OfficerModel? officer; // null for create, not null for edit
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const AddOfficerModal({
    Key? key,
    this.officer,
    required this.onClose,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<AddOfficerModal> createState() => _AddOfficerModalState();
}

class _AddOfficerModalState extends State<AddOfficerModal> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _officerNumberController =
      TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // State
  String _selectedRank = 'constable';
  String? _selectedUnit;
  DateTime? _dateOfBirth;
  DateTime? _employmentDate = DateTime.now();
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.officer != null) {
      _officerNumberController.text = widget.officer!.officerNumber;
      _fullNameController.text = widget.officer!.fullName;
      _phoneController.text = widget.officer!.phoneNumber ?? '';
      _emailController.text = widget.officer!.email ?? '';
      _selectedRank = widget.officer!.rank;
      _selectedUnit = widget.officer!.unitId;
      _dateOfBirth = widget.officer!.dateOfBirth;
      _employmentDate = widget.officer!.employmentDate;
      _isActive = widget.officer!.isActive;
    }
  }

  @override
  void dispose() {
    _officerNumberController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a unit'),
          backgroundColor: Color(0xFFE85C5C),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final officerProvider = context.read<OfficerProvider>();
    bool success;

    if (widget.officer == null) {
      // Create new officer
      success = await officerProvider.createOfficer(
        officerNumber: _officerNumberController.text.trim(),
        fullName: _fullNameController.text.trim(),
        rank: _selectedRank,
        unitId: _selectedUnit!,
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _dateOfBirth,
        employmentDate: _employmentDate,
        isActive: _isActive,
      );
    } else {
      // Update existing officer
      success = await officerProvider.updateOfficer(
        officerId: widget.officer!.officerId,
        fullName: _fullNameController.text.trim(),
        rank: _selectedRank,
        unitId: _selectedUnit,
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _dateOfBirth,
        isActive: _isActive,
      );
    }

    setState(() => _isLoading = false);

    if (success) {
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.officer == null
              ? 'Officer added successfully'
              : 'Officer updated successfully'),
          backgroundColor: const Color(0xFF3CCB7F),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(officerProvider.errorMessage ?? 'Operation failed'),
          backgroundColor: const Color(0xFFE85C5C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          width: 700,
          constraints: const BoxConstraints(maxHeight: 650),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column
                            Expanded(
                              child: Column(
                                children: [
                                  _buildTextField(
                                    controller: _officerNumberController,
                                    label: 'Officer Number',
                                    hint: 'e.g., RNP-245789',
                                    required: true,
                                    enabled: widget.officer == null,
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _fullNameController,
                                    label: 'Full Name',
                                    hint: 'First and Last Name',
                                    required: true,
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDropdownField(
                                    label: 'Rank',
                                    value: _selectedRank,
                                    items: const [
                                      {
                                        'value': 'constable',
                                        'label': 'Constable'
                                      },
                                      {
                                        'value': 'corporal',
                                        'label': 'Corporal'
                                      },
                                      {
                                        'value': 'sergeant',
                                        'label': 'Sergeant'
                                      },
                                      {
                                        'value': 'inspector',
                                        'label': 'Inspector'
                                      },
                                      {
                                        'value': 'superintendent',
                                        'label': 'Superintendent'
                                      },
                                      {
                                        'value': 'commissioner',
                                        'label': 'Commissioner'
                                      },
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _selectedRank = value!),
                                    required: true,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDateField(
                                    label: 'Date of Birth',
                                    value: _dateOfBirth,
                                    onChanged: (date) =>
                                        setState(() => _dateOfBirth = date),
                                    required: false,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right Column
                            Expanded(
                              child: Column(
                                children: [
                                  _buildDropdownField(
                                    label: 'Unit Assignment',
                                    value: _selectedUnit,
                                    items: const [
                                      {
                                        'value': 'unit1',
                                        'label': 'Kigali Central Station'
                                      },
                                      {
                                        'value': 'unit2',
                                        'label': 'Nyamirambo Station'
                                      },
                                      {
                                        'value': 'unit3',
                                        'label': 'Kicukiro Station'
                                      },
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _selectedUnit = value),
                                    required: true,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _phoneController,
                                    label: 'Phone Number',
                                    hint: '+250 788 000 000',
                                    required: true,
                                    prefixIcon: Icons.phone,
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _emailController,
                                    label: 'Email',
                                    hint: 'officer@rnp.gov.rw',
                                    prefixIcon: Icons.email,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDateField(
                                    label: 'Employment Date',
                                    value: _employmentDate,
                                    onChanged: (date) =>
                                        setState(() => _employmentDate = date),
                                    required: true,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildStatusToggle(),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                widget.officer == null ? 'Add New Officer' : 'Edit Officer',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Fill in the officer details below',
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

  Widget _buildStatusToggle() {
    return Row(
      children: [
        const Text(
          'Active Status',
          style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () => setState(() => _isActive = !_isActive),
          child: Container(
            width: 52,
            height: 28,
            decoration: BoxDecoration(
              color:
                  _isActive ? const Color(0xFF1E88E5) : const Color(0xFF37404F),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(2),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment:
                  _isActive ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _isActive ? 'Active' : 'Inactive',
          style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
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
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
            label: Text(
              widget.officer == null ? 'Add Officer' : 'Update Officer',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
    IconData? prefixIcon,
    bool enabled = true,
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
          enabled: enabled,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF78909C)),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: const Color(0xFF78909C), size: 20)
                : null,
            filled: true,
            fillColor:
                enabled ? const Color(0xFF2A3040) : const Color(0xFF1A1F2E),
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
                borderSide:
                    const BorderSide(color: Color(0xFFE85C5C), width: 2)),
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
    required DateTime? value,
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
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
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
                const Icon(Icons.calendar_today,
                    color: Color(0xFF78909C), size: 16),
                const SizedBox(width: 12),
                Text(
                  value != null
                      ? '${value.day}/${value.month}/${value.year}'
                      : 'Select date',
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
