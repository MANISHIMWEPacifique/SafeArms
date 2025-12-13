// Dashboard Provider
// State management for dashboard statistics

import 'package:flutter/foundation.dart';
import '../services/dashboard_service.dart';

class DashboardProvider with ChangeNotifier {
  final DashboardService _dashboardService = DashboardService();

  Map<String, dynamic>? _dashboardStats;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get dashboardStats => _dashboardStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Convenience getters for common stats
  int get totalUsersCount => _dashboardStats?['total_users'] ?? 0;
  int get activeUnitsCount => _dashboardStats?['active_units'] ?? 0;
  int get activeCustodyCount => _dashboardStats?['active_custody'] ?? 0;
  int get officersCount => _dashboardStats?['officers_count'] ?? 0;
  Map<String, dynamic>? get firearmsStats => _dashboardStats?['firearms'];
  List<dynamic>? get anomaliesStats => _dashboardStats?['anomalies'];
  Map<String, dynamic>? get pendingApprovals =>
      _dashboardStats?['pending_approvals'];
  List<dynamic> get recentCustodyActivity =>
      _dashboardStats?['recent_custody'] ?? [];

  // Load all dashboard statistics with one API call
  Future<void> loadDashboardStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboardStats = await _dashboardService.getDashboardStats();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _dashboardStats = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
