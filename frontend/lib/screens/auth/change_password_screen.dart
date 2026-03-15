// Change Password Screen
// Shown when must_change_password flag is true (first login with admin-provided password)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboards/admin_dashboard.dart';
import '../dashboards/hq_commander_dashboard.dart';
import '../dashboards/station_commander_dashboard.dart';
import '../dashboards/investigator_dashboard.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isBrandingExpanded = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Password validation
  bool _hasMinLength(String password) => password.length >= 8;
  bool _hasUppercase(String password) => password.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String password) => password.contains(RegExp(r'[a-z]'));
  bool _hasNumber(String password) => password.contains(RegExp(r'[0-9]'));
  bool _hasSpecialChar(String password) =>
      password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  bool _isPasswordValid(String password) {
    return _hasMinLength(password) &&
        _hasUppercase(password) &&
        _hasLowercase(password) &&
        _hasNumber(password) &&
        _hasSpecialChar(password);
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.changePassword(
      _oldPasswordController.text,
      _newPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully! Redirecting...'),
          backgroundColor: Color(0xFF3CCB7F),
        ),
      );

      // Navigate to the appropriate screen
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _navigateToAppropriateScreen(authProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(authProvider.errorMessage ?? 'Failed to change password'),
          backgroundColor: const Color(0xFFE85C5C),
        ),
      );
    }
  }

  void _navigateToAppropriateScreen(AuthProvider authProvider) {
    Widget screen;

    switch (authProvider.userRole) {
      case 'admin':
        screen = const AdminDashboard();
        break;
      case 'hq_firearm_commander':
        screen = const HqCommanderDashboard();
        break;
      case 'station_commander':
        screen = const StationCommanderDashboard();
        break;
      case 'investigator':
        screen = const InvestigatorDashboard();
        break;
      default:
        screen = const AdminDashboard();
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => screen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;
    final primaryWidth = (screenWidth * 0.88).clamp(280.0, screenWidth - 64.0);
    final secondaryWidth = (screenWidth - primaryWidth).clamp(56.0, 120.0);
    final brandingWidth = _isBrandingExpanded ? primaryWidth : secondaryWidth;
    final formWidth = _isBrandingExpanded ? secondaryWidth : primaryWidth;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: isMobile
          ? SafeArea(
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    width: brandingWidth,
                    child: _isBrandingExpanded
                        ? _buildBrandingPanel(
                            compact: true,
                            collapsible: true,
                            onToggle: () => setState(
                              () => _isBrandingExpanded = false,
                            ),
                          )
                        : _buildBrandingPanel(
                            compact: true,
                            collapsible: true,
                            collapsed: true,
                            onToggle: () => setState(
                              () => _isBrandingExpanded = true,
                            ),
                          ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    width: formWidth,
                    child: _isBrandingExpanded
                        ? _buildCollapsedFormTab(
                            label: 'Password',
                            onTap: () => setState(
                              () => _isBrandingExpanded = false,
                            ),
                          )
                        : _buildChangePasswordForm(compact: true),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                // Left Panel - Branding
                Expanded(flex: 4, child: _buildBrandingPanel()),
                // Right Panel - Change Password Form
                Expanded(flex: 6, child: _buildChangePasswordForm()),
              ],
            ),
    );
  }

  Widget _buildBrandingPanel({
    bool compact = false,
    bool collapsible = false,
    bool collapsed = false,
    VoidCallback? onToggle,
  }) {
    if (collapsed) {
      return Container(
        color: Colors.white,
        child: Column(
          children: [
            if (collapsible)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: onToggle,
                  icon: const Icon(Icons.chevron_right),
                  color: const Color(0xFF1E88E5),
                ),
              ),
            const Spacer(),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Color(0xFF1E88E5),
              ),
            ),
            const SizedBox(height: 16),
            const RotatedBox(
              quarterTurns: 3,
              child: Text(
                'SafeArms',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E88E5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 28.0 : 60.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (collapsible)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: onToggle,
                    icon: const Icon(Icons.chevron_left),
                    color: const Color(0xFF1E88E5),
                  ),
                ),
              // Logo
              Container(
                width: compact ? 88 : 120,
                height: compact ? 88 : 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: compact ? 44 : 64,
                  color: const Color(0xFF1E88E5),
                ),
              ),
              SizedBox(height: compact ? 20 : 32),
              Text(
                'SafeArms',
                style: TextStyle(
                  fontSize: compact ? 32 : 42,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E88E5),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: compact ? 10 : 16),
              Text(
                'Secure Your Account',
                style: TextStyle(
                  fontSize: compact ? 14 : 16,
                  color: const Color(0xFF78909C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangePasswordForm({bool compact = false}) {
    return Container(
      color: const Color(0xFF1A1F2E),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 20.0 : 40.0,
            vertical: compact ? 28.0 : 40.0,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'Change Your Password',
                    style: TextStyle(
                      fontSize: compact ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account requires a password change before continuing',
                    style: TextStyle(fontSize: 16, color: Color(0xFFB0BEC5)),
                  ),
                  const SizedBox(height: 32),

                  // Lock icon
                  _buildLockIcon(),
                  const SizedBox(height: 32),

                  // Info banner
                  _buildInfoBanner(),
                  const SizedBox(height: 24),

                  // Old password (admin-provided)
                  _buildFieldLabel('Current Password (provided by admin)'),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    controller: _oldPasswordController,
                    hint: 'Enter admin-provided password',
                    obscure: _obscureOldPassword,
                    onToggle: () => setState(
                        () => _obscureOldPassword = !_obscureOldPassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // New password
                  _buildFieldLabel('New Password'),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    controller: _newPasswordController,
                    hint: 'Enter your new password',
                    obscure: _obscureNewPassword,
                    onToggle: () => setState(
                        () => _obscureNewPassword = !_obscureNewPassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (!_isPasswordValid(value)) {
                        return 'Password does not meet requirements';
                      }
                      if (value == _oldPasswordController.text) {
                        return 'New password must be different from current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Confirm password
                  _buildFieldLabel('Confirm New Password'),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    hint: 'Re-enter your new password',
                    obscure: _obscureConfirmPassword,
                    onToggle: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Password requirements
                  _buildPasswordRequirements(),
                  const SizedBox(height: 32),

                  // Submit button
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockIcon() {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFFF9800).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.lock_reset,
          size: 40,
          color: Color(0xFFFF9800),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3E2723).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: Color(0xFFFF9800), width: 4),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFFFFB74D), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'For security, you must set a personal password to replace the one provided by your administrator.',
              style: TextStyle(fontSize: 14, color: Color(0xFFFFE0B2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFFB0BEC5),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF78909C)),
        filled: true,
        fillColor: const Color(0xFF2A3040),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF78909C)),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF78909C),
          ),
          onPressed: onToggle,
        ),
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
          borderSide: const BorderSide(color: Color(0xFFE85C5C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE85C5C), width: 2),
        ),
        errorStyle: const TextStyle(color: Color(0xFFE85C5C)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    final password = _newPasswordController.text;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password Requirements',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB0BEC5),
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementRow(
              'At least 8 characters', _hasMinLength(password)),
          const SizedBox(height: 6),
          _buildRequirementRow(
              'One uppercase letter (A-Z)', _hasUppercase(password)),
          const SizedBox(height: 6),
          _buildRequirementRow(
              'One lowercase letter (a-z)', _hasLowercase(password)),
          const SizedBox(height: 6),
          _buildRequirementRow('One number (0-9)', _hasNumber(password)),
          const SizedBox(height: 6),
          _buildRequirementRow(
              'One special character (!@#\$%^&*)', _hasSpecialChar(password)),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 16,
          color: met ? const Color(0xFF3CCB7F) : const Color(0xFF78909C),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: met ? const Color(0xFF3CCB7F) : const Color(0xFF78909C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleChangePassword,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
        disabledBackgroundColor: const Color(0xFF37404F),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Set New Password & Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildCollapsedFormTab({
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      color: const Color(0xFF1A1F2E),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.chevron_left),
              color: const Color(0xFF64B5F6),
            ),
          ),
          const Spacer(),
          const Icon(Icons.lock_reset, color: Color(0xFF64B5F6), size: 24),
          const SizedBox(height: 14),
          RotatedBox(
            quarterTurns: 1,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
