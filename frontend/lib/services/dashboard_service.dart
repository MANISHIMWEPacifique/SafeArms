// Dashboard Service
// API calls for dashboard statistics and data

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class DashboardService {
  final AuthService _authService = AuthService();

  // Get all dashboard statistics based on user role
  // This single endpoint returns all needed data:
  // - firearms stats (total, available, in_custody, maintenance)
  // - active_custody count
  // - anomalies (grouped by severity)
  // - pending_approvals (for admin/hq_commander)
  // - total_users (for admin)
  // - active_units (for admin)
  Future<Map<String, dynamic>> getDashboardStats() async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.dashboardUrl),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch dashboard data');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Failed to fetch dashboard data: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }
}
