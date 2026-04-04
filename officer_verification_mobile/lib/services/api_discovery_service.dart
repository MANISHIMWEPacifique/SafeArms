import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

enum DiscoveryRefreshTrigger { startup, apiFailure, manualTest }

class DiscoveryRefreshResult {
  const DiscoveryRefreshResult({
    required this.attempted,
    required this.success,
    required this.appliedConfig,
    required this.activeUrlChanged,
    required this.message,
  });

  final bool attempted;
  final bool success;
  final bool appliedConfig;
  final bool activeUrlChanged;
  final String message;
}

class ApiDiscoveryService {
  ApiDiscoveryService({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 3);

  final http.Client _client;
  final Duration _timeout;

  Future<DiscoveryRefreshResult> refresh({
    required DiscoveryRefreshTrigger trigger,
  }) async {
    final discoveryEndpoint = ApiConfig.discoveryUrl.trim();
    if (discoveryEndpoint.isEmpty) {
      return const DiscoveryRefreshResult(
        attempted: false,
        success: false,
        appliedConfig: false,
        activeUrlChanged: false,
        message: 'Discovery URL is not configured.',
      );
    }

    final discoveryUri = Uri.tryParse(discoveryEndpoint);
    if (discoveryUri == null || !discoveryUri.isAbsolute) {
      const message = 'Discovery URL is invalid.';
      await ApiConfig.recordDiscoveryFailure(message);
      return const DiscoveryRefreshResult(
        attempted: true,
        success: false,
        appliedConfig: false,
        activeUrlChanged: false,
        message: message,
      );
    }

    try {
      final response = await _client
          .get(discoveryUri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message =
            'Discovery request failed with status ${response.statusCode}.';
        await ApiConfig.recordDiscoveryFailure(message);
        return DiscoveryRefreshResult(
          attempted: true,
          success: false,
          appliedConfig: false,
          activeUrlChanged: false,
          message: message,
        );
      }

      final payload = _parsePayload(response.body);
      final activeChanged = await ApiConfig.saveDiscoveredConfig(
        baseUrl: payload.apiBaseUrl,
        version: payload.version,
        updatedAt: payload.updatedAt,
        backupBaseUrl: payload.backupApiBaseUrl,
        notes: payload.notes,
      );

      final message = activeChanged
          ? 'Server address updated automatically from discovery.'
          : 'Discovery checked successfully.';

      return DiscoveryRefreshResult(
        attempted: true,
        success: true,
        appliedConfig: true,
        activeUrlChanged: activeChanged,
        message: message,
      );
    } on TimeoutException {
      const message = 'Discovery request timed out.';
      await ApiConfig.recordDiscoveryFailure(message);
      return const DiscoveryRefreshResult(
        attempted: true,
        success: false,
        appliedConfig: false,
        activeUrlChanged: false,
        message: message,
      );
    } on FormatException catch (error) {
      await ApiConfig.recordDiscoveryFailure(error.message);
      return DiscoveryRefreshResult(
        attempted: true,
        success: false,
        appliedConfig: false,
        activeUrlChanged: false,
        message: error.message,
      );
    } catch (_) {
      const message = 'Unable to fetch discovery configuration.';
      await ApiConfig.recordDiscoveryFailure(message);
      return const DiscoveryRefreshResult(
        attempted: true,
        success: false,
        appliedConfig: false,
        activeUrlChanged: false,
        message: message,
      );
    }
  }

  void dispose() {
    _client.close();
  }

  _DiscoveryPayload _parsePayload(String responseBody) {
    dynamic decoded;
    try {
      decoded = jsonDecode(responseBody);
    } catch (_) {
      throw const FormatException('Discovery response is not valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Discovery response must be a JSON object.');
    }

    var payload = decoded;
    final nestedData = decoded['data'];
    if (nestedData is Map<String, dynamic>) {
      payload = nestedData;
    }

    final apiBaseUrl = _readString(payload['api_base_url']);
    final version = _readString(payload['version']);
    final updatedAt = _readString(payload['updated_at']);
    final backupApiBaseUrl = _readString(payload['backup_api_base_url']);
    final notes = _readString(payload['notes']);

    if (apiBaseUrl.isEmpty) {
      throw const FormatException('Discovery api_base_url is required.');
    }

    if (updatedAt.isEmpty) {
      throw const FormatException('Discovery updated_at is required.');
    }

    if (!ApiConfig.isValidHttpUrl(apiBaseUrl)) {
      throw const FormatException(
        'Discovery api_base_url must be a valid URL.',
      );
    }

    if (backupApiBaseUrl.isNotEmpty &&
        !ApiConfig.isValidHttpUrl(backupApiBaseUrl)) {
      throw const FormatException(
        'Discovery backup_api_base_url must be a valid URL.',
      );
    }

    return _DiscoveryPayload(
      apiBaseUrl: apiBaseUrl,
      version: version,
      updatedAt: updatedAt,
      backupApiBaseUrl: backupApiBaseUrl,
      notes: notes,
    );
  }

  String _readString(dynamic value) => value?.toString().trim() ?? '';
}

class _DiscoveryPayload {
  const _DiscoveryPayload({
    required this.apiBaseUrl,
    required this.version,
    required this.updatedAt,
    required this.backupApiBaseUrl,
    required this.notes,
  });

  final String apiBaseUrl;
  final String version;
  final String updatedAt;
  final String backupApiBaseUrl;
  final String notes;
}
