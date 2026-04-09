import 'package:flutter/material.dart';

import '../models/approval_request.dart';
import '../theme/app_colors.dart';
import '../widgets/action_button.dart';

enum VerificationDecision { approve, reject }

class DecisionConfirmationScreen extends StatefulWidget {
  const DecisionConfirmationScreen({
    super.key,
    required this.request,
    required this.decision,
    required this.onCancel,
    required this.onConfirm,
    this.isSubmitting = false,
  });

  final ApprovalRequest request;
  final VerificationDecision decision;
  final VoidCallback onCancel;
  final ValueChanged<String?> onConfirm;
  final bool isSubmitting;

  @override
  State<DecisionConfirmationScreen> createState() =>
      _DecisionConfirmationScreenState();
}

class _DecisionConfirmationScreenState
    extends State<DecisionConfirmationScreen> {
  final TextEditingController _notesController = TextEditingController();
  String? _selectedReason;

  static const List<String> _rejectReasons = [
    'Wrong firearm serial',
    'Officer mismatch',
    'Physical verification failed',
    'Missing operational detail',
  ];

  bool get _canConfirm {
    if (widget.decision == VerificationDecision.approve) {
      return true;
    }
    return _selectedReason != null;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canConfirm) {
      return;
    }

    if (widget.decision == VerificationDecision.approve) {
      widget.onConfirm(null);
      return;
    }

    final note = _notesController.text.trim();
    final reason = _selectedReason!;
    if (note.isEmpty) {
      widget.onConfirm(reason);
      return;
    }

    widget.onConfirm('$reason | $note');
  }

  @override
  Widget build(BuildContext context) {
    final approving = widget.decision == VerificationDecision.approve;
    final heading = approving ? 'Confirm Approval' : 'Confirm Rejection';
    final actionColor = approving ? AppColors.success : AppColors.reject;

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                approving
                    ? 'One tap to complete verified approval.'
                    : 'Select one reason before rejecting.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line('Request', widget.request.requestId),
                    _line('Firearm', widget.request.firearmSerial),
                    _line('Requested By', widget.request.requestedBy),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!approving) ...[
                const Text(
                  'Reason',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _rejectReasons
                      .map(
                        (reason) => ChoiceChip(
                          label: Text(reason),
                          selected: _selectedReason == reason,
                          onSelected: (selected) {
                            if (!selected) {
                              return;
                            }
                            setState(() => _selectedReason = reason);
                          },
                          selectedColor: AppColors.reject,
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          labelStyle: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 200,
                  cursorColor: AppColors.textPrimary,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Optional note',
                    counterStyle: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'This approval will be written to custody audit records.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.isSubmitting ? null : widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActionButton(
                      label: 'Confirm',
                      onPressed: (_canConfirm && !widget.isSubmitting)
                          ? _submit
                          : null,
                      backgroundColor: actionColor,
                      isLoading: widget.isSubmitting,
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

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
