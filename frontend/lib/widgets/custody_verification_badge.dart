import 'package:flutter/material.dart';

class CustodyVerificationBadge extends StatelessWidget {
  final Map<String, dynamic> custody;

  const CustodyVerificationBadge({
    super.key,
    required this.custody,
  });

  @override
  Widget build(BuildContext context) {
    final state = _VerificationBadgeState.fromCustody(custody);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: state.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: state.color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(state.icon, color: state.color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.label,
                  style: TextStyle(
                    color: state.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (state.signature.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              state.signature,
              style: TextStyle(
                color: state.color.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _VerificationBadgeState {
  final String label;
  final Color color;
  final IconData icon;
  final String signature;

  const _VerificationBadgeState({
    required this.label,
    required this.color,
    required this.icon,
    required this.signature,
  });

  factory _VerificationBadgeState.fromCustody(Map<String, dynamic> custody) {
    final status = (custody['verification_status'] ?? 'not_requested')
        .toString()
        .toLowerCase();
    final verificationId = custody['verification_id']?.toString().trim() ?? '';
    final decidedDeviceKey =
        custody['verification_decided_device_key']?.toString().trim() ?? '';

    final signature = status == 'approved'
        ? [verificationId, decidedDeviceKey]
            .where((part) => part.isNotEmpty)
            .join(' / ')
        : verificationId;

    switch (status) {
      case 'approved':
        return _VerificationBadgeState(
          label: 'Verified',
          color: const Color(0xFF3CCB7F),
          icon: Icons.verified_rounded,
          signature: signature,
        );
      case 'pending':
        return _VerificationBadgeState(
          label: 'Verification Pending',
          color: const Color(0xFFFFC857),
          icon: Icons.pending_actions_rounded,
          signature: signature,
        );
      case 'rejected':
      case 'cancelled':
      case 'expired':
        return _VerificationBadgeState(
          label: 'Verification ${status.toUpperCase()}',
          color: const Color(0xFFE85C5C),
          icon: Icons.gpp_bad_rounded,
          signature: signature,
        );
      default:
        return _VerificationBadgeState(
          label: 'Verification Not Requested',
          color: const Color(0xFF78909C),
          icon: Icons.shield_outlined,
          signature: signature,
        );
    }
  }
}
