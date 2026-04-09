import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

import '../config/api_config.dart';
import '../services/verification_api_service.dart';
import '../theme/app_colors.dart';

class ConnectionSetupScreen extends StatefulWidget {
  const ConnectionSetupScreen({super.key});

  @override
  State<ConnectionSetupScreen> createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends State<ConnectionSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _pinController;
  late final VerificationApiService _apiService;

  bool _isExchanging = false;
  bool _isUpdatingUrl = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = VerificationApiService();
    _apiBaseUrlController = TextEditingController(
      text: ApiConfig.effectiveBaseUrl,
    );
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _apiService.dispose();
    _apiBaseUrlController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String _normalizeApiBaseUrl(String value) {
    final normalized = ApiConfig.normalizeBaseUrlInput(value);
    if (normalized.endsWith('/api')) {
      return normalized;
    }
    return '$normalized/api';
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceName = 'Unknown Device';
    String deviceFingerprint = 'unknown_fingerprint';
    String platform = 'unknown';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceName = '${androidInfo.brand} ${androidInfo.model}';
      deviceFingerprint = androidInfo.id;
      platform = 'android';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = iosInfo.name;
      deviceFingerprint = iosInfo.identifierForVendor ?? 'unknown_ios_id';
      platform = 'ios';
    }

    return {
      'device_name': deviceName,
      'device_fingerprint': deviceFingerprint,
      'platform': platform,
      'app_version': '1.0.0', // Could be fetched via package_info_plus
    };
  }

  Future<void> _exchangePin() async {
    if (ApiConfig.hasDeviceCredentials) {
      setState(() {
        _errorMessage =
            'This phone is already enrolled. Remove the active enrollment from the web dashboard before enrolling again.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isExchanging = true;
      _errorMessage = null;
    });

    try {
      final normalizedApiBaseUrl = _normalizeApiBaseUrl(
        _apiBaseUrlController.text,
      );

      final deviceData = await _getDeviceInfo();

      final result = await _apiService.exchangePin(
        baseUrl: normalizedApiBaseUrl,
        pin: _pinController.text,
        deviceFingerprint: deviceData['device_fingerprint']!,
        deviceName: deviceData['device_name']!,
        platform: deviceData['platform']!,
        appVersion: deviceData['app_version']!,
      );

      await ApiConfig.saveRuntimeConfig(
        baseUrl: normalizedApiBaseUrl,
        officerId: result['officer_id'].toString(),
        deviceKey: result['device_key'].toString(),
        deviceToken: result['device_token'].toString(),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isExchanging = false);
      }
    }
  }

  Future<void> _editApiBaseUrl() async {
    final inputBaseUrl = _apiBaseUrlController.text.trim();
    if (inputBaseUrl.isEmpty) {
      setState(() {
        _errorMessage = 'API Base URL is required.';
      });
      return;
    }

    final normalizedApiBaseUrl = _normalizeApiBaseUrl(inputBaseUrl);
    if (!ApiConfig.isValidHttpUrl(normalizedApiBaseUrl)) {
      setState(() {
        _errorMessage =
            'API Base URL must be a valid absolute URL using http:// or https://.';
      });
      return;
    }

    setState(() {
      _isUpdatingUrl = true;
      _errorMessage = null;
    });

    try {
      await ApiConfig.saveManualBaseUrl(normalizedApiBaseUrl);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('API Base URL updated.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isUpdatingUrl = false);
      }
    }
  }

  Future<void> _clearLocalEnrollmentCredentials() async {
    final shouldClear =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Clear local enrollment credentials?'),
            content: const Text(
              'This only clears saved credentials on this phone. You must remove the active enrollment from the web dashboard before enrolling again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldClear) return;

    await ApiConfig.clearDeviceCredentials();

    if (!mounted) return;

    setState(() {
      _pinController.clear();
      _errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local enrollment credentials cleared.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Connection Setup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              const Icon(
                Icons.phonelink_setup,
                size: 64,
                color: AppColors.accentBlue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Connection Setup',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Edit API Base URL when the server address changes. Enrollment PIN is only needed to enroll a new device.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              if (ApiConfig.hasDeviceCredentials) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This phone is already enrolled. Re-enrollment is blocked until the current device is removed from the web dashboard.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const Text(
                'Connection',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set the SafeArms API Base URL for this phone.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _apiBaseUrlController,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cloud_queue),
                ),
                cursorColor: AppColors.textPrimary,
                style: const TextStyle(color: AppColors.textPrimary),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'API Base URL is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isUpdatingUrl || _isExchanging
                    ? null
                    : _editApiBaseUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isUpdatingUrl
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Text(
                        'EDIT API URL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
              const SizedBox(height: 32),

              const Divider(color: AppColors.border),
              const SizedBox(height: 20),
              const Text(
                'Enrollment',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use a 6-digit commander PIN only when enrolling this device for the first time.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: '6-Digit Enrollment PIN',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
                cursorColor: AppColors.textPrimary,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  letterSpacing: 8,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'PIN is required';
                  }
                  if (value.length != 6) {
                    return 'PIN must be 6 digits';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed:
                    _isExchanging ||
                        _isUpdatingUrl ||
                        ApiConfig.hasDeviceCredentials
                    ? null
                    : _exchangePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isExchanging
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Text(
                        'ENROLL DEVICE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),

              if (ApiConfig.hasDeviceCredentials) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _clearLocalEnrollmentCredentials,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear Local Enrollment Credentials'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
