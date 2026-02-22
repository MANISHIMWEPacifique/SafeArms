// Unit Confirmation Screen
// Station commanders confirm their assigned unit

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboards/station_commander_dashboard.dart';

class UnitConfirmationScreen extends StatefulWidget {
  const UnitConfirmationScreen({super.key});

  @override
  State<UnitConfirmationScreen> createState() => _UnitConfirmationScreenState();
}

class _UnitConfirmationScreenState extends State<UnitConfirmationScreen> {
  bool _isConfirmed = false;
  bool _isLoading = false;

  Future<void> _handleConfirm() async {
    if (!_isConfirmed) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.confirmUnit();

    if (!mounted) return;

    if (success) {
      // Navigate to Station Commander Dashboard
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const StationCommanderDashboard(),
        ),
        (route) => false,
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Failed to confirm unit'),
          backgroundColor: const Color(0xFFE85C5C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              color: const Color(0xFF252A3A),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(48.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // SafeArms Logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF1E88E5),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 24),

                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF42A5F5),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                const Text(
                  'Confirm Your Unit Assignment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is a one-time setup to link your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFFB0BEC5)),
                ),
                const SizedBox(height: 32),

                // User Info Card
                _buildUserInfoCard(user),
                const SizedBox(height: 24),

                // Assigned Unit Card
                _buildUnitCard(),
                const SizedBox(height: 24),

                // Info Message
                _buildInfoMessage(),
                const SizedBox(height: 24),

                // Confirmation Checkbox
                _buildCheckbox(),
                const SizedBox(height: 24),

                // Confirm Button
                _buildConfirmButton(),
                const SizedBox(height: 24),

                // Help Text
                _buildHelpText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(Map<String, dynamic>? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Color(0xFF78909C), size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LOGGED IN AS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78909C),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?['username'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Station Commander',
                  style: TextStyle(fontSize: 14, color: Color(0xFFB0BEC5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF1E88E5), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.business,
                  color: Color(0xFF42A5F5),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'YOUR ASSIGNED UNIT',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB0BEC5),
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Nyamirambo Police Station',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildUnitDetail(Icons.category, 'Police Station'),
          const SizedBox(height: 8),
          _buildUnitDetail(Icons.location_on, 'Nyamirambo, Kigali'),
        ],
      ),
    );
  }

  Widget _buildUnitDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF78909C), size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: Color(0xFFB0BEC5)),
        ),
      ],
    );
  }

  Widget _buildInfoMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: Color(0xFF42A5F5), width: 4),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF42A5F5), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Once confirmed, you will have access to manage firearms and officers within this unit only.',
              style: TextStyle(fontSize: 14, color: Color(0xFFE3F2FD)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox() {
    return InkWell(
      onTap: () => setState(() => _isConfirmed = !_isConfirmed),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color:
                  _isConfirmed ? const Color(0xFF1E88E5) : Colors.transparent,
              border: Border.all(
                color: _isConfirmed
                    ? const Color(0xFF1E88E5)
                    : const Color(0xFF37404F),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _isConfirmed
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          const Text(
            'I confirm this is my assigned unit',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final isEnabled = _isConfirmed && !_isLoading;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled ? _handleConfirm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
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
                'Confirm & Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildHelpText() {
    return Column(
      children: [
        const Text(
          'Wrong unit assigned?',
          style: TextStyle(fontSize: 14, color: Color(0xFF78909C)),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: const Color(0xFF252A3A),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.support_agent,
                          color: Color(0xFF1E88E5),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Contact System Administrator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'If your unit assignment is incorrect, please contact the system administrator to request a reassignment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB0BEC5),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3040),
                          border: Border.all(color: const Color(0xFF37404F)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.email_outlined,
                                    color: Color(0xFF78909C), size: 18),
                                SizedBox(width: 12),
                                Text(
                                  'admin@safearms.rw',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.phone_outlined,
                                    color: Color(0xFF78909C), size: 18),
                                SizedBox(width: 12),
                                Text(
                                  '+250 788 000 000',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: const Text(
            'Contact System Administrator',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64B5F6),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
