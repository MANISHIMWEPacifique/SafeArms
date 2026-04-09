// Settings Service - API calls for system configuration
// SafeArms Frontend

import '../config/api_config.dart';
import 'api_client.dart';

class SettingsService {
  // Get system settings
  Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final token = await ApiClient.getToken();
      if (token == null) {
        return {}; // Silently fall back if not authenticated
      }
      final data = await ApiClient.get('${ApiConfig.apiBase}/settings');
      return data['data'] ?? {};
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return {}; // Expected for users without settings permissions.
      }
      throw Exception('Error fetching settings: $e');
    } catch (e) {
      throw Exception('Error fetching settings: $e');
    }
  }

  // Update system settings
  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      await ApiClient.put('${ApiConfig.apiBase}/settings', body: settings);
      return true;
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
      List<String> queryParams = [];
      if (startDate != null) {
        queryParams.add('start_date=${startDate.toIso8601String()}');
      }
      if (endDate != null) {
        queryParams.add('end_date=${endDate.toIso8601String()}');
      }
      if (userId != null) queryParams.add('user_id=$userId');
      if (action != null) queryParams.add('action=$action');
      if (status != null) queryParams.add('status=$status');

      var url = '${ApiConfig.apiBase}/audit-logs';
      if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';

      final data = await ApiClient.get(url);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching audit logs: $e');
    }
  }

  // Get system health status
  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final data = await ApiClient.get('${ApiConfig.apiBase}/system/health');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching system health: $e');
    }
  }

  // Get ML model configuration
  Future<Map<String, dynamic>> getMLConfiguration() async {
    try {
      final data = await ApiClient.get('${ApiConfig.apiBase}/ml/config');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching ML config: $e');
    }
  }

  // Update ML model configuration
  Future<bool> updateMLConfiguration(Map<String, dynamic> config) async {
    try {
      await ApiClient.put('${ApiConfig.apiBase}/ml/config', body: config);
      return true;
    } catch (e) {
      throw Exception('Error updating ML config: $e');
    }
  }

  // Trigger ML model training (longer timeout needed)
  Future<Map<String, dynamic>> trainMLModel({
    bool force = false,
    bool wait = true,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.apiBase}/ml/train',
        body: {
          'force': force,
          'wait': wait,
        },
        timeout: const Duration(seconds: 120),
      );
      return data;
    } catch (e) {
      throw Exception('Error training ML model: $e');
    }
  }

  // Get ML model status (active model, training samples, etc.)
  Future<Map<String, dynamic>> getMLStatus() async {
    try {
      final data = await ApiClient.get('${ApiConfig.apiBase}/ml/ml-status');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching ML status: $e');
    }
  }
}
