// Anomaly Service
// API calls for anomaly management

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class AnomalyService {
  final AuthService _authService = AuthService();

  // Get all anomalies with optional filters
  Future<List<Map<String, dynamic>>> getAnomalies({
    int? limit,
    int? offset,
    String? severity,
    String? status,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    // Build query parameters
    Map<String, String> queryParams = {};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();
    if (severity != null) queryParams['severity'] = severity;
    if (status != null) queryParams['status'] = status;

    final uri = Uri.parse(
      ApiConfig.anomaliesUrl,
    ).replace(queryParameters: queryParams);

    try {
      final response = await http
          .get(uri, headers: ApiConfig.authHeaders(token))
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch anomalies');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to fetch anomalies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Get anomalies for a specific unit
  Future<List<Map<String, dynamic>>> getUnitAnomalies(
    String unitId, {
    int? limit,
    int? offset,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    Map<String, String> queryParams = {};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    final uri = Uri.parse(
      '${ApiConfig.anomaliesUrl}/unit/$unitId',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http
          .get(uri, headers: ApiConfig.authHeaders(token))
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch unit anomalies');
        }
      } else {
        throw Exception(
          'Failed to fetch unit anomalies: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Update anomaly status
  Future<Map<String, dynamic>> updateAnomaly(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http
          .put(
            Uri.parse('${ApiConfig.anomaliesUrl}/$id'),
            headers: ApiConfig.authHeaders(token),
            body: json.encode(updates),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to update anomaly');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Anomaly not found');
      } else {
        throw Exception('Failed to update anomaly: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }
}
