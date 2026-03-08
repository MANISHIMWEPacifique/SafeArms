// Dashboard Service
// API calls for dashboard statistics and data

import '../config/api_config.dart';
import 'api_client.dart';

class DashboardService {
  // Get all dashboard statistics based on user role
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final data = await ApiClient.get(ApiConfig.dashboardUrl);
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching dashboard data: $e');
    }
  }
}
