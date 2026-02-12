// Delete User Confirmation Modal
// SafeArms Frontend

import 'package:flutter/material.dart';

class DeleteUserConfirmationModal extends StatefulWidget {
  final String userId;
  final String fullName;
  final String username;
  final VoidCallback onClose;
  final VoidCallback onConfirm;

  const DeleteUserConfirmationModal({
    Key? key,
    required this.userId,
    required this.fullName,
    required this.username,
    required this.onClose,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<DeleteUserConfirmationModal> createState() => _DeleteUserConfirmationModalState();
}

class _DeleteUserConfirmationModalState extends State<DeleteUserConfirmationModal> {
  bool _confirmChecked = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1F2E).withValues(alpha: 0.95),
      child: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            borderRadius: BorderRadius.circular(16),
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
              const Icon(Icons.warning, color: Color(0xFFE85C5C), size: 64),
              const SizedBox(height: 24),
              const Text(
                'Delete User Account?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3040),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF37404F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${widget.username}',
                      style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'This action cannot be undone. All user data and access will be permanently removed.',
                style: TextStyle(color: Color(0xFFE85C5C), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () => setState(() => _confirmChecked = !_confirmChecked),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _confirmChecked ? const Color(0xFFE85C5C) : Colors.transparent,
                        border: Border.all(
                          color: _confirmChecked ? const Color(0xFFE85C5C) : const Color(0xFF37404F),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _confirmChecked
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'I understand this action is permanent',
                      style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: widget.onClose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF78909C),
                      side: const BorderSide(color: Color(0xFF37404F)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _confirmChecked ? widget.onConfirm : null,
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text(
                      'Delete User',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE85C5C),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF78909C).withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
