// API Client
// Centralized HTTP client helpers

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class _HttpRequestResult {
  const _HttpRequestResult({
    required this.response,
    required this.effectiveUrl,
  });

  final http.Response response;
  final String effectiveUrl;
}

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
    Duration? timeout,
  }) async {
    final headers = await authHeaders(requireAuth: requireAuth);
    final request = await _sendWithLocalFallback(
      url: url,
      timeout: timeout ?? ApiConfig.timeout,
      sender: (uri) => http.get(uri, headers: headers),
    );
    return _handleResponse(request.response, requestUrl: request.effectiveUrl);
  }

  /// Generic POST request.
  static Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    Duration? timeout,
  }) async {
    final headers = await authHeaders(requireAuth: requireAuth);
    final encodedBody = body == null ? null : jsonEncode(body);
    final request = await _sendWithLocalFallback(
      url: url,
      timeout: timeout ?? ApiConfig.timeout,
      sender: (uri) => http.post(uri, headers: headers, body: encodedBody),
    );
    return _handleResponse(request.response, requestUrl: request.effectiveUrl);
  }

  /// Generic PUT request.
  static Future<Map<String, dynamic>> put(
    String url, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    Duration? timeout,
  }) async {
    final headers = await authHeaders(requireAuth: requireAuth);
    final encodedBody = body == null ? null : jsonEncode(body);
    final request = await _sendWithLocalFallback(
      url: url,
      timeout: timeout ?? ApiConfig.timeout,
      sender: (uri) => http.put(uri, headers: headers, body: encodedBody),
    );
    return _handleResponse(request.response, requestUrl: request.effectiveUrl);
  }

  /// Generic DELETE request.
  static Future<Map<String, dynamic>> delete(
    String url, {
    bool requireAuth = true,
    Duration? timeout,
  }) async {
    final headers = await authHeaders(requireAuth: requireAuth);
    final request = await _sendWithLocalFallback(
      url: url,
      timeout: timeout ?? ApiConfig.timeout,
      sender: (uri) => http.delete(uri, headers: headers),
    );
    return _handleResponse(request.response, requestUrl: request.effectiveUrl);
  }

  /// Generic PATCH request.
  static Future<Map<String, dynamic>> patch(
    String url, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    Duration? timeout,
  }) async {
    final headers = await authHeaders(requireAuth: requireAuth);
    final encodedBody = body == null ? null : jsonEncode(body);
    final request = await _sendWithLocalFallback(
      url: url,
      timeout: timeout ?? ApiConfig.timeout,
      sender: (uri) => http.patch(uri, headers: headers, body: encodedBody),
    );
    return _handleResponse(request.response, requestUrl: request.effectiveUrl);
  }

  static Future<_HttpRequestResult> _sendWithLocalFallback({
    required String url,
    required Duration timeout,
    required Future<http.Response> Function(Uri uri) sender,
  }) async {
    final primaryUri = Uri.parse(url);
    final fallbackUri = _buildLocalApiFallbackUri(primaryUri);

    try {
      final primaryResponse = await sender(primaryUri).timeout(timeout);

      if (fallbackUri == null || primaryResponse.statusCode != 404) {
        return _HttpRequestResult(
          response: primaryResponse,
          effectiveUrl: primaryUri.toString(),
        );
      }

      final fallbackResponse = await sender(fallbackUri).timeout(timeout);
      if (fallbackResponse.statusCode != 404) {
        debugPrint(
          'ApiClient fallback applied: ${primaryUri.toString()} -> ${fallbackUri.toString()}',
        );
        return _HttpRequestResult(
          response: fallbackResponse,
          effectiveUrl: fallbackUri.toString(),
        );
      }

      return _HttpRequestResult(
        response: primaryResponse,
        effectiveUrl: primaryUri.toString(),
      );
    } catch (error) {
      if (fallbackUri != null) {
        try {
          final fallbackResponse = await sender(fallbackUri).timeout(timeout);
          debugPrint(
            'ApiClient fallback after network error: ${primaryUri.toString()} -> ${fallbackUri.toString()}',
          );
          return _HttpRequestResult(
            response: fallbackResponse,
            effectiveUrl: fallbackUri.toString(),
          );
        } catch (_) {
          // Rethrow the original network error below.
        }
      }

      rethrow;
    }
  }

  static Uri? _buildLocalApiFallbackUri(Uri requestUri) {
    if (!kIsWeb) return null;
    if (!requestUri.path.startsWith('/api/')) return null;

    final isLocalHost =
        requestUri.host == 'localhost' || requestUri.host == '127.0.0.1';
    if (!isLocalHost) return null;

    final frontendUri = Uri.base;
    final sameHost = requestUri.host == frontendUri.host;
    final samePort = requestUri.port == frontendUri.port;

    // Retry only when API is mistakenly targeting the Flutter web host port.
    if (!sameHost || !samePort || requestUri.port == 3000) {
      return null;
    }

    return requestUri.replace(scheme: 'http', port: 3000);
  }

  static String? _build404Hint(String requestUrl) {
    if (!kIsWeb) return null;

    final uri = Uri.tryParse(requestUrl);
    if (uri == null || !uri.path.startsWith('/api/')) return null;

    final isLocalHost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (!isLocalHost) return null;

    final frontendUri = Uri.base;
    final sameFrontendHostPort =
        uri.host == frontendUri.host && uri.port == frontendUri.port;

    if (sameFrontendHostPort && uri.port != 3000) {
      return 'API route was requested from the Flutter web host port. '
          'Use API_BASE_URL=http://${uri.host}:3000 or remove the override.';
    }

    return null;
  }

  static Map<String, dynamic> _handleResponse(
    http.Response response, {
    required String requestUrl,
  }) {
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
    final hint = response.statusCode == 404 ? _build404Hint(requestUrl) : null;

    throw ApiException(
      statusCode: response.statusCode,
      message: hint == null
          ? (message ?? 'Request failed')
          : '${message ?? 'Request failed'} $hint',
      url: requestUrl,
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? url;

  ApiException({required this.statusCode, required this.message, this.url});

  @override
  String toString() =>
      'ApiException($statusCode): $message${url == null ? '' : ' [url: $url]'}';
}
