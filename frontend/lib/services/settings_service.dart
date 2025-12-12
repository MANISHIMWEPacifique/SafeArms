// Settings Service - API calls for system configuration
// SafeArms Frontend

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import './auth_service.dart';

class SettingsService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get system settings
  Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/settings'),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load settings');
      }
    } catch (e) {
      throw Exception('Error fetching settings: $e');
    }
  }

  // Update system settings
  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/settings'),
        headers: headers,
        body: json.encode(settings),
      ).timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error updating settings: $e');
    }
  }

  // Get audit logs
  Future<List<Map<String, dynamic>>> getAuditLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    String? action,
    String? status,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}/api/audit-logs';
      
      List<String> queryParams = [];
      if (startDate != null) queryParams.add('start_date=${startDate.toIso8601String()}');
      if (endDate != null) queryParams.add('end_date=${endDate.toIso8601String()}');
      if (userId != null) queryParams.add('user_id=$userId');
      if (action != null) queryParams.add('action=$action');
      if (status != null) queryParams.add('status=$status');
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load audit logs');
      }
    } catch (e) {
      throw Exception('Error fetching audit logs: $e');
    }
  }

  // Get system health status
  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/system/health'),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load system health');
      }
    } catch (e) {
      throw Exception('Error fetching system health: $e');
    }
  }

  // Get ML model configuration
  Future<Map<String, dynamic>> getMLConfiguration() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/ml/config'),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load ML config');
      }
    } catch (e) {
      throw Exception('Error fetching ML config: $e');
    }
  }

  // Update ML model configuration
  Future<bool> updateMLConfiguration(Map<String, dynamic> config) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/ml/config'),
        headers: headers,
        body: json.encode(config),
      ).timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error updating ML config: $e');
    }
  }

  // Trigger ML model training
  Future<bool> trainMLModel() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/ml/train'),
        headers: headers,
      ).timeout(const Duration(seconds: 120)); // Longer timeout for training

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error training ML model: $e');
    }
  }
}
