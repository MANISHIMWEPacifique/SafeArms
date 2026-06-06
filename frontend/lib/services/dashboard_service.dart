// Dashboard Service
// API calls for dashboard statistics and data

import '../config/api_config.dart';
import 'api_client.dart';

class DashboardService {
  // Get all dashboard statistics based on user role
  Future<Map<String, dynamic>> getDashboardStats({
    bool includeRecent = true,
  }) async {
    try {
      final url = includeRecent
          ? ApiConfig.dashboardUrl
          : '${ApiConfig.dashboardUrl}?include_recent=false';
      final data = await ApiClient.get(url);
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching dashboard data: $e');
    }
  }
}
