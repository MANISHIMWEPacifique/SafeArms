// API Configuration
// Contains API base URL and endpoint configurations

class ApiConfig {
  // Base URL for backend API
  static const String baseUrl = 'http://localhost:3000';

  // API Version
  static const String apiVersion = '/api';

  // Full API base path
  static String get apiBase => '$baseUrl$apiVersion';

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
  static String get ballisticUrl => '$apiBase/ballistic';
  static String get custodyUrl => '$apiBase/custody';
  static String get anomaliesUrl => '$apiBase/anomalies';
  static String get approvalsUrl => '$apiBase/approvals';
  static String get reportsUrl => '$apiBase/reports';
  static String get dashboardUrl => '$apiBase/dashboard';

  // Timeout Configuration
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

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
