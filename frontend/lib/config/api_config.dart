// API Configuration
// Contains API base URL and endpoint configurations

import 'package:flutter/foundation.dart';

class ApiConfig {
  // Base URL for backend API — override at build time with:
  //   flutter run --dart-define=API_BASE_URL=https://your-server.com
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  // API Version
  static const String apiVersion = '/api';

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'http://localhost:3000';
    }

    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static bool _isLocalWebHost(Uri uri) {
    return kIsWeb &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1') &&
        uri.hasAuthority;
  }

  static bool _shouldUseLocalBackendFallback(Uri configuredUri) {
    if (!_isLocalWebHost(configuredUri)) return false;

    final frontendUri = Uri.base;
    final sameHost = configuredUri.host == frontendUri.host;
    final samePort = configuredUri.port == frontendUri.port;

    // If API base points to the active Flutter web host/port, it's usually
    // a misconfiguration for local dev. Backend API stays on :3000.
    return sameHost && samePort && configuredUri.port != 3000;
  }

  static String get baseUrl {
    final normalized = _normalizeBaseUrl(_configuredBaseUrl);
    final parsed = Uri.tryParse(normalized);

    if (parsed == null) {
      return normalized;
    }

    if (_shouldUseLocalBackendFallback(parsed)) {
      return 'http://${parsed.host}:3000';
    }

    return normalized;
  }

  // Full API base path
  static String get apiBase {
    final normalizedBase = baseUrl;
    if (normalizedBase.endsWith(apiVersion)) {
      return normalizedBase;
    }
    return '$normalizedBase$apiVersion';
  }

  // Authentication Endpoints
  static String get loginUrl => '$apiBase/auth/login';
  static String get verifyOtpUrl => '$apiBase/auth/verify-otp';
  static String get resendOtpUrl => '$apiBase/auth/resend-otp';
  static String get logoutUrl => '$apiBase/auth/logout';
  static String get changePasswordUrl => '$apiBase/auth/change-password';
  static String get confirmUnitUrl => '$apiBase/auth/confirm-unit';

  // Core Resource Endpoints
  static String get usersUrl => '$apiBase/users';
  static String get unitsUrl => '$apiBase/units';
  static String get officersUrl => '$apiBase/officers';
  static String get firearmsUrl => '$apiBase/firearms';
  static String get ballisticUrl => '$apiBase/ballistic-profiles';
  static String get custodyUrl => '$apiBase/custody';
  static String get anomaliesUrl => '$apiBase/anomalies';
  static String get approvalsUrl => '$apiBase/approvals';
  static String get reportsUrl => '$apiBase/reports';
  static String get dashboardUrl => '$apiBase/dashboard';

  // Timeout Configuration
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration timeout = Duration(seconds: 30);

  // Aliases for compatibility
  static String get firearms => firearmsUrl;
  static String get custody => custodyUrl;
  static String get officers => officersUrl;
  static String get units => unitsUrl;
  static String get users => usersUrl;
  static String get ballistic => ballisticUrl;
  static String get anomalies => anomaliesUrl;
  static String get approvals => approvalsUrl;

  // Headers
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Map<String, String> authHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };
}
