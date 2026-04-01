import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _defaultBaseUrl = 'http://10.0.2.2:5000/api';
  static const String _prefBaseUrl = 'safearms_api_base_url';
  static const String _prefOfficerId = 'safearms_officer_id';
  static const String _prefDeviceKey = 'safearms_device_key';
  static const String _prefDeviceToken = 'safearms_device_token';

  static const String baseUrl = String.fromEnvironment(
    'SAFEARMS_API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const bool useMockFlow = bool.fromEnvironment(
    'SAFEARMS_USE_MOCK_FLOW',
    defaultValue: false,
  );

  static const String officerId = String.fromEnvironment(
    'SAFEARMS_OFFICER_ID',
    defaultValue: '',
  );

  static const String deviceKey = String.fromEnvironment(
    'SAFEARMS_DEVICE_KEY',
    defaultValue: '',
  );

  static const String deviceToken = String.fromEnvironment(
    'SAFEARMS_DEVICE_TOKEN',
    defaultValue: '',
  );

  static String _runtimeBaseUrl = '';
  static String _runtimeOfficerId = '';
  static String _runtimeDeviceKey = '';
  static String _runtimeDeviceToken = '';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _runtimeBaseUrl = (prefs.getString(_prefBaseUrl) ?? '').trim();
    _runtimeOfficerId = (prefs.getString(_prefOfficerId) ?? '').trim();
    _runtimeDeviceKey = (prefs.getString(_prefDeviceKey) ?? '').trim();
    _runtimeDeviceToken = (prefs.getString(_prefDeviceToken) ?? '').trim();
  }

  static Future<void> saveRuntimeConfig({
    required String baseUrl,
    required String officerId,
    required String deviceKey,
    required String deviceToken,
  }) async {
    final normalizedBase = baseUrl.trim();
    final normalizedOfficerId = officerId.trim();
    final normalizedDeviceKey = deviceKey.trim();
    final normalizedDeviceToken = deviceToken.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBaseUrl, normalizedBase);
    await prefs.setString(_prefOfficerId, normalizedOfficerId);
    await prefs.setString(_prefDeviceKey, normalizedDeviceKey);
    await prefs.setString(_prefDeviceToken, normalizedDeviceToken);

    _runtimeBaseUrl = normalizedBase;
    _runtimeOfficerId = normalizedOfficerId;
    _runtimeDeviceKey = normalizedDeviceKey;
    _runtimeDeviceToken = normalizedDeviceToken;
  }

  static Future<void> clearRuntimeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefBaseUrl);
    await prefs.remove(_prefOfficerId);
    await prefs.remove(_prefDeviceKey);
    await prefs.remove(_prefDeviceToken);

    _runtimeBaseUrl = '';
    _runtimeOfficerId = '';
    _runtimeDeviceKey = '';
    _runtimeDeviceToken = '';
  }

  static String get effectiveBaseUrl {
    if (_runtimeBaseUrl.isNotEmpty) {
      return _runtimeBaseUrl;
    }
    return baseUrl;
  }

  static String get effectiveOfficerId {
    if (_runtimeOfficerId.isNotEmpty) {
      return _runtimeOfficerId;
    }
    return officerId;
  }

  static String get effectiveDeviceKey {
    if (_runtimeDeviceKey.isNotEmpty) {
      return _runtimeDeviceKey;
    }
    return deviceKey;
  }

  static String get effectiveDeviceToken {
    if (_runtimeDeviceToken.isNotEmpty) {
      return _runtimeDeviceToken;
    }
    return deviceToken;
  }

  static String get normalizedBaseUrl {
    final selectedBase = effectiveBaseUrl;
    if (selectedBase.endsWith('/')) {
      return selectedBase.substring(0, selectedBase.length - 1);
    }
    return selectedBase;
  }

  static bool get hasDeviceCredentials {
    return effectiveOfficerId.trim().isNotEmpty &&
        effectiveDeviceKey.trim().isNotEmpty &&
        effectiveDeviceToken.trim().isNotEmpty;
  }
}
