import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_colors.dart';

class ConnectionSetupScreen extends StatefulWidget {
  const ConnectionSetupScreen({super.key});

  @override
  State<ConnectionSetupScreen> createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends State<ConnectionSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _officerIdController;
  late final TextEditingController _deviceKeyController;
  late final TextEditingController _deviceTokenController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _apiBaseUrlController = TextEditingController(
      text: ApiConfig.effectiveBaseUrl,
    );
    _officerIdController = TextEditingController(
      text: ApiConfig.effectiveOfficerId,
    );
    _deviceKeyController = TextEditingController(
      text: ApiConfig.effectiveDeviceKey,
    );
    _deviceTokenController = TextEditingController(
      text: ApiConfig.effectiveDeviceToken,
    );
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _officerIdController.dispose();
    _deviceKeyController.dispose();
    _deviceTokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ApiConfig.saveRuntimeConfig(
        baseUrl: _apiBaseUrlController.text,
        officerId: _officerIdController.text,
        deviceKey: _deviceKeyController.text,
        deviceToken: _deviceTokenController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _useBuildDefaults() async {
    setState(() => _isSaving = true);

    try {
      await ApiConfig.clearRuntimeConfig();

      _apiBaseUrlController.text = ApiConfig.baseUrl;
      _officerIdController.text = ApiConfig.officerId;
      _deviceKeyController.text = ApiConfig.deviceKey;
      _deviceTokenController.text = ApiConfig.deviceToken;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Runtime overrides cleared. Build-time values restored.',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _requiredValidator(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Connection Setup',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Standalone mode requires a reachable backend URL (LAN or public). Example LAN URL: http://192.168.1.10:3000/api',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _apiBaseUrlController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration('API Base URL'),
                  validator: (value) =>
                      _requiredValidator(value, 'API Base URL'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _officerIdController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration('Officer ID'),
                  validator: (value) => _requiredValidator(value, 'Officer ID'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deviceKeyController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration('Device Key'),
                  validator: (value) => _requiredValidator(value, 'Device Key'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deviceTokenController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration('Device Token'),
                  validator: (value) =>
                      _requiredValidator(value, 'Device Token'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _useBuildDefaults,
                  icon: const Icon(Icons.restore),
                  label: const Text('Use Build Defaults'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save and Continue'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accentBlue),
      ),
    );
  }
}
