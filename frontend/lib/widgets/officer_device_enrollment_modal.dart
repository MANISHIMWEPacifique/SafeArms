import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/officer_model.dart';
import '../services/officer_verification_service.dart';
import 'base_modal_widget.dart';

class OfficerDeviceEnrollmentModal extends StatefulWidget {
  const OfficerDeviceEnrollmentModal({
    super.key,
    required this.officer,
    required this.onClose,
  });

  final OfficerModel officer;
  final VoidCallback onClose;

  @override
  State<OfficerDeviceEnrollmentModal> createState() =>
      _OfficerDeviceEnrollmentModalState();
}

class _OfficerDeviceEnrollmentModalState
    extends State<OfficerDeviceEnrollmentModal> {
  final OfficerVerificationService _verificationService =
      OfficerVerificationService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _deviceFingerprintController =
      TextEditingController();
  final TextEditingController _appVersionController = TextEditingController();

  String _platform = 'android';
  bool _isLoadingDevices = false;
  bool _isRegistering = false;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _devices = <Map<String, dynamic>>[];
  Map<String, dynamic>? _latestEnrollment;

  @override
  void initState() {
    super.initState();
    _deviceNameController.text = '${widget.officer.fullName} Phone';
    _appVersionController.text = '1.0.0';
    _loadDevices();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _deviceFingerprintController.dispose();
    _appVersionController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoadingDevices = true;
      _errorMessage = null;
    });

    try {
      final devices =
          await _verificationService.getOfficerDevices(widget.officer.officerId);
      if (!mounted) return;

      setState(() {
        _devices = devices;
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

  Future<void> _registerDevice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _verificationService.registerOfficerDevice(
        officerId: widget.officer.officerId,
        platform: _platform,
        deviceName: _deviceNameController.text,
        deviceFingerprint: _deviceFingerprintController.text,
        appVersion: _appVersionController.text,
        metadata: <String, dynamic>{
          'registration_source': 'station_commander_dashboard',
        },
      );

      if (!mounted) return;

      setState(() {
        _latestEnrollment = result;
        _isRegistering = false;
        final reused = result['reused_existing_device'] == true;
        _successMessage = reused
            ? 'Existing device was found and token has been rotated.'
            : 'Device enrolled successfully. Share credentials with the officer.';
      });

      await _loadDevices();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRegistering = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _revokeDevice(String deviceKey) async {
    final shouldRevoke = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF252A3A),
          title: const Text(
            'Revoke Device?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'The officer will no longer receive verification requests on this device.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85C5C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Revoke'),
            ),
          ],
        );
      },
    );

    if (shouldRevoke != true) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _verificationService.revokeOfficerDevice(deviceKey);
      if (!mounted) return;

      setState(() {
        _successMessage = 'Device revoked successfully.';
      });

      await _loadDevices();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _copyValue(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          backgroundColor: const Color(0xFF3CCB7F),
        ),
      );
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return 'N/A';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    final local = parsed.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final latestDevice = _latestEnrollment?['device'] is Map
        ? Map<String, dynamic>.from(_latestEnrollment!['device'] as Map)
        : <String, dynamic>{};
    final latestDeviceKey = latestDevice['device_key']?.toString() ?? '';
    final latestToken = _latestEnrollment?['device_token']?.toString() ?? '';

    return BaseModalWidget(
      width: 860,
      headerTitle: 'Officer Device Enrollment',
      headerSubtitle:
          '${widget.officer.fullName} (${widget.officer.officerNumber})',
      headerIcon: Icons.phone_android,
      headerIconColor: const Color(0xFF1E88E5),
      onClose: widget.onClose,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E88E5)),
            ),
            child: const Text(
              'Register a phone for this officer. After enrollment, share the generated device key and token to configure the officer mobile app.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            _buildStatusBanner(_errorMessage!, const Color(0xFFE85C5C)),
            const SizedBox(height: 12),
          ],
          if (_successMessage != null) ...[
            _buildStatusBanner(_successMessage!, const Color(0xFF3CCB7F)),
            const SizedBox(height: 12),
          ],
          Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _platform,
                        decoration: _inputDecoration('Platform'),
                        items: const [
                          DropdownMenuItem(
                              value: 'android', child: Text('Android')),
                          DropdownMenuItem(value: 'ios', child: Text('iOS')),
                        ],
                        dropdownColor: const Color(0xFF252A3A),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _platform = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _deviceNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Device Name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _deviceFingerprintController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Device Fingerprint (optional)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _appVersionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('App Version'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isRegistering ? null : _registerDevice,
                    icon: _isRegistering
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      _isRegistering ? 'Registering...' : 'Register Device',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (latestDeviceKey.isNotEmpty || latestToken.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildLatestCredentialsCard(
              deviceKey: latestDeviceKey,
              token: latestToken,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Registered Devices',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _isLoadingDevices ? null : _loadDevices,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          if (_isLoadingDevices)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
              ),
            )
          else if (_devices.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF37404F)),
              ),
              child: Text(
                'No devices enrolled yet for this officer.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
              ),
            )
          else
            Column(
              children: _devices
                  .map((device) => _buildDeviceTile(device))
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 13),
      ),
    );
  }

  Widget _buildLatestCredentialsCard({
    required String deviceKey,
    required String token,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3CCB7F).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3CCB7F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest Device Credentials',
            style: TextStyle(
              color: Color(0xFF3CCB7F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildCredentialRow('Device Key', deviceKey),
          const SizedBox(height: 8),
          _buildCredentialRow('Device Token', token),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    final hasValue = value.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ),
        Expanded(
          child: SelectableText(
            hasValue ? value : 'N/A',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        IconButton(
          onPressed: hasValue ? () => _copyValue(label, value) : null,
          icon: const Icon(Icons.copy, size: 16),
          tooltip: 'Copy $label',
          color: const Color(0xFF3CCB7F),
        ),
      ],
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> device) {
    final deviceKey = device['device_key']?.toString() ?? 'N/A';
    final deviceName = device['device_name']?.toString().trim();
    final platform = device['platform']?.toString().toUpperCase() ?? 'UNKNOWN';
    final appVersion = device['app_version']?.toString().trim();
    final isRevoked = device['is_revoked'] == true;
    final enrolledAt = _formatDate(device['enrolled_at']);
    final lastSeen = _formatDate(device['last_seen_at']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (deviceName != null && deviceName.isNotEmpty)
                      ? deviceName
                      : 'Unnamed Device',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isRevoked
                      ? const Color(0xFFE85C5C).withValues(alpha: 0.2)
                      : const Color(0xFF3CCB7F).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isRevoked ? 'Revoked' : 'Active',
                  style: TextStyle(
                    color: isRevoked
                        ? const Color(0xFFE85C5C)
                        : const Color(0xFF3CCB7F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailLine('Device Key', deviceKey),
          _buildDetailLine('Platform', platform),
          _buildDetailLine('App Version',
              (appVersion != null && appVersion.isNotEmpty) ? appVersion : 'N/A'),
          _buildDetailLine('Enrolled', enrolledAt),
          _buildDetailLine('Last Seen', lastSeen),
          if (!isRevoked)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _revokeDevice(deviceKey),
                icon: const Icon(Icons.block, size: 16),
                label: const Text('Revoke'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE85C5C),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
      filled: true,
      fillColor: const Color(0xFF1A1F2E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF37404F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF37404F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1E88E5)),
      ),
    );
  }
}
