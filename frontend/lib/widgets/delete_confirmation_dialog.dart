import 'package:flutter/material.dart';

/// Reusable delete confirmation dialog styled after Dialog A (Minimal Sharp).
///
/// Usage:
/// ```dart
/// final confirmed = await DeleteConfirmationDialog.show(
///   context: context,
///   title: 'Delete Officer?',
///   message: 'You are about to permanently delete',
///   itemName: 'John Doe',
///   detail: 'All associated records will be removed. This cannot be undone.',
///   confirmText: 'Delete Officer',
/// );
/// ```
class DeleteConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? itemName;
  final String? detail;
  final String confirmText;
  final VoidCallback? onConfirm;

  const DeleteConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.itemName,
    this.detail,
    this.confirmText = 'Delete',
    this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String? itemName,
    String? detail,
    String confirmText = 'Delete',
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0xE0020812),
      builder: (ctx) => DeleteConfirmationDialog(
        title: title,
        message: message,
        itemName: itemName,
        detail: detail,
        confirmText: confirmText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
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
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
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
                        TextSpan(text: message),
                        if (itemName != null) ...[
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: '"$itemName"',
                            style: const TextStyle(
                              color: Color(0xFF1E88E5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const TextSpan(text: '. '),
                        ],
                        if (detail != null) TextSpan(text: detail),
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
                  // Cancel button
                  Expanded(
                    child: Material(
                      color: const Color(0xFF252A3A),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(false),
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
                  // Delete button
                  Expanded(
                    child: Material(
                      color: const Color(0xFF8B1A1A),
                      child: InkWell(
                        onTap: () {
                          onConfirm?.call();
                          Navigator.of(context).pop(true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            confirmText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
    );
  }
}
