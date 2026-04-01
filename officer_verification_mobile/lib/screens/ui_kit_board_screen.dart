import 'package:flutter/material.dart';

import '../models/approval_request.dart';
import '../theme/app_colors.dart';
import '../widgets/iphone14_frame.dart';
import 'decision_confirmation_screen.dart';
import 'incoming_request_screen.dart';
import 'pin_entry_screen.dart';
import 'splash_screen.dart';
import 'success_screen.dart';

class UiKitBoardScreen extends StatefulWidget {
  const UiKitBoardScreen({super.key, required this.onStartFlow});

  final VoidCallback onStartFlow;

  @override
  State<UiKitBoardScreen> createState() => _UiKitBoardScreenState();
}

class _UiKitBoardScreenState extends State<UiKitBoardScreen> {
  int _index = 0;

  final ApprovalRequest _request = ApprovalRequest.sample();

  late final List<_PreviewItem> _items = [
    _PreviewItem(
      label: 'Splash',
      builder: () => const SplashScreen(autoAdvance: false),
    ),
    _PreviewItem(
      label: 'PIN Entry',
      builder: () => PinEntryScreen(
        expectedPin: '2468',
        isInteractive: false,
        onVerified: () {},
      ),
    ),
    _PreviewItem(
      label: 'Incoming Request',
      builder: () => IncomingRequestScreen(
        request: _request,
        onApprove: () {},
        onReject: () {},
        onDismiss: () {},
      ),
    ),
    _PreviewItem(
      label: 'Confirm Decision',
      builder: () => DecisionConfirmationScreen(
        request: _request,
        decision: VerificationDecision.reject,
        onCancel: () {},
        onConfirm: (_) {},
      ),
    ),
    _PreviewItem(
      label: 'Success',
      builder: () => SuccessScreen(
        request: _request,
        approved: true,
        autoClose: false,
        onDone: () {},
      ),
    ),
  ];

  void _move(int delta) {
    setState(() {
      _index = (_index + delta).clamp(0, _items.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _items[_index];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 460;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                children: [
                  const Text(
                    'SafeArms Officer Verification UI Kit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Professional, secure, one-tap mobile flow',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  IPhone14Frame(
                    child: IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: current.builder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_items.length, (i) {
                      final selected = i == _index;
                      return ChoiceChip(
                        selected: selected,
                        onSelected: (_) => setState(() => _index = i),
                        label: Text(_items[i].label),
                        selectedColor: AppColors.accentBlue,
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _index > 0 ? () => _move(-1) : null,
                          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                          label: const Text('Previous'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _index < _items.length - 1
                              ? () => _move(1)
                              : null,
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          label: const Text('Next'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: isNarrow ? double.infinity : 420,
                    child: ElevatedButton.icon(
                      onPressed: widget.onStartFlow,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Open Live Verification Flow'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.accentBlue,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PreviewItem {
  const _PreviewItem({required this.label, required this.builder});

  final String label;
  final Widget Function() builder;
}
