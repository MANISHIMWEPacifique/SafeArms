// Settings Provider - State management for system configuration
// SafeArms Frontend — backed by SharedPreferences

import 'package:flutter/foundation.dart';
import '../services/preferences_service.dart';
import '../services/settings_service.dart';
import '../utils/date_formatter.dart';

class SettingsProvider with ChangeNotifier {
  PreferencesService? _prefs;
  final SettingsService _settingsService = SettingsService();
  static const Duration _settingsReloadGracePeriod = Duration(seconds: 30);
  DateTime? _lastLoadedAt;
  Future<void>? _loadSettingsFuture;

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

  // ── Sync to Backend ──────────────────────
  Future<void> _syncToServer() async {
    try {
      await _settingsService.updateSettings({
        'date_format': _dateFormat,
        'time_format': _timeFormat,
        'items_per_page': _itemsPerPage,
        'session_timeout': _sessionTimeout,
        'anomaly_threshold': _anomalyThreshold,
        'critical_threshold': _criticalThreshold,
        'auto_refresh_enabled': _autoRefreshEnabled,
        'auto_refresh_interval': _autoRefreshInterval,
        'min_password_length': _minPasswordLength,
        'otp_validity_minutes': _otpValidityMinutes,
        'max_otp_attempts': _maxOtpAttempts,
        'enforce_2fa': _enforce2FA,
        'notify_critical_anomalies': _notifyCriticalAnomalies,
        'notify_pending_approvals': _notifyPendingApprovals,
        'notify_custody_changes': _notifyCustodyChanges,
      });
    } catch (e) {
      debugPrint('Warning: Failed to sync settings to server: $e');
    }
  }

  // ── Load all settings from SharedPreferences and API ─────────────
  Future<void> loadSettings({bool force = false}) async {
    if (_loadSettingsFuture != null) {
      await _loadSettingsFuture;
      if (!force) {
        return;
      }
    }

    if (!force &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) <
            _settingsReloadGracePeriod) {
      return;
    }

    final loadFuture = _loadSettingsInternal();
    _loadSettingsFuture = loadFuture;

