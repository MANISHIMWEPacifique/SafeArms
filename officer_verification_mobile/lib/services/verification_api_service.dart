import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/approval_request.dart';

class VerificationApiException implements Exception {
  const VerificationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VerificationApiService {
  VerificationApiService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${ApiConfig.normalizedBaseUrl}$path');

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

    final response = await _client.post(
      _uri('/officer-verification/mobile/pending'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final decoded = _decodeResponse(response);
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

    final response = await _client.post(
      _uri('/officer-verification/mobile/decision'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic parsed;
    try {
      parsed = jsonDecode(response.body);
    } catch (_) {
      throw VerificationApiException('Invalid API response from verification server.');
    }

    if (parsed is! Map<String, dynamic>) {
      throw VerificationApiException('Unexpected API response format.');
    }

    final success = parsed['success'] == true;
    final message = parsed['message']?.toString();

    if (!success || response.statusCode >= 400) {
      throw VerificationApiException(
        message ?? 'Verification request failed (${response.statusCode}).',
      );
    }

    return parsed;
  }

  void dispose() {
    _client.close();
  }
}