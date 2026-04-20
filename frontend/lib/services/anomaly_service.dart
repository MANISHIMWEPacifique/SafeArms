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
    bool includeRemoved = false,
  }) async {
    try {
      Map<String, String> queryParams = {};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      if (severity != null) queryParams['severity'] = severity;
      if (status != null) queryParams['status'] = status;
      if (includeRemoved) queryParams['include_removed'] = 'true';

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
    bool includeRemoved = false,
  }) async {
    try {
      Map<String, String> queryParams = {};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      if (includeRemoved) queryParams['include_removed'] = 'true';

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

  // Mark anomaly as acceptable operational change
  Future<Map<String, dynamic>> markAcceptableChange(
    String id, {
    String? notes,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.anomaliesUrl}/$id/acceptable-change',
        body: {'notes': notes ?? ''},
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error marking acceptable change: $e');
    }
  }

  // Delete anomaly from dashboard views (record retained in system).
  Future<Map<String, dynamic>> deleteFromDashboard(
    String id, {
    String? reason,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.anomaliesUrl}/$id/delete-from-dashboard',
        body: {'reason': reason ?? 'Deleted from dashboard'},
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error deleting anomaly from dashboard: $e');
    }
  }

  // Restore anomaly into dashboard views.
  Future<Map<String, dynamic>> restoreToDashboard(String id) async {
    try {
      final data =
          await ApiClient.delete('${ApiConfig.anomaliesUrl}/$id/delete-from-dashboard');
      return data['data'];
    } catch (e) {
      throw Exception('Error restoring anomaly to dashboard: $e');
    }
  }

  // Backward-compatible aliases.
  Future<Map<String, dynamic>> hideFromDashboard(
    String id, {
    String? reason,
  }) => deleteFromDashboard(id, reason: reason);

  Future<Map<String, dynamic>> unhideFromDashboard(String id) =>
      restoreToDashboard(id);

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
    bool includeRemoved = true,
  }) async {
    Map<String, String> queryParams = {};
    if (unitId != null) queryParams['unit_id'] = unitId;
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (severity != null) queryParams['severity'] = severity;
    if (status != null) queryParams['status'] = status;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();
    if (includeRemoved) queryParams['include_removed'] = 'true';

    final uri = Uri.parse('${ApiConfig.anomaliesUrl}/investigation/search')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    try {
      final data = await ApiClient.get(uri.toString());
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } on ApiException catch (endpointError) {
      // Fallback for older backends where the dedicated investigation endpoint
      // may be unavailable; preserve filters and apply date window client-side.
      if (endpointError.statusCode != 404) {
        throw Exception('Error searching anomalies: $endpointError');
      }

      try {
        final allResults = await getAnomalies(
          limit: limit ?? 300,
          offset: offset,
          severity: severity,
          status: status,
          includeRemoved: includeRemoved,
        );

        final parsedStartDate =
            startDate != null ? DateTime.tryParse(startDate) : null;
        final parsedEndDate = endDate != null ? DateTime.tryParse(endDate) : null;

        return allResults.where((anomaly) {
          final anomalyUnitId = anomaly['unit_id']?.toString();
          if (unitId != null && unitId.isNotEmpty && anomalyUnitId != unitId) {
            return false;
          }

          if (parsedStartDate != null || parsedEndDate != null) {
            final detectedAtRaw = anomaly['detected_at']?.toString();
            final detectedAt =
                detectedAtRaw != null ? DateTime.tryParse(detectedAtRaw) : null;

            if (detectedAt == null) {
              return false;
            }

            if (parsedStartDate != null && detectedAt.isBefore(parsedStartDate)) {
              return false;
            }

            if (parsedEndDate != null && detectedAt.isAfter(parsedEndDate)) {
              return false;
            }
          }

          return true;
        }).toList();
      } catch (fallbackError) {
        throw Exception(
          'Error searching anomalies: $endpointError | Fallback failed: $fallbackError',
        );
      }
    } catch (e) {
      throw Exception('Error searching anomalies: $e');
    }
  }
}
