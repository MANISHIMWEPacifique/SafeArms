import 'package:flutter/material.dart';

import '../models/approval_request.dart';
import '../theme/app_colors.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({
    super.key,
    required this.request,
    required this.approved,
    required this.onDone,
    this.autoClose = true,
  });

  final ApprovalRequest request;
  final bool approved;
  final VoidCallback onDone;
  final bool autoClose;

  @override
  Widget build(BuildContext context) {
    final statusText = approved ? 'Approved' : 'Rejected';
    final statusColor = approved ? AppColors.success : AppColors.reject;
    final statusIcon = approved ? Icons.check_circle : Icons.cancel;
    final subtitle = approved
        ? 'Authorization recorded successfully'
        : 'Rejection recorded successfully';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withAlpha(25),
                ),
                padding: const EdgeInsets.all(20),
                child: Icon(statusIcon, size: 80, color: statusColor),
              ),
              const SizedBox(height: 24),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Transaction ID: ${request.requestId}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
