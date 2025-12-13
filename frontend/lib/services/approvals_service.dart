// Approvals Service - API calls for HQ Commander review and approval
// SafeArms Frontend

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import './auth_service.dart';

class ApprovalsService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ===== LOSS REPORT APPROVALS =====

  Future<List<Map<String, dynamic>>> getPendingLossReports({
    String? priority,
    String? unit,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}/api/approvals/loss-reports';

      List<String> queryParams = [];
      if (priority != null && priority != 'all')
        queryParams.add('priority=$priority');
      if (unit != null && unit != 'all') queryParams.add('unit=$unit');

      if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load pending loss reports');
      }
    } catch (e) {
      throw Exception('Error fetching pending loss reports: $e');
    }
  }

  Future<bool> approveLossReport({
    required String reportId,
    String? approvalNotes,
    List<String>? followUpActions,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'approval_notes': approvalNotes,
        'follow_up_actions': followUpActions,
      });

      final response = await http
          .put(
            Uri.parse(
                '${ApiConfig.baseUrl}/api/approvals/loss-reports/$reportId/approve'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error approving loss report: $e');
    }
  }

  Future<bool> rejectLossReport({
    required String reportId,
    required String rejectionReason,
    required String feedback,
    List<String>? requiredActions,
    String? resubmissionPriority,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'rejection_reason': rejectionReason,
        'detailed_feedback': feedback,
        'required_actions': requiredActions,
        'resubmission_priority': resubmissionPriority,
      });

      final response = await http
          .put(
            Uri.parse(
                '${ApiConfig.baseUrl}/api/approvals/loss-reports/$reportId/reject'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error rejecting loss report: $e');
    }
  }

  // ===== DESTRUCTION APPROVALS =====

  Future<List<Map<String, dynamic>>> getPendingDestructionRequests({
    String? priority,
    String? unit,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}/api/approvals/destruction-requests';

      List<String> queryParams = [];
      if (priority != null && priority != 'all')
        queryParams.add('priority=$priority');
      if (unit != null && unit != 'all') queryParams.add('unit=$unit');

      if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load pending destruction requests');
      }
    } catch (e) {
      throw Exception('Error fetching pending destruction requests: $e');
    }
  }

  Future<bool> approveDestruction({
    required String requestId,
    String? approvalNotes,
    DateTime? scheduledDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'approval_notes': approvalNotes,
        'scheduled_destruction_date': scheduledDate?.toIso8601String(),
      });

      final response = await http
          .put(
            Uri.parse(
                '${ApiConfig.baseUrl}/api/approvals/destruction-requests/$requestId/approve'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error approving destruction request: $e');
    }
  }

  // ===== PROCUREMENT APPROVALS =====

  Future<List<Map<String, dynamic>>> getPendingProcurementRequests({
    String? priority,
    String? unit,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}/api/approvals/procurement-requests';

      List<String> queryParams = [];
      if (priority != null && priority != 'all')
        queryParams.add('priority=$priority');
      if (unit != null && unit != 'all') queryParams.add('unit=$unit');

      if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load pending procurement requests');
      }
    } catch (e) {
      throw Exception('Error fetching pending procurement requests: $e');
    }
  }

  Future<bool> approveProcurement({
    required String requestId,
    String? approvalNotes,
    double? approvedAmount,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'approval_notes': approvalNotes,
        'approved_amount': approvedAmount,
      });

      final response = await http
          .put(
            Uri.parse(
                '${ApiConfig.baseUrl}/api/approvals/procurement-requests/$requestId/approve'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error approving procurement request: $e');
    }
  }

  // ===== STATISTICS =====

  Future<Map<String, dynamic>> getApprovalStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/approvals/stats'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load approval stats');
      }
    } catch (e) {
      throw Exception('Error fetching approval stats: $e');
    }
  }
}
