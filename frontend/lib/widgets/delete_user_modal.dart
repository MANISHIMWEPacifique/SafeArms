// Delete User Confirmation Modal
// SafeArms Frontend — Dialog A (Minimal Sharp) style

import 'package:flutter/material.dart';

class DeleteUserConfirmationModal extends StatelessWidget {
  final String userId;
  final String fullName;
  final String username;
  final VoidCallback onClose;
  final VoidCallback onConfirm;

  const DeleteUserConfirmationModal({
    super.key,
    required this.userId,
    required this.fullName,
    required this.username,
    required this.onClose,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE0020812),
      child: Center(
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            border: Border.all(color: const Color(0xFF37404F)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 80,
                offset: const Offset(0, 32),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Content area
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE85C5C).withValues(alpha: 0.1),
                        border: Border.all(
                          color:
                              const Color(0xFFE85C5C).withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_remove_outlined,
                          color: Color(0xFFE85C5C),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    const Text(
                      'Delete User?',
                      style: TextStyle(
                        color: Color(0xFFD0E4F8),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Description
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF78909C),
                          fontSize: 13.5,
                          height: 1.65,
                        ),
                        children: [
                          const TextSpan(
                              text: 'You are about to permanently delete '),
                          TextSpan(
                            text: '"$fullName"',
                            style: const TextStyle(
                              color: Color(0xFF1E88E5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: ' (@$username). ',
                          ),
                          const TextSpan(
                            text:
                                'All user data and access will be permanently removed. This cannot be undone.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons (full-width split)
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF37404F)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: const Color(0xFF252A3A),
                        child: InkWell(
                          onTap: onClose,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Color(0xFF37404F)),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: const Color(0xFF8B1A1A),
                        child: InkWell(
                          onTap: onConfirm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: const Text(
                              'Delete User',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFFFAAAA),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
