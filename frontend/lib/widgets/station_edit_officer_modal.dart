// Station Edit Officer Modal
// Unit-specific officer editing for Station Commanders
// Uses same form layout as StationAddOfficerModal
// SafeArms Frontend

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/officer_provider.dart';
import '../providers/auth_provider.dart';
import '../models/officer_model.dart';

class StationEditOfficerModal extends StatefulWidget {
  final OfficerModel officer;
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const StationEditOfficerModal({
    Key? key,
    required this.officer,
    required this.onClose,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<StationEditOfficerModal> createState() =>
      _StationEditOfficerModalState();
}

class _StationEditOfficerModalState extends State<StationEditOfficerModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _officerNumberController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _rankController;

  late DateTime? _dateOfBirth;
  late DateTime? _employmentDate;
  late bool _isActive;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _officerNumberController =
        TextEditingController(text: widget.officer.officerNumber);
    _fullNameController = TextEditingController(text: widget.officer.fullName);
    _phoneController =
        TextEditingController(text: widget.officer.phoneNumber ?? '');
    _emailController = TextEditingController(text: widget.officer.email ?? '');
    _rankController = TextEditingController(text: widget.officer.rank);
    _dateOfBirth = widget.officer.dateOfBirth;
    _employmentDate = widget.officer.employmentDate;
    _isActive = widget.officer.isActive;
  }

  @override
  void dispose() {
    _officerNumberController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _rankController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final officerProvider = context.read<OfficerProvider>();
      final success = await officerProvider.updateOfficer(
        officerId: widget.officer.officerId,
        fullName: _fullNameController.text.trim(),
        rank: _rankController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        dateOfBirth: _dateOfBirth,
        isActive: _isActive,
      );

      if (success) {
        widget.onSuccess();
      } else {
        setState(() {
          _errorMessage =
              officerProvider.errorMessage ?? 'Failed to update officer';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSubmitting = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isEmploymentDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isEmploymentDate
          ? (_employmentDate ?? DateTime.now())
          : (_dateOfBirth ??
              DateTime.now().subtract(const Duration(days: 365 * 25))),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1E88E5),
              surface: Color(0xFF252A3A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isEmploymentDate) {
          _employmentDate = picked;
        } else {
          _dateOfBirth = picked;
        }
      });
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
          width: 600,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            borderRadius: BorderRadius.circular(16),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Unit Assignment Banner
                        _buildUnitBanner(unitName),
                        const SizedBox(height: 24),

                        // Error Message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE85C5C)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFE85C5C)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Color(0xFFE85C5C), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: Color(0xFFE85C5C)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Officer Information Section
                        _buildSectionHeader('Officer Information'),
                        const SizedBox(height: 16),

                        // Officer Number (read-only) and Full Name
                        Row(
                          children: [
                            Expanded(child: _buildOfficerNumberField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFullNameField()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Rank
                        _buildRankField(),
                        const SizedBox(height: 24),

                        // Contact Information Section
                        _buildSectionHeader('Contact Information'),
                        const SizedBox(height: 16),

                        // Phone and Email
                        Row(
                          children: [
                            Expanded(child: _buildPhoneField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildEmailField()),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Dates Section
                        _buildSectionHeader('Employment Details'),
                        const SizedBox(height: 16),

                        // Date of Birth and Employment Date
                        Row(
                          children: [
                            Expanded(child: _buildDateOfBirthPicker()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildEmploymentDatePicker()),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Active Status Toggle
                        _buildActiveStatusToggle(),
                        const SizedBox(height: 32),

                        // Submit Button
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
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
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC857).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit, color: Color(0xFFFFC857), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Officer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.officer.officerNumber,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white54),
            hoverColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitBanner(String unitName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E88E5).withValues(alpha: 0.2),
            const Color(0xFF1A1F2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.apartment, color: Color(0xFF1E88E5), size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unit Assignment',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              Text(
                unitName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF37404F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Locked',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildOfficerNumberField() {
    return TextFormField(
      controller: _officerNumberController,
      enabled: false,
      style: const TextStyle(color: Colors.white54),
      decoration: _inputDecoration('Officer Number (read-only)', Icons.badge),
    );
  }

  Widget _buildFullNameField() {
    return TextFormField(
      controller: _fullNameController,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Full Name', Icons.person),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Full name is required';
        }
        return null;
      },
    );
  }

  Widget _buildRankField() {
    return TextFormField(
      controller: _rankController,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Rank', Icons.military_tech),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Rank is required';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Phone Number', Icons.phone),
      keyboardType: TextInputType.phone,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Phone number is required';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Email (Optional)', Icons.email),
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildDateOfBirthPicker() {
    return InkWell(
      onTap: () => _selectDate(context, false),
      child: InputDecorator(
        decoration: _inputDecoration('Date of Birth', Icons.cake),
        child: Text(
          _dateOfBirth != null
              ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
              : 'Select date',
          style: TextStyle(
            color: _dateOfBirth != null ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildEmploymentDatePicker() {
    return InkWell(
      onTap: () => _selectDate(context, true),
      child: InputDecorator(
        decoration: _inputDecoration('Employment Date', Icons.work),
        child: Text(
          _employmentDate != null
              ? '${_employmentDate!.day}/${_employmentDate!.month}/${_employmentDate!.year}'
              : 'Select date',
          style: TextStyle(
            color: _employmentDate != null ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveStatusToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isActive ? Icons.check_circle : Icons.cancel,
                color: _isActive
                    ? const Color(0xFF3CCB7F)
                    : const Color(0xFFE85C5C),
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'Active Status',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          Switch(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            activeColor: const Color(0xFF3CCB7F),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          disabledBackgroundColor:
              const Color(0xFF1E88E5).withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: const Color(0xFF1A1F2E),
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
        borderSide: const BorderSide(color: Color(0xFF1E88E5)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE85C5C)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE85C5C)),
      ),
    );
  }
}
