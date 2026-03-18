// Login Screen
// User authentication screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isBrandingExpanded = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      // Navigate to OTP screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              OtpScreen(username: _usernameController.text.trim()),
        ),
      );
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed'),
          backgroundColor: const Color(0xFFE85C5C),
        ),
      );
    }
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
                            label: 'Sign In',
                            onTap: () => setState(
                              () => _isBrandingExpanded = false,
                            ),
                          )
                        : _buildLoginForm(compact: true),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                // Left Panel - Branding
                Expanded(flex: 4, child: _buildBrandingPanel()),
                // Right Panel - Login Form
                Expanded(flex: 6, child: _buildLoginForm()),
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
    const Color logoBgColor = Color(0xFFF0F3F6);

    if (collapsed) {
      return Container(
        color: logoBgColor,
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
            // Logo
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const Spacer(),
          ],
        ),
      );
    }

    return Container(
      color: logoBgColor,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 28.0 : 60.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
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
                width: compact ? 200 : 280,
                height: compact ? 200 : 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: compact ? 30 : 40),
              // Tagline
              Text(
                'Police Firearm Control &\nInvestigation Support Platform',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 16 : 20,
                  color: const Color(
                      0xFF1A1F2E), // Using dark background color for high contrast
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              Text(
                'RWANDA NATIONAL POLICE',
                style: TextStyle(
                  fontSize: compact ? 13 : 15,
                  color: const Color(0xFF1E88E5), // Using app primary color
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm({bool compact = false}) {
    return Container(
      color: const Color(0xFF1A1F2E),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 20.0 : 40.0,
            vertical: compact ? 28.0 : 40.0,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: compact ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your credentials to access SafeArms',
                    style: TextStyle(fontSize: 16, color: Color(0xFFB0BEC5)),
                  ),
                  const SizedBox(height: 40),
                  // Username Input
                  _buildInputField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username is required';
                      }
                      if (value.trim().length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Password Input
                  _buildPasswordField(),
                  const SizedBox(height: 24),
                  // Info Box
                  _buildInfoBox(),
                  const SizedBox(height: 32),
                  // Login Button
                  _buildLoginButton(),
                  const SizedBox(height: 24),
                  // Footer
                  const Center(
                    child: Text(
                      '© 2026 Rwanda National Police',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78909C)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
          const Icon(Icons.login, color: Color(0xFF64B5F6), size: 24),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFB0BEC5),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
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
              borderSide: const BorderSide(color: Color(0xFFE85C5C)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE85C5C), width: 2),
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF78909C)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFB0BEC5),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            return null;
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
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
              borderSide: const BorderSide(color: Color(0xFFE85C5C)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE85C5C), width: 2),
            ),
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFF78909C),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF78909C),
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
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
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: Color(0xFF1E88E5), width: 4),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF42A5F5), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Two-factor authentication required after login',
              style: TextStyle(fontSize: 14, color: Color(0xFFE3F2FD)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
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
              'Sign In',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
