class ApiConfig {
  static const String _defaultBaseUrl = 'http://10.0.2.2:5000/api';

  static const String baseUrl = String.fromEnvironment(
    'SAFEARMS_API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const bool useMockFlow = bool.fromEnvironment(
    'SAFEARMS_USE_MOCK_FLOW',
    defaultValue: true,
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

  static String get normalizedBaseUrl {
    if (baseUrl.endsWith('/')) {
      return baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }

  static bool get hasDeviceCredentials {
    return officerId.trim().isNotEmpty &&
        deviceKey.trim().isNotEmpty &&
        deviceToken.trim().isNotEmpty;
  }
}