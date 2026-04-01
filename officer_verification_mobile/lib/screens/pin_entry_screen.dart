import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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

  Widget _buildKey(String value) {
    return SizedBox(
      width: 80,
      height: 80,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () => _onNumberTap(value),
        child: Center(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
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
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.security, color: AppColors.accentBlue, size: 56),
            const SizedBox(height: 16),
            const Text(
              'SafeArms',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Rwanda National Police',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 60),
            const Text(
              'Enter PIN to confirm identity',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pinLength,
                (index) => _buildDot(index < _pin.length),
              ),
            ),
            const Spacer(),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ]) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map(_buildKey).toList(),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 80, height: 80),
                _buildKey('0'),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(40),
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
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
