import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'connection_setup_screen.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({
    super.key,
    required this.onVerified,
    this.expectedPin = '2468',
    this.isInteractive = true,
  });

  final VoidCallback onVerified;
  final String expectedPin;
  final bool isInteractive;

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  static const int _pinLength = 4;
  String _pin = '';

  void _onNumberTap(String value) {
    if (!widget.isInteractive || _pin.length >= _pinLength) return;
    setState(() => _pin += value);
    if (_pin.length == _pinLength) {
      if (_pin == widget.expectedPin) {
        widget.onVerified();
      } else {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _pin = '');
        });
      }
    }
  }

  void _onDeleteTap() {
    if (!widget.isInteractive || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _buildDot(bool isFilled) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isFilled ? AppColors.accentBlue : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isFilled
              ? AppColors.accentBlue
              : AppColors.textSecondary.withAlpha(128),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildKey(String value, {required double keySize}) {
    final textSize = (keySize * 0.35).clamp(22.0, 28.0);

    return SizedBox(
      width: keySize,
      height: keySize,
      child: InkWell(
        borderRadius: BorderRadius.circular(keySize / 2),
        onTap: () => _onNumberTap(value),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: textSize,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactHeight = constraints.maxHeight < 700;
            final isVeryCompactHeight = constraints.maxHeight < 620;

            final baseKeySize = ((constraints.maxWidth - 64) / 3).clamp(
              56.0,
              80.0,
            );
            final keySize = isVeryCompactHeight
                ? baseKeySize.clamp(52.0, 64.0)
                : (isCompactHeight
                      ? baseKeySize.clamp(56.0, 72.0)
                      : baseKeySize);

            final topSpacing = isVeryCompactHeight
                ? 16.0
                : (isCompactHeight ? 24.0 : 60.0);
            final sectionSpacing = isCompactHeight ? 28.0 : 60.0;
            final promptSpacing = isCompactHeight ? 20.0 : 30.0;
            final keypadSpacing = isCompactHeight ? 18.0 : 26.0;
            final rowSpacing = isCompactHeight ? 6.0 : 10.0;
            final bottomSpacing = isCompactHeight ? 20.0 : 48.0;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SizedBox(height: topSpacing),
                      Icon(
                        Icons.security,
                        color: AppColors.accentBlue,
                        size: isCompactHeight ? 48 : 56,
                      ),
                      SizedBox(height: isCompactHeight ? 12 : 16),
                      Text(
                        'SafeArms',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: isCompactHeight ? 24 : 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rwanda National Police',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: isCompactHeight ? 13 : 14,
                        ),
                      ),
                      SizedBox(height: sectionSpacing),
                      Text(
                        'Enter PIN to confirm identity',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: isCompactHeight ? 15 : 16,
                        ),
                      ),
                      SizedBox(height: promptSpacing),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pinLength,
                          (index) => _buildDot(index < _pin.length),
                        ),
                      ),
                      SizedBox(height: keypadSpacing),
                      for (final row in const [
                        ['1', '2', '3'],
                        ['4', '5', '6'],
                        ['7', '8', '9'],
                      ]) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final value in row)
                              _buildKey(value, keySize: keySize),
                          ],
                        ),
                        SizedBox(height: rowSpacing),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(width: keySize, height: keySize),
                          _buildKey('0', keySize: keySize),
                          SizedBox(
                            width: keySize,
                            height: keySize,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(keySize / 2),
                              onTap: _onDeleteTap,
                              child: const Center(
                                child: Icon(
                                  Icons.backspace_outlined,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompactHeight ? 4 : 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ConnectionSetupScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Connection Setup'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentBlue,
                        ),
                      ),
                      SizedBox(height: bottomSpacing),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
