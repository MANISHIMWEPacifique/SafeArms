// Anomaly Service
// API calls for anomaly management

import '../config/api_config.dart';
import 'api_client.dart';

class AnomalyService {
  // Get all anomalies with optional filters
  Future<List<Map<String, dynamic>>> getAnomalies({
    int? limit,
    int? offset,
    String? severity,
    String? status,
  }) async {
    try {
      Map<String, String> queryParams = {};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      if (severity != null) queryParams['severity'] = severity;
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse(ApiConfig.anomaliesUrl).replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final data = await ApiClient.get(uri.toString());
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching anomalies: $e');
    }
  }

  // Get anomalies for a specific unit
  Future<List<Map<String, dynamic>>> getUnitAnomalies(
    String unitId, {
    int? limit,
    int? offset,
  }) async {
    try {
      Map<String, String> queryParams = {};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      final uri = Uri.parse('${ApiConfig.anomaliesUrl}/unit/$unitId').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final data = await ApiClient.get(uri.toString());
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching unit anomalies: $e');
    }
  }

  // Update anomaly status
  Future<Map<String, dynamic>> updateAnomaly(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final data = await ApiClient.put(
        '${ApiConfig.anomaliesUrl}/$id',
        body: updates,
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error updating anomaly: $e');
    }
  }

  // Start investigation on an anomaly
  Future<Map<String, dynamic>> investigateAnomaly(
    String id, {
    String? notes,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.anomaliesUrl}/$id/investigate',
        body: {'notes': notes ?? ''},
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error starting investigation: $e');
    }
  }

  // Resolve an anomaly
  Future<Map<String, dynamic>> resolveAnomaly(
    String id, {
    String? notes,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.anomaliesUrl}/$id/resolve',
        body: {'notes': notes ?? ''},
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error resolving anomaly: $e');
    }
  }

  // Mark anomaly as false positive (data feeds ML model training)
  Future<Map<String, dynamic>> markFalsePositive(
    String id, {
    String? notes,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.anomaliesUrl}/$id/false-positive',
        body: {'notes': notes ?? ''},
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error marking false positive: $e');
    }
  }

  // Submit explanation for critical anomaly
  Future<Map<String, dynamic>> submitExplanation(
    String id, {
    required String message,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.anomaliesUrl}/$id/explanation',
        body: {'message': message},
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error submitting explanation: $e');
    }
  }

  // Search anomalies for investigation (by unit and time interval)
  Future<List<Map<String, dynamic>>> searchForInvestigation({
    String? unitId,
    String? startDate,
    String? endDate,
    String? severity,
    String? status,
    int? limit,
    int? offset,
  }) async {
    try {
      Map<String, String> queryParams = {};
      if (unitId != null) queryParams['unit_id'] = unitId;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (severity != null) queryParams['severity'] = severity;
      if (status != null) queryParams['status'] = status;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      final uri = Uri.parse('${ApiConfig.anomaliesUrl}/investigation/search')
          .replace(
              queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final data = await ApiClient.get(uri.toString());
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error searching anomalies: $e');
    }
  }
}
