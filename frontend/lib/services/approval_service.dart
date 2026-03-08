// Approval Service
// API calls for approval workflow management

import '../config/api_config.dart';
import 'api_client.dart';

class ApprovalService {
  // Get pending approvals (HQ Commander only)
  Future<Map<String, dynamic>> getPendingApprovals() async {
    try {
      final data = await ApiClient.get('${ApiConfig.approvalsUrl}/pending');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching pending approvals: $e');
    }
  }

  // Process loss report approval
  Future<Map<String, dynamic>> processLossReport(
    String id,
    String status,
    String reviewNotes,
  ) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.approvalsUrl}/loss-report/$id',
        body: {'status': status, 'review_notes': reviewNotes},
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error processing loss report: $e');
    }
  }

  // Process destruction request approval
  Future<Map<String, dynamic>> processDestructionRequest(
    String id,
    String status,
    String reviewNotes,
  ) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.approvalsUrl}/destruction/$id',
        body: {'status': status, 'review_notes': reviewNotes},
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error processing destruction request: $e');
    }
  }

  // Process procurement request approval
  Future<Map<String, dynamic>> processProcurementRequest(
    String id,
    String status,
    String reviewNotes,
  ) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.approvalsUrl}/procurement/$id',
        body: {'status': status, 'review_notes': reviewNotes},
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error processing procurement request: $e');
    }
  }
}
