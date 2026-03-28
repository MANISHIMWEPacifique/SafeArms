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
  static Future<Map<String, String>> authHeaders({
    bool requireAuth = true,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      if (requireAuth) {
        throw ApiException(
          statusCode: 401,
          message: 'Authentication required. Please login again.',
        );
      }

      return ApiConfig.defaultHeaders;
    }

    return ApiConfig.authHeaders(token);
  }

  /// Generic GET request.
  static Future<Map<String, dynamic>> get(
    String url, {
    bool requireAuth = true,
  }) async {
    final headers = await authHeaders(requireAuth: requireAuth);
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  /// Generic POST request.
  static Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final headers = await authHeaders(requireAuth: requireAuth);
    final response = await http
        .post(
          Uri.parse(url),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  /// Generic PUT request.
  static Future<Map<String, dynamic>> put(
    String url, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final headers = await authHeaders(requireAuth: requireAuth);
    final response = await http
        .put(
          Uri.parse(url),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  /// Generic DELETE request.
  static Future<Map<String, dynamic>> delete(
    String url, {
    bool requireAuth = true,
  }) async {
    final headers = await authHeaders(requireAuth: requireAuth);
    final response = await http
        .delete(Uri.parse(url), headers: headers)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  /// Generic PATCH request.
  static Future<Map<String, dynamic>> patch(
    String url, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final headers = await authHeaders(requireAuth: requireAuth);
    final response = await http
        .patch(
          Uri.parse(url),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    dynamic body;

    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    }

    final message = body is Map<String, dynamic>
        ? body['message']?.toString()
        : null;

    throw ApiException(
      statusCode: response.statusCode,
      message: message ?? 'Request failed',
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
