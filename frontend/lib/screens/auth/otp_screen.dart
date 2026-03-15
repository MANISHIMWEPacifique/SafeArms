// OTP Verification Screen
// Email-based OTP (6-digit code) verification

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'change_password_screen.dart';
import '../dashboards/admin_dashboard.dart';
import '../dashboards/hq_commander_dashboard.dart';
import '../dashboards/station_commander_dashboard.dart';
import '../dashboards/investigator_dashboard.dart';

class OtpScreen extends StatefulWidget {
  final String username;

  const OtpScreen({super.key, required this.username});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  bool _isInvalid = false;
  bool _isBrandingExpanded = false;
  int _remainingSeconds = 300; // 5 minutes
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Auto-focus first input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getOtpCode() {
    return _controllers.map((c) => c.text).join();
  }

  bool _isCodeComplete() {
    return _controllers.every((c) => c.text.isNotEmpty);
  }

  Future<void> _handleVerify() async {
    if (!_isCodeComplete()) return;

    setState(() {
      _isLoading = true;
      _isInvalid = false;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyOtp(_getOtpCode());

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      // Navigate based on role and unit confirmation status
      _navigateToAppropriateScreen(authProvider);
    } else {
      // Show error
      setState(() => _isInvalid = true);
      _shakeAnimation();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Invalid OTP code'),
          backgroundColor: const Color(0xFFE85C5C),
        ),
      );
    }
  }

  void _navigateToAppropriateScreen(AuthProvider authProvider) {
    Widget screen;

    // Check if user must change their password first
    if (authProvider.requiresPasswordChange) {
      screen = const ChangePasswordScreen();
    } else {
      // Navigate to role-specific dashboard
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
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => screen),
      (route) => false,
    );
  }

  void _shakeAnimation() {
    // Simple invalid feedback
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _isInvalid = false);
      }
    });
  }

  Future<void> _handleResendOtp() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.resendOtp();

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      // Clear inputs and restart timer
      for (var controller in _controllers) {
        controller.clear();
      }
      _startTimer();
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New OTP code sent to your email'),
          backgroundColor: Color(0xFF3CCB7F),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Failed to resend OTP'),
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
                            label: 'Verify',
                            onTap: () => setState(
                              () => _isBrandingExpanded = false,
                            ),
                          )
                        : _buildOtpForm(compact: true),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                // Left Panel - Branding
                Expanded(flex: 4, child: _buildBrandingPanel()),
                // Right Panel - OTP Form
                Expanded(flex: 6, child: _buildOtpForm()),
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
                'Secure Access',
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

  Widget _buildOtpForm({bool compact = false}) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'Two-Factor Authentication',
                  style: TextStyle(
                    fontSize: compact ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter the 6-digit code sent to your email',
                  style: TextStyle(fontSize: 16, color: Color(0xFFB0BEC5)),
                ),
                const SizedBox(height: 16),
                // User indicator
                _buildUserChip(),
                const SizedBox(height: 32),
                // Icon
                _buildAuthIcon(),
                const SizedBox(height: 32),
                // 6-digit input
                _buildOtpInputs(),
                const SizedBox(height: 16),
                // Timer
                _buildTimer(),
                const SizedBox(height: 24),
                // Info box
                _buildInfoBox(),
                const SizedBox(height: 32),
                // Verify button
                _buildVerifyButton(),
                const SizedBox(height: 24),
                // Divider
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF37404F))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(color: Color(0xFF78909C)),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0xFF37404F))),
                  ],
                ),
                const SizedBox(height: 24),
                // Help section
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Having trouble?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB0BEC5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading ? null : _handleResendOtp,
                        child: const Text(
                          'Resend OTP Code',
                          style: TextStyle(
                            color: Color(0xFF64B5F6),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Back button
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF78909C)),
                  label: const Text(
                    'Back to Login',
                    style: TextStyle(color: Color(0xFF78909C)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserChip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, size: 16, color: Color(0xFF78909C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Logged in as: ${widget.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Color(0xFFB0BEC5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthIcon() {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.email_outlined,
          size: 40,
          color: Color(0xFF42A5F5),
        ),
      ),
    );
  }

  Widget _buildOtpInputs() {
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 500;
    final horizontalPadding = compact ? 40.0 : 0.0;
    final spacing = compact ? 8.0 : 12.0;
    final availableWidth = screenWidth - horizontalPadding;
    final boxWidth =
        ((availableWidth - (spacing * 5)) / 6).clamp(42.0, 56.0).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        return Padding(
          padding: EdgeInsets.only(right: index < 5 ? spacing : 0),
          child: _buildOtpBox(index, boxWidth),
        );
      }),
    );
  }

  Widget _buildOtpBox(int index, double boxWidth) {
    return SizedBox(
      width: boxWidth,
      height: (boxWidth * 1.14).clamp(50.0, 64.0),
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF2A3040),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _isInvalid
                  ? const Color(0xFFE85C5C)
                  : const Color(0xFF37404F),
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _isInvalid
                  ? const Color(0xFFE85C5C)
                  : const Color(0xFF37404F),
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _isInvalid
                  ? const Color(0xFFE85C5C)
                  : const Color(0xFF1E88E5),
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          setState(() => _isInvalid = false);
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (_isCodeComplete()) {
            _handleVerify();
          }
        },
        onTap: () {
          _controllers[index].selection = TextSelection.fromPosition(
            TextPosition(offset: _controllers[index].text.length),
          );
        },
      ),
    );
  }

  Widget _buildTimer() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time,
            size: 16,
            color: Color(0xFFB0BEC5), // textSecondary
          ),
          const SizedBox(width: 8),
          Text(
            'Code expires in: ${_formatTime(_remainingSeconds)}',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB0BEC5), // textSecondary
            ),
          ),
        ],
      ),
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
          Icon(Icons.shield_outlined, color: Color(0xFF42A5F5), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Check your email for the 6-digit verification code',
              style: TextStyle(fontSize: 14, color: Color(0xFFE3F2FD)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    final isEnabled = _isCodeComplete() && !_isLoading;
    return ElevatedButton(
      onPressed: isEnabled ? _handleVerify : null,
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
              'Verify & Continue',
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
          const Icon(Icons.verified_user, color: Color(0xFF64B5F6), size: 24),
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
