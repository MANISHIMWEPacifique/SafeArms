// Custody Dialog
// Dialog for assigning/returning firearms

import 'package:flutter/material.dart';

class CustodyDialog extends StatelessWidget {
  final String title;
  final String actionLabel;
  final Color actionColor;
  final Widget content;
  final VoidCallback? onAction;
  final bool isLoading;

  const CustodyDialog({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.content,
    this.actionColor = const Color(0xFF1E88E5),
    this.onAction,
    this.isLoading = false,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String actionLabel,
    required Widget content,
    Color actionColor = const Color(0xFF1E88E5),
    VoidCallback? onAction,
    bool isLoading = false,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => CustodyDialog(
        title: title,
        actionLabel: actionLabel,
        content: content,
        actionColor: actionColor,
        onAction: onAction,
        isLoading: isLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A3040),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF78909C)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF37404F)),
              const SizedBox(height: 16),
              content,
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF78909C)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: isLoading ? null : onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(actionLabel),
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
