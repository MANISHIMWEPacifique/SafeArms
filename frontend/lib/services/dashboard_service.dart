// Dashboard Service
// API calls for dashboard statistics and data

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class DashboardService {
  final AuthService _authService = AuthService();

  // Get dashboard statistics based on user role
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

  // Get recent custody activity for station commanders
  Future<List<Map<String, dynamic>>> getRecentCustodyActivity() async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.custodyUrl}/recent?limit=5'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(
            data['message'] ?? 'Failed to fetch custody activity',
          );
        }
      } else {
        throw Exception(
          'Failed to fetch custody activity: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Get active units count
  Future<int> getActiveUnitsCount() async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.unitsUrl}/stats'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['data']['active_count'] ?? 0;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch units data');
        }
      } else {
        throw Exception('Failed to fetch units data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Get total users count (admin only)
  Future<int> getTotalUsersCount() async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.usersUrl}/count'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['data']['count'] ?? 0;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch users count');
        }
      } else {
        throw Exception('Failed to fetch users count: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Get officers count for station commanders
  Future<int> getOfficersCount() async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.officersUrl}/count'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['data']['count'] ?? 0;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch officers count');
        }
      } else {
        throw Exception(
          'Failed to fetch officers count: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }
}
