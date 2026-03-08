// Preferences Service - SharedPreferences wrapper for local settings
// SafeArms Frontend

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static PreferencesService? _instance;
  static SharedPreferences? _prefs;

  PreferencesService._();

  static Future<PreferencesService> getInstance() async {
    if (_instance == null) {
      _instance = PreferencesService._();
      _prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // ── Key constants ──────────────────────────────────────────

  // General
  static const String keyDateFormat = 'setting_date_format';
  static const String keyTimeFormat = 'setting_time_format';
  static const String keyItemsPerPage = 'setting_items_per_page';
  static const String keySessionTimeout = 'setting_session_timeout';

  // Anomaly Detection
  static const String keyAnomalyThreshold = 'setting_anomaly_threshold';
  static const String keyCriticalThreshold = 'setting_critical_threshold';
  static const String keyAutoRefreshEnabled = 'setting_auto_refresh_enabled';
  static const String keyAutoRefreshInterval = 'setting_auto_refresh_interval';

  // Security
  static const String keyMinPasswordLength = 'setting_min_password_length';
  static const String keyOtpValidityMinutes = 'setting_otp_validity';
  static const String keyMaxOtpAttempts = 'setting_max_otp_attempts';
  static const String keyEnforce2FA = 'setting_enforce_2fa';

  // Notifications
  static const String keyNotifyCriticalAnomalies = 'setting_notify_critical';
  static const String keyNotifyPendingApprovals = 'setting_notify_approvals';
  static const String keyNotifyCustodyChanges = 'setting_notify_custody';

  // ── Defaults ───────────────────────────────────────────────

  static const String defaultDateFormat = 'DD/MM/YYYY';
  static const String defaultTimeFormat = '24-hour';
  static const int defaultItemsPerPage = 25;
  static const int defaultSessionTimeout = 30;
  static const double defaultAnomalyThreshold = 0.35;
  static const double defaultCriticalThreshold = 0.85;
  static const bool defaultAutoRefreshEnabled = true;
  static const int defaultAutoRefreshInterval = 5;
  static const int defaultMinPasswordLength = 8;
  static const int defaultOtpValidity = 5;
  static const int defaultMaxOtpAttempts = 3;
  static const bool defaultEnforce2FA = true;
  static const bool defaultNotifyCritical = true;
  static const bool defaultNotifyApprovals = true;
  static const bool defaultNotifyCustody = false;

  // ── Getters ────────────────────────────────────────────────

  // General
  String get dateFormat =>
      _prefs?.getString(keyDateFormat) ?? defaultDateFormat;
  String get timeFormat =>
      _prefs?.getString(keyTimeFormat) ?? defaultTimeFormat;
  int get itemsPerPage =>
      _prefs?.getInt(keyItemsPerPage) ?? defaultItemsPerPage;
  int get sessionTimeout =>
      _prefs?.getInt(keySessionTimeout) ?? defaultSessionTimeout;

  // Anomaly Detection
  double get anomalyThreshold =>
      _prefs?.getDouble(keyAnomalyThreshold) ?? defaultAnomalyThreshold;
  double get criticalThreshold =>
      _prefs?.getDouble(keyCriticalThreshold) ?? defaultCriticalThreshold;
  bool get autoRefreshEnabled =>
      _prefs?.getBool(keyAutoRefreshEnabled) ?? defaultAutoRefreshEnabled;
  int get autoRefreshInterval =>
      _prefs?.getInt(keyAutoRefreshInterval) ?? defaultAutoRefreshInterval;

  // Security
  int get minPasswordLength =>
      _prefs?.getInt(keyMinPasswordLength) ?? defaultMinPasswordLength;
  int get otpValidityMinutes =>
      _prefs?.getInt(keyOtpValidityMinutes) ?? defaultOtpValidity;
  int get maxOtpAttempts =>
      _prefs?.getInt(keyMaxOtpAttempts) ?? defaultMaxOtpAttempts;
  bool get enforce2FA => _prefs?.getBool(keyEnforce2FA) ?? defaultEnforce2FA;

  // Notifications
  bool get notifyCriticalAnomalies =>
      _prefs?.getBool(keyNotifyCriticalAnomalies) ?? defaultNotifyCritical;
  bool get notifyPendingApprovals =>
      _prefs?.getBool(keyNotifyPendingApprovals) ?? defaultNotifyApprovals;
  bool get notifyCustodyChanges =>
      _prefs?.getBool(keyNotifyCustodyChanges) ?? defaultNotifyCustody;

  // ── Setters ────────────────────────────────────────────────

  // General
  Future<void> setDateFormat(String value) =>
      _prefs!.setString(keyDateFormat, value);
  Future<void> setTimeFormat(String value) =>
      _prefs!.setString(keyTimeFormat, value);
  Future<void> setItemsPerPage(int value) =>
      _prefs!.setInt(keyItemsPerPage, value);
  Future<void> setSessionTimeout(int value) =>
      _prefs!.setInt(keySessionTimeout, value);

  // Anomaly Detection
  Future<void> setAnomalyThreshold(double value) =>
      _prefs!.setDouble(keyAnomalyThreshold, value);
  Future<void> setCriticalThreshold(double value) =>
      _prefs!.setDouble(keyCriticalThreshold, value);
  Future<void> setAutoRefreshEnabled(bool value) =>
      _prefs!.setBool(keyAutoRefreshEnabled, value);
  Future<void> setAutoRefreshInterval(int value) =>
      _prefs!.setInt(keyAutoRefreshInterval, value);

  // Security
  Future<void> setMinPasswordLength(int value) =>
      _prefs!.setInt(keyMinPasswordLength, value);
  Future<void> setOtpValidityMinutes(int value) =>
      _prefs!.setInt(keyOtpValidityMinutes, value);
  Future<void> setMaxOtpAttempts(int value) =>
      _prefs!.setInt(keyMaxOtpAttempts, value);
  Future<void> setEnforce2FA(bool value) =>
      _prefs!.setBool(keyEnforce2FA, value);

  // Notifications
  Future<void> setNotifyCriticalAnomalies(bool value) =>
      _prefs!.setBool(keyNotifyCriticalAnomalies, value);
  Future<void> setNotifyPendingApprovals(bool value) =>
      _prefs!.setBool(keyNotifyPendingApprovals, value);
  Future<void> setNotifyCustodyChanges(bool value) =>
      _prefs!.setBool(keyNotifyCustodyChanges, value);

  // ── Bulk operations ────────────────────────────────────────

  /// Returns all settings as a map (for display / debugging)
  Map<String, dynamic> getAllSettings() {
    return {
      'dateFormat': dateFormat,
      'timeFormat': timeFormat,
      'itemsPerPage': itemsPerPage,
      'sessionTimeout': sessionTimeout,
      'anomalyThreshold': anomalyThreshold,
      'criticalThreshold': criticalThreshold,
      'autoRefreshEnabled': autoRefreshEnabled,
      'autoRefreshInterval': autoRefreshInterval,
      'minPasswordLength': minPasswordLength,
      'otpValidityMinutes': otpValidityMinutes,
      'maxOtpAttempts': maxOtpAttempts,
      'enforce2FA': enforce2FA,
      'notifyCriticalAnomalies': notifyCriticalAnomalies,
      'notifyPendingApprovals': notifyPendingApprovals,
      'notifyCustodyChanges': notifyCustodyChanges,
    };
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _prefs!.remove(keyDateFormat);
    await _prefs!.remove(keyTimeFormat);
    await _prefs!.remove(keyItemsPerPage);
    await _prefs!.remove(keySessionTimeout);
    await _prefs!.remove(keyAnomalyThreshold);
    await _prefs!.remove(keyCriticalThreshold);
    await _prefs!.remove(keyAutoRefreshEnabled);
    await _prefs!.remove(keyAutoRefreshInterval);
    await _prefs!.remove(keyMinPasswordLength);
    await _prefs!.remove(keyOtpValidityMinutes);
    await _prefs!.remove(keyMaxOtpAttempts);
    await _prefs!.remove(keyEnforce2FA);
    await _prefs!.remove(keyNotifyCriticalAnomalies);
    await _prefs!.remove(keyNotifyPendingApprovals);
    await _prefs!.remove(keyNotifyCustodyChanges);
  }
}
