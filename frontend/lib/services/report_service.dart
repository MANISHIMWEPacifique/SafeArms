// Report Service
// API calls for report generation
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import './auth_service.dart';

class ReportService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================
  // LOSS REPORTS
  // ============================================

  /// Get all loss reports
  Future<List<Map<String, dynamic>>> getLossReports({
    String? status,
    String? unitId,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.reportsUrl}/loss';

      List<String> queryParams = [];
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams.add('status=$status');
      }
      if (unitId != null && unitId.isNotEmpty) {
        queryParams.add('unit_id=$unitId');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load loss reports: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching loss reports: $e');
    }
  }

  /// Create a loss report
  Future<Map<String, dynamic>> createLossReport({
    required String firearmId,
    required String lossType,
    required String circumstances,
    DateTime? lossDate,
    String? lossLocation,
    String? policeCaseNumber,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'firearm_id': firearmId,
        'loss_type': lossType,
        'circumstances': circumstances,
        'loss_date': (lossDate ?? DateTime.now()).toIso8601String(),
        'loss_location': lossLocation,
        'police_case_number': policeCaseNumber,
      });

      final response = await http
          .post(
            Uri.parse('${ApiConfig.reportsUrl}/loss'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create loss report');
      }
    } catch (e) {
      throw Exception('Error creating loss report: $e');
    }
  }

  // ============================================
  // DESTRUCTION REQUESTS
  // ============================================

  /// Get all destruction requests
  Future<List<Map<String, dynamic>>> getDestructionRequests({
    String? status,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.reportsUrl}/destruction';

      if (status != null && status.isNotEmpty && status != 'all') {
        url += '?status=$status';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception(
            'Failed to load destruction requests: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching destruction requests: $e');
    }
  }

  /// Create a destruction request
  Future<Map<String, dynamic>> createDestructionRequest({
    required String firearmId,
    required String reason,
    String? notes,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'firearm_id': firearmId,
        'destruction_reason': reason,
        'condition_description': notes,
      });

      final response = await http
          .post(
            Uri.parse('${ApiConfig.reportsUrl}/destruction'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(
            error['message'] ?? 'Failed to create destruction request');
      }
    } catch (e) {
      throw Exception('Error creating destruction request: $e');
    }
  }

  // ============================================
  // PROCUREMENT REQUESTS
  // ============================================

  /// Get all procurement requests
  Future<List<Map<String, dynamic>>> getProcurementRequests({
    String? status,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.reportsUrl}/procurement';

      if (status != null && status.isNotEmpty && status != 'all') {
        url += '?status=$status';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception(
            'Failed to load procurement requests: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching procurement requests: $e');
    }
  }

  /// Create a procurement request
  Future<Map<String, dynamic>> createProcurementRequest({
    required String firearmType,
    required int quantity,
    required String justification,
    String? notes,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'firearm_type': firearmType,
        'quantity': quantity,
        'justification': justification,
        'notes': notes,
      });

      final response = await http
          .post(
            Uri.parse('${ApiConfig.reportsUrl}/procurement'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(
            error['message'] ?? 'Failed to create procurement request');
      }
    } catch (e) {
      throw Exception('Error creating procurement request: $e');
    }
  }

  // ============================================
  // CHAIN OF CUSTODY REPORTS
  // ============================================

  /// Get chain of custody report for a firearm
  Future<Map<String, dynamic>> getChainOfCustodyReport({
    required String firearmId,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.reportsUrl}/chain-of-custody/$firearmId';

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

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        final error = json.decode(response.body);
        throw Exception(
            error['message'] ?? 'Failed to load chain of custody report');
      }
    } catch (e) {
      throw Exception('Error fetching chain of custody report: $e');
    }
  }

  /// Verify chain of custody integrity
  Future<Map<String, dynamic>> verifyChainOfCustody({
    required String firearmId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.reportsUrl}/chain-of-custody/$firearmId/verify'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        final error = json.decode(response.body);
        throw Exception(
            error['message'] ?? 'Failed to verify chain of custody');
      }
    } catch (e) {
      throw Exception('Error verifying chain of custody: $e');
    }
  }

  // ============================================
  // STATUS UPDATES
  // ============================================

  /// Update loss report status
  Future<Map<String, dynamic>> updateLossReportStatus(
      String reportId, String status) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'status': status});

      final response = await http
          .patch(
            Uri.parse('${ApiConfig.reportsUrl}/loss/$reportId/status'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        final error = json.decode(response.body);
        throw Exception(
            error['message'] ?? 'Failed to update loss report status');
      }
    } catch (e) {
      throw Exception('Error updating loss report: $e');
    }
  }

  /// Update destruction request status
  Future<Map<String, dynamic>> updateDestructionRequestStatus(
      String requestId, String status) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'status': status});

      final response = await http
          .patch(
            Uri.parse('${ApiConfig.reportsUrl}/destruction/$requestId/status'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        final error = json.decode(response.body);
        throw Exception(
            error['message'] ?? 'Failed to update destruction request status');
      }
    } catch (e) {
      throw Exception('Error updating destruction request: $e');
    }
  }

  /// Update procurement request status
  Future<Map<String, dynamic>> updateProcurementRequestStatus(
      String requestId, String status) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'status': status});

      final response = await http
          .patch(
            Uri.parse('${ApiConfig.reportsUrl}/procurement/$requestId/status'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        final error = json.decode(response.body);
        throw Exception(
            error['message'] ?? 'Failed to update procurement request status');
      }
    } catch (e) {
      throw Exception('Error updating procurement request: $e');
    }
  }

  // ============================================
  // AUDIT TRAIL REPORTS
  // ============================================

  /// Get audit trail for a specific entity
  Future<List<Map<String, dynamic>>> getAuditTrail({
    required String entityType,
    required String entityId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.reportsUrl}/audit-trail/$entityType/$entityId?limit=$limit&offset=$offset'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load audit trail: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching audit trail: $e');
    }
  }

  /// Get audit summary (admin only)
  Future<Map<String, dynamic>> getAuditSummary({int days = 30}) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.reportsUrl}/audit-summary?days=$days'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load audit summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching audit summary: $e');
    }
  }
}
