import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/approval_request.dart';
import 'api_discovery_service.dart';

class VerificationApiException implements Exception {
  const VerificationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VerificationApiService {
  VerificationApiService({
    http.Client? client,
    ApiDiscoveryService? discoveryService,
  }) : _client = client ?? http.Client(),
       _discoveryService = discoveryService ?? ApiDiscoveryService();

  final http.Client _client;
  final ApiDiscoveryService _discoveryService;

  static const Duration _requestTimeout = Duration(seconds: 12);

  Future<Map<String, dynamic>> exchangePin({
    required String baseUrl,
    required String pin,
    required String deviceFingerprint,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/enrollment/exchange-pin');
      
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pin': pin,
          'device_fingerprint': deviceFingerprint,
          'device_name': deviceName,
          'platform': platform,
          'app_version': appVersion,
        }),
      ).timeout(_requestTimeout);

      if (response.statusCode != 200 && response.statusCode != 201) {
        final Map<String, dynamic> errorBody;
        try {
          errorBody = jsonDecode(response.body);
        } catch (_) {
          throw VerificationApiException('Failed to enroll device (${response.statusCode})');
        }
        throw VerificationApiException(
          errorBody['message'] ?? 'Failed to enroll device',
        );
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw const VerificationApiException('Unexpected server response format');
      }

      return data['data'] as Map<String, dynamic>;
    } on SocketException {
      throw const VerificationApiException(
          'Unable to reach server. Check your network or API Base URL.');
    } on TimeoutException {
      throw const VerificationApiException('Server request timed out.');
    } on FormatException {
      throw const VerificationApiException('Invalid response from server.');
    }
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.normalizedBaseUrl}$path');

  Future<void> testConnection({required String baseUrl}) async {
    final normalized = ApiConfig.normalizeBaseUrlInput(baseUrl);
    if (!ApiConfig.isValidHttpUrl(normalized)) {
      throw const VerificationApiException(
        'Enter a valid API Base URL using http:// or https://.',
      );
    }

    final healthUri = ApiConfig.healthUriForBaseUrl(normalized);
    if (healthUri == null) {
      throw const VerificationApiException('Unable to build health check URL.');
    }

    try {
      final response = await _client.get(healthUri).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw VerificationApiException(
          'Server reached, but health check returned ${response.statusCode}.',
        );
      }
    } on TimeoutException {
      throw const VerificationApiException(
        'Health check timed out. Verify the URL and network access.',
      );
    } on SocketException {
      throw const VerificationApiException(
        'Cannot reach the SafeArms server from this device.',
      );
    } on http.ClientException {
      throw const VerificationApiException(
        'Connection failed. Verify the server URL and network access.',
      );
    }
  }

  Future<List<ApprovalRequest>> fetchPendingRequests({
    required String officerId,
    required String deviceKey,
    required String deviceToken,
  }) async {
    final payload = {
      'officer_id': officerId,
      'device_key': deviceKey,
      'device_token': deviceToken,
    };

    final response = await _postJsonWithRecovery(
      path: '/officer-verification/mobile/pending',
      payload: payload,
    );

    final decoded = _decodeResponse(response);
    await ApiConfig.markCurrentBaseUrlHealthy();
    final data = decoded['data'];

    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map>()
        .map((item) => ApprovalRequest.fromApi(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> submitDecision({
    required String verificationId,
    required String officerId,
    required String deviceKey,
    required String deviceToken,
    required String challengeCode,
    required String decision,
    String? reason,
  }) async {
    final payload = {
      'verification_id': verificationId,
      'officer_id': officerId,
      'device_key': deviceKey,
      'device_token': deviceToken,
      'challenge_code': challengeCode,
      'decision': decision,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      'metadata': {'client': 'officer_verification_mobile'},
    };

    final response = await _postJsonWithRecovery(
      path: '/officer-verification/mobile/decision',
      payload: payload,
    );

    _decodeResponse(response);
    await ApiConfig.markCurrentBaseUrlHealthy();
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic parsed;
    try {
      parsed = jsonDecode(response.body);
    } catch (_) {
      throw const VerificationApiException(
        'Invalid API response from verification server.',
      );
    }

    if (parsed is! Map<String, dynamic>) {
      throw const VerificationApiException('Unexpected API response format.');
    }

    final success = parsed['success'] == true;
    final message = parsed['message']?.toString();

    if (!success || response.statusCode >= 400) {
      throw VerificationApiException(
        _buildApiFailureMessage(
          statusCode: response.statusCode,
          apiMessage: message,
        ),
      );
    }

    return parsed;
  }

  Future<http.Response> _postJsonWithRecovery({
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _executePost(path: path, payload: payload);
    } on Object catch (error) {
      if (!_isConnectivityError(error)) {
        throw _mapTransportError(error);
      }

      final refreshResult = await _discoveryService.refresh(
        trigger: DiscoveryRefreshTrigger.apiFailure,
      );

      if (!refreshResult.success) {
        throw const VerificationApiException(
          'Cannot reach SafeArms server. Check connectivity and retry, or open Connection Setup.',
        );
      }

      try {
        return await _executePost(path: path, payload: payload);
      } on Object catch (retryError) {
        if (_isConnectivityError(retryError)) {
          throw const VerificationApiException(
            'Connection is still unavailable after automatic server refresh. Tap Retry or open Connection Setup.',
          );
        }

        throw _mapTransportError(retryError);
      }
    }
  }

  Future<http.Response> _executePost({
    required String path,
    required Map<String, dynamic> payload,
  }) {
    return _client
        .post(
          _uri(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_requestTimeout);
  }

  bool _isConnectivityError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException;
  }

  VerificationApiException _mapTransportError(Object error) {
    if (error is VerificationApiException) {
      return error;
    }

    if (error is TimeoutException) {
      return const VerificationApiException(
        'SafeArms server timed out. Please retry.',
      );
    }

    if (error is SocketException || error is http.ClientException) {
      return const VerificationApiException(
        'Cannot reach SafeArms server. Verify your connection settings.',
      );
    }

    if (error is FormatException) {
      return const VerificationApiException(
        'Received unexpected data from SafeArms server.',
      );
    }

    return const VerificationApiException(
      'Verification request failed. Please retry.',
    );
  }

  String _buildApiFailureMessage({
    required int statusCode,
    String? apiMessage,
  }) {
    final trimmedMessage = apiMessage?.trim() ?? '';
    if (trimmedMessage.isNotEmpty) {
      return trimmedMessage;
    }

    switch (statusCode) {
      case 401:
      case 403:
        return 'Device is not authorized. Verify Officer ID, Device Key, and Device Token.';
      case 404:
        return 'No active verification request was found for this device.';
      case 408:
      case 504:
        return 'SafeArms server did not respond in time. Please retry.';
      default:
        return 'Verification request failed (${statusCode.toString()}).';
    }
  }

  void dispose() {
    _client.close();
    _discoveryService.dispose();
  }
}
