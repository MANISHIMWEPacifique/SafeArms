// API Client
// Centralized HTTP client helpers

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();

  /// Retrieve the stored auth token.
  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  /// Build auth headers for an authenticated request.
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    if (token == null) return ApiConfig.defaultHeaders;
    return ApiConfig.authHeaders(token);
  }

  /// Generic GET request.
  static Future<Map<String, dynamic>> get(String url) async {
    final headers = await authHeaders();
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  /// Generic POST request.
  static Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await authHeaders();
    final response = await http
        .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  /// Generic PUT request.
  static Future<Map<String, dynamic>> put(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await authHeaders();
    final response = await http
        .put(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  /// Generic DELETE request.
  static Future<Map<String, dynamic>> delete(String url) async {
    final headers = await authHeaders();
    final response = await http
        .delete(Uri.parse(url), headers: headers)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: body['message']?.toString() ?? 'Request failed',
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
