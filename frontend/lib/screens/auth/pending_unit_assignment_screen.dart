import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class PendingUnitAssignmentScreen extends StatefulWidget {
  const PendingUnitAssignmentScreen({super.key});

  @override
  State<PendingUnitAssignmentScreen> createState() =>
      _PendingUnitAssignmentScreenState();
}

class _PendingUnitAssignmentScreenState
    extends State<PendingUnitAssignmentScreen> {
  bool _isSigningOut = false;

  Future<void> _signOutToLogin() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
          sessionExpiredMessage:
              'Account is pending unit assignment. Sign in again after admin assignment.',
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final username =
        authProvider.currentUser?['username']?.toString() ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF252A3A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF37404F)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.schedule_outlined,
                      color: Color(0xFF1E88E5),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Pending Unit Assignment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Account $username is active, but a unit has not been assigned yet.',
                    style: const TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ask an administrator to select you as Unit Commander in Units Management. After assignment, sign in again and confirm your unit.',
                    style: TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSigningOut ? null : _signOutToLogin,
                      icon: _isSigningOut
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.logout, size: 18),
                      label: Text(
                          _isSigningOut ? 'Signing out...' : 'Return to Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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
}
