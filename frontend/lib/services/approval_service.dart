// Approval Service
// API calls for approval workflow management

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class ApprovalService {
  final AuthService _authService = AuthService();

  // Get pending approvals (HQ Commander only)
  Future<Map<String, dynamic>> getPendingApprovals() async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.approvalsUrl}/pending'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['data'];
        } else {
          throw Exception(
            data['message'] ?? 'Failed to fetch pending approvals',
          );
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. HQ Commander role required.');
      } else {
        throw Exception(
          'Failed to fetch pending approvals: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Process loss report approval
  Future<Map<String, dynamic>> processLossReport(
    String id,
    String status,
    String reviewNotes,
  ) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.approvalsUrl}/loss-report/$id'),
            headers: ApiConfig.authHeaders(token),
            body: json.encode({'status': status, 'review_notes': reviewNotes}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to process loss report');
        }
      } else {
        throw Exception(
          'Failed to process loss report: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Process destruction request approval
  Future<Map<String, dynamic>> processDestructionRequest(
    String id,
    String status,
    String reviewNotes,
  ) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.approvalsUrl}/destruction/$id'),
            headers: ApiConfig.authHeaders(token),
            body: json.encode({'status': status, 'review_notes': reviewNotes}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['data'];
        } else {
          throw Exception(
            data['message'] ?? 'Failed to process destruction request',
          );
        }
      } else {
        throw Exception(
          'Failed to process destruction request: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Process procurement request approval
  Future<Map<String, dynamic>> processProcurementRequest(
    String id,
    String status,
    String reviewNotes,
  ) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.approvalsUrl}/procurement/$id'),
            headers: ApiConfig.authHeaders(token),
            body: json.encode({'status': status, 'review_notes': reviewNotes}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['data'];
        } else {
          throw Exception(
            data['message'] ?? 'Failed to process procurement request',
          );
        }
      } else {
        throw Exception(
          'Failed to process procurement request: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }
}
