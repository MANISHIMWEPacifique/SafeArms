// Settings Provider - State management for system configuration
// SafeArms Frontend — backed by SharedPreferences

import 'package:flutter/foundation.dart';
import '../services/preferences_service.dart';
import '../services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  PreferencesService? _prefs;
  final SettingsService _settingsService = SettingsService();

  bool _isLoading = false;
  final bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // ── General ──────────────────────
  String _dateFormat = PreferencesService.defaultDateFormat;
  String _timeFormat = PreferencesService.defaultTimeFormat;
  int _itemsPerPage = PreferencesService.defaultItemsPerPage;
  int _sessionTimeout = PreferencesService.defaultSessionTimeout;

  // ── Anomaly Detection ────────────
  double _anomalyThreshold = PreferencesService.defaultAnomalyThreshold;
  double _criticalThreshold = PreferencesService.defaultCriticalThreshold;
  bool _autoRefreshEnabled = PreferencesService.defaultAutoRefreshEnabled;
  int _autoRefreshInterval = PreferencesService.defaultAutoRefreshInterval;

  // ── Security ─────────────────────
  int _minPasswordLength = PreferencesService.defaultMinPasswordLength;
  int _otpValidityMinutes = PreferencesService.defaultOtpValidity;
  int _maxOtpAttempts = PreferencesService.defaultMaxOtpAttempts;
  bool _enforce2FA = PreferencesService.defaultEnforce2FA;

  // ── Notifications ────────────────
  bool _notifyCriticalAnomalies = PreferencesService.defaultNotifyCritical;
  bool _notifyPendingApprovals = PreferencesService.defaultNotifyApprovals;
  bool _notifyCustodyChanges = PreferencesService.defaultNotifyCustody;

  // ── ML Model Status ──────────────
  Map<String, dynamic>? _mlStatus;
  bool _isTraining = false;
  String? _trainingError;

  // ── Getters ──────────────────────
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  String get dateFormat => _dateFormat;
  String get timeFormat => _timeFormat;
  int get itemsPerPage => _itemsPerPage;
  int get sessionTimeout => _sessionTimeout;

  double get anomalyThreshold => _anomalyThreshold;
  double get criticalThreshold => _criticalThreshold;
  bool get autoRefreshEnabled => _autoRefreshEnabled;
  int get autoRefreshInterval => _autoRefreshInterval;

  int get minPasswordLength => _minPasswordLength;
  int get otpValidityMinutes => _otpValidityMinutes;
  int get maxOtpAttempts => _maxOtpAttempts;
  bool get enforce2FA => _enforce2FA;

  bool get notifyCriticalAnomalies => _notifyCriticalAnomalies;
  bool get notifyPendingApprovals => _notifyPendingApprovals;
  bool get notifyCustodyChanges => _notifyCustodyChanges;

  // ML Model Status
  Map<String, dynamic>? get mlStatus => _mlStatus;
  bool get isTraining => _isTraining;
  String? get trainingError => _trainingError;
  bool get hasActiveModel => _mlStatus?['active_model'] != null;
  bool get canTrain => _mlStatus?['can_train'] == true;

  // ── Load all settings from SharedPreferences ─────────────
  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _prefs = await PreferencesService.getInstance();

      _dateFormat = _prefs!.dateFormat;
      _timeFormat = _prefs!.timeFormat;
      _itemsPerPage = _prefs!.itemsPerPage;
      _sessionTimeout = _prefs!.sessionTimeout;

      _anomalyThreshold = _prefs!.anomalyThreshold;
      _criticalThreshold = _prefs!.criticalThreshold;
      _autoRefreshEnabled = _prefs!.autoRefreshEnabled;
      _autoRefreshInterval = _prefs!.autoRefreshInterval;

      _minPasswordLength = _prefs!.minPasswordLength;
      _otpValidityMinutes = _prefs!.otpValidityMinutes;
      _maxOtpAttempts = _prefs!.maxOtpAttempts;
      _enforce2FA = _prefs!.enforce2FA;

      _notifyCriticalAnomalies = _prefs!.notifyCriticalAnomalies;
      _notifyPendingApprovals = _prefs!.notifyPendingApprovals;
      _notifyCustodyChanges = _prefs!.notifyCustodyChanges;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // No-op for backward compatibility (nothing to load from server)
  Future<void> loadSystemHealth() async {}

  // ── Individual setters (persist immediately) ──────────────

  // General
  Future<void> setDateFormat(String value) async {
    _dateFormat = value;
    await _prefs?.setDateFormat(value);
    notifyListeners();
  }

  Future<void> setTimeFormat(String value) async {
    _timeFormat = value;
    await _prefs?.setTimeFormat(value);
    notifyListeners();
  }

  Future<void> setItemsPerPage(int value) async {
    _itemsPerPage = value;
    await _prefs?.setItemsPerPage(value);
    notifyListeners();
  }

  Future<void> setSessionTimeout(int value) async {
    _sessionTimeout = value;
    await _prefs?.setSessionTimeout(value);
    notifyListeners();
  }

  // Anomaly Detection
  Future<void> setAnomalyThreshold(double value) async {
    _anomalyThreshold = value;
    await _prefs?.setAnomalyThreshold(value);
    notifyListeners();
  }

  Future<void> setCriticalThreshold(double value) async {
    _criticalThreshold = value;
    await _prefs?.setCriticalThreshold(value);
    notifyListeners();
  }

  Future<void> setAutoRefreshEnabled(bool value) async {
    _autoRefreshEnabled = value;
    await _prefs?.setAutoRefreshEnabled(value);
    notifyListeners();
  }

  Future<void> setAutoRefreshInterval(int value) async {
    _autoRefreshInterval = value;
    await _prefs?.setAutoRefreshInterval(value);
    notifyListeners();
  }

  // Security
  Future<void> setMinPasswordLength(int value) async {
    _minPasswordLength = value;
    await _prefs?.setMinPasswordLength(value);
    notifyListeners();
  }

  Future<void> setOtpValidityMinutes(int value) async {
    _otpValidityMinutes = value;
    await _prefs?.setOtpValidityMinutes(value);
    notifyListeners();
  }

  Future<void> setMaxOtpAttempts(int value) async {
    _maxOtpAttempts = value;
    await _prefs?.setMaxOtpAttempts(value);
    notifyListeners();
  }

  Future<void> setEnforce2FA(bool value) async {
    _enforce2FA = value;
    await _prefs?.setEnforce2FA(value);
    notifyListeners();
  }

  // Notifications
  Future<void> setNotifyCriticalAnomalies(bool value) async {
    _notifyCriticalAnomalies = value;
    await _prefs?.setNotifyCriticalAnomalies(value);
    notifyListeners();
  }

  Future<void> setNotifyPendingApprovals(bool value) async {
    _notifyPendingApprovals = value;
    await _prefs?.setNotifyPendingApprovals(value);
    notifyListeners();
  }

  Future<void> setNotifyCustodyChanges(bool value) async {
    _notifyCustodyChanges = value;
    await _prefs?.setNotifyCustodyChanges(value);
    notifyListeners();
  }

  // ── ML Model Management ─────────────────────────────────

  Future<void> loadMLStatus() async {
    try {
      _mlStatus = await _settingsService.getMLStatus();
      _trainingError = null;
      notifyListeners();
    } catch (e) {
      // Silently fail — ML status is supplementary info
      _trainingError = null;
      notifyListeners();
    }
  }

  Future<void> trainModel() async {
    _isTraining = true;
    _trainingError = null;
    notifyListeners();

    try {
      await _settingsService.trainMLModel();
      // Wait briefly then refresh status
      await Future.delayed(const Duration(seconds: 2));
      await loadMLStatus();
      _isTraining = false;
      _successMessage = 'Model training completed successfully';
      notifyListeners();
    } catch (e) {
      _isTraining = false;
      _trainingError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  // ── Reset to defaults ─────────────────────────────────────
  Future<void> resetToDefaults() async {
    await _prefs?.resetToDefaults();
    await loadSettings();
    _successMessage = 'Settings reset to defaults';
    notifyListeners();
  }

  // ── Messages ──────────────────────────────────────────────
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void showSuccess(String message) {
    _successMessage = message;
    notifyListeners();
  }
}
