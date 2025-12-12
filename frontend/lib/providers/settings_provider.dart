// Settings Provider - State management for system configuration
// SafeArms Frontend

import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  // State
  Map<String, dynamic> _systemSettings = {};
  List<Map<String, dynamic>> _auditLogs = [];
  Map<String, dynamic> _systemHealth = {};
  Map<String, dynamic> _mlConfiguration = {};
  
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  Map<String, dynamic> get systemSettings => _systemSettings;
  List<Map<String, dynamic>> get auditLogs => _auditLogs;
  Map<String, dynamic> get systemHealth => _systemHealth;
  Map<String, dynamic> get mlConfiguration => _mlConfiguration;
  
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // Load system settings
  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _systemSettings = await _settingsService.getSystemSettings();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save system settings
  Future<bool> saveSettings(Map<String, dynamic> settings) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final success = await _settingsService.updateSettings(settings);
      if (success) {
        _systemSettings = settings;
        _successMessage = 'Settings saved successfully';
      }
      _isSaving = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // Load audit logs
  Future<void> loadAuditLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    String? action,
    String? status,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _auditLogs = await _settingsService.getAuditLogs(
        startDate: startDate,
        endDate: endDate,
        userId: userId,
        action: action,
        status: status,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load system health
  Future<void> loadSystemHealth() async {
    try {
      _systemHealth = await _settingsService.getSystemHealth();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading system health: $e');
    }
  }

  // Load ML configuration
  Future<void> loadMLConfiguration() async {
    _isLoading = true;
    notifyListeners();

    try {
      _mlConfiguration = await _settingsService.getMLConfiguration();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update ML configuration
  Future<bool> updateMLConfiguration(Map<String, dynamic> config) async {
    _isSaving = true;
    notifyListeners();

    try {
      final success = await _settingsService.updateMLConfiguration(config);
      if (success) {
        _mlConfiguration = config;
        _successMessage = 'ML configuration updated';
      }
      _isSaving = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // Train ML model
  Future<bool> trainMLModel() async {
    _isSaving = true;
    notifyListeners();

    try {
      final success = await _settingsService.trainMLModel();
      if (success) {
        _successMessage = 'Model training started';
      }
      _isSaving = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // Clear messages
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
