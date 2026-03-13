import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? subtitle;
  final Widget? actionButton;
  final double iconSize;
  final EdgeInsets padding;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    this.title,
    this.subtitle,
    this.actionButton,
    this.iconSize = 64,
    this.padding = const EdgeInsets.all(48),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: const Color(0xFF78909C)),
            const SizedBox(height: 16),
            if (title != null)
              Text(
                title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            if (subtitle != null) ...[
              if (title != null) const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionButton != null) ...[
              const SizedBox(height: 24),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }
}
