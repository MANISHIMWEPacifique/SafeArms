import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, this.maxLength = 4});

  final int length;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (index) {
        final filled = index < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.accentBlue : Colors.transparent,
            border: Border.all(
              color: filled ? AppColors.accentBlue : AppColors.border,
              width: 1.6,
            ),
          ),
        );
      }),
    );
  }
}
