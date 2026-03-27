// Approvals Service - API calls for HQ Commander review and approval
// SafeArms Frontend

import '../config/api_config.dart';
import 'api_client.dart';

class ApprovalsService {
  /// Build query string from optional filters
  String _buildQuery(Map<String, String?> params) {
    final filtered = params.entries
        .where(
            (e) => e.value != null && e.value!.isNotEmpty && e.value != 'all')
        .map((e) => '${e.key}=${e.value}')
        .toList();
    return filtered.isEmpty ? '' : '?${filtered.join('&')}';
  }

  // ===== LOSS REPORT APPROVALS =====

  Future<List<Map<String, dynamic>>> getPendingLossReports({
    String? priority,
    String? unit,
  }) async {
    try {
      final query = _buildQuery({'priority': priority, 'unit': unit});
      final data =
          await ApiClient.get('${ApiConfig.approvalsUrl}/loss-reports$query');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
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
      await ApiClient.put(
        '${ApiConfig.approvalsUrl}/loss-reports/$reportId/approve',
        body: {
          'approval_notes': approvalNotes,
          'follow_up_actions': followUpActions,
        },
      );
      return true;
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
      await ApiClient.put(
        '${ApiConfig.approvalsUrl}/loss-reports/$reportId/reject',
        body: {
          'rejection_reason': rejectionReason,
          'detailed_feedback': feedback,
          'required_actions': requiredActions,
          'resubmission_priority': resubmissionPriority,
        },
      );
      return true;
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
      final query = _buildQuery({'priority': priority, 'unit': unit});
      final data = await ApiClient.get(
          '${ApiConfig.approvalsUrl}/destruction-requests$query');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
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
      await ApiClient.put(
        '${ApiConfig.approvalsUrl}/destruction-requests/$requestId/approve',
        body: {
          'approval_notes': approvalNotes,
          'scheduled_destruction_date': scheduledDate?.toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      throw Exception('Error approving destruction request: $e');
    }
  }

  Future<bool> rejectDestruction({
    required String requestId,
    required String rejectionReason,
    required String feedback,
  }) async {
    try {
      await ApiClient.put(
        '${ApiConfig.approvalsUrl}/destruction-requests/$requestId/reject',
        body: {
          'rejection_reason': rejectionReason,
          'detailed_feedback': feedback,
        },
      );
      return true;
    } catch (e) {
      throw Exception('Error rejecting destruction request: $e');
    }
  }

  // ===== PROCUREMENT APPROVALS =====

  Future<List<Map<String, dynamic>>> getPendingProcurementRequests({
    String? priority,
    String? unit,
  }) async {
    try {
      final query = _buildQuery({'priority': priority, 'unit': unit});
      final data = await ApiClient.get(
          '${ApiConfig.approvalsUrl}/procurement-requests$query');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
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
      await ApiClient.put(
        '${ApiConfig.approvalsUrl}/procurement-requests/$requestId/approve',
        body: {
          'approval_notes': approvalNotes,
          'approved_amount': approvedAmount,
        },
      );
      return true;
    } catch (e) {
      throw Exception('Error approving procurement request: $e');
    }
  }

  Future<bool> rejectProcurement({
    required String requestId,
    required String rejectionReason,
    required String feedback,
  }) async {
    try {
      await ApiClient.put(
        '${ApiConfig.approvalsUrl}/procurement-requests/$requestId/reject',
        body: {
          'rejection_reason': rejectionReason,
          'detailed_feedback': feedback,
        },
      );
      return true;
    } catch (e) {
      throw Exception('Error rejecting procurement request: $e');
    }
  }

  // ===== STATISTICS =====

  Future<Map<String, dynamic>> getApprovalStats() async {
    try {
      final data = await ApiClient.get('${ApiConfig.approvalsUrl}/stats');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching approval stats: $e');
    }
  }
}
