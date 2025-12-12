// Create/Edit User Modal Dialog
// SafeArms Frontend

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';

class CreateUserModal extends StatefulWidget {
  final UserModel? user; // null for create, not null for edit
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const CreateUserModal({
    Key? key,
    this.user,
    required this.onClose,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<CreateUserModal> createState() => _CreateUserModalState();
}

class _CreateUserModalState extends State<CreateUserModal> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // State
  String _selectedRole = 'station_commander';
  String? _selectedUnit;
  bool _isActive = true;
  bool _mustChangePassword = true;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _fullNameController.text = widget.user!.fullName;
      _emailController.text = widget.user!.email;
      _usernameController.text = widget.user!.username;
      _phoneController.text = widget.user!.phoneNumber ?? '';
      _selectedRole = widget.user!.role;
      _selectedUnit = widget.user!.unitId;
      _isActive = widget.user!.isActive;
      _mustChangePassword = widget.user!.mustChangePassword;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userProvider = context.read<UserProvider>();
    bool success;

    if (widget.user == null) {
      // Create new user
      success = await userProvider.createUser(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole,
        unitId: _selectedRole == 'station_commander' ? _selectedUnit : null,
        isActive: _isActive,
        mustChangePassword: _mustChangePassword,
      );
    } else {
      // Update existing user
      success = await userProvider.updateUser(
        userId: widget.user!.userId,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole,
        unitId: _selectedRole == 'station_commander' ? _selectedUnit : null,
        isActive: _isActive,
        mustChangePassword: _mustChangePassword,
      );
    }

    setState(() => _isLoading = false);

    if (success) {
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.user == null ? 'User created successfully' : 'User updated successfully'),
          backgroundColor: const Color(0xFF3CCB7F),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userProvider.errorMessage ?? 'Operation failed'),
          backgroundColor: const Color(0xFFE85C5C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1F2E).withOpacity(0.95),
      child: Center(
        child: Container(
          width: 800,
          constraints: const BoxConstraints(maxHeight: 700),
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
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPersonalInfo(),
                        const SizedBox(height: 24),
                        _buildAccountDetails(),
                        if (widget.user == null) ...[
                          const SizedBox(height: 24),
                          _buildPasswordFields(),
                        ],
                        const SizedBox(height: 24),
                        _buildRoleSelection(),
                        if (_selectedRole == 'station_commander') ...[
                          const SizedBox(height: 24),
                          _buildUnitAssignment(),
                        ],
                        const SizedBox(height: 24),
                        _buildStatusToggle(),
                        if (widget.user == null) ...[
                          const SizedBox(height: 24),
                          _buildPasswordChangeOption(),
                        ],
                        const SizedBox(height: 24),
                        _buildInfoBox(),
                        const SizedBox(height: 24),
                        _buildActionButtons(),
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
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF37404F), width: 1),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user == null ? 'Create New User' : 'Edit User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.user == null
                    ? 'Fill in the details below to create a new user account'
                    : 'Update user information',
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF78909C)),
            onPressed: widget.onClose,
            hoverColor: const Color(0xFFE85C5C).withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _fullNameController,
                label: 'Full Name',
                hint: 'e.g., Jean Paul Nkusi',
                required: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Full name is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                hint: 'user@rnp.gov.rw',
                required: true,
                prefixIcon: Icons.email,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountDetails() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _usernameController,
            label: 'Username',
            hint: 'username (no spaces)',
            required: true,
            enabled: widget.user == null, // Cannot change username when editing
            helperText: 'Minimum 3 characters, no spaces',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username is required';
              }
              if (value.length < 3) {
                return 'Minimum 3 characters';
              }
              if (value.contains(' ')) {
                return 'No spaces allowed';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: '+250 788 000 000',
            required: true,
            prefixIcon: Icons.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Phone number is required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordFields() {
    return Row(
      children: [
        Expanded(
          child: _buildPasswordField(
            controller: _passwordController,
            label: 'Initial Password',
            showPassword: _showPassword,
            onToggle: () => setState(() => _showPassword = !_showPassword),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 8) {
                return 'Minimum 8 characters';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPasswordField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            showPassword: _showConfirmPassword,
            onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Assign Role',
              style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildRoleCard(
              role: 'admin',
              icon: Icons.shield,
              iconColor: const Color(0xFFE85C5C),
              title: 'Admin',
              description: 'Full system access and configuration',
            ),
            const SizedBox(width: 12),
            _buildRoleCard(
              role: 'hq_firearm_commander',
              icon: Icons.military_tech,
              iconColor: const Color(0xFF1E88E5),
              title: 'HQ Commander',
              description: 'National oversight and approvals',
            ),
            const SizedBox(width: 12),
            _buildRoleCard(
              role: 'station_commander',
              icon: Icons.business,
              iconColor: const Color(0xFF3CCB7F),
              title: 'Station Commander',
              description: 'Unit-level firearm management',
            ),
            const SizedBox(width: 12),
            _buildRoleCard(
              role: 'forensic_analyst',
              icon: Icons.search,
              iconColor: const Color(0xFF42A5F5),
              title: 'Forensic Analyst',
              description: 'Investigation and forensic support',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedRole == role;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            border: Border.all(
              color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFF37404F),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFF37404F),
                        width: 2,
                      ),
                      color: isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.circle, color: Colors.white, size: 10),
                          )
                        : null,
                  ),
                  const Spacer(),
                  Icon(icon, color: iconColor, size: 32),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF78909C), fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitAssignment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Assigned Unit',
              style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
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
              value: _selectedUnit,
              isExpanded: true,
              hint: const Text(
                'Select police unit...',
                style: TextStyle(color: Color(0xFF78909C)),
              ),
              dropdownColor: const Color(0xFF2A3040),
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(
                  value: 'unit1',
                  child: Text('Nyamirambo Police Station'),
                ),
                DropdownMenuItem(
                  value: 'unit2',
                  child: Text('Kicukiro Police Station'),
                ),
                // Add more units from backend
              ],
              onChanged: (value) => setState(() => _selectedUnit = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusToggle() {
    return Row(
      children: [
        const Text(
          'Account Status',
          style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () => setState(() => _isActive = !_isActive),
          child: Container(
            width: 52,
            height: 28,
            decoration: BoxDecoration(
              color: _isActive ? const Color(0xFF1E88E5) : const Color(0xFF37404F),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(2),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: _isActive ? Alignment.centerRight : Alignment.centerLeft,
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

  Widget _buildPasswordChangeOption() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _mustChangePassword = !_mustChangePassword),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _mustChangePassword ? const Color(0xFF1E88E5) : Colors.transparent,
              border: Border.all(
                color: _mustChangePassword ? const Color(0xFF1E88E5) : const Color(0xFF37404F),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _mustChangePassword
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User must change password on first login',
                style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
              ),
              SizedBox(height: 2),
              Text(
                'Recommended for security',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF42A5F5), width: 4),
        ),
      ),
      child: Row(
        children: const [
          Icon(Icons.info, color: Color(0xFF42A5F5), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'System Admins are the only users who can create and manage user accounts. The new user will receive their credentials and 2FA setup instructions.',
              style: TextStyle(color: Color(0xFFE3F2FD), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: widget.onClose,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB0BEC5),
            side: const BorderSide(color: Color(0xFF37404F)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle, size: 18),
          label: Text(
            widget.user == null ? 'Create User' : 'Update User',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    IconData? prefixIcon,
    String? helperText,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
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
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF78909C), size: 20) : null,
            filled: true,
            fillColor: enabled ? const Color(0xFF2A3040) : const Color(0xFF1A1F2E),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: validator,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(helperText, style: const TextStyle(color: Color(0xFF78909C), fontSize: 11)),
        ],
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool showPassword,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('Initial Password', style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !showPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Minimum 8 characters',
            hintStyle: const TextStyle(color: Color(0xFF78909C)),
            suffixIcon: IconButton(
              icon: Icon(
                showPassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF78909C),
                size: 20,
              ),
              onPressed: onToggle,
            ),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: validator,
        ),
        const SizedBox(height: 4),
        const Text(
          'Minimum 8 characters',
          style: TextStyle(color: Color(0xFF78909C), fontSize: 11),
        ),
      ],
    );
  }
}
