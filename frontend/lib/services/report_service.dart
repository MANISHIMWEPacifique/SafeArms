// Report Service
// API calls for report generation

import '../config/api_config.dart';
import 'api_client.dart';

class ReportService {
  /// Build query string from optional filters
  String _buildQuery(Map<String, String?> params) {
    final filtered = params.entries
        .where(
            (e) => e.value != null && e.value!.isNotEmpty && e.value != 'all')
        .map((e) => '${e.key}=${e.value}')
        .toList();
    return filtered.isEmpty ? '' : '?${filtered.join('&')}';
  }

  // ============================================
  // LOSS REPORTS
  // ============================================

  Future<List<Map<String, dynamic>>> getLossReports({
    String? status,
    String? unitId,
  }) async {
    try {
      final query = _buildQuery({'status': status, 'unit_id': unitId});
      final data = await ApiClient.get('${ApiConfig.reportsUrl}/loss$query');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching loss reports: $e');
    }
  }

  Future<Map<String, dynamic>> createLossReport({
    required String firearmId,
    required String lossType,
    required String circumstances,
    DateTime? lossDate,
    String? lossLocation,
    String? policeCaseNumber,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.reportsUrl}/loss',
        body: {
          'firearm_id': firearmId,
          'loss_type': lossType,
          'circumstances': circumstances,
          'loss_date': (lossDate ?? DateTime.now()).toIso8601String(),
          'loss_location': lossLocation,
          'police_case_number': policeCaseNumber,
        },
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error creating loss report: $e');
    }
  }

  Future<void> deleteLossReport(String reportId) async {
    try {
      await ApiClient.delete('${ApiConfig.reportsUrl}/loss/$reportId');
    } catch (e) {
      throw Exception('Error deleting loss report: $e');
    }
  }

  // ============================================
  // DESTRUCTION REQUESTS
  // ============================================

  Future<List<Map<String, dynamic>>> getDestructionRequests({
    String? status,
  }) async {
    try {
      var url = '${ApiConfig.reportsUrl}/destruction';
      if (status != null && status.isNotEmpty && status != 'all') {
        url += '?status=$status';
      }
      final data = await ApiClient.get(url);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching destruction requests: $e');
    }
  }

  Future<Map<String, dynamic>> createDestructionRequest({
    required String firearmId,
    required String reason,
    String? notes,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.reportsUrl}/destruction',
        body: {
          'firearm_id': firearmId,
          'destruction_reason': reason,
          'condition_description': notes,
        },
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error creating destruction request: $e');
    }
  }

  Future<void> deleteDestructionRequest(String requestId) async {
    try {
      await ApiClient.delete('${ApiConfig.reportsUrl}/destruction/$requestId');
    } catch (e) {
      throw Exception('Error deleting destruction request: $e');
    }
  }

  // ============================================
  // PROCUREMENT REQUESTS
  // ============================================

  Future<List<Map<String, dynamic>>> getProcurementRequests({
    String? status,
  }) async {
    try {
      var url = '${ApiConfig.reportsUrl}/procurement';
      if (status != null && status.isNotEmpty && status != 'all') {
        url += '?status=$status';
      }
      final data = await ApiClient.get(url);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching procurement requests: $e');
    }
  }

  Future<Map<String, dynamic>> createProcurementRequest({
    required String firearmType,
    required int quantity,
    required String justification,
    String? notes,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.reportsUrl}/procurement',
        body: {
          'firearm_type': firearmType,
          'quantity': quantity,
          'justification': justification,
          'notes': notes,
        },
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error creating procurement request: $e');
    }
  }

  Future<void> deleteProcurementRequest(String requestId) async {
    try {
      await ApiClient.delete('${ApiConfig.reportsUrl}/procurement/$requestId');
    } catch (e) {
      throw Exception('Error deleting procurement request: $e');
    }
  }

  // ============================================
  // CHAIN OF CUSTODY REPORTS
  // ============================================

  Future<Map<String, dynamic>> getChainOfCustodyReport({
    required String firearmId,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
  }) async {
    try {
      List<String> queryParams = [];
      if (startDate != null) {
        queryParams.add('start_date=${startDate.toIso8601String()}');
      }
      if (endDate != null) {
        queryParams.add('end_date=${endDate.toIso8601String()}');
      }
      if (reason != null && reason.isNotEmpty) {
        queryParams.add('reason=${Uri.encodeComponent(reason)}');
      }

      var url = '${ApiConfig.reportsUrl}/chain-of-custody/$firearmId';
      if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';

      final data = await ApiClient.get(url);
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching chain of custody report: $e');
    }
  }

  Future<Map<String, dynamic>> verifyChainOfCustody({
    required String firearmId,
  }) async {
    try {
      final data = await ApiClient.get(
          '${ApiConfig.reportsUrl}/chain-of-custody/$firearmId/verify');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error verifying chain of custody: $e');
    }
  }

  // ============================================
  // STATUS UPDATES
  // ============================================

  Future<Map<String, dynamic>> updateLossReportStatus(
      String reportId, String status) async {
    try {
      final data = await ApiClient.patch(
        '${ApiConfig.reportsUrl}/loss/$reportId/status',
        body: {'status': status},
      );
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error updating loss report: $e');
    }
  }

  Future<Map<String, dynamic>> updateDestructionRequestStatus(
      String requestId, String status) async {
    try {
      final data = await ApiClient.patch(
        '${ApiConfig.reportsUrl}/destruction/$requestId/status',
        body: {'status': status},
      );
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error updating destruction request: $e');
    }
  }

  Future<Map<String, dynamic>> updateProcurementRequestStatus(
      String requestId, String status) async {
    try {
      final data = await ApiClient.patch(
        '${ApiConfig.reportsUrl}/procurement/$requestId/status',
        body: {'status': status},
      );
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error updating procurement request: $e');
    }
  }

  // ============================================
  // AUDIT TRAIL REPORTS
  // ============================================

  Future<List<Map<String, dynamic>>> getAuditTrail({
    required String entityType,
    required String entityId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final data = await ApiClient.get(
          '${ApiConfig.reportsUrl}/audit-trail/$entityType/$entityId?limit=$limit&offset=$offset');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching audit trail: $e');
    }
  }

  Future<Map<String, dynamic>> getAuditSummary({int days = 30}) async {
    try {
      final data = await ApiClient.get(
          '${ApiConfig.reportsUrl}/audit-summary?days=$days');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching audit summary: $e');
    }
  }
}