    try {
      await loadFuture;
    } finally {
      if (identical(_loadSettingsFuture, loadFuture)) {
        _loadSettingsFuture = null;
      }
    }
  }

  Future<void> _loadSettingsInternal() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _prefs = await PreferencesService.getInstance();

      // Try fetching from server
      try {
        final dbSettings = await _settingsService.getSystemSettings();
        if (dbSettings.isNotEmpty) {
          if (dbSettings.containsKey('date_format')) {
            await _prefs!.setDateFormat(dbSettings['date_format'].toString());
          }
          if (dbSettings.containsKey('time_format')) {
            await _prefs!.setTimeFormat(dbSettings['time_format'].toString());
          }
          if (dbSettings.containsKey('items_per_page')) {
            await _prefs!.setItemsPerPage(
                int.tryParse(dbSettings['items_per_page'].toString()) ??
                    PreferencesService.defaultItemsPerPage);
          }
          if (dbSettings.containsKey('session_timeout')) {
            await _prefs!.setSessionTimeout(
                int.tryParse(dbSettings['session_timeout'].toString()) ??
                    PreferencesService.defaultSessionTimeout);
          }
          if (dbSettings.containsKey('min_password_length')) {
            await _prefs!.setMinPasswordLength(
                int.tryParse(dbSettings['min_password_length'].toString()) ??
                    PreferencesService.defaultMinPasswordLength);
          }
          if (dbSettings.containsKey('enforce_2fa')) {
            await _prefs!.setEnforce2FA(
                dbSettings['enforce_2fa'].toString().toLowerCase() == 'true');
          }
          if (dbSettings.containsKey('anomaly_threshold')) {
            await _prefs!.setAnomalyThreshold(
                double.tryParse(dbSettings['anomaly_threshold'].toString()) ??
                    PreferencesService.defaultAnomalyThreshold);
          }
          if (dbSettings.containsKey('critical_threshold')) {
            await _prefs!.setCriticalThreshold(
                double.tryParse(dbSettings['critical_threshold'].toString()) ??
                    PreferencesService.defaultCriticalThreshold);
          }
          if (dbSettings.containsKey('otp_validity_minutes')) {
            await _prefs!.setOtpValidityMinutes(
                int.tryParse(dbSettings['otp_validity_minutes'].toString()) ??
                    PreferencesService.defaultOtpValidity);
          }
          if (dbSettings.containsKey('max_otp_attempts')) {
            await _prefs!.setMaxOtpAttempts(
                int.tryParse(dbSettings['max_otp_attempts'].toString()) ??
                    PreferencesService.defaultMaxOtpAttempts);
          }
        }
      } catch (e) {
        debugPrint('Could not load API settings, falling back to local: $e');
      }

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

      // Update global formatters
      DateFormatter.setFormats(
        dateFormat: _dateFormat,
        timeFormat: _timeFormat,
      );

      _lastLoadedAt = DateTime.now();
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

  // ── Individual setters (persist locally and remotely) ──────────────

  // General
  Future<void> setDateFormat(String value) async {
    _dateFormat = value;
    DateFormatter.setFormats(dateFormat: value);
    await _prefs?.setDateFormat(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setTimeFormat(String value) async {
    _timeFormat = value;
    DateFormatter.setFormats(timeFormat: value);
    await _prefs?.setTimeFormat(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setItemsPerPage(int value) async {
    _itemsPerPage = value;
    await _prefs?.setItemsPerPage(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setSessionTimeout(int value) async {
    _sessionTimeout = value;
    await _prefs?.setSessionTimeout(value);
    await _syncToServer();
    notifyListeners();
  }

  // Anomaly Detection
  Future<void> setAnomalyThreshold(double value) async {
    _anomalyThreshold = value;
    await _prefs?.setAnomalyThreshold(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setCriticalThreshold(double value) async {
    _criticalThreshold = value;
    await _prefs?.setCriticalThreshold(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setAutoRefreshEnabled(bool value) async {
    _autoRefreshEnabled = value;
    await _prefs?.setAutoRefreshEnabled(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setAutoRefreshInterval(int value) async {
    _autoRefreshInterval = value;
    await _prefs?.setAutoRefreshInterval(value);
    await _syncToServer();
    notifyListeners();
  }

  // Security
  Future<void> setMinPasswordLength(int value) async {
    _minPasswordLength = value;
    await _prefs?.setMinPasswordLength(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setOtpValidityMinutes(int value) async {
    _otpValidityMinutes = value;
    await _prefs?.setOtpValidityMinutes(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setMaxOtpAttempts(int value) async {
    _maxOtpAttempts = value;
    await _prefs?.setMaxOtpAttempts(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setEnforce2FA(bool value) async {
    _enforce2FA = value;
    await _prefs?.setEnforce2FA(value);
    await _syncToServer();
    notifyListeners();
  }

  // Notifications
  Future<void> setNotifyCriticalAnomalies(bool value) async {
    _notifyCriticalAnomalies = value;
    await _prefs?.setNotifyCriticalAnomalies(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setNotifyPendingApprovals(bool value) async {
    _notifyPendingApprovals = value;
    await _prefs?.setNotifyPendingApprovals(value);
    await _syncToServer();
    notifyListeners();
  }

  Future<void> setNotifyCustodyChanges(bool value) async {
    _notifyCustodyChanges = value;
    await _prefs?.setNotifyCustodyChanges(value);
    await _syncToServer();
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

  Future<void> trainModel({bool force = false, bool wait = true}) async {
    _isTraining = true;
    _trainingError = null;
    notifyListeners();

    try {
      final result = await _settingsService.trainMLModel(
        force: force,
        wait: wait,
      );
      final payload = (result['data'] is Map<String, dynamic>)
          ? result['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      final status = payload['status']?.toString() ?? '';

      if (wait) {
        // Give the backend a short window to commit model metadata updates.
        await Future.delayed(const Duration(seconds: 2));
      }

      await loadMLStatus();
      _isTraining = false;

      if (status == 'skipped') {
        final reason = payload['reason']?.toString();
        _successMessage = reason == null || reason.isEmpty
            ? 'Model training skipped: retraining not needed yet'
            : 'Model training skipped: $reason';
      } else if (status == 'started' || status == 'running') {
        _successMessage = 'Model training started in background';
      } else {
        _successMessage =
            result['message']?.toString() ?? 'Model training completed';
      }

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
    await loadSettings(force: true);
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
