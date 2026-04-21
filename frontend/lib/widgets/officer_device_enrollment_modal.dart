import 'package:flutter/material.dart';

import '../models/officer_model.dart';
import '../services/officer_verification_service.dart';
import 'base_modal_widget.dart';

class OfficerDeviceEnrollmentModal extends StatefulWidget {
  const OfficerDeviceEnrollmentModal({
    super.key,
    required this.officer,
    required this.onClose,
    this.onDeviceStateChanged,
  });

  final OfficerModel officer;
  final VoidCallback onClose;
  final VoidCallback? onDeviceStateChanged;

  @override
  State<OfficerDeviceEnrollmentModal> createState() =>
      _OfficerDeviceEnrollmentModalState();
}

class _OfficerDeviceEnrollmentModalState
    extends State<OfficerDeviceEnrollmentModal> {
  final OfficerVerificationService _verificationService =
      OfficerVerificationService();

  List<Map<String, dynamic>> _activeDevices = [];
  String? _pin;
//  DateTime? _expiresAt; // left unused for now
  bool _isLoadingDevices = true;
  bool _isGenerating = false;
  String? _removingDeviceKey;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadActiveDevices();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadActiveDevices() async {
    setState(() {
      _isLoadingDevices = true;
      _errorMessage = null;
    });

    try {
      final devices = await _verificationService.getOfficerDevices(
        widget.officer.officerId,
      );

      if (!mounted) return;

      setState(() {
        _activeDevices = devices;
        _isLoadingDevices = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingDevices = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _removeDevice(String deviceKey) async {
    setState(() {
      _removingDeviceKey = deviceKey;
      _errorMessage = null;
    });

    try {
      await _verificationService.removeOfficerDevice(deviceKey);
      await _loadActiveDevices();

      if (!mounted) return;

      widget.onDeviceStateChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device removed. You can now generate a new PIN.'),
          backgroundColor: Color(0xFF3CCB7F),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _removingDeviceKey = null;
        });
      }
    }
  }

  String _buildLastSeenText(Map<String, dynamic> device) {
    final lastSeen = device['last_seen_at']?.toString();
    if (lastSeen == null || lastSeen.isEmpty) {
      return 'Last seen: not available';
    }

    final parsed = DateTime.tryParse(lastSeen);
    if (parsed == null) {
      return 'Last seen: not available';
    }

    return 'Last seen: ${parsed.toLocal()}';
  }

  Future<void> _generatePin() async {
    if (_activeDevices.isNotEmpty) {
      setState(() {
        _errorMessage =
            'Officer already has an active enrolled device. Remove it first before generating a new PIN.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _pin = null;
//      _expiresAt = null;
    });

    try {
      final response = await _verificationService.generateEnrollmentPin(
        widget.officer.officerId,
        widget.officer.unitId,
      );

      if (!mounted) return;

      setState(() {
        _pin = response['pin'] as String;
//        _expiresAt = DateTime.tryParse(response['expires_at'] as String);
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseModalWidget(
      headerTitle: 'Enroll Officer Device',
      headerIcon: Icons.phonelink_setup,
      width: 500,
      body: _buildContent(),
      onClose: widget.onClose,
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildOfficerHeader(),
        const SizedBox(height: 24),
        if (_isLoadingDevices)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                ),
              ),
            ),
          ),
        if (!_isLoadingDevices && _activeDevices.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active enrolled device found. Remove it before generating a new PIN.',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._activeDevices.map((device) {
                  final deviceKey = device['device_key']?.toString() ?? '';
                  final deviceName =
                      (device['device_name']?.toString().trim().isNotEmpty ??
                              false)
                          ? device['device_name'].toString().trim()
                          : 'Unknown device';
                  final platform = (device['platform']
                              ?.toString()
                              .toUpperCase()
                              .trim()
                              .isNotEmpty ??
                          false)
                      ? device['platform'].toString().toUpperCase().trim()
                      : 'UNKNOWN';
                  final isRemoving = _removingDeviceKey == deviceKey;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D324A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android,
                            color: Color(0xFF00E5FF), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$deviceName ($platform)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _buildLastSeenText(device),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: isRemoving || deviceKey.isEmpty
                              ? null
                              : () => _removeDevice(deviceKey),
                          icon: isRemoving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFE85C5C),
                                    ),
                                  ),
                                )
                              : const Icon(Icons.delete_outline, size: 16),
                          label: Text(isRemoving ? 'Removing' : 'Remove'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE85C5C),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Text(
          _activeDevices.isEmpty
              ? 'Generate a secure 6-digit PIN to enroll the officer\'s mobile app.'
              : 'This officer is already enrolled. Remove the active device first to issue a new PIN.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_pin != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF2D324A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text(
                  'ENROLLMENT PIN',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _pin!,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter this PIN in the SafeArms Mobile App.\nExpires in 15 minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (_pin == null)
          Center(
            child: ElevatedButton(
              onPressed: _isGenerating ||
                      _isLoadingDevices ||
                      _activeDevices.isNotEmpty ||
                      _removingDeviceKey != null
                  ? null
                  : _generatePin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF1E2336),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF1E2336)),
                      ),
                    )
                  : const Text('GENERATE NEW PIN'),
            ),
          ),
      ],
    );
  }

  Widget _buildOfficerHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D324A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Color(0xFF00E5FF), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.officer.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.officer.officerNumber,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
